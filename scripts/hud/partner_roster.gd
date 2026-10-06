class_name PartnerRoster
extends Node
## ทีมคู่หูสูงสุด 3 ตัว ใช้ PartnerMonster บนสนามเพียง Node เดียว
## สมาชิกแต่ละตัวเก็บ HP/MP/คูลดาวน์/Level/EXP แยกจากกัน แม้ใช้ PartnerMonster บนสนาม Node เดียว
signal changed
signal switched(index: int)
signal feedback(message: String)

const CAPACITY: int = 3
const MAX_ENHANCEMENT: int = 5
const ENHANCEMENT_EGG_COST: int = 5
const ENHANCEMENT_SUCCESS: Array[float] = [1.0, 0.85, 0.70, 0.55, 0.40]
const ENHANCEMENT_HP_PER_LEVEL: float = 0.06
const ENHANCEMENT_ATTACK_PER_LEVEL: float = 0.05
const ENHANCEMENT_SPEED_PER_LEVEL: float = 0.015

var tamer: Tamer
var partner: PartnerMonster
var members: Array[Dictionary] = []
## Storage ไม่จำกัดจำนวนและรองรับสายพันธุ์ซ้ำด้วย uid ต่อสมาชิก
var storage: Array[Dictionary] = []
var active_index: int = 0
var initialized: bool = false
var _switching: bool = false
var _legacy_family: StarterPartnerData
var _enhancement_rng := RandomNumberGenerator.new()

func configure(player: Tamer) -> void:
    tamer = player
    partner = player.partner
    GameManager.ensure_catalog()
    _enhancement_rng.randomize()

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

    # Level/EXP ของ actor ปัจจุบันจะถูกบันทึกกลับเฉพาะสมาชิก active เท่านั้น
    partner.progress.progress_changed.connect(_on_partner_progress_changed)


func family(id: StringName) -> StarterPartnerData:
    if id == &"legacy":
        return _legacy_family
    return GameManager.catalog.starter_by_id(id)


func initialize(saved: Dictionary = {}) -> void:
    # Roster v4: แต่ละ Digimon มี Level/EXP ของตัวเอง
    # เซฟ v3 ที่เคยใช้ shared_progress จะถูกคัดลอกเป็นค่าเริ่มต้นให้สมาชิกเดิมครั้งเดียว
    members.clear()
    storage.clear()

    var legacy_progress: Dictionary = _legacy_progress_fallback(saved)

    var raw: Variant = saved.get("members", [])
    if raw is Array:
        for entry: Variant in raw:
            if not (entry is Dictionary) or members.size() >= CAPACITY:
                continue
            var id := StringName(str(entry.get("id", "")))
            var data: StarterPartnerData = family(id)
            if data == null or data.forms.is_empty():
                continue
            var member: Dictionary = (entry as Dictionary).duplicate(true)
            _ensure_uid(member)
            member["progress"] = _entry_progress(member, legacy_progress)
            member["unlocked_forms"] = _sanitize_unlocked_forms(member, data)
            member["enhancement"] = clampi(int(member.get("enhancement", 0)), 0, MAX_ENHANCEMENT)
            members.append(member)

    var raw_storage: Variant = saved.get("storage", [])
    if raw_storage is Array:
        for entry: Variant in raw_storage:
            if not (entry is Dictionary):
                continue
            var stored_id := StringName(str(entry.get("id", "")))
            var stored_data: StarterPartnerData = family(stored_id)
            if stored_data == null or stored_data.forms.is_empty():
                continue
            var stored: Dictionary = (entry as Dictionary).duplicate(true)
            _ensure_uid(stored)
            stored["progress"] = _entry_progress(stored, legacy_progress)
            stored["unlocked_forms"] = _sanitize_unlocked_forms(stored, stored_data)
            stored["enhancement"] = clampi(int(stored.get("enhancement", 0)), 0, MAX_ENHANCEMENT)
            storage.append(stored)

    _switching = true

    if members.is_empty():
        # เซฟเก่าที่มีคู่หูเดียว ใช้ progress ของ actor ที่ story_world restore ไว้
        var id: StringName = &"legacy"
        for starter: StarterPartnerData in GameManager.catalog.starters:
            if not starter.forms.is_empty() and starter.forms[0] == partner.forms[0]:
                id = starter.id
                break
        var first: Dictionary = _capture(id)
        _ensure_uid(first)
        first["progress"] = _sanitize_progress(partner.progress.get_save_data())
        first["unlocked_forms"] = [String(partner.forms[0].id)]
        members.append(first)
        active_index = 0
    else:
        active_index = 0
        var saved_uid: String = str(saved.get("active_uid", ""))
        for index: int in range(members.size()):
            if (not saved_uid.is_empty() and str(members[index].get("uid", "")) == saved_uid) or (saved_uid.is_empty() and str(members[index].get("id", "")) == str(saved.get("active_id", ""))):
                active_index = index
                break
        if not _apply_member(members[active_index].duplicate(true)):
            push_warning("PartnerRoster: restore สมาชิก active ไม่สำเร็จ ใช้ actor ปัจจุบันแทน")

    _switching = false
    initialized = true
    _capture_active()
    changed.emit()


func _legacy_progress_fallback(saved: Dictionary) -> Dictionary:
    # Migration v3: shared_progress เดิมกลายเป็น progress เริ่มต้นของสมาชิกที่ไม่มีข้อมูลเฉพาะตัว
    var saved_shared: Variant = saved.get("shared_progress", null)
    if saved_shared is Dictionary and saved_shared.has("level"):
        return _sanitize_progress(saved_shared)
    return _sanitize_progress(partner.progress.get_save_data())


func _entry_progress(entry: Dictionary, fallback: Dictionary) -> Dictionary:
    var raw_progress: Variant = entry.get("progress", null)
    if raw_progress is Dictionary and raw_progress.has("level"):
        return _sanitize_progress(raw_progress)
    return fallback.duplicate(true)


func _sanitize_progress(raw: Dictionary) -> Dictionary:
    var level: int = clampi(int(raw.get("level", 1)), 1, EvolutionRules.MAX_LEVEL)
    var exp: int = maxi(0, int(raw.get("exp", 0)))
    if level >= EvolutionRules.MAX_LEVEL:
        exp = 0
    return {"level": level, "exp": exp}


func _sanitize_unlocked_forms(entry: Dictionary, data: StarterPartnerData) -> Array[String]:
    var result: Array[String] = []
    if data == null or data.forms.is_empty():
        return result
    result.append(String(data.forms[0].id))
    var raw: Variant = entry.get("unlocked_forms", [])
    if raw is Array:
        for value: Variant in raw:
            var form_id: String = str(value)
            if form_id.is_empty() or form_id in result:
                continue
            for form: MonsterData in data.forms:
                if form != null and String(form.id) == form_id:
                    result.append(form_id)
                    break
    return result

func is_active_form_unlocked(form_id: StringName) -> bool:
    if not initialized or members.is_empty() or active_index < 0 or active_index >= members.size():
        return false
    var raw: Variant = members[active_index].get("unlocked_forms", [])
    return raw is Array and String(form_id) in raw

func unlock_active_form(form_id: StringName) -> bool:
    if not initialized or members.is_empty() or active_index < 0 or active_index >= members.size():
        return false
    var data: StarterPartnerData = family(StringName(str(members[active_index].get("id", ""))))
    if data == null:
        return false
    var valid: bool = false
    for form: MonsterData in data.forms:
        if form != null and form.id == form_id:
            valid = true
            break
    if not valid:
        return false
    var unlocked: Array[String] = _sanitize_unlocked_forms(members[active_index], data)
    if String(form_id) not in unlocked:
        unlocked.append(String(form_id))
    members[active_index]["unlocked_forms"] = unlocked
    changed.emit()
    tamer.save_party_progress()
    return true

func _make_uid(id: StringName) -> String:
    return "%s-%d-%d" % [String(id), Time.get_ticks_usec(), randi()]

func _ensure_uid(entry: Dictionary) -> void:
    if str(entry.get("uid", "")).is_empty():
        entry["uid"] = _make_uid(StringName(str(entry.get("id", "partner"))))

func has_partner(id: StringName) -> bool:
    return members.any(
        func(member: Dictionary) -> bool:
            return str(member.get("id", "")) == String(id)
    )


func active_member_id() -> StringName:
    if not initialized or members.is_empty():
        return &""
    # Fusion/UI อาจถามระหว่าง _apply_member; ห้าม capture actor ตัวใหม่ลงสมาชิกตัวเก่า
    if not _switching:
        _capture_active()
    return StringName(str(members[active_index].get("id", "")))


func member_level(id: StringName) -> int:
    # ถ้ามีสายพันธุ์ซ้ำ คืนเลเวลสูงสุดของตัวที่อยู่ใน Party
    # Fusion จึงยังเช็ก Agumon/Gabumon แยกตัวได้โดยไม่ใช้ Shared Level
    if not initialized:
        return 0
    var best: int = 0
    for member: Dictionary in members:
        if str(member.get("id", "")) != String(id):
            continue
        var progress_data: Dictionary = _entry_progress(member, {"level":1, "exp":0})
        best = maxi(best, int(progress_data.get("level", 1)))
    return best


func current_enhancement_level() -> int:
    if not initialized or members.is_empty() or active_index < 0 or active_index >= members.size():
        return 0
    return clampi(int(members[active_index].get("enhancement", 0)), 0, MAX_ENHANCEMENT)


func enhancement_level(entry: Dictionary) -> int:
    return clampi(int(entry.get("enhancement", 0)), 0, MAX_ENHANCEMENT)


func enhancement_success_chance(current_level: int) -> float:
    var safe_level: int = clampi(current_level, 0, MAX_ENHANCEMENT)
    if safe_level >= MAX_ENHANCEMENT:
        return 0.0
    return ENHANCEMENT_SUCCESS[safe_level]


func enhancement_egg_item_id(partner_id: StringName) -> String:
    if InventoryManager.catalog == null:
        return ""
    for item: ItemData in InventoryManager.catalog.items:
        if item != null and item.item_type == ItemData.ItemType.EGG and item.egg_partner_id == partner_id:
            return item.item_id
    return ""


func enhancement_bonus_text(level: int) -> String:
    var safe_level: int = clampi(level, 0, MAX_ENHANCEMENT)
    return "HP +%d%% • ATK +%d%% • SPD +%.1f%%" % [
        roundi(ENHANCEMENT_HP_PER_LEVEL * safe_level * 100.0),
        roundi(ENHANCEMENT_ATTACK_PER_LEVEL * safe_level * 100.0),
        ENHANCEMENT_SPEED_PER_LEVEL * safe_level * 100.0
    ]


func enhance_member(index: int, in_party: bool) -> bool:
    if not initialized:
        feedback.emit("ระบบ Digimon ยังไม่พร้อม")
        return false
    var source: Array[Dictionary] = members if in_party else storage
    if index < 0 or index >= source.size():
        feedback.emit("ไม่พบ Digimon ที่เลือก")
        return false

    var entry: Dictionary = source[index]
    var current: int = enhancement_level(entry)
    if current >= MAX_ENHANCEMENT:
        feedback.emit("Digimon ตัวนี้ Enhancement +5 สูงสุดแล้ว")
        return false

    var family_id := StringName(str(entry.get("id", "")))
    var egg_id: String = enhancement_egg_item_id(family_id)
    if egg_id.is_empty():
        feedback.emit("สายพันธุ์นี้ไม่มี Digitama สำหรับใช้ยกระดับ")
        return false

    var owned: int = InventoryManager.count(egg_id)
    if owned < ENHANCEMENT_EGG_COST:
        var egg: ItemData = InventoryManager.catalog.find_item(egg_id)
        var egg_name: String = egg.item_name if egg != null else egg_id
        feedback.emit("ต้องใช้ %s x%d • มี %d" % [egg_name, ENHANCEMENT_EGG_COST, owned])
        return false

    if not InventoryManager.remove_item(egg_id, ENHANCEMENT_EGG_COST):
        feedback.emit("ใช้ Digitama ไม่สำเร็จ")
        return false

    var target_level: int = current + 1
    var chance: float = enhancement_success_chance(current)
    var success: bool = _enhancement_rng.randf() < chance
    if success:
        entry["enhancement"] = target_level
        source[index] = entry
        if in_party and index == active_index:
            partner.refresh_enhancement_stats()
        changed.emit()
        tamer.save_party_progress()
        feedback.emit("Enhancement สำเร็จ +%d • %s" % [target_level, enhancement_bonus_text(target_level)])
        return true

    changed.emit()
    tamer.save_party_progress()
    feedback.emit("Enhancement +%d ล้มเหลว • Digitama ถูกใช้ 5 ใบ • ระดับยัง +%d" % [target_level, current])
    return false


func add_partner(id: StringName) -> bool:
    # Digimon ใหม่เริ่ม Lv.1 ของตัวเอง ไม่รับเลเวลจากสมาชิกเดิม
    var data: StarterPartnerData = family(id)
    if not initialized or data == null or data.forms.is_empty() or has_partner(id) or members.size() >= CAPACITY:
        return false

    var rookie: MonsterData = data.forms[0]
    var hp_max: int = rookie.max_hp + int(tamer.equipment.total_bonuses().partner_hp)

    members.append({
        "uid": _make_uid(id),
        "id": String(id),
        "form_id": String(rookie.id),
        "hp": hp_max,
        "max_hp": hp_max,
        "mp": partner.digimon_max_mp,
        "egg": false,
        "progress": {"level": 1, "exp": 0},
        "unlocked_forms": [String(rookie.id)],
        "enhancement": 0,
        "cooldowns": {},
        "basic_cooldown": 0.0
    })

    changed.emit()
    return true


func available_hatches() -> Array[StringName]:
    # Compatibility เท่านั้น ระบบใหม่เลือกชนิดจาก Digitama โดยตรง
    var result: Array[StringName] = []
    if initialized:
        for data: StarterPartnerData in GameManager.catalog.starters:
            result.append(data.id)
    return result

func add_hatched_to_storage(id: StringName) -> bool:
    # ฟักแล้วเข้าคลังเสมอ Party เต็มก็ฟักต่อได้ และเก็บสายพันธุ์ซ้ำได้
    var data: StarterPartnerData = family(id)
    if not initialized or data == null or data.forms.is_empty():
        return false
    var rookie: MonsterData = data.forms[0]
    var hp_max: int = rookie.max_hp + int(tamer.equipment.total_bonuses().partner_hp)
    storage.append({
        "uid": _make_uid(id), "id": String(id), "form_id": String(rookie.id),
        "hp": hp_max, "max_hp": hp_max, "mp": partner.digimon_max_mp, "egg": false,
        "progress": {"level": 1, "exp": 0}, "unlocked_forms": [String(rookie.id)], "enhancement": 0, "cooldowns": {}, "basic_cooldown": 0.0
    })
    changed.emit()
    tamer.save_party_progress()
    return true

func move_storage_to_party(storage_index: int) -> bool:
    # เมธอดนี้เรียกจาก Digimon Archive เท่านั้น
    if not initialized or members.size() >= CAPACITY or storage_index < 0 or storage_index >= storage.size():
        feedback.emit("Party เต็ม 3 ตัว หรือข้อมูลคลังไม่ถูกต้อง")
        return false
    var entry: Dictionary = storage[storage_index]
    if family(StringName(str(entry.get("id", "")))) == null:
        return false
    storage.remove_at(storage_index)
    members.append(entry)
    changed.emit()
    tamer.save_party_progress()
    return true

func move_party_to_storage(party_index: int) -> bool:
    # ต้องเหลืออย่างน้อย 1 ตัวเพื่อให้ Partner actor ในสนามมีข้อมูลเสมอ
    if not initialized or members.size() <= 1 or party_index < 0 or party_index >= members.size():
        feedback.emit("ต้องเหลือคู่หูใน Party อย่างน้อย 1 ตัว")
        return false
    _capture_active()
    var moving: Dictionary = members[party_index].duplicate(true)
    if party_index == active_index:
        var next_index: int = 1 if party_index == 0 else 0
        var previous_index: int = active_index
        var previous_snapshot: Dictionary = members[previous_index].duplicate(true)
        _switching = true
        active_index = next_index
        if not _apply_member(members[next_index].duplicate(true)):
            active_index = previous_index
            _apply_member(previous_snapshot)
            _switching = false
            return false
        members.remove_at(party_index)
        active_index = next_index - 1 if party_index < next_index else next_index
        _switching = false
        switched.emit(active_index)
    else:
        members.remove_at(party_index)
        if party_index < active_index:
            active_index -= 1
    storage.append(moving)
    changed.emit()
    tamer.save_party_progress()
    return true


func select_member(index: int) -> bool:
    if not initialized or _switching or index < 0 or index >= members.size() or index == active_index:
        return false

    if get_tree().paused or partner.evolution_busy:
        feedback.emit("รอหน้าต่างหรือคัตซีนจบก่อนสลับคู่หู")
        return false

    var candidate: StarterPartnerData = family(StringName(members[index].get("id", "")))
    if candidate == null or candidate.forms.is_empty():
        return false

    # เก็บ HP/MP/Form/CD/Level/EXP ของตัวเดิมก่อนสลับ
    _capture_active()

    var previous_index: int = active_index
    var previous_snapshot: Dictionary = members[previous_index].duplicate(true)
    var target_snapshot: Dictionary = members[index].duplicate(true)

    _switching = true

    # ตั้ง active_index เป็นสมาชิกเป้าหมายก่อนโหลด เพื่อให้ Evolution unlock
    # ตรวจ unlocked_forms ของตัวที่จะสลับเข้า ไม่ใช่ของตัวที่กำลังออก
    active_index = index
    if not _apply_member(target_snapshot):
        active_index = previous_index
        _apply_member(previous_snapshot)
        _switching = false
        return false

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

    # โหลด Level/EXP ของสมาชิกเป้าหมายก่อนคำนวณสเตตัสและสิทธิ์ร่าง
    var member_progress: Dictionary = _entry_progress(entry, {"level":1, "exp":0})
    partner.progress.restore_data(member_progress)

    partner.auto_battle = false
    partner.cancel_page_skill()
    partner.cancel_battle()
    tamer.set_target(null)
    partner.velocity = Vector2.ZERO

    if partner._morph_tween != null and partner._morph_tween.is_valid():
        partner._morph_tween.kill()

    partner.forms.assign(data.forms)

    var form: MonsterData = data.forms[0]
    var member_level_value: int = partner.progress.level

    # สมาชิกแต่ละตัวจำร่างของตัวเอง แต่ต้องผ่าน Level ของตัวนั้น + Story unlock
    for index: int in range(data.forms.size()):
        var possible: MonsterData = data.forms[index]
        if possible == null:
            continue
        if index > 0 and not EvolutionRules.can_use_form(member_level_value, index, possible):
            continue
        if index > 0 and not QuestManager.can_use_form(possible):
            continue
        if index > 0:
            var unlocked_forms: Variant = entry.get("unlocked_forms", [])
            if not (unlocked_forms is Array) or String(possible.id) not in unlocked_forms:
                continue

        form = possible
        if String(possible.id) == str(entry.get("form_id", "")):
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
        # ถ้าร่างที่เซฟไว้สูงเกินเลเวลของตัวนี้/Story ให้ลดร่างแต่รักษา %HP
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


func _capture(id: StringName, uid: String = "") -> Dictionary:
    var cooldowns: Dictionary = {}

    for key: Variant in partner.skill_cooldowns:
        cooldowns[String(key)] = float(partner.skill_cooldowns[key])

    return {
        "uid": uid if not uid.is_empty() else _make_uid(id),
        "id": String(id),
        "form_id": String(partner.current_form.id),
        "hp": partner.hp,
        "max_hp": partner.max_hp,
        "mp": partner.digimon_mp,
        "egg": not partner.is_alive(),
        "progress": _sanitize_progress(partner.progress.get_save_data()),
        "enhancement": current_enhancement_level(),
        "cooldowns": cooldowns,
        "basic_cooldown": partner._basic_cooldown
    }


func _capture_active() -> void:
    # ระหว่างสลับ actor ถูกโหลดข้อมูลของ target ก่อน active_index commit
    # การ capture ตอนนี้จะทำให้ Level/EXP ของ target ไปทับสมาชิกเดิม
    if _switching or members.is_empty() or active_index < 0 or active_index >= members.size():
        return

    # actor ปัจจุบันเป็น source of truth เฉพาะสมาชิก active เท่านั้น
    var previous_unlocked: Variant = members[active_index].get("unlocked_forms", [])
    var previous_enhancement: int = enhancement_level(members[active_index])
    members[active_index] = _capture(
        StringName(members[active_index].get("id", "")),
        str(members[active_index].get("uid", ""))
    )
    members[active_index]["unlocked_forms"] = previous_unlocked.duplicate(true) if previous_unlocked is Array else []
    members[active_index]["enhancement"] = previous_enhancement


func _on_partner_progress_changed(
        _level: int,
        _current_exp: int,
        _max_exp: int
) -> void:
    # EXP/Level ที่ actor ได้ถูกเขียนกลับเฉพาะ Digimon ที่กำลังลงสนาม
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
        "version": 6,
        "active_id": members[active_index].get("id", ""),
        "active_uid": members[active_index].get("uid", ""),
        "members": members.duplicate(true),
        "storage": storage.duplicate(true)
    }
