class_name ClassicCommand
extends TouchCommand
## ปุ่มสี่เหลี่ยมใช้ระบบหลาย finger เดิม ต่างกันเฉพาะภาพกรอบ
func _draw() -> void:
    var fill: Color = tint.darkened(0.55) if locked else tint
    if _finger >= 0:
        fill = fill.lightened(0.15)
    draw_style_box(ClassicUIStyle.frame(ClassicUIStyle.GOLD, fill), Rect2(Vector2.ZERO, size))
    draw_texture_rect(preload("res://assets/ui/digital/slot_frame.png"), Rect2(Vector2.ZERO, size), false, Color("657386") if locked else Color.WHITE)
    draw_line(Vector2(3, 3), Vector2(size.x - 3, 3), Color("47c8ee"), 2.0)
    if icon != null:
        var side: float = minf(size.x, size.y) * 0.55
        draw_texture_rect(icon, Rect2(Vector2((size.x - side) * 0.5, 4), Vector2.ONE * side), false)
