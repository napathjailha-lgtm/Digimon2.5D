extends Node2D
## ภาพกระทบแยกจากดาเมจโดยเด็ดขาด: ห้ามเรียก take_damage จากไฟล์นี้
## สองชั้นใน Node เดียว: วงกระแทกที่พื้น + เศษธาตุเหนือพื้น
var color: Color = Color.ORANGE
var radius: float = 12.0
var style: String = "fire"
var elapsed: float = 0.0
var lifetime: float = 0.58
var _extent: float
var _pieces: int = 12
const FIRE_ART: Texture2D = preload("res://assets/vfx_painted/burst.png")
const ELECTRIC_ART: Texture2D = preload("res://assets/vfx_painted/electric.png")

func _ready() -> void:
    add_to_group("skill_vfx")
    z_index = 6
    material = SkillVFXPaint.unlit_material()
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _extent = clampf(radius * 1.1, 38.0, 130.0)
    _pieces = 5 if GameVisualSettings.low_effects else 12
    if GameVisualSettings.low_effects:
        lifetime = 0.40

func _process(delta: float) -> void:
    # สืบทอด Process Mode สนาม จึงหยุดพร้อมคัตซีน
    elapsed += delta
    if elapsed >= lifetime:
        queue_free()
    else:
        queue_redraw()

func _draw() -> void:
    var t := clampf(elapsed / lifetime, 0.0, 1.0)
    var fade := pow(1.0 - t, 1.5)
    var spread := 1.0 - pow(1.0 - t, 3.0)
    var center := Vector2(0, -22)
    # บีบแกน Y เฉพาะวงพื้น ไม่บีบตัวระเบิดให้แบน
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.46))
    SkillVFXPaint.glow(self, Vector2.ZERO, _extent * (0.6 + spread), Color(color, fade * 0.55))
    draw_arc(Vector2.ZERO, _extent * (0.2 + spread), 0, TAU, 48, Color(color, fade * 0.7), 2.0, true)
    draw_set_transform(Vector2.ZERO)
    SkillVFXPaint.glow(self, center, _extent * (0.7 + spread * 0.4), Color(color, fade * 0.8))
    if t < 0.35:
        SkillVFXPaint.glow(self, center, _extent * 0.60, Color(1, 0.98, 0.88, (1.0 - t / 0.35) * 0.65))
    # ภาพ PNG มี alpha จริง: ซ้อนบนฉากได้โดยไม่มีกรอบดำหรือขาว
    # แยกจาก hitbox ทั้งหมด และโหลดร่วมเพียงสอง texture ทั้งเกม
    if style in ["fire", "missile", "wing", "lightning"]:
        var art: Texture2D = ELECTRIC_ART if style == "lightning" else FIRE_ART
        var side := _extent * (1.8 + spread * 1.2)
        var art_size := Vector2(side, side * art.get_height() / art.get_width())
        var art_center := center + Vector2(0, -_extent * 0.18 if style != "lightning" else 0.0)
        draw_texture_rect(art, Rect2(art_center - art_size * 0.5, art_size), false, Color(1, 1, 1, minf(1.0, fade * 1.35)))
    for i: int in range(_pieces):
        var angle := float(i) * TAU / float(_pieces) + 0.23
        var axis := Vector2.from_angle(angle)
        var distance_factor := 0.55 + 0.3 * sin(float(i) * 6.3 + 1.0)
        var at := center + axis * _extent * spread * distance_factor
        match style:
            "lightning":
                SkillVFXPaint.bolt(self, center + axis * 4, center + axis * _extent * (0.5 + spread), float(i), Color(color.lightened(0.45), fade), 1.5)
            "ice":
                SkillVFXPaint.spark(self, at, axis, (6.0 + _extent * 0.10) * (1.0 - t * 0.4), Color(color.lightened(0.35), fade))
            "nature":
                SkillVFXPaint.leaf(self, at + Vector2(0, -sin(t * PI) * 12), angle + t * 3, 7, Color(color, fade))
            "wind", "wing":
                SkillVFXPaint.leaf(self, at, angle + t * 4, 8, Color(color.lightened(0.5), fade))
            "claw":
                if i < 3:
                    var slash_center := center + Vector2(float(i - 1) * 11, 0)
                    draw_arc(slash_center, _extent * (0.45 + spread * 0.3), -1.2, 1.2, 24, Color(color.lightened(0.5), fade), 4 * (1.0 - t) + 1, true)
            "astral":
                SkillVFXPaint.spark(self, at, Vector2.UP, 8 * (1.0 - t), Color(color.lightened(0.6), fade))
                SkillVFXPaint.spark(self, at, Vector2.RIGHT, 6 * (1.0 - t), Color(color.lightened(0.6), fade))
            _:
                # ไฟ/จรวด: เปลวกระจายแล้วลอยขึ้น แสงดับก่อนเศษไฟ
                at.y -= t * t * 28
                SkillVFXPaint.glow(self, at, (7.0 + _extent * 0.13) * (1.0 - t * 0.7), Color(color, fade))
                SkillVFXPaint.spark(self, at, axis, 5 * (1.0 - t), Color(1, 0.93, 0.68, fade))
    if style in ["wind", "wing", "astral"]:
        for ring: int in range(2):
            var angle := t * 3.0 + ring * PI
            draw_arc(center, _extent * (0.4 + spread * 0.5), angle, angle + PI * 0.7, 24, Color(color.lightened(0.25), fade), 3, true)
