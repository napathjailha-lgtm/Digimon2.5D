class_name DigimonTouchButton
extends Button
## ปุ่มในหน้าต่างใช้ touch จริง เพราะโปรเจกต์ปิด emulate_mouse_from_touch
## รับตอนปล่อยนิ้ว และเคารพขอบ ScrollContainer เพื่อไม่กดปุ่มที่เลื่อนพ้นหน้าต่าง
var _finger: int = -1

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

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        _finger = -1
        return
    if event is InputEventScreenTouch:
        if event.pressed and not event.canceled and _finger == -1 and _contains(event.position):
            if not disabled:
                _finger = event.index
                modulate = Color(1.2, 1.2, 1.2)
            get_viewport().set_input_as_handled()
        elif event.index == _finger and (not event.pressed or event.canceled):
            _finger = -1
            modulate = Color.WHITE
            get_viewport().set_input_as_handled()
            if not disabled and not event.canceled and _contains(event.position):
                pressed.emit()
    elif event is InputEventScreenDrag and event.index == _finger:
        # ยกเลิก click เมื่อลาก เพื่อให้ผู้เล่นเลื่อนเนื้อหาได้อย่างปลอดภัย
        _finger = -1
        modulate = Color.WHITE

func release_input() -> void:
    _finger = -1
    modulate = Color.WHITE

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        release_input()
