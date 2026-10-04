class_name PartnerRoster
extends Node
## ทีมคู่หูสูงสุด 3 ตัว ใช้ PartnerMonster บนสนามเพียง Node เดียว
## Resource คือข้อมูลต้นแบบ; HP/MP/EXP/คูลดาวน์แยกเก็บของแต่ละสมาชิก
signal changed
signal switched(index: int)
signal feedback(message: String)
const CAPACITY: int = 3
var tamer: Tamer
var partner: PartnerMonster
var members: Array[Dictionary] = []
var active_index: int = 0
var initialized: bool = false
var _switching: bool = false
var _legacy_family: StarterPartnerData

func configure(player: Tamer) -> void:
    # ผูกกับ Node เดิม จึงไม่ทำให้ Loot, EXP, Safe Zone หรือเป้าศัตรูอ้างคู่หูที่ถูก free
    tamer = player
    partner = player.partner
    GameManager.ensure_catalog()
    _legacy_family = StarterPartnerData.new()
    _legacy_family.id = &"legacy"
    _legacy_family.forms.assign(partner.forms)
    _legacy_family.display_name = partner.forms[0].monster_name
    for source: Signal in [partner.hp_changed, partner.mp_changed, partner.form_changed,
            partner.state_changed, partner.progress.progress_changed]:
        source.connect(_on_actor_changed)

func family(id: StringName) -> StarterPartnerData:
    if id == &"legacy":
        return _legacy_family
    return GameManager.catalog.starter_by_id(id)

func initialize(saved: Dictionary = {}) -> void:
    # World เรียกหลังโหลดเซฟเดิม และก่อน bind กระเป๋า เพื่อไม่เขียนข้อมูลเก่าทับเซฟทีม
    members.clear()
    var raw: Variant = saved.get("members", [])
    if raw is Array:
        for entry: Variant in raw:
            if not (entry is Dictionary) or members.size() >= CAPACITY:
                continue
            var id := StringName(str(entry.get("id", "")))
            var data: StarterPartnerData = family(id)
            if data == null or data.forms.is_empty() or has_partner(id):
                continue
            members.append(entry.duplicate(true))
    if members.is_empty():
        # เซฟ v22 ที่มีคู่หูเดียว: ย้ายข้อมูลตัวเดิมครบ ไม่แจกเพื่อนเพิ่มเอง
        var id: StringName = &"legacy"
        for starter: StarterPartnerData in GameManager.catalog.starters:
            if not starter.forms.is_empty() and starter.forms[0] == partner.forms[0]:
                id = starter.id
                break
        members.append(_capture(id))
        active_index = 0
    else:
        active_index = 0
        for index: int in range(members.size()):
            if str(members[index].id) == str(saved.get("active_id", "")):
                active_index = index
                break
        _switching = true
        _apply_member(members[active_index])
        _switching = false
    initialized = true
    _capture_active()
    changed.emit()

func has_partner(id: StringName) -> bool:
    return members.any(func(member: Dictionary) -> bool: return str(member.id) == String(id))

func add_partner(id: StringName) -> bool:
    # จุดเชื่อม Hatching/Quest reward; ไม่อนุญาตเกิน 3 ตัวหรือใช้ ID ที่ไม่มีใน Catalog
    var data: StarterPartnerData = family(id)
    if not initialized or data == null or data.forms.is_empty() or has_partner(id) or members.size() >= CAPACITY:
        return false
    var rookie: MonsterData = data.forms[0]
    var hp_max: int = rookie.max_hp + int(tamer.equipment.total_bonuses().partner_hp)
    members.append({"id":String(id), "form_id":String(rookie.id), "hp":hp_max,
        "max_hp":hp_max, "mp":partner.digimon_max_mp, "egg":false,
        "progress":{"level":1, "exp":0}, "cooldowns":{}, "basic_cooldown":0.0})
    changed.emit()
    return true

func available_hatches() -> Array[StringName]:
    # คืนเฉพาะสายที่ยังไม่มี ผู้เล่นไม่เสียไข่ถ้าทีมเต็ม
    var result: Array[StringName] = []
    if not initialized or members.size() >= CAPACITY:
        return result
    for data: StarterPartnerData in GameManager.catalog.starters:
        if not has_partner(data.id):
            result.append(data.id)
    return result

func select_member(index: int) -> bool:
    # ตรวจอีกครั้งฝั่ง gameplay ป้องกัน callback UI เก่า/คำสั่งระหว่าง cutscene หรือ modal
    if not initialized or _switching or index < 0 or index >= members.size() or index == active_index:
        return false
    if get_tree().paused or partner.evolution_busy:
        feedback.emit("รอหน้าต่างหรือคัตซีนจบก่อนสลับคู่หู")
        return false
    var candidate: StarterPartnerData = family(StringName(members[index].id))
    if candidate == null or candidate.forms.is_empty():
        return false
    _capture_active()
    var previous_index: int = active_index
    _switching = true
    if not _apply_member(members[index]):
        _apply_member(members[previous_index])
        _switching = false
        return false
    active_index = index
    _switching = false
    _capture_active()
    changed.emit()
    switched.emit(index)
    tamer.save_party_progress()
    return true

func _apply_member(entry: Dictionary) -> bool:
    var data: StarterPartnerData = family(StringName(entry.id))
    if data == null or data.forms.is_empty():
        return false
    # ยกเลิก wind-up/คำสั่งสกิลค้างก่อนสวมสมาชิกใหม่ ไม่ส่ง impact ของตัวเก่าไปสร้างดาเมจ
    partner.auto_battle = false
    partner.cancel_page_skill()
    partner.cancel_battle()
    tamer.set_target(null)
    partner.velocity = Vector2.ZERO
    if partner._morph_tween != null and partner._morph_tween.is_valid():
        partner._morph_tween.kill()
    partner.progress.restore_data(entry.get("progress", {}) if entry.get("progress") is Dictionary else {})
    partner.forms.assign(data.forms)
    var form: MonsterData = data.forms[0]
    for possible: MonsterData in data.forms:
        if String(possible.id) == str(entry.get("form_id", "")) and QuestManager.can_use_form(possible) and tamer.can_battle():
            form = possible
            break
    if not form.validation_error().is_empty():
        return false
    partner.state = PartnerMonster.State.IDLE
    partner._internal_load = true
    var loaded: bool = partner.load_monster_data(form, false)
    partner._internal_load = false
    if not loaded:
        return false
    partner.sprite.show()
    partner.sprite.modulate = Color.WHITE
    partner.egg_sprite.hide()
    var saved_hp: int = maxi(0, int(entry.get("hp", 0)))
    if String(form.id) != str(entry.get("form_id", "")):
        # Tamer อ่อนแอ/เควสต์ยังล็อกจึงต้องลดร่าง: รักษา %HP ไม่ยกเลือดของร่างใหญ่ใส่ Rookie
        var ratio: float = clampf(float(saved_hp) / maxi(1, int(entry.get("max_hp", partner.max_hp))), 0, 1)
        saved_hp = maxi(1, roundi(partner.max_hp * ratio)) if saved_hp > 0 else 0
    partner.hp = clampi(saved_hp, 0, partner.max_hp)
    partner.digimon_mp = _finite_number(entry.get("mp", 0), 0, partner.digimon_max_mp)
    partner.skill_cooldowns.clear()
    var cooldowns: Variant = entry.get("cooldowns", {})
    if cooldowns is Dictionary:
        for key: Variant in cooldowns:
            partner.skill_cooldowns[StringName(str(key))] = _finite_number(cooldowns[key], 0, 3600)
    partner._basic_cooldown = _finite_number(entry.get("basic_cooldown", 0), 0, 3600)
    if bool(entry.get("egg", false)) or partner.hp == 0:
        partner.enter_fainted(false) # ใช้ร่างไข่เดิม ไม่ queue_free และไม่แจก HP ฟรี
    partner.hp_changed.emit(partner.hp, partner.max_hp)
    partner.mp_changed.emit(partner.digimon_mp, partner.digimon_max_mp)
    partner.state_changed.emit(partner.state)
    return true

func _finite_number(raw: Variant, minimum: float, maximum: float) -> float:
    return clampf(float(raw), minimum, maximum) if (raw is int or raw is float) and is_finite(float(raw)) else minimum

func _capture(id: StringName) -> Dictionary:
    var cooldowns: Dictionary = {}
    for key: Variant in partner.skill_cooldowns:
        cooldowns[String(key)] = float(partner.skill_cooldowns[key])
    return {"id":String(id), "form_id":String(partner.current_form.id), "hp":partner.hp,
        "max_hp":partner.max_hp, "mp":partner.digimon_mp, "egg":not partner.is_alive(),
        "progress":partner.progress.get_save_data(), "cooldowns":cooldowns,
        "basic_cooldown":partner._basic_cooldown}

func _capture_active() -> void:
    if not members.is_empty():
        members[active_index] = _capture(StringName(members[active_index].id))

func _on_actor_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
    # รับหลาย Signal ใน callback เดียว แต่ไม่เขียนสถานะชั่วคราวระหว่างการสลับตัว
    if initialized and not _switching:
        _capture_active()
        changed.emit()

func _process(delta: float) -> void:
    # คูลดาวน์ของตัวสำรองยังลดในเวลาเกม; inherited process mode หยุดเมื่อเกม pause
    if not initialized or _switching:
        return
    for index: int in range(members.size()):
        if index == active_index:
            continue
        var cooldowns: Variant = members[index].get("cooldowns", {})
        if cooldowns is Dictionary:
            for key: Variant in cooldowns:
                cooldowns[key] = maxf(0, _finite_number(cooldowns[key], 0, 3600) - delta)
        members[index]["basic_cooldown"] = maxf(0, _finite_number(members[index].get("basic_cooldown", 0), 0, 3600) - delta)

func get_save_data() -> Dictionary:
    if not initialized:
        return {}
    if not _switching:
        _capture_active()
    return {"version":1, "active_id":members[active_index].id, "members":members.duplicate(true)}
