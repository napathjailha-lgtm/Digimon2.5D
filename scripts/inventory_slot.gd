class_name InventorySlot
extends EquipmentButton
## ไอคอนกระเป๋าขนาดคงที่ แยกพื้นที่ชื่อและจำนวน ไม่ทับภาพของอุปกรณ์เดิม
func _draw() -> void:
    var border: Color = Color("e5c170") if selected else Color("34779f")
    var fill: Color = Color("164461") if selected else Color("0a2238")
    if _finger >= 0:
        fill = fill.lightened(0.15)
    draw_style_box(ClassicUIStyle.frame(border, fill), Rect2(Vector2.ZERO, size))
    # กรอบหยักโลหะเลือกสีทองเมื่อ selected; ช่องว่างมืดกว่าเพื่อไม่แย่งสายตาจากไอเทม
    draw_texture_rect(preload("res://assets/ui/digital/slot_frame.png"),Rect2(Vector2.ZERO,size),false,Color("eac386") if selected else (Color("334d63") if locked else Color("9bc1d4")))
    if icon != null:
        draw_texture_rect(icon, Rect2(Vector2((size.x - 50) * 0.5, 8), Vector2(50, 50)), false)
    if quantity >= 0:
        draw_string(ThemeDB.fallback_font, Vector2(size.x - 38, 18), "x" + str(quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff0b5"))
