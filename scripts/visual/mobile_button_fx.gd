class_name MobileButtonFX
extends Node
## เพิ่มเป็นลูกของ Control หรือ BaseButton; เอฟเฟกต์ไม่ emit คำสั่งเกมเอง
@export var visual_target: Control
@export_range(0.85, 1.0, 0.01) var press_scale: float = 0.93
var _rest_scale := Vector2.ONE
var _scale_tween: Tween
var _flash_tween: Tween
var _glow: ColorRect
var _material: ShaderMaterial
var _down: bool = false

static func attach(button: Control) -> MobileButtonFX:
    # ปุ่มที่สร้าง runtime เช่นสกิล/ช่องกระเป๋าใช้สคริปต์เดียวกันและไม่ต่อ Signal ซ้ำ
    var existing := button.get_node_or_null("VisualFX") as MobileButtonFX
    if existing != null:
        return existing
    var fx := MobileButtonFX.new()
    fx.name = "VisualFX"
    fx.visual_target = button
    button.add_child(fx)
    return fx

func _ready() -> void:
    # PROCESS_ALWAYS ทำให้การเด้งคืนทำงานแม้ปุ่มนั้นเป็นปุ่มเปิดหน้าต่าง Pause
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("button_visual_fx")
    if visual_target == null:
        visual_target = get_parent() as Control
    if visual_target == null:
        return
    _rest_scale = visual_target.scale
    _glow = ColorRect.new()
    _glow.name = "PressGlow"
    _glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _material = ShaderMaterial.new()
    _material.shader = preload("res://shaders/ui_button_glow.gdshader")
    _glow.material = _material
    _glow.visible = false
    visual_target.add_child(_glow)
    visual_target.move_child(_glow, 0)
    visual_target.resized.connect(_update_pivot)
    visual_target.visibility_changed.connect(_on_visibility_changed)
    if visual_target is BaseButton:
        var button := visual_target as BaseButton
        button.button_down.connect(set_down.bind(true))
        button.button_up.connect(set_down.bind(false))
    _update_pivot()

func _update_pivot() -> void:
    # ตั้ง pivot กลางปุ่มก่อน scale; Container ยังเป็นผู้จัด position/size ตามเดิม
    if is_instance_valid(visual_target):
        visual_target.pivot_offset = visual_target.size * 0.5

func contains_screen_point(screen_point: Vector2) -> bool:
    # ยกเลิกเฉพาะสเกลเอฟเฟกต์ตอนตรวจ hitbox: นิ้วไม่หลุดปุ่มเพราะภาพยุบ 7%
    var local: Vector2 = visual_target.get_global_transform_with_canvas().affine_inverse() * screen_point
    local = (local - visual_target.pivot_offset) * (visual_target.scale / _rest_scale) + visual_target.pivot_offset
    return Rect2(Vector2.ZERO, visual_target.size).has_point(local)

func set_down(down: bool) -> void:
    # Tween scale กับ flash แยกกัน กดเร็วหลายครั้งก็ไม่ทิ้งปุ่มไว้ในสเกลผิด
    if _down == down or not is_instance_valid(visual_target):
        return
    _down = down
    _kill(_scale_tween)
    if not GameVisualSettings.motion_enabled:
        visual_target.scale = _rest_scale
        return
    _update_pivot()
    _scale_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    if down:
        _scale_tween.tween_property(visual_target, "scale", _rest_scale * press_scale, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _flash()
    else:
        _scale_tween.tween_property(visual_target, "scale", _rest_scale * 1.035, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _scale_tween.tween_property(visual_target, "scale", _rest_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _flash() -> void:
    # วาบสั้น 0.22s: สื่อว่ารับการแตะแล้ว โดยไม่บดบังเลข cooldown นานเกินไป
    _kill(_flash_tween)
    _glow.show()
    _material.set_shader_parameter("flash", 0.85)
    _flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _flash_tween.tween_method(_set_flash, 0.85, 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _flash_tween.tween_callback(_glow.hide)

func _set_flash(value: float) -> void:
    # ส่ง uniform ให้ material ของปุ่มนี้เท่านั้น ไม่แก้ shared ShaderMaterial ของปุ่มอื่น
    _material.set_shader_parameter("flash", value)

func reset() -> void:
    # ใช้เมื่อย้าย Scene, เปิด modal, ปล่อยนิ้วแบบ canceled หรือแอปเสีย focus
    _down = false
    _kill(_scale_tween)
    _kill(_flash_tween)
    if is_instance_valid(visual_target):
        visual_target.scale = _rest_scale
    if is_instance_valid(_glow):
        _glow.hide()

func _on_visibility_changed() -> void:
    # ไม่ให้ Tween เก่ายังหดปุ่มที่เปิดกลับมาครั้งต่อไป
    if not visual_target.is_visible_in_tree():
        reset()

func _notification(what: int) -> void:
    # นิ้วที่ปล่อยนอกแอปจะไม่มี touch-up; ต้องคืนภาพเองตอน focus หาย
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        reset()

func _kill(tween: Tween) -> void:
    # ล้าง Tween ที่ยัง valid เท่านั้น เพื่อเรียก reset ซ้ำได้อย่างปลอดภัย
    if tween != null and tween.is_valid():
        tween.kill()
