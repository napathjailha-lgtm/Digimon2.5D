extends Control
## พื้นหลังหน้าก่อนเข้าเกม ใช้ภาพแผนที่เดิมร่วมกับกริดดิจิตอลวาดเบา ๆ
var _art: Texture2D = preload("res://assets/art/file_island.png")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    draw_texture_rect(_art, Rect2(Vector2.ZERO, size), false, Color(0.28, 0.4, 0.48))
    draw_rect(Rect2(Vector2.ZERO, size), Color("031422b8"))
    for x: int in range(0, int(size.x), 80):
        draw_line(Vector2(x, 0), Vector2(x, size.y), Color("3fb4d110"))
    for y: int in range(0, int(size.y), 80):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color("3fb4d110"))
    draw_circle(Vector2(size.x * 0.2, size.y * 0.4), 145, Color("12384999"))
    draw_arc(Vector2(size.x * 0.2, size.y * 0.4), 146, 0, TAU, 90, Color("45c8e759"), 2)
