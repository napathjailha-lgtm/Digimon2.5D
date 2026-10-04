class_name WorldServicePoint
extends Area2D
## จุดโต้ตอบบนโลก ใช้ Area2D เดียวรองรับ Touch/Mouse และปุ่ม E เมื่ออยู่ใกล้

@export_enum("archive", "shop", "incubator") var service_id: String = "archive"
@export var interaction_radius: float = 125.0
@export var title: String = "SERVICE"
var tamer: Tamer
var _near: bool = false

func _ready() -> void:
    input_pickable = true
    monitoring = true
    HybridInput.ensure_actions()
    tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    input_event.connect(_on_input_event)
    var label := get_node_or_null("Title") as Label
    if label != null:
        label.text = title

func _process(_delta: float) -> void:
    if not is_instance_valid(tamer):
        tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    _near = is_instance_valid(tamer) and global_position.distance_to(tamer.global_position) <= interaction_radius
    var prompt := get_node_or_null("Prompt") as Label
    if prompt != null:
        prompt.visible = _near
        prompt.text = "แตะ / คลิก / E"

func _unhandled_input(event: InputEvent) -> void:
    # Keyboard ใช้ E เฉพาะจุดที่ผู้เล่นอยู่ใกล้ที่สุด; event ถูก consume หลังเปิดหน้าต่าง
    if not _near or get_tree().paused:
        return
    if event.is_action_pressed(&"interact"):
        _request_interaction()
        get_viewport().set_input_as_handled()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    # Area2D รับทั้ง MouseButton และ ScreenTouch โดยไม่พึ่ง Button UI
    if not _near or get_tree().paused:
        return
    var activate: bool = false
    if event is InputEventMouseButton:
        activate = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
    elif event is InputEventScreenTouch:
        activate = event.pressed and not event.canceled
    if activate:
        _request_interaction()
        get_viewport().set_input_as_handled()

func _request_interaction() -> void:
    var controller := get_tree().get_first_node_in_group("world_service_controller") as WorldServiceController
    if controller != null:
        controller.open_service(StringName(service_id))
