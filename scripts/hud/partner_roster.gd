class_name PartnerRoster
extends Node
## ทีมคู่หูสูงสุด 3 ตัว ใช้ PartnerMonster บนสนามเพียง Node เดียว
## HP/MP/เลเวล/EXP/คูลดาวน์แยกแต่ละสมาชิก เพื่อให้ Jogress ตรวจ Lv90 ของทั้งสองตัวจริง
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
    tamer = player
    partner = player.partner
    GameManager.ensure_catalog()

    _legacy_family = StarterPartnerData.new()
    _legacy_family.id = &"legacy"
    _legacy_family.forms.assign(partner.forms)
    _legacy_family.display_name = partner.forms[0].monster_name

    # สถานะเฉพาะตัวของสมาชิก
    for source: Signal in [
        partner.hp_changed,
        partner.mp_changed,
        partner.form_changed,
        partner.state_changed
    ]:
        source.connect(_on_actor_changed)

    # Level/EXP เป็น progression สมาชิก ของทั้งทีม
    partner.progress.progress_changed.connect(_on_partner_progress_changed)


func family(id: StringName) -> StarterPartnerData:
    if id == &"legacy":
        return _legacy_family
    return GameManager.catalog.starter_by_id(id)


func initialize(saved: Dictionary = {}) -> void:
    # World เรียกหลัง restore partner_progress เดิมแล้ว
    # จึงสามารถ migrate เซฟเก่าที่เคยเก็บเลเวลแยกสมาชิกได้โดยไม่ทำเลเวลหาย
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
            members.append((entry as Dictionary).duplicate(true))

    # เซฟ v2 เคยใช้เลเวลร่วม: รักษาค่าที่ผู้เล่นมีอยู่เมื่อย้ายมา v3
    # เซฟที่มี progress รายตัวอยู่แล้วต้องไม่เอาค่าสูงสุดของตัวอื่นมาทับ
    for member: Dictionary in members:
        if not member.get("progress") is Dictionary:
            var legacy: Variant = saved.get("shared_progress", {"level": 1, "exp": 0})
            member["progress"] = _sanitize_progress(legacy if legacy is Dictionary else {})

    # กันสัญญาณจากการโหลดข้อมูลทับ snapshot ของสมาชิกเดิม
    _switching = true

    if members.is_empty():
        # เซฟเก่าที่มีคู่หูเดียว
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
            if str(members[index].get("id", "")) == str(saved.get("active_id", "")):
                active_index = index
                break
        if not _apply_member(members[active_index].duplicate(true)):
            push_warning("PartnerRoster: restore สมาชิก active ไม่สำเร็จ ใช้ actor ปัจจุบันแทน")

    _switching = false
    initialized = true
    _capture_active()
    changed.emit()


func _sanitize_progress(raw: Dictionary) -> Dictionary:
    var level: int = clampi(int(raw.get("level", 1)), 1, EvolutionRules.MAX_LEVEL)
    var exp: int = maxi(0, int(raw.get("exp", 0)))
    if level >= EvolutionRules.MAX_LEVEL:
        exp = 0
    return {"level": level, "exp": exp}


func has_partner(id: StringName) -> bool:
    return members.any(
        func(member: Dictionary) -> bool:
            return str(member.get("id", "")) == String(id)
    )


func active_member_id() -> StringName:
    if not initialized or members.is_empty():
        return &""
    _capture_active()
    return StringName(str(members[active_index].get("id", "")))


func member_level(id: StringName) -> int:
    if not initialized:
        return 0
    _capture_active()
    for member: Dictionary in members:
        if StringName(member.get("id", "")) == id:
            return clampi(int(member.get("progress", {}).get("level", 1)), 1, EvolutionRules.MAX_LEVEL)
    return 0

func member_alive(id: StringName) -> bool:
    _capture_active()
    for member: Dictionary in members:
        if StringName(member.get("id", "")) == id:
            return not bool(member.get("egg", false)) and int(member.get("hp", 0)) > 0
    return false

func add_partner(id: StringName) -> bool:
    # สมาชิกใหม่เริ่ม Lv1; การฝึกของตัวเดิมไม่ทำให้ตัวใหม่ปลด Jogress ทันที
    var data: StarterPartnerData = family(id)
    if not initialized or data == null or data.forms.is_empty() or has_partner(id) or members.size() >= CAPACITY:
        return false

    var rookie: MonsterData = data.forms[0]
    var hp_max: int = rookie.max_hp + int(tamer.equipment.total_bonuses().partner_hp)

    members.append({
        "id": String(id),
        "form_id": String(rookie.id),
        "hp": hp_max,
        "max_hp": hp_max,
        "mp": partner.digimon_max_mp,
        "egg": false,
        "progress": {"level": 1, "exp": 0},
        "cooldowns": {},
        "basic_cooldown": 0.0
    })

    changed.emit()
    return true


func available_hatches() -> Array[StringName]:
    var result: Array[StringName] = []
    if not initialized or members.size() >= CAPACITY:
        return result

    for data: StarterPartnerData in GameManager.catalog.starters:
        if not has_partner(data.id):
            result.append(data.id)

    return result


func select_member(index: int) -> bool:
    if not initialized or _switching or index < 0 or index >= members.size() or index == active_index:
        return false

    if get_tree().paused or partner.evolution_busy or partner.current_form.id == &"omegamon":
        feedback.emit("ปิดหน้าต่าง/รอคัตซีน หรือแยก Omegamon ก่อนสลับคู่หู")
        return false

    var candidate: StarterPartnerData = family(StringName(members[index].get("id", "")))
    if candidate == null or candidate.forms.is_empty():
        return false

    # เก็บสถานะตัวเดิมก่อนโหลดสมาชิกเป้าหมาย
    _capture_active()

    var previous_index: int = active_index
    var previous_snapshot: Dictionary = members[previous_index].duplicate(true)
    var target_snapshot: Dictionary = members[index].duplicate(true)

    _switching = true

    if not _apply_member(target_snapshot):
        _apply_member(previous_snapshot)
        _switching = false
        return false

    active_index = index
    _switching = false

    _capture_active()

    changed.emit()
    switched.emit(index)
    feedback.emit("สลับคู่หูเป็น %s • Lv%d" % [candidate.display_name, partner.progress.level])
    tamer.save_party_progress()
    return true


func _apply_member(entry: Dictionary) -> bool:
    var data: StarterPartnerData = family(StringName(entry.get("id", "")))
    if data == null or data.forms.is_empty():
        return false

    # คืนเลเวลของสมาชิกเป้าหมายก่อนคำนวณสเตตัส
    partner.progress.restore_data(entry.get("progress", {}))

    partner.auto_battle = false
    partner.cancel_page_skill()
    partner.cancel_battle()
    tamer.set_target(null)
    partner.velocity = Vector2.ZERO

    if partner._morph_tween != null and partner._morph_tween.is_valid():
        partner._morph_tween.kill()

    partner.forms.assign(data.forms)

    var form: MonsterData = data.forms[0]
    # โหลดเฉพาะร่างที่เซฟไว้และเลเวลอนุญาต ไม่แจกการวิวัฒนาการฟรีตอนสลับตัว
    for index: int in range(data.forms.size()):
        var possible: MonsterData = data.forms[index]
        if possible != null and String(possible.id) == str(entry.get("form_id", "")) and EvolutionRules.can_use_form(partner.progress.level, index) and tamer.can_battle():
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
        # ถ้าร่างที่เซฟไว้สูงเกิน เลเวลสมาชิก ให้ลดร่างแต่รักษา %HP
        var ratio: float = clampf(
            float(saved_hp) / maxi(1, int(entry.get("max_hp", partner.max_hp))),
            0.0,
            1.0
        )
        saved_hp = maxi(1, roundi(partner.max_hp * ratio)) if saved_hp > 0 else 0

    partner.hp = clampi(saved_hp, 0, partner.max_hp)
    partner.digimon_mp = _finite_number(
        entry.get("mp", 0),
        0,
        partner.digimon_max_mp
    )

    partner.skill_cooldowns.clear()
    var cooldowns: Variant = entry.get("cooldowns", {})
    if cooldowns is Dictionary:
        for key: Variant in cooldowns:
            partner.skill_cooldowns[StringName(str(key))] = _finite_number(
                cooldowns[key],
                0,
                3600
            )

    partner._basic_cooldown = _finite_number(
        entry.get("basic_cooldown", 0),
        0,
        3600
    )

    if bool(entry.get("egg", false)) or partner.hp == 0:
        partner.enter_fainted(false)

    partner.hp_changed.emit(partner.hp, partner.max_hp)
    partner.mp_changed.emit(partner.digimon_mp, partner.digimon_max_mp)
    partner.state_changed.emit(partner.state)

    return true


func _finite_number(raw: Variant, minimum: float, maximum: float) -> float:
    if (raw is int or raw is float) and is_finite(float(raw)):
        return clampf(float(raw), minimum, maximum)
    return minimum


func _capture(id: StringName) -> Dictionary:
    var cooldowns: Dictionary = {}

    for key: Variant in partner.skill_cooldowns:
        cooldowns[String(key)] = float(partner.skill_cooldowns[key])

    # Omegamon เป็นสถานะชั่วคราว ไม่ยัด ID นอกสายร่างลงสมาชิก
    # เก็บร่าง Mega และ %HP เทียบฐาน Mega เพื่อให้เซฟยังโหลดได้แม้ fusion ใช้ไม่ได้
    var saved_form: MonsterData = partner.current_form
    var saved_max: int = partner.max_hp
    var saved_hp: int = partner.hp
    if saved_form.id == &"omegamon":
        saved_form = family(id).forms[3]
        saved_max = partner.max_hp - partner.current_form.max_hp + saved_form.max_hp
        saved_hp = maxi(1, roundi(float(partner.hp) / partner.max_hp * saved_max)) if partner.hp > 0 else 0
    return {
        "id": String(id),
        "form_id": String(saved_form.id),
        "hp": saved_hp,
        "max_hp": saved_max,
        "mp": partner.digimon_mp,
        "egg": not partner.is_alive(),
        "progress": partner.progress.get_save_data(),
        "cooldowns": cooldowns,
        "basic_cooldown": partner._basic_cooldown
    }


func _capture_active() -> void:
    if members.is_empty() or _switching:
        return

    # actor ปัจจุบันคือ source of truth ของ เลเวลสมาชิก ระหว่าง gameplay
    members[active_index] = _capture(
        StringName(members[active_index].get("id", ""))
    )


func _on_partner_progress_changed(
        _level: int,
        _current_exp: int,
        _max_exp: int
) -> void:
    # EXP เปลี่ยนเฉพาะสมาชิกบนสนาม ไม่กระจายเลเวลไปตัวสำรอง

    if initialized and not _switching:
        _capture_active()
        changed.emit()


func _on_actor_changed(
        _a: Variant = null,
        _b: Variant = null,
        _c: Variant = null
) -> void:
    if initialized and not _switching:
        _capture_active()
        changed.emit()


func _process(delta: float) -> void:
    # คูลดาวน์ยังแยกเป็นรายตัวและลดต่อแม้อยู่ตัวสำรอง
    if not initialized or _switching:
        return

    for index: int in range(members.size()):
        if index == active_index:
            continue

        var cooldowns: Variant = members[index].get("cooldowns", {})
        if cooldowns is Dictionary:
            for key: Variant in cooldowns:
                cooldowns[key] = maxf(
                    0,
                    _finite_number(cooldowns[key], 0, 3600) - delta
                )

        members[index]["basic_cooldown"] = maxf(
            0,
            _finite_number(
                members[index].get("basic_cooldown", 0),
                0,
                3600
            ) - delta
        )


func get_save_data() -> Dictionary:
    if not initialized:
        return {}

    if not _switching:
        _capture_active()


    return {
        "version": 3,
        "active_id": members[active_index].get("id", ""),
        "members": members.duplicate(true)
    }
