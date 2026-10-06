class_name DigimonTouchButton
extends Button
## ปุ่มในหน้าต่างใช้ touch จริง เพราะโปรเจกต์ปิด emulate_mouse_from_touch
## ถ้าอยู่ใน ScrollContainer ต้องไม่กิน touch-down เพื่อให้ drag gesture ไปถึงตัว scroll

var _finger: int = -1
var _dragged: bool = false
var _press_position := Vector2.ZERO
const DRAG_THRESHOLD := 8.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _contains(point: Vector2) -> bool:
    var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * point
    if not Rect2(Vector2.ZERO, size).has_point(local):
        return false
    var ancestor: Node = get_parent()
    while ancestor != null:
        if ancestor is Control and ancestor.clip_contents:
            var clipped: Vector2 = ancestor.get_global_transform_with_canvas().affine_inverse() * point
            if not Rect2(Vector2.ZERO, ancestor.size).has_point(clipped):
                return false
        ancestor = ancestor.get_parent()
    return true

func _inside_scroll_container() -> bool:
    var ancestor: Node = get_parent()
    while ancestor != null:
        if ancestor is ScrollContainer:
            return true
        ancestor = ancestor.get_parent()
    return false

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        release_input()
        return

    if event is InputEventScreenTouch:
        if event.pressed and not event.canceled and _finger == -1 and _contains(event.position):
            if disabled:
                return
            _finger = event.index
            _dragged = false
            _press_position = event.position
            modulate = Color(1.2, 1.2, 1.2)

            # ปุ่มที่อยู่ใน ScrollContainer ต้องปล่อย touch-down ผ่านไป
            # ไม่เช่นนั้น ScrollContainer จะไม่รู้ว่ามี gesture เริ่มต้นและลากไม่ได้บน iOS/Android Web
            if not _inside_scroll_container():
                get_viewport().set_input_as_handled()

        elif event.index == _finger and (not event.pressed or event.canceled):
            var should_press: bool = (
                not disabled
                and not event.canceled
                and not _dragged
                and _contains(event.position)
            )
            _finger = -1
            _dragged = false
            modulate = Color.WHITE
            if should_press:
                pressed.emit()
                get_viewport().set_input_as_handled()

    elif event is InputEventScreenDrag and event.index == _finger:
        if event.position.distance_to(_press_position) >= DRAG_THRESHOLD:
            _dragged = true
            _finger = -1
            modulate = Color.WHITE
            # ห้าม set_input_as_handled() ตรงนี้ ให้ ScrollContainer รับ drag ต่อ

func release_input() -> void:
    _finger = -1
    _dragged = false
    modulate = Color.WHITE

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        release_input()
