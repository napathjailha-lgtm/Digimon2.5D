class_name GroundSkillIndicator
extends Node2D
## Root อยู่ที่พิกัดล็อกเป้าจริง; ลูก GroundVisual รับการบีบภาพเท่านั้น
signal warning_finished
@export_range(12.0, 500.0) var radius: float = 29.0
@export_range(0.15, 1.0) var flatten_y: float = 0.46
@export_range(-0.45, 0.45) var shear_x: float = 0.12
@export var heading_degrees: float = 0.0
@export var tint: Color = Color("ffd477")
@export_range(0.0, 0.3) var fill_alpha: float = 0.08
var visual: GroundRingVisual
var _warning_tween: Tween

func _ready() -> void:
    # อยู่บนพื้นทุกครั้ง ไม่ลอยขึ้นหน้า sprite เมื่อ Actor ถูก Y Sort
    z_as_relative = false
    z_index = -18
    visual = GroundRingVisual.new()
    visual.name = "GroundVisual"
    var unlit := CanvasItemMaterial.new()
    unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    visual.material = unlit
    add_child(visual)
    refresh_visual()

func refresh_visual() -> void:
    # เปลี่ยนรัศมี/สีได้โดยไม่สร้าง material หรือ texture ใหม่ทุกเฟรม
    if not is_instance_valid(visual):
        return
    visual.radius = radius
    visual.tint = tint
    visual.fill_alpha = fill_alpha
    GroundProjection.apply_to_visual(visual, flatten_y, shear_x, deg_to_rad(heading_degrees))
    visual.queue_redraw()

func start_warning(duration: float = 1.2) -> void:
    # เป็นเวลาของภาพเท่านั้น ผู้เรียกเป็นเจ้าของดาเมจและการยกเลิกสกิล
    # Tween ผูกกับ Node จึงหยุดตามโลกเมื่อเปิด Inventory หรือคัตซีน
    cancel_warning()
    visual.warning = true
    _set_warning_progress(0.0)
    _warning_tween = create_tween()
    _warning_tween.tween_method(_set_warning_progress, 0.0, 1.0, maxf(0.05, duration))
    _warning_tween.tween_callback(_finish_warning)

func contains_world_point(world_point: Vector2) -> bool:
    # สำหรับสกิลใหม่ที่ใช้วงรีนี้เป็นพื้นที่โดนจริง: แปลงจุดกลับผ่านฐานของ Visual
    # ระบบโจมตีเดิมยังใช้ SkillHitResolver ของเดิม จึงไม่เปลี่ยนสมดุลโดยอัตโนมัติ
    if not is_instance_valid(visual):
        return false
    var plane_point: Vector2 = visual.global_transform.affine_inverse() * world_point
    return plane_point.length_squared() <= radius * radius

func cancel_warning() -> void:
    # รีเซ็ตเมื่อบอสตาย/สกิลถูกขัด ไม่ทิ้ง callback เก่าทำงานตอนเริ่มใหม่
    if _warning_tween != null and _warning_tween.is_valid():
        _warning_tween.kill()
    if is_instance_valid(visual):
        visual.warning = false
        visual.progress = 0.0
        visual.queue_redraw()

func _set_warning_progress(value: float) -> void:
    # redraw เฉพาะวงที่กำลังเติม ไม่ redraw ทุก Actor
    visual.progress = clampf(value, 0, 1)
    visual.queue_redraw()

func _finish_warning() -> void:
    # ให้ระบบต่อสู้ตรวจเงื่อนไขก่อนลงดาเมจอีกครั้ง ไม่มีดาเมจในสคริปต์ภาพ
    warning_finished.emit()
