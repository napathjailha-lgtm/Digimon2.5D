extends Node2D
## เอฟเฟกต์เบา ๆ สำหรับมือถือ ใช้ Tween ขยายวงแสงและจางออก
var radius: float = 5.0:
    set(value):
        radius = value
        queue_redraw()

func _ready() -> void:
    # เพิ่มเป็นลูกตัวละคร เอฟเฟกต์จึงเคลื่อนตามตัวละครขณะเล่น
    z_index = 210
    var label := Label.new()
    label.text = "LEVEL UP!"
    label.position = Vector2(-65, -100)
    label.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(self, "radius", 65.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "position:y", -130.0, 0.9)
    tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.45)
    tween.chain().tween_callback(queue_free)

func _draw() -> void:
    # วาดวงแสงจากโค้ด ไม่ต้องใช้ Particle จำนวนมาก
    draw_arc(Vector2(0, -20), radius, 0, TAU, 48, Color(0.4, 0.95, 1), 3.0)
    draw_arc(Vector2(0, -20), radius * 0.65, 0, TAU, 48, Color(1, 0.9, 0.35), 2.0)
