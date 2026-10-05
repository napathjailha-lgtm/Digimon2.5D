class_name WorldServicePoint
extends Area2D
## จุดบริการในโลก: Touch/Mouse เปิดตรง Area2D ส่วน Keyboard E ให้ Controller เลือกจุดที่ใกล้ที่สุด
## แยกแบบนี้เพื่อไม่ให้ NPC ที่มีรัศมีซ้อนกันตอบสนอง E พร้อมกัน

@export_enum("archive", "shop", "incubator") var service_id: String = "archive"
@export var interaction_radius: float = 125.0
@export var title: String = "SERVICE"
@export var accent_color: Color = Color("55c7e6")

var tamer: Tamer
var _near: bool = false

func _ready() -> void:
    input_pickable = true
    monitoring = true
    HybridInput.ensure_actions()
    add_to_group("world_service_points")
    tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    input_event.connect(_on_input_event)

    var title_label := get_node_or_null("Title") as Label
    if title_label != null:
        title_label.text = title
        title_label.add_theme_color_override("font_color", Color.WHITE)
        title_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
        title_label.add_theme_constant_override("outline_size", 5)

    var prompt := get_node_or_null("Prompt") as Label
    if prompt != null:
        prompt.add_theme_color_override("font_color", accent_color)
        prompt.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
        prompt.add_theme_constant_override("outline_size", 4)

func _process(_delta: float) -> void:
    if not is_instance_valid(tamer):
        tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    _near = is_instance_valid(tamer) and distance_to_tamer() <= interaction_radius

    var prompt := get_node_or_null("Prompt") as Label
    if prompt != null:
        prompt.visible = _near
        if HybridPlatform.is_touch_device():
            prompt.text = "แตะตู้ หรือปุ่ม ใช้งาน"
        else:
            prompt.text = "E  /  คลิกเพื่อใช้งาน"

    var marker := get_node_or_null("Marker") as Sprite2D
    if marker != null:
        marker.modulate = Color.WHITE if _near else Color(0.78, 0.86, 0.92)

func distance_to_tamer() -> float:
    return global_position.distance_to(tamer.global_position) if is_instance_valid(tamer) else INF

func can_interact() -> bool:
    # API กลางร่วมกันทั้ง E, Mouse และปุ่มใช้งานบนมือถือ
    return _near and is_visible_in_tree() and not get_tree().paused

func can_keyboard_interact() -> bool:
    # เก็บชื่อเดิมไว้เพื่อ compatibility กับสคริปต์เก่า
    return can_interact()

func request_interaction() -> void:
    if not _near or get_tree().paused:
        return
    var controller := get_tree().get_first_node_in_group("world_service_controller") as WorldServiceController
    if controller != null:
        controller.open_service(StringName(service_id))

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    # บน Web เมาส์ถูก emulate เป็น touch ได้ แต่รองรับ MouseButton ตรงด้วยเพื่อให้ desktop ชัดเจน
    if not _near or get_tree().paused:
        return
    var activate: bool = false
    if event is InputEventMouseButton:
        activate = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
    elif event is InputEventScreenTouch:
        activate = event.pressed and not event.canceled
    if activate:
        request_interaction()
        get_viewport().set_input_as_handled()
