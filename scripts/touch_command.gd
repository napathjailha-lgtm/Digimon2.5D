class_name TouchCommand
extends Control
## ปุ่มสัมผัสใช้ finger index ของตนเอง จึงไม่ติดข้อจำกัดเมาส์หนึ่ง pointer
signal pressed
@export var caption: String = "Attack"
@export var tint: Color = Color(0.15, 0.35, 0.5)
@export var icon: Texture2D
var _label: Label
var locked: bool = false:
    set(value):
        # เปลี่ยนสถานะปุ่มเมื่อ DS/HP เปลี่ยน ต้องวาดสีใหม่แม้ชื่อไม่เปลี่ยน
        if locked == value:
            return
        locked = value
        queue_redraw()
var _finger: int = -1
var visual_fx: MobileButtonFX

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var label := Label.new()
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 16)
    add_child(label)
    _label = label
    label.text = caption
    label.add_theme_color_override("font_color", Color("edf9ff"))
    label.add_theme_color_override("font_outline_color", Color("071222"))
    label.add_theme_constant_override("outline_size", 2)
    visual_fx = MobileButtonFX.attach(self)
    if icon != null:
        label.add_theme_font_size_override("font_size", 11)
        label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        label.offset_bottom = -6.0
        label.clip_text = true

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        # ภาพยุบได้ แต่ hitbox ใช้ขนาดพักของปุ่ม ไม่ให้แตะหลุดเพราะ Tween
        var inside: bool = visual_fx.contains_screen_point(event.position)
        if event.pressed and not event.canceled and _finger == -1 and inside:
            _finger = event.index
            get_viewport().set_input_as_handled()
            if not locked:
                visual_fx.set_down(true)
                pressed.emit()
            queue_redraw()
        elif event.index == _finger:
            if not event.pressed or event.canceled:
                _finger = -1
                visual_fx.set_down(false)
                queue_redraw()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == _finger:
        visual_fx.set_down(not locked and visual_fx.contains_screen_point(event.position))
        get_viewport().set_input_as_handled()

func set_caption(value: String) -> void:
    if caption == value and _label != null and _label.text == value:
        return
    caption = value
    if _label != null:
        _label.text = value
    queue_redraw()

func release_input() -> void:
    # ล้างนิ้วที่ถือปุ่มก่อน pause ไม่ให้ปุ่มกดไม่ได้หลังกลับเข้าเกม
    _finger = -1
    if is_instance_valid(visual_fx):
        visual_fx.reset()
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        release_input()

func _draw() -> void:
    var color: Color = tint.darkened(0.5) if locked else tint
    if _finger >= 0:
        color = color.lightened(0.2)
    var radius: float = minf(size.x, size.y) * 0.48
    # กรอบแปดเหลี่ยมพิกเซลแทนวงกลมทึบ; ไอคอนยังอยู่กลางปุ่มที่อ่านง่าย
    draw_texture_rect(preload("res://assets/ui/digital/command_frame.png"), Rect2(Vector2.ZERO, size), false, Color("607487") if locked else Color.WHITE)
    draw_arc(size * 0.5, radius * 0.83, -PI * 0.7, PI * 0.25, 24, color.lightened(0.30), 1.0)
    if icon != null:
        var icon_size := Vector2.ONE * radius * 1.05
        draw_texture_rect(icon, Rect2(size * 0.5 - icon_size * 0.5 - Vector2(0, 6), icon_size), false, Color(0.5, 0.5, 0.5) if locked else Color.WHITE)
