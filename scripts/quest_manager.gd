extends Node
## Autoload ชื่อ QuestManager: ไม่ประกาศ class_name ชื่อนี้ซ้ำ
## ต้นแบบ client/local; เกมออนไลน์ให้เซิร์ฟเวอร์ยืนยัน event และสถานะก่อนส่งมาใช้

enum Status { LOCKED, ACTIVE, COMPLETED }
signal quest_updated(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal unlocks_changed(max_stage: int)
signal zone_changed(zone_id: StringName)

var catalog: QuestCatalog = preload("res://data/quest_catalog.tres")
const ZONE_ORDER: Array[StringName] = [&"file_island", &"server_continent", &"odaiba", &"spiral_mountain"]
var save_path: String = "user://story_progress.json"
var current_zone: StringName = &"file_island"
var max_unlocked_stage: int = MonsterData.EvolutionStage.CHAMPION
var party_profile: Dictionary = {} # เซฟ HP/ร่าง/เลเวลของปาร์ตี้ข้ามการเปิดเกม
var party_snapshot: Dictionary = {} # เก็บ DS/HP/ร่างระหว่างเปลี่ยน Scene ใน session
var _completed: Array[StringName] = []
var _progress: Dictionary = {}
var _flags: Array[StringName] = []
var _zones: Array[StringName] = [&"file_island"]
var _seen_events: Dictionary = {}

func _ready() -> void:
    load_progress()

func get_current_quest() -> StoryQuest:
    for quest: StoryQuest in catalog.quests:
        if quest.id not in _completed:
            return quest
    return null

func get_quest(quest_id: StringName) -> StoryQuest:
    for quest: StoryQuest in catalog.quests:
        if quest.id == quest_id:
            return quest
    return null

func get_status(quest_id: StringName) -> Status:
    if quest_id in _completed:
        return Status.COMPLETED
    var active: StoryQuest = get_current_quest()
    return Status.ACTIVE if active != null and active.id == quest_id else Status.LOCKED

func get_progress(quest_id: StringName) -> int:
    var quest: StoryQuest = get_quest(quest_id)
    if quest == null:
        return 0
    return quest.required_count if quest_id in _completed else int(_progress.get(quest_id, 0))

func is_completed(quest_id: StringName) -> bool:
    return quest_id in _completed

func report_event(kind: StoryQuest.Objective, target_id: StringName, amount: int = 1, event_id: String = "") -> bool:
    var quest: StoryQuest = get_current_quest()
    # นับเฉพาะเควสต์ Active ที่ตรงชนิด เป้าหมาย และโซน
    if quest == null or amount <= 0:
        return false
    if quest.objective != kind or quest.target_id != target_id or quest.zone_id != current_zone:
        return false
    var key: String = String(quest.id) + "|" + event_id
    if not event_id.is_empty() and _seen_events.has(key):
        return false
    if not event_id.is_empty():
        _seen_events[key] = true
    _progress[quest.id] = mini(quest.required_count, get_progress(quest.id) + amount)
    if get_progress(quest.id) >= quest.required_count:
        # Commit ก่อน emit: event ซ้ำจะไม่แจก reward ซ้ำ
        _completed.append(quest.id)
        _rebuild_unlocks()
        save_progress()
        unlocks_changed.emit(max_unlocked_stage)
        quest_completed.emit(quest.id)
    else:
        save_progress()
    quest_updated.emit(quest.id)
    return true

func has_flag(flag: StringName) -> bool:
    return flag == &"" or flag in _flags

func can_use_form(data: MonsterData) -> bool:
    return data != null and int(data.evolution_stage) <= max_unlocked_stage and has_flag(data.required_story_flag)

func is_zone_unlocked(zone_id: StringName) -> bool:
    return zone_id in _zones

func set_current_zone(zone_id: StringName) -> void:
    if zone_id in ZONE_ORDER and is_zone_unlocked(zone_id):
        current_zone = zone_id
        save_progress()
        zone_changed.emit(zone_id)

func _rebuild_unlocks() -> void:
    # รางวัลคำนวณจากเควสต์ที่จบ ไม่บันทึกซ้ำเป็นอีกแหล่งข้อมูล
    max_unlocked_stage = MonsterData.EvolutionStage.CHAMPION
    _flags.clear()
    _zones.assign([&"file_island"])
    for quest: StoryQuest in catalog.quests:
        if quest.id not in _completed:
            continue
        max_unlocked_stage = maxi(max_unlocked_stage, quest.unlock_stage)
        for flag: StringName in quest.unlock_flags:
            if flag not in _flags:
                _flags.append(flag)
        for zone_id: StringName in quest.unlock_zones:
            if zone_id not in _zones:
                _zones.append(zone_id)

func _clear_progress() -> void:
    _completed.clear()
    _progress.clear()
    _seen_events.clear()
    party_snapshot.clear()
    party_profile.clear()
    current_zone = &"file_island"
    _rebuild_unlocks()

func reset_progress(write_save: bool = true) -> void:
    _clear_progress()
    if write_save:
        save_progress()
    unlocks_changed.emit(max_unlocked_stage)
    quest_updated.emit(&"")
    zone_changed.emit(current_zone)

func save_progress() -> bool:
    var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        push_warning("QuestManager: บันทึกไม่ได้ " + error_string(FileAccess.get_open_error()))
        return false
    file.store_string(JSON.stringify({"version": 1, "completed": _completed, "progress": _progress, "zone": current_zone, "events": _seen_events.keys(), "party": party_profile}))
    file.close()
    return true

func load_progress() -> bool:
    if not FileAccess.file_exists(save_path):
        return false
    var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary or parsed.get("version", 0) != 1:
        return false
    if not parsed.get("completed", []) is Array or not parsed.get("progress", {}) is Dictionary:
        return false
    _clear_progress()
    # รับเฉพาะ prefix ที่เรียงตามเนื้อเรื่อง ป้องกัน save ข้าม prerequisites
    var raw_completed: Array = parsed.get("completed", [])
    for quest: StoryQuest in catalog.quests:
        if String(quest.id) not in raw_completed:
            break
        _completed.append(quest.id)
    var active: StoryQuest = get_current_quest()
    if active != null:
        var value: Variant = parsed.get("progress", {}).get(String(active.id), 0)
        if value is int or value is float:
            _progress[active.id] = clampi(int(value), 0, maxi(0, active.required_count - 1))
    var events: Variant = parsed.get("events", [])
    if events is Array:
        for key: Variant in events.slice(0, 512):
            if key is String:
                _seen_events[key] = true
    if parsed.get("party", {}) is Dictionary:
        party_profile = parsed.get("party", {}).duplicate(true)
    _rebuild_unlocks()
    # v25 รวมทุกบทไว้บนเกาะเดียว เก็บเควสต์ที่ผ่านแล้วตามเดิม
    current_zone = &"file_island"
    unlocks_changed.emit(max_unlocked_stage)
    quest_updated.emit(&"")
    zone_changed.emit(current_zone)
    return true
