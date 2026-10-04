class_name ServiceUIStyle
extends RefCounted
## ชุดสไตล์กลางของ Archive / Merchant / Incubator
## ใช้สีและกรอบตระกูลเดียวกับ HUD เดิม เพื่อให้หน้าต่างใหม่ไม่ดูเป็น prototype แยกส่วน

const BG := Color("071522f7")
const BG_SOFT := Color("0b2032f2")
const CARD := Color("0d2940ee")
const CYAN := Color("55c7e6")
const GOLD := Color("e0bd72")
const GREEN := Color("8fd37d")
const PURPLE := Color("b994f4")
const RED := Color("ef7f86")
const TEXT := Color("eaf7ff")
const MUTED := Color("91a9bb")

static func make_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font = preload("res://assets/fonts/NotoSansThai.ttf")
    theme.default_font_size = 16
    return theme

static func panel(accent: Color = CYAN, background: Color = BG) -> StyleBoxFlat:
    var style: StyleBoxFlat = ClassicUIStyle.frame(accent, background)
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.shadow_color = Color(0, 0, 0, 0.42)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 4)
    return style

static func card(accent: Color = Color("2b6e8b"), background: Color = CARD) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = accent
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

static func button(button: Button, accent: Color = CYAN, selected: bool = false) -> void:
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 16)
    var normal := card(GOLD if selected else accent, Color("0a2336") if not selected else Color("18384a"))
    var hover := card((GOLD if selected else accent).lightened(0.15), Color("13344a"))
    var pressed := card(GOLD, Color("1c4054"))
    var disabled := card(Color("405466"), Color("091521"))
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)

static func label(text: String, font_size: int = 16, color: Color = TEXT) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", color)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return node

static func badge(text: String, color: Color) -> Label:
    var node := label(text, 13, color.lightened(0.2))
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.custom_minimum_size = Vector2(92, 28)
    node.add_theme_stylebox_override("normal", card(color.darkened(0.2), Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.92)))
    return node

static func section(title: String, accent: Color) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", card(accent, BG_SOFT))
    frame.set_meta("title", title)
    return frame

static func progress_bar(color: Color, height: float = 10.0) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size.y = height
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var under := StyleBoxFlat.new()
    under.bg_color = Color("050c13")
    under.set_corner_radius_all(5)
    bar.add_theme_stylebox_override("background", under)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.set_corner_radius_all(5)
    bar.add_theme_stylebox_override("fill", fill)
    return bar
