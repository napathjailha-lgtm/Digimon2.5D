class_name DepthCliffEdge
extends Node2D
## ขอบเกาะด้านเหนือเป็นหน้าผาทางภาพ กำแพง/Navigation ยังอยู่ที่ขอบเดิม
var width: float = 5120.0

func _draw() -> void:
    # สีเย็นใต้ขอบหญ้าสื่อความสูง โดยไม่ยก Tile/Collision จริง
    draw_rect(Rect2(0, -46, width, 46), Color("335c65"))
    draw_rect(Rect2(0, -46, width, 9), Color("729373"))
    draw_line(Vector2(0, -35), Vector2(width, -35), Color("8cac87"), 3.0)
    draw_line(Vector2(0, -2), Vector2(width, -2), Color("233f50"), 4.0)
    for i: int in range(int(width / 48.0)):
        var x: float = float(i) * 48.0
        draw_line(Vector2(x + 12, -31), Vector2(x + 5, -4), Color(0.16, 0.29, 0.35, 0.45), 2.0)
