class_name ModalVisualFX
extends Node
## ติดให้ modal แต่ละอัน; Pause ownership และคำสั่งปิดยังอยู่ในสคริปต์หน้าต่างเดิม
var root: Control
var panel: Control
var blur: ColorRect
var copy: BackBufferCopy
var _material: ShaderMaterial
var _tween: Tween
var _rest_scale := Vector2.ONE

static func attach(overlay_root: Control, popup_panel: Control) -> ModalVisualFX:
    # BackBufferCopy ต้องถูกวาดก่อน Blur ส่วน Panel ต้องอยู่หลัง Blur ในลำดับลูก
    var fx := ModalVisualFX.new()
    fx.root = overlay_root
    fx.panel = popup_panel
    overlay_root.add_child(fx)
    return fx

func _ready() -> void:
    # Blur ทำงานเฉพาะตอน modal เปิด ไม่อ่านหน้าจอเพิ่มขณะเดินบนสนาม
    process_mode = Node.PROCESS_MODE_ALWAYS
    for child: Node in root.get_children():
        if child is ColorRect and child.name in ["Shade", "Dim"]:
            (child as ColorRect).color.a = 0.0 # แทน Shade เดิม แต่เก็บ input blocking ไว้
    copy = BackBufferCopy.new()
    copy.name = "BackdropCopy"
    copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
    root.add_child(copy)
    root.move_child(copy, 0)
    blur = ColorRect.new()
    blur.name = "ScreenBlur"
    blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
    blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _material = ShaderMaterial.new()
    _material.shader = preload("res://shaders/ui_screen_blur.gdshader")
    blur.material = _material
    root.add_child(blur)
    root.move_child(blur, 1)
    blur.hide()

func animate_open() -> void:
    # เก็บสเกล adaptive ที่ _layout คำนวณไว้ แล้วขยาย 0.8 → 1.05 → 1.0
    _stop()
    _rest_scale = panel.scale
    panel.pivot_offset = panel.size * 0.5
    # BackBufferCopy + blur shader มีโอกาสได้ framebuffer ไม่พร้อมใน first-open บน Android/Web touch.
    # มือถือใช้ dim overlay ที่เสถียรกว่าและเบากว่า ส่วน Desktop ยังคง blur ตาม setting เดิม.
    var use_blur: bool = GameVisualSettings.blur_enabled and not GameVisualSettings.low_effects and not HybridPlatform.is_touch_device()
    copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if use_blur else BackBufferCopy.COPY_MODE_DISABLED
    blur.material = _material if use_blur else null
    blur.color = Color.WHITE if use_blur else Color(0.01, 0.025, 0.06, 0.56)
    blur.show()
    _material.set_shader_parameter("radius_px", 3.0 if GameVisualSettings.low_effects else 5.0)
    _material.set_shader_parameter("strength", 1.0)
    if not GameVisualSettings.motion_enabled:
        panel.scale = _rest_scale
        panel.modulate.a = 1.0
        return
    panel.scale = _rest_scale * 0.8
    panel.modulate.a = 0.0
    _material.set_shader_parameter("strength", 0.0)
    _tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _tween.set_parallel(true)
    _tween.tween_property(panel, "modulate:a", 1.0, 0.12)
    _tween.tween_method(_set_blur, 0.0, 1.0, 0.22)
    _tween.tween_property(panel, "scale", _rest_scale * 1.05, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.chain().tween_property(panel, "scale", _rest_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Container อาจจัดขนาดหลัง show: ปรับ pivot อีกครั้งหลังเฟรม layout โดยไม่ขยับตำแหน่ง
    _update_pivot.call_deferred()

func reset() -> void:
    # ปิดได้ทันทีและคืนภาพเดิม ก่อนเจ้าของหน้าต่างปล่อย pause
    _stop()
    panel.scale = _rest_scale
    panel.modulate.a = 1.0
    copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
    blur.hide()

func _update_pivot() -> void:
    # Anchor/Container ยังคุมขนาด หน้าต่างจึงอยู่กลางจอทุกอัตราส่วน Landscape
    if is_instance_valid(panel):
        panel.pivot_offset = panel.size * 0.5

func _set_blur(value: float) -> void:
    # การ fade uniform ไม่สร้าง material ใหม่ทุกเฟรม
    _material.set_shader_parameter("strength", value)

func _stop() -> void:
    # เปิด-ปิดเร็วไม่ให้ tween ของรอบก่อนดัน scale รอบใหม่
    if _tween != null and _tween.is_valid():
        _tween.kill()
