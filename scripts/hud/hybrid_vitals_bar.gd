class_name HybridVitalsBar
extends ProgressBar
## เส้นพลังงานบาง ไม่มี texture frame ที่บังคับความสูงขั้นต่ำ
## value เป็นภาพแสดงผลเท่านั้น; gameplay อ่าน HP/MP จาก Tamer/Partner ตามเดิม
@export var fill_color := Color("9cdd75")
var _tween: Tween
var _goal: float = -1.0
var _limit: float = -1.0
var _initialized: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    show_percentage = false
    step = 0.0
    min_value = 0.0
    add_to_group("smooth_texture_bars")
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.025, 0.045, 0.06, 0.55)
    background.set_corner_radius_all(3)
    add_theme_stylebox_override("background", background)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(3)
    add_theme_stylebox_override("fill", fill)

func set_vitals(current: float, maximum: float, _caption: String = "", instant: bool = false) -> void:
    # Signal HP/MP อื่นอาจส่งค่าเดิมมา: ไม่สร้าง Tween ซ้ำจนหลอดเดินทางไม่ถึงเป้าหมาย
    if not is_finite(current) or not is_finite(maximum):
        return
    var limit: float = maxf(1.0, maximum)
    var goal: float = clampf(current, 0.0, limit)
    if _initialized and is_equal_approx(_goal, goal) and is_equal_approx(_limit, limit) and not instant:
        return
    _kill_tween()
    var old_ratio: float = value / maxf(1.0, max_value)
    max_value = limit
    if _initialized and not is_equal_approx(_limit, limit):
        value = old_ratio * limit
    _goal = goal
    _limit = limit
    if instant or not _initialized or not GameVisualSettings.motion_enabled:
        value = goal
    else:
        _tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _tween.tween_property(self, "value", goal, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _initialized = true

func snap_to_target() -> void:
    # เปลี่ยนสมาชิกทีมต้อง snap ป้องกันการไหลจาก HP ของตัวเก่าไปหาตัวใหม่
    _kill_tween()
    if _initialized:
        value = _goal

func _kill_tween() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
