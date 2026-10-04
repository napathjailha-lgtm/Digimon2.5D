class_name HybridChatCommand
extends ClassicCommand
## กรอบปุ่มแชตบาง โปร่งแสง ใช้ระบบ touch ของ ClassicCommand เดิม
func _draw() -> void:
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.06, 0.13, 0.16, 0.42 if _finger < 0 else 0.8)
    frame.border_color = Color(0.93, 0.90, 0.80, 0.4)
    frame.set_border_width_all(1)
    frame.set_corner_radius_all(6)
    draw_style_box(frame, Rect2(Vector2.ZERO, size))
