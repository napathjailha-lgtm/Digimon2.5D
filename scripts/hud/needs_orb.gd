class_name NeedsOrb
extends Control
## ไอคอนอิ่ม/แรงเป็นวงแหวนโปร่งแสง ไม่เพิ่มหลอดยาวอีกสองหลอดบนสนาม
var amount: float = 100.0
var value: float:
    get: return amount # รองรับตัวอ่าน HUD เดิม โดยยังเก็บข้อมูลเพียงค่าเดียว
var title: String = "อิ่ม"
var color := Color("e6c28b")
var _label: Label

func _ready() -> void:
    custom_minimum_size = Vector2(52, 48)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label = Label.new()
    _label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_font_size_override("font_size", 11)
    _label.add_theme_constant_override("outline_size", 2)
    add_child(_label)
    set_value(amount)

func set_value(next_amount: float) -> void:
    amount = clampf(next_amount, 0, 100)
    if _label != null:
        _label.text = "%s\n%.0f" % [title, amount]
    queue_redraw()

func _draw() -> void:
    var center: Vector2 = size * 0.5
    draw_circle(center, 22, Color(0.04, 0.09, 0.12, 0.45))
    draw_arc(center, 22, 0, TAU, 40, Color(1, 1, 1, 0.18), 1.5, true)
    if amount > 0:
        draw_arc(center, 22, -PI * 0.5, -PI * 0.5 + TAU * amount / 100, 40,
            Color("f48175") if amount <= 20 else color, 2.0, true)
