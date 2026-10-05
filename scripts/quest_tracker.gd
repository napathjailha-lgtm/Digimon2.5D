class_name QuestTracker
extends Control
## UI ฝั่งซ้าย รับ touch ก่อน Tamer._unhandled_input เพื่อไม่เลือกเป้าหมายทะลุ UI
signal navigation_requested(target_node: Node2D)
signal feedback(message: String)
@export var tamer: Tamer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var detail_label: Label = $Panel/Margin/VBox/Detail
@onready var progress_label: Label = $Panel/Margin/VBox/Progress

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    QuestManager.quest_updated.connect(_refresh)
    QuestManager.zone_changed.connect(_on_zone_changed)
    _refresh(&"")

func _refresh(_quest_id: StringName) -> void:
    var quest: StoryQuest = QuestManager.get_current_quest()
    if quest == null:
        title_label.text = "เนื้อเรื่องตัวอย่างสำเร็จ"
        detail_label.text = "คุณผ่านเควสต์หลักครบแล้ว"
        progress_label.text = ""
        return
    title_label.text = "[เควสต์หลัก] " + quest.title
    detail_label.text = quest.description
    var reward_text: String = ""
    if quest.reward_exp > 0 or quest.reward_bits > 0:
        reward_text = " • รางวัล EXP %d / %d Bits" % [quest.reward_exp, quest.reward_bits]
    progress_label.text = "%d / %d • แนะนำ Lv.%d%s • แตะเพื่อนำทาง" % [QuestManager.get_progress(quest.id), quest.required_count, quest.recommended_level, reward_text]

func _on_zone_changed(_zone: StringName) -> void:
    _refresh(&"")

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
        if Rect2(Vector2.ZERO, size).has_point(local):
            get_viewport().set_input_as_handled()
            if event.pressed and not event.canceled:
                request_navigation()

func request_navigation() -> void:
    var quest: StoryQuest = QuestManager.get_current_quest()
    if quest == null or not is_instance_valid(tamer):
        return
    var destination: Node2D = _resolve_destination(quest)
    if destination == null:
        feedback.emit("ยังไม่พบเป้าหมายเควสต์")
        return
    navigation_requested.emit(destination)

func _resolve_destination(quest: StoryQuest) -> Node2D:
    if quest.zone_id != QuestManager.current_zone:
        # เดินไปประตูทีละโซน เมื่อต้องข้ามแผนที่กด Tracker อีกครั้งในโซนใหม่
        var current_index: int = QuestManager.ZONE_ORDER.find(QuestManager.current_zone)
        var target_index: int = QuestManager.ZONE_ORDER.find(quest.zone_id)
        if current_index < 0 or target_index < 0:
            return null
        var next_index: int = current_index + (1 if target_index > current_index else -1)
        var next_zone: StringName = QuestManager.ZONE_ORDER[next_index]
        for node: Node in get_tree().get_nodes_in_group("story_portals"):
            var portal := node as StoryPortal
            if portal != null and portal.destination_zone == next_zone and portal.can_enter():
                return portal.get_node("QuestTarget") as Node2D
        return null
    var nearest: QuestTarget
    var best_distance: float = INF
    for node: Node in get_tree().get_nodes_in_group("quest_targets"):
        var target_node := node as QuestTarget
        if target_node.target_id != quest.target_id:
            continue
        var distance: float = tamer.global_position.distance_squared_to(target_node.global_position)
        if distance < best_distance:
            best_distance = distance
            nearest = target_node
    return nearest
