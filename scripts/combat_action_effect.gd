class_name CombatActionEffect
extends Node2D
## เอฟเฟกต์เบา ๆ ไม่เพิ่ม Texture ใหญ่หรืออนุภาคจำนวนมากบนมือถือ
enum Kind { CHARGE, SLASH, RELEASE }
var kind: Kind = Kind.CHARGE
var color: Color = Color.ORANGE
var radius: float = 18.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 0.3
var elapsed: float = 0.0
var style: String = "fire"

func _ready() -> void:
    material = SkillVFXPaint.unlit_material()
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= lifetime:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var t: float = clampf(elapsed / maxf(lifetime, 0.01), 0.0, 1.0)
    if kind == Kind.CHARGE:
        var pulse: float = 0.6 + 0.4 * sin(t * PI)
        SkillVFXPaint.glow(self, Vector2.ZERO, radius * (0.8 + t), Color(color, pulse * 0.55))
        draw_arc(Vector2.ZERO, radius * (1.2 - t * 0.4), t * TAU, t * TAU + PI * 1.7, 24, Color(color, pulse), 2.0, true)
        draw_circle(Vector2.ZERO, radius * 0.25 * pulse, Color(color, 0.75))
        for index: int in range(6):
            var angle: float = float(index) * TAU / 6.0 + t * TAU
            draw_circle(Vector2.from_angle(angle) * radius * (1.2 - t), 2.0, Color.WHITE)
        if style == "lightning" and not GameVisualSettings.low_effects:
            SkillVFXPaint.bolt(self, Vector2(-radius, 0), Vector2(radius, 0), 1.0, Color(color, pulse))
    elif kind == Kind.SLASH:
        SkillVFXPaint.glow(self, Vector2.ZERO, radius * 1.3, Color(color, (1.0 - t) * 0.35))
        # กรงเล็บสามเส้นหันตามเป้าหมายจริง
        var angle: float = direction.angle()
        for index: int in range(3):
            var center: Vector2 = direction.orthogonal() * (float(index) - 1.0) * 5.0
            draw_arc(center, radius * (0.7 + t * 0.4), angle - 0.9, angle + 0.9, 16, Color(color, 1.0 - t), 3.0 * (1.0 - t) + 1.0, true)
    else:
        SkillVFXPaint.glow(self, Vector2.ZERO, radius * (1.2 + t), Color(color, (1.0 - t) * 0.65))
        draw_arc(Vector2.ZERO, radius * (0.3 + t), 0.0, TAU, 32, Color(color, 1.0 - t), 2.0, true)
        draw_circle(Vector2.ZERO, radius * 0.25 * (1.0 - t), Color(Color.WHITE, 1.0 - t))
