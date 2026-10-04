class_name GroundRingVisual
extends Node2D
## วาดวงในระนาบปกติ แล้วให้ parent คำนวณ Transform2D ฉายลงพื้น
var radius: float = 29.0
var tint: Color = Color("ffd477")
var fill_alpha: float = 0.08
var progress: float = 0.0
var warning: bool = false

func _draw() -> void:
    # เส้นเข้มด้านนอกช่วยให้วงอ่านออกทั้งบนทราย หญ้า และพื้นสว่าง
    draw_circle(Vector2.ZERO, radius, Color(tint, fill_alpha))
    draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.035, 0.08, 0.10, 0.75), 6.0, true)
    draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(tint, 0.9), 2.5, true)
    draw_arc(Vector2.ZERO, radius - 5.0, 0, TAU, 64, Color(tint, 0.38), 1.0, true)
    # ขีดสี่ทิศและจุดพิกเซลให้กลิ่นอายเครื่องสแกนในโลกดิจิตอล
    for i: int in range(12):
        var direction := Vector2.from_angle(float(i) * TAU / 12.0)
        var length: float = 8.0 if i % 3 == 0 else 3.0
        draw_line(direction * (radius + 3), direction * (radius + 3 + length), tint, 2.0, true)
    if warning and progress > 0.001:
        # เส้นเติมตามเวลาอ่านง่ายกว่าไฟกะพริบเร็ว เหมาะกับจอมือถือ
        draw_arc(Vector2.ZERO, radius - 10.0, -PI * 0.5,
            -PI * 0.5 + TAU * progress, 64, Color(tint, 0.95), 3.0, true)

