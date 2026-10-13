class_name ClassicUIStyle
extends RefCounted
## สีและกรอบร่วมกันของ HUD แก้จากไฟล์นี้แล้วหน้าต่างต่าง ๆ เปลี่ยนตาม
const NAVY := Color("241b10f5")
const BLUE := Color("b38a46")
const GOLD := Color("e6c57d")
const TEXT := Color("f3e7cc")

static func frame(accent: Color = GOLD, background: Color = NAVY) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    # กรอบ MMORPG แบบเก่า: น้ำตาลเข้มโปร่งแสง + ขอบทองที่ยังเก็บสี accent ของแต่ละระบบไว้เล็กน้อย
    style.bg_color = background.lerp(NAVY, 0.62)
    style.border_color = accent.lerp(GOLD, 0.78)
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    style.shadow_color = Color(0.01, 0.008, 0.003, 0.50)
    style.shadow_size = 4
    style.shadow_offset = Vector2(2, 3)
    return style

static func title_bar(background: Color = Color("68152a")) -> StyleBoxFlat:
    # แถบหัวหน้าต่างแดงเลือดหมูตัดกับขอบทองแบบ MMORPG คลาสสิก
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = GOLD
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    style.corner_radius_bottom_left = 2
    style.corner_radius_bottom_right = 2
    style.shadow_color = Color(0.01, 0.006, 0.002, 0.45)
    style.shadow_size = 3
    style.shadow_offset = Vector2(1, 2)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    return style


static func label(text: String, at: Vector2, extent: Vector2, font_size: int = 14) -> Label:
    var node := Label.new()
    node.text = text
    node.position = at
    node.size = extent
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", TEXT)
    return node
