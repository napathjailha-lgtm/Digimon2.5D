class_name MobileJoystick
extends Control
## จำ finger index ของ Joystick โดยเฉพาะ นิ้วอื่นยังแตะปุ่มโจมตีได้

@export var radius: float = 75.0
@export_range(0.0, 0.9) var dead_zone: float = 0.12
var move_vector: Vector2 = Vector2.ZERO
var _finger: int = -1
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var local: Vector2 = _local_position(event.position)
        if event.pressed and not event.canceled and _finger == -1 and Rect2(Vector2.ZERO, size).has_point(local):
            _finger = event.index
            _update_vector(local)
            get_viewport().set_input_as_handled()
        elif event.index == _finger:
            if not event.pressed or event.canceled:
                _reset()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == _finger:
        _update_vector(_local_position(event.position))
        get_viewport().set_input_as_handled()

func _local_position(screen_position: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * screen_position

func _update_vector(local: Vector2) -> void:
    _knob = (local - size * 0.5).limit_length(radius)
    var raw: Vector2 = _knob / radius
    var strength: float = raw.length()
    # ตัด dead zone แล้ว remap ช่วงที่เหลือเป็น 0..1 อย่างต่อเนื่อง
    move_vector = Vector2.ZERO if strength <= dead_zone else raw.normalized() * ((strength - dead_zone) / (1.0 - dead_zone))
    queue_redraw()

func _reset() -> void:
    _finger = -1
    _knob = Vector2.ZERO
    move_vector = Vector2.ZERO
    queue_redraw()

func release_input() -> void:
    # เรียกก่อน pause เพื่อไม่ค้างเวกเตอร์จากนิ้วที่ปล่อยระหว่างคัตซีน
    _reset()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _reset()

func _draw() -> void:
    var center: Vector2 = size * 0.5
    # ฐานวงกลมโปร่งแสงและสีเดียวกับปุ่มต่อสู้ ลดความรกฝั่งนิ้วโป้งซ้าย
    draw_circle(center, radius, Color(0.04, 0.09, 0.12, 0.28))
    draw_arc(center, radius, 0.0, TAU, 64, Color(0.93, 0.90, 0.80, 0.45), 1.5, true)
    var knob_center: Vector2 = center + _knob
    draw_circle(knob_center, 26, Color(0.88, 0.86, 0.73, 0.25 if _finger >= 0 else 0.12))
    draw_arc(knob_center, 26, 0, TAU, 40, Color(0.93, 0.90, 0.80, 0.70), 1.5, true)
    draw_circle(knob_center, 5, Color("eee3c8"))
