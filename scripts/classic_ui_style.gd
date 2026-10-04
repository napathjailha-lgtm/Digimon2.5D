class_name ClassicUIStyle
extends RefCounted
## สีและกรอบร่วมกันของ HUD แก้จากไฟล์นี้แล้วหน้าต่างต่าง ๆ เปลี่ยนตาม
const NAVY := Color("081522f5")
const BLUE := Color("3d829b")
const GOLD := Color("d1b378")
const TEXT := Color("e5f6ff")

static func frame(accent: Color = BLUE, background: Color = NAVY) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = accent
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.shadow_color = Color(0.01, 0.02, 0.04, 0.32)
    style.shadow_size = 3
    style.shadow_offset = Vector2(0, 2)
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
