class_name InventorySlot
extends EquipmentButton
## ไอคอนกระเป๋าขนาดคงที่ แยกพื้นที่ชื่อและจำนวน ไม่ทับภาพของอุปกรณ์เดิม
func _draw() -> void:
    var border: Color = Color("f0d58e") if selected else Color("bd9957")
    var fill: Color = Color("59401d") if selected else Color("2a1d0e")
    if locked:
        fill = Color("171109")
    if _finger >= 0:
        fill = fill.lightened(0.15)
    draw_style_box(ClassicUIStyle.frame(border, fill), Rect2(Vector2.ZERO, size))
    # ขอบทอง/พื้นน้ำตาลเข้มแบบช่องไอเทม MMORPG
    draw_texture_rect(preload("res://assets/ui/digital/slot_frame.png"), Rect2(Vector2.ZERO, size), false, Color("f3d795") if selected else (Color("6d552d") if locked else Color("d8b66d")))
    if icon != null:
        draw_texture_rect(icon, Rect2(Vector2((size.x - 50) * 0.5, 8), Vector2(50, 50)), false)
    if quantity >= 0:
        draw_string(ThemeDB.fallback_font, Vector2(size.x - 38, 18), "x" + str(quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff0b5"))
