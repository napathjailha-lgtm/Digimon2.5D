class_name CriticalScreenFX
extends CanvasLayer
## อ่านสิทธิ์ Cannot Battle จาก Tamer จริง; ไม่อ่านเปอร์เซ็นต์ภาพหลอดที่ยัง Tween
var _rect: ColorRect
var _material: ShaderMaterial
var _critical: bool = false
var _phase: float = 0.0

func _ready() -> void:
    # layer ต่ำกว่า HUD จึงไม่ย้อมปุ่ม/ตัวอักษรเป็นแดง และไม่ขวางการกดจอ
    layer = 5
    _rect = ColorRect.new()
    _rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _material = ShaderMaterial.new()
    _material.shader = preload("res://shaders/critical_vignette.gdshader")
    _rect.material = _material
    add_child(_rect)
    _rect.hide()
    set_process(false)

func set_critical(value: bool) -> void:
    # ใช้ latch เดิมของ survival: ขอบยังเตือนจน HP ฟื้นตามเงื่อนไขที่เกมกำหนด
    if _critical == value:
        return
    _critical = value
    _phase = 0.0
    _rect.visible = value
    set_process(value)
    _material.set_shader_parameter("intensity", 0.18 if value else 0.0)

func _process(delta: float) -> void:
    # หนึ่งจังหวะต่อ ~1.8s สีแดงจาง 10–22%; Reduce Motion เปลี่ยนเป็นขอบนิ่ง
    _phase += delta
    var strength: float = 0.14
    if GameVisualSettings.motion_enabled:
        strength = 0.10 + (sin(_phase * TAU / 1.8) * 0.5 + 0.5) * 0.12
    _material.set_shader_parameter("intensity", strength)

