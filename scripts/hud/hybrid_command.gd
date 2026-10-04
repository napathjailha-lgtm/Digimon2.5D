class_name HybridCommand
extends TouchCommand
## สืบทอด finger index เดิม จึงกด Joystick กับสกิลได้พร้อมกันหลายสัมผัส
## วาดวงกลม/คูลดาวน์ด้วย CanvasItem ไม่สร้าง Texture หรือ Tween ใหม่ทุกเฟรม
@export var plain_text: bool = false
@export var empty_slot: bool = false
## เปิดเฉพาะปุ่มภาพวาด: ใช้ UV ตัดวงกลม จึงไม่มีขอบสี่เหลี่ยมทับฉาก
@export var illustrated: bool = false
var art_accent := Color("efc47c")
var _art_points := PackedVector2Array()
var _art_uvs := PackedVector2Array()
var _art_size := Vector2.ZERO
var cooldown_left: float = 0.0
var cooldown_total: float = 1.0
var _countdown: Label

func _ready() -> void:
    super._ready()
    _label.add_theme_font_size_override("font_size", 12)
    if plain_text:
        _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        _label.add_theme_font_size_override("font_size", 15)
        _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    elif icon != null:
        _label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        _label.offset_bottom = -5
    _countdown = Label.new()
    _countdown.name = "CooldownNumber"
    _countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _countdown.add_theme_font_size_override("font_size", 22)
    _countdown.add_theme_constant_override("outline_size", 3)
    _countdown.add_theme_color_override("font_outline_color", Color("10202b"))
    add_child(_countdown)
    _countdown.hide()
    if illustrated:
        texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        _label.add_theme_font_size_override("font_size", 10 if size.x < 90 else 12)
        _label.offset_left = 6
        _label.offset_right = -6
        _label.offset_top = size.y * (0.45 if size.x < 90 else 0.62)
        _label.offset_bottom = -4
        _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        _label.clip_text = true
        _label.add_theme_constant_override("outline_size", 2)
        _label.add_theme_constant_override("line_spacing", -3)

func set_cooldown(remaining: float, duration: float) -> void:
    # เลขปัดขึ้น: 0.1 วินาทียังแสดง 1 และรับคำสั่งได้เมื่อ CD จริงเป็นศูนย์เท่านั้น
    var next_left: float = maxf(0.0, remaining)
    if is_equal_approx(cooldown_left, next_left) and is_equal_approx(cooldown_total, duration):
        return
    cooldown_left = next_left
    cooldown_total = maxf(0.001, duration)
    if _countdown != null:
        _countdown.visible = cooldown_left > 0.0
        _countdown.text = str(ceili(cooldown_left))
    queue_redraw()

func _draw() -> void:
    if plain_text:
        return # Quest tracker มีข้อความและเงาตัวอักษร ไม่มีกล่องทึบบังฉาก
    var center: Vector2 = size * 0.5
    var radius: float = minf(size.x, size.y) * 0.47
    var rim := Color("eee3c8")
    var fill := Color(0.06, 0.12, 0.17, 0.60)
    if empty_slot:
        # ช่องสำรองยังมี hitbox เดิม แต่ภาพเล็กและจาง ลดสิ่งรบกวนสายตา
        radius *= 0.68
        draw_circle(center, radius, Color(0.02, 0.04, 0.06, 0.20))
        draw_arc(center, radius, 0, TAU, 32, Color(0.82, 0.86, 0.9, 0.20), 1, true)
        draw_circle(center, 2, Color(0.85, 0.9, 0.95, 0.35))
        return
    if locked:
        rim.a = 0.38
        fill.a = 0.42
    if bool(get_meta("active", false)):
        rim = Color("f3d69c")
        fill = Color(0.21, 0.27, 0.22, 0.74)
    if _finger >= 0 and not locked:
        fill = Color(0.28, 0.36, 0.32, 0.82)
    draw_circle(center, radius, fill)
    if illustrated and icon != null:
        _draw_illustration(center, radius)
    draw_arc(center, radius, 0.0, TAU, 48, rim, 1.6, true)
    if empty_slot:
        draw_line(center - Vector2(8, 0), center + Vector2(8, 0), rim, 2, true)
        draw_line(center - Vector2(0, 8), center + Vector2(0, 8), rim, 2, true)
    elif icon != null and not illustrated:
        var side: float = radius * 1.02
        draw_texture_rect(icon, Rect2(center - Vector2(side * 0.5, side * 0.5 + 5), Vector2.ONE * side), false,
            Color(0.72, 0.74, 0.73) if locked else Color.WHITE)
    if cooldown_left > 0.0:
        # แผ่นดำแบบ pie sweep ลดพื้นที่ตาม CD ไม่ย้อมทั้ง HUD และไม่ทับเลข countdown
        var fraction: float = clampf(cooldown_left / cooldown_total, 0.0, 1.0)
        if fraction >= 0.999:
            draw_circle(center, radius - 2, Color(0, 0, 0, 0.62))
            return
        var fan := PackedVector2Array([center])
        var segments: int = maxi(2, ceili(48.0 * fraction))
        for index: int in range(segments + 1):
            var angle: float = -PI * 0.5 + TAU * fraction * float(index) / segments
            fan.append(center + Vector2(cos(angle), sin(angle)) * (radius - 2))
        draw_colored_polygon(fan, Color(0, 0, 0, 0.62))

func _draw_illustration(center: Vector2, radius: float) -> void:
    # สร้างรูปทรงเมื่อขนาดเปลี่ยนเท่านั้น ใช้ texture ที่ Godot cache ไว้ร่วมกัน
    if _art_size != size:
        _art_size = size
        _art_points.clear()
        _art_uvs.clear()
        for index: int in range(64):
            var unit := Vector2.from_angle(TAU * float(index) / 64.0)
            _art_points.append(center + unit * (radius - 3.0))
            _art_uvs.append(Vector2.ONE * 0.5 + unit * 0.5)
    draw_circle(center + Vector2(0, 2), radius + 2, Color(0.01, 0.02, 0.04, 0.8))
    draw_polygon(_art_points, PackedColorArray([Color("929ba9") if locked else Color.WHITE]), _art_uvs, icon)
    draw_arc(center, radius - 1, 0, TAU, 64, Color("121b2a"), 5, true)
    draw_arc(center, radius, 0, TAU, 64, art_accent.darkened(0.4) if locked else art_accent, 1.5, true)
    draw_arc(center, radius - 2, -PI * 0.9, -PI * 0.15, 24, Color(1, 0.95, 0.8, 0.65), 1, true)
    # เงารองตัวอักษรอยู่ภายในวงกลม ไม่ใช้ชื่อยาวล้นไปทับปุ่มข้าง ๆ
    if not caption.is_empty():
        draw_arc(center, radius * 0.67, PI * 0.20, PI * 0.80, 24, Color(0.01, 0.02, 0.04, 0.65), radius * 0.48, true)
