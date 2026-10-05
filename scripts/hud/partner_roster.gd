class_name PartnerRoster
extends Node
## ทีมคู่หูสูงสุด 3 ตัว ใช้ PartnerMonster บนสนามเพียง Node เดียว
## HP/MP/คูลดาวน์เก็บแยกแต่ละสมาชิก แต่ Level/EXP ใช้ร่วมกันทั้งทีม (Shared Partner Level)
signal changed
signal switched(index: int)
signal feedback(message: String)

const CAPACITY: int = 3

var tamer: Tamer
var partner: PartnerMonster
var members: Array[Dictionary] = []
## Storage ไม่จำกัดจำนวนและรองรับสายพันธุ์ซ้ำด้วย uid ต่อสมาชิก
var storage: Array[Dictionary] = []
var active_index: int = 0
var initialized: bool = false
var _switching: bool = false
var _legacy_family: StarterPartnerData

# เลเวล/EXP ของคู่หูทั้งทีมใช้ชุดเดียวกัน
# สมาชิกทุกตัวจะอ่านค่าจาก Dictionary นี้ ไม่สร้าง Lv1 แยกกันอีก
var shared_progress: Dictionary = {"level": 1, "exp": 0}


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

    # Level/EXP เป็น shared progression ของทั้งทีม
    partner.progress.progress_changed.connect(_on_partner_progress_changed)


func family(id: StringName) -> StarterPartnerData:
    if id == &"legacy":
        return _legacy_family
    return GameManager.catalog.starter_by_id(id)


func initialize(saved: Dictionary = {}) -> void:
    # World เรียกหลัง restore partner_progress เดิมแล้ว
    # จึงสามารถ migrate เซฟเก่าที่เคยเก็บเลเวลแยกสมาชิกได้โดยไม่ทำเลเวลหาย
    members.clear()
    storage.clear()

    var raw: Variant = saved.get("members", [])
    if raw is Array:
        for entry: Variant in raw:
            if not (entry is Dictionary) or members.size() >= CAPACITY:
                continue
            var id := GameManager.catalog.canonical_starter_id(StringName(str(entry.get("id", ""))))
            var data: StarterPartnerData = family(id)
            if data == null or data.forms.is_empty():
                continue
            var member: Dictionary = (entry as Dictionary).duplicate(true)
            member["id"] = String(id)
            member["form_id"] = String(GameManager.catalog.canonical_form_id(StringName(str(member.get("form_id", "")))))
            _ensure_uid(member)
            members.append(member)

    var raw_storage: Variant = saved.get("storage", [])
    if raw_storage is Array:
        for entry: Variant in raw_storage:
            if not (entry is Dictionary):
                continue
            var stored_id := GameManager.catalog.canonical_starter_id(StringName(str(entry.get("id", ""))))
            var stored_data: StarterPartnerData = family(stored_id)
            if stored_data == null or stored_data.forms.is_empty():
                continue
            var stored: Dictionary = (entry as Dictionary).duplicate(true)
            stored["id"] = String(stored_id)
            stored["form_id"] = String(GameManager.catalog.canonical_form_id(StringName(str(stored.get("form_id", "")))))
            _ensure_uid(stored)
            storage.append(stored)

    shared_progress = _resolve_shared_progress(saved)

    # ให้ Node Partner ตัวเดียวในสนามใช้ shared level ก่อนคำนวณสเตตัส/ร่าง
    _switching = true
    partner.progress.restore_data(shared_progress)

    if members.is_empty():
        # เซฟเก่าที่มีคู่หูเดียว
        var id: StringName = &"legacy"
        for starter: StarterPartnerData in GameManager.catalog.starters:
            if not starter.forms.is_empty() and starter.forms[0] == partner.forms[0]:
                id = starter.id
                break
        var first: Dictionary = _capture(id)
        _ensure_uid(first)
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
    _sync_shared_progress_to_members()
    _capture_active()
    changed.emit()


func _resolve_shared_progress(saved: Dictionary) -> Dictionary:
    # v2+: ใช้ shared_progress ที่บันทึกไว้โดยตรง
    var saved_shared: Variant = saved.get("shared_progress", null)
    if saved_shared is Dictionary and saved_shared.has("level"):
        return _sanitize_progress(saved_shared)

    # Migration v1: เลือก progression ที่สูงที่สุดจาก
    # 1) actor ปัจจุบันที่ story_world restore ไว้
    # 2) สมาชิกทุกตัวใน roster เก่า
    var best: Dictionary = _sanitize_progress(partner.progress.get_save_data())

    for member: Dictionary in members:
        var raw_progress: Variant = member.get("progress", null)
        if raw_progress is Dictionary and raw_progress.has("level"):
            var candidate: Dictionary = _sanitize_progress(raw_progress)
            if _progress_is_higher(candidate, best):
                best = candidate

    return best


func _sanitize_progress(raw: Dictionary) -> Dictionary:
    var level: int = clampi(int(raw.get("level", 1)), 1, EvolutionRules.MAX_LEVEL)
    var exp: int = maxi(0, int(raw.get("exp", 0)))
    if level >= EvolutionRules.MAX_LEVEL:
        exp = 0
    return {"level": level, "exp": exp}


func _progress_is_higher(a: Dictionary, b: Dictionary) -> bool:
    var a_level: int = int(a.get("level", 1))
    var b_level: int = int(b.get("level", 1))
    if a_level != b_level:
        return a_level > b_level
    return int(a.get("exp", 0)) > int(b.get("exp", 0))


func _sync_shared_progress_to_members() -> void:
    for index: int in range(members.size()):
        members[index]["progress"] = shared_progress.duplicate(true)


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
    _capture_active()
    return StringName(str(members[active_index].get("id", "")))


func member_level(id: StringName) -> int:
    # Jogress ยังเช็ก Agumon/Gabumon แยกว่ามีในทีม
    # แต่เลเวลเป็น Shared Partner Level จึงเท่ากันทุกสมาชิก
    if not initialized or not has_partner(id):
        return 0
    return clampi(int(shared_progress.get("level", 1)), 1, EvolutionRules.MAX_LEVEL)


func add_partner(id: StringName) -> bool:
    # สมาชิกใหม่เข้าทีมด้วย Shared Partner Level ปัจจุบันทันที
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
        "progress": shared_progress.duplicate(true),
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
        "progress": shared_progress.duplicate(true), "cooldowns": {}, "basic_cooldown": 0.0
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
    _sync_shared_progress_to_members()
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
        _switching = true
        if not _apply_member(members[next_index].duplicate(true)):
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
    _sync_shared_progress_to_members()
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

    # เก็บ HP/MP/Form/CD ของตัวเดิม แต่ไม่เปลี่ยน shared level
    _capture_active()

    var previous_index: int = active_index
    var previous_snapshot: Dictionary = members[previous_index].duplicate(true)
    var target_snapshot: Dictionary = members[index].duplicate(true)

    _switching = true

    # บังคับ target ใช้ shared progression ก่อนโหลดสเตตัสของร่าง
    partner.progress.restore_data(shared_progress)

    if not _apply_member(target_snapshot):
        _apply_member(previous_snapshot)
        _switching = false
        return false

    active_index = index
    _switching = false

    _capture_active()
    _sync_shared_progress_to_members()

    changed.emit()
    switched.emit(index)
    feedback.emit("สลับคู่หูเป็น %s • Lv%d" % [candidate.display_name, partner.progress.level])
    tamer.save_party_progress()
    return true


func _apply_member(entry: Dictionary) -> bool:
    var data: StarterPartnerData = family(StringName(entry.get("id", "")))
    if data == null or data.forms.is_empty():
        return false

    # Progress ไม่อ่านจาก entry แล้ว เพราะเป็น Shared Partner Level
    partner.progress.restore_data(shared_progress)

    partner.auto_battle = false
    partner.cancel_page_skill()
    partner.cancel_battle()
    tamer.set_target(null)
    partner.velocity = Vector2.ZERO

    if partner._morph_tween != null and partner._morph_tween.is_valid():
        partner._morph_tween.kill()

    partner.forms.assign(data.forms)

    var form: MonsterData = data.forms[0]
    var shared_level: int = clampi(
        int(shared_progress.get("level", 1)),
        1,
        EvolutionRules.MAX_LEVEL
    )

    # สมาชิกแต่ละตัวจำร่างของตัวเอง แต่ต้องไม่เกินร่างที่ Shared Level ปลดล็อก
    for index: int in range(data.forms.size()):
        var possible: MonsterData = data.forms[index]
        if possible == null:
            continue
        if not EvolutionRules.can_use_form(shared_level, index):
            continue
        if not QuestManager.has_flag(possible.required_story_flag):
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
        # ถ้าร่างที่เซฟไว้สูงเกิน shared level ให้ลดร่างแต่รักษา %HP
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
        "progress": shared_progress.duplicate(true),
        "cooldowns": cooldowns,
        "basic_cooldown": partner._basic_cooldown
    }


func _capture_active() -> void:
    if members.is_empty():
        return

    # actor ปัจจุบันคือ source of truth ของ Shared Level ระหว่าง gameplay
    shared_progress = _sanitize_progress(partner.progress.get_save_data())
    members[active_index] = _capture(
        StringName(members[active_index].get("id", "")),
        str(members[active_index].get("uid", ""))
    )


func _on_partner_progress_changed(
        _level: int,
        _current_exp: int,
        _max_exp: int
) -> void:
    # ทุกครั้งที่ active partner ได้ EXP/Level ให้กระจาย progression ไปทั้งทีมทันที
    shared_progress = _sanitize_progress(partner.progress.get_save_data())
    _sync_shared_progress_to_members()

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

    _sync_shared_progress_to_members()

    return {
        "version": 3,
        "active_id": members[active_index].get("id", ""),
        "active_uid": members[active_index].get("uid", ""),
        "shared_progress": shared_progress.duplicate(true),
        "members": members.duplicate(true),
        "storage": storage.duplicate(true)
    }
