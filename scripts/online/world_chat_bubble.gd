class_name WorldChatBubble
extends PanelContainer

const THAI_FONT: Font = preload("res://assets/fonts/NotoSansThai.ttf")

@export var lifetime: float = 4.5
@export var fade_time: float = 0.7

var message_label: Label
var _time_left: float = 0.0

func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 500

    var panel := StyleBoxFlat.new()
    panel.bg_color = Color(0.03, 0.08, 0.13, 0.9)
    panel.border_color = Color(0.5, 0.86, 1.0, 0.85)
    panel.set_border_width_all(1)
    panel.set_corner_radius_all(10)
    panel.content_margin_left = 10
    panel.content_margin_right = 10
    panel.content_margin_top = 5
    panel.content_margin_bottom = 5
    add_theme_stylebox_override("panel", panel)

    message_label = Label.new()
    message_label.name = "Message"
    message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_override("font", THAI_FONT)
    message_label.add_theme_font_size_override("font_size", 14)
    message_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    message_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
    message_label.add_theme_constant_override("outline_size", 3)
    add_child(message_label)

func show_message(message: String) -> void:
    var clean := message.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").substr(0, 160)
    if clean.is_empty() or not is_instance_valid(message_label):
        return
    # World bubbles are intentionally shorter than the full chat log so the
    # text remains readable above a character on landscape mobile screens.
    message_label.text = clean.substr(0, 72)
    modulate.a = 1.0
    visible = true
    _time_left = lifetime

func _process(delta: float) -> void:
    if not visible:
        return
    _time_left -= delta
    if _time_left <= 0.0:
        visible = false
        modulate.a = 1.0
        return
    if _time_left < fade_time:
        modulate.a = clampf(_time_left / maxf(0.01, fade_time), 0.0, 1.0)
