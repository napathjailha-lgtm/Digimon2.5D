class_name EquipmentStage
extends Control
## เวทีดิจิตอลวาดด้วย Canvas2D ไม่เพิ่มแสง/Viewport ราคาแพงใน UI มือถือ
func _draw() -> void:
    var c: Vector2 = Vector2(size.x * 0.5, size.y - 28)
    for x: int in range(-5, 6):
        draw_line(Vector2(size.x * 0.5 + x * 9, 45), Vector2(size.x * 0.5 + x * 72, size.y), Color("124b69"), 1.0)
    for y: int in [75, 125, 182, 245, 315, 375]:
        draw_line(Vector2(0, y), Vector2(size.x, y), Color("144560"), 1.0)
    draw_set_transform(c, 0, Vector2(1.0, 0.28))
    draw_circle(Vector2.ZERO, 120, Color("0e526b55"))
    for radius: float in [78.0, 106.0, 119.0]:
        draw_arc(Vector2.ZERO, radius, 0, TAU, 80, Color("36ceec"), 2.0)
    for i: int in range(12):
        var direction := Vector2.from_angle(i * TAU / 12)
        draw_line(direction * 100, direction * 120, Color("93f0ff"), 2.0)
    draw_set_transform(Vector2.ZERO)
