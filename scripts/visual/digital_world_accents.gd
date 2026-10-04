class_name DigitalWorldAccents
extends Node2D
## วงรหัสแสงในเมืองเพิ่มอัตลักษณ์ดิจิตอล โดยไม่เพิ่ม collision หรือเปลี่ยน navigation
@export var radius: float = 128.0
var _phase: float = 0.0
var _step: float = 0.0

func _ready() -> void:
    # วาดเส้นบนพื้นใต้ตัวละคร ไม่เปิด PointLight เพิ่มทุกชิ้น
    z_index = -10

func _process(delta: float) -> void:
    # อัปเดต 12fps พอสำหรับรายละเอียดฉากที่อยู่ไกล; ไม่ทำเอฟเฟกต์เมื่อ Reduce Effects
    _step += delta
    if _step < 0.083 or GameVisualSettings.low_effects:
        return
    _phase += _step
    _step = 0.0
    queue_redraw()

func _draw() -> void:
    # รูปวงรีจำลอง perspectiva พื้นแบบ RO; สีอ่อนทำให้ตัวละครยังเป็นจุดสนใจ
    var alpha: float = 0.20 + sin(_phase * 0.9) * 0.04 if GameVisualSettings.motion_enabled else 0.20
    var cyan := Color(0.20, 0.90, 1.0, alpha)
    draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.40))
    draw_arc(Vector2.ZERO, radius, 0, TAU, 64, cyan, 2.0)
    for i: int in range(8):
        var start: float = float(i) * TAU / 8.0 + 0.05
        draw_arc(Vector2.ZERO, radius - 10, start, start + 0.52, 8, cyan, 2.0)
        var p: Vector2 = Vector2.from_angle(start) * (radius + 8)
        draw_rect(Rect2(p - Vector2(2,2), Vector2(4,4)), cyan)
    draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

