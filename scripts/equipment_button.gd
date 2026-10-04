class_name EquipmentButton
extends TouchCommand
## ใช้ finger index เดิมของเกม รองรับ touch โดยไม่ต้องเปิด emulate_mouse_from_touch
var selected: bool = false
var accent: Color = Color("34779f")
var quantity: int = -1

func _draw() -> void:
    var border: Color = Color("e5c170") if selected else accent
    var fill: Color = Color("164461") if selected else Color("0a2238")
    if locked:
        fill = Color("0a1725")
    if _finger >= 0:
        fill = fill.lightened(0.15)
    draw_style_box(ClassicUIStyle.frame(border, fill), Rect2(Vector2.ZERO, size))
    draw_texture_rect(preload("res://assets/ui/digital/slot_frame.png"), Rect2(Vector2.ZERO, size), false, Color("e8bd79") if selected else (Color("51687d") if locked else Color.WHITE))
    draw_line(Vector2(3, 3), Vector2(size.x - 3, 3), border.lightened(0.15), 1.0)
    if icon != null:
        var side: float = minf(size.x - 12, size.y - 16)
        draw_texture_rect(icon, Rect2(Vector2((size.x - side) * 0.5, 5), Vector2.ONE * side), false, Color(0.4, 0.45, 0.5) if locked else Color.WHITE)
    if quantity >= 0:
        draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, size.y - 5), str(quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff0b5"))
