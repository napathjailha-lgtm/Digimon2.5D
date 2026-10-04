class_name SmoothTextureBar
extends TextureProgressBar
## หลอดแสดงผลเท่านั้น: ห้ามใช้ value ที่กำลัง Tween มาตัดสินความตายหรือสิทธิ์ต่อสู้
@export var fill_color: Color = Color("ef7189")
@export_range(0.05, 1.0, 0.01) var drain_seconds: float = 0.32
@export_range(0.05, 1.0, 0.01) var recover_seconds: float = 0.45
var _value_tween: Tween
var _initialized: bool = false
var _goal: float = -1.0
var _limit: float = -1.0

func _ready() -> void:
    add_to_group("smooth_texture_bars")
    # กรอบสามชั้นใช้ PNG พิกเซลจริง; Nine Patch ยืดเฉพาะกลาง ไม่บิดมุมโลหะ
    texture_under = preload("res://assets/ui/digital/bar_under.png")
    texture_progress = preload("res://assets/ui/digital/bar_fill.png")
    texture_over = preload("res://assets/ui/digital/bar_frame.png")
    tint_progress = fill_color
    nine_patch_stretch = true
    stretch_margin_left = 8
    stretch_margin_right = 8
    stretch_margin_top = 6
    stretch_margin_bottom = 6
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    step = 0.0 # เลขทศนิยมระหว่าง Tween ทำให้หลอดไหล ไม่กระโดดทีละ 1 HP
    var label := get_node_or_null("Value") as Label
    if label != null:
        label.add_theme_color_override("font_color", Color("f2fbff"))
        label.add_theme_color_override("font_outline_color", Color("08111b"))
        label.add_theme_constant_override("outline_size", 2)

func set_vitals(current: float, maximum: float, caption: String = "", instant: bool = false) -> void:
    # รับค่าจริงผ่าน Signal; label เปลี่ยนทันที แต่ภาพหลอดค่อย ๆ ตามค่าจริง
    if not is_finite(current) or not is_finite(maximum):
        return
    var safe_max: float = maxf(1.0, maximum)
    var target_value: float = clampf(current, 0.0, safe_max)
    var label := get_node_or_null("Value") as Label
    if label != null:
        label.text = caption
    if _initialized and is_equal_approx(_goal, target_value) and is_equal_approx(_limit, safe_max) and not instant:
        return # ไม่สร้าง Tween ซ้ำเมื่อ Signal อื่นส่งค่า HP เดิมมา
    _stop_tween()
    var previous_ratio: float = value / maxf(1.0, max_value)
    max_value = safe_max
    if _initialized and not is_equal_approx(_limit, safe_max):
        value = previous_ratio * safe_max # เพิ่ม max HP แล้วไม่กระพริบเป็นเลือดเต็มฟรี
    _goal = target_value
    _limit = safe_max
    if instant or not _initialized or not GameVisualSettings.motion_enabled:
        value = target_value
        _initialized = true
        return
    var duration: float = recover_seconds if target_value > value else drain_seconds
    _value_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _value_tween.tween_property(self, "value", target_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func snap_to_target() -> void:
    # เรียกตอนเลือก Reduce Motion; หยุดหลอดที่ยังไหลอยู่แล้วแสดงข้อมูลล่าสุด
    _stop_tween()
    if _initialized:
        value = _goal

func _stop_tween() -> void:
    # Kill ก่อนเริ่มอันใหม่ เพื่อไม่ให้ Tween เก่ากับใหม่แย่งเขียน value
    if _value_tween != null and _value_tween.is_valid():
        _value_tween.kill()
