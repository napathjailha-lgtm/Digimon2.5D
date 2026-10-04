extends Node2D
## ฉากทดสอบลานโล่ง: กำหนด NavigationPolygon พร้อมใช้ ไม่ต้อง bake เพิ่ม
func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.18, 0.17))
    for x: int in range(0, 1281, 64):
        draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.2, 0.3, 0.27), 1.0)
    for y: int in range(0, 721, 64):
        draw_line(Vector2(0, y), Vector2(1280, y), Color(0.2, 0.3, 0.27), 1.0)
