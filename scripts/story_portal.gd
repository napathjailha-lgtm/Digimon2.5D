class_name StoryPortal
extends Area2D
## ประตูเปลี่ยน Scene เปิดเมื่อเควสต์และโซนปลายทางถูกปลดล็อก
signal cutscene_requested(quest_id: StringName)
@export var required_quest: StringName
@export var destination_zone: StringName
@export_file("*.tscn") var destination_scene: String
@export var interaction_distance: float = 90.0
var _transitioning: bool = false

func _ready() -> void:
    add_to_group("story_portals")
    body_entered.connect(_on_body_entered)
    QuestManager.quest_updated.connect(_refresh_visual)
    _refresh_visual(&"")

func can_enter() -> bool:
    return (required_quest == &"" or QuestManager.is_completed(required_quest)) and QuestManager.is_zone_unlocked(destination_zone)

func _on_body_entered(body: Node2D) -> void:
    if body is Tamer:
        try_enter(body)

func try_enter(tamer: Tamer) -> bool:
    if _transitioning or not can_enter() or not is_instance_valid(tamer):
        return false
    if global_position.distance_to(tamer.global_position) > interaction_distance:
        return false
    if destination_scene.is_empty() or not ResourceLoader.exists(destination_scene):
        return false
    _transitioning = true
    # เก็บปาร์ตี้ข้าม Scene เฉพาะ session; QuestManager ไม่เก็บ reference Node
    QuestManager.party_snapshot = tamer.capture_party_state()
    QuestManager.party_profile = QuestManager.party_snapshot.duplicate(true)
    QuestManager.save_progress()
    tamer.cancel_auto_navigation()
    cutscene_requested.emit(required_quest)
    # ตัวอย่างวาร์ปทันที; หากมี cutscene ให้เปลี่ยน Scene หลังเล่นจบ
    _change_zone.call_deferred()
    return true

func _change_zone() -> void:
    var error: Error = get_tree().change_scene_to_file(destination_scene)
    if error != OK:
        _transitioning = false
        push_warning("เปลี่ยนโซนไม่สำเร็จ: " + error_string(error))

func _refresh_visual(_quest_id: StringName) -> void:
    $Visual.color = Color(0.2, 0.7, 0.8, 0.8) if can_enter() else Color(0.3, 0.3, 0.3, 0.8)
    $Name.text = String(destination_zone) + ("" if can_enter() else " [LOCKED]")
