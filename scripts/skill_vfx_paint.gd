class_name SkillVFXPaint
extends RefCounted
## วาดร่วมทุกธาตุ: texture แสงนุ่มสร้างครั้งเดียว ไม่ใช้แสง/Shader เต็มจอ
static var _glow: GradientTexture2D

static func glow(canvas: CanvasItem, at: Vector2, radius: float, tint: Color) -> void:
    if radius <= 0.0 or tint.a <= 0.0:
        return
    if _glow == null:
        _glow = GradientTexture2D.new()
        _glow.width = 64
        _glow.height = 64
        _glow.fill = GradientTexture2D.FILL_RADIAL
        _glow.fill_from = Vector2(0.5, 0.5)
        _glow.fill_to = Vector2(1.0, 0.5)
        var gradient := Gradient.new()
        gradient.offsets = PackedFloat32Array([0.0, 0.24, 0.58, 1.0])
        gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
        _glow.gradient = gradient
    canvas.draw_texture_rect(_glow, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, tint)

static func spark(canvas: CanvasItem, at: Vector2, axis: Vector2, length: float, tint: Color) -> void:
    var side := axis.orthogonal() * length * 0.20
    canvas.draw_colored_polygon(PackedVector2Array([at + axis * length, at + side, at - axis * length, at - side]), tint)

static func bolt(canvas: CanvasItem, start: Vector2, end: Vector2, seed_value: float, tint: Color, width: float = 2.0) -> void:
    # คง seed ตลอดอายุภาพ ลดการกะพริบถี่จากการสุ่มใหม่ทุกเฟรม
    var axis := end - start
    var side := axis.normalized().orthogonal()
    var points := PackedVector2Array([start])
    for i: int in range(1, 6):
        points.append(start + axis * (float(i) / 6.0) + side * sin(float(i) * 7.7 + seed_value) * axis.length() * 0.12)
    points.append(end)
    canvas.draw_polyline(points, Color(tint, tint.a * 0.2), width * 4, true)
    canvas.draw_polyline(points, tint, width, true)

static func leaf(canvas: CanvasItem, at: Vector2, angle: float, length: float, tint: Color) -> void:
    var axis := Vector2.from_angle(angle) * length
    var side := axis.orthogonal() * 0.40
    canvas.draw_colored_polygon(PackedVector2Array([at + axis, at + side, at - axis * 0.6, at - side]), tint)
    canvas.draw_line(at - axis * 0.35, at + axis * 0.65, Color(0.94, 1, 0.78, tint.a), 1, true)

static func unlit_material() -> CanvasItemMaterial:
    var result := CanvasItemMaterial.new()
    result.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    return result
