extends Control
## อุโมงค์ดิจิตอลจากเส้นและวงแสง AnimationPlayer เป็นผู้เปลี่ยนค่า phase
@export var phase: float = 0.0:
    set(value):
        phase = value
        queue_redraw()

func _draw() -> void:
    # ใช้ draw calls จำนวนน้อย พื้นหลังปรับตามขนาดจอใน CanvasLayer
    # พื้นอุโมงค์โปร่งบางส่วนเพื่อให้เห็นฉากโลกที่ถูกเบลออยู่ใต้ CanvasLayer
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.085, 0.65))
    var center: Vector2 = size * 0.5
    var reach: float = size.length() * 0.6
    for index: int in range(12):
        var ratio: float = fposmod(float(index) / 12.0 + phase * 0.045, 1.0)
        var radius: float = 28.0 + ratio * ratio * reach
        draw_arc(center, radius, phase * 0.15, phase * 0.15 + TAU, 80, Color(0.12, 0.65, 1.0, ratio * 0.65), 2.0 + ratio * 3)
    for index: int in range(24):
        var direction := Vector2.from_angle(float(index) * TAU / 24.0 + phase * 0.12)
        draw_line(center + direction * 30, center + direction * reach, Color(0.15, 0.45, 0.95, 0.45), 1.5)
        if index % 3 == 0:
            draw_string(get_theme_default_font(), center + direction * 300, "010101", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 0.95, 1, 0.7))
