class_name FieldQuestNPC
extends StoryNPC
## NPC ภารกิจภาคสนามแบบ procedural ใช้รูปทรงดิจิทัลต้นฉบับ ไม่พึ่ง asset ตัวละครภายนอก

@export var display_name: String = "Field Agent"
@export var accent_color: Color = Color("66d9ff")

var _name_label: Label

func _ready() -> void:
    collision_layer = 16
    collision_mask = 0
    monitoring = false
    input_pickable = false

    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(72, 108)
    collision.shape = shape
    collision.position = Vector2(0, -54)
    add_child(collision)

    var target := QuestTarget.new()
    target.name = "QuestTarget"
    target.target_id = npc_id
    add_child(target)

    _name_label = Label.new()
    _name_label.position = Vector2(-105, -150)
    _name_label.size = Vector2(210, 30)
    _name_label.text = "%s [NPC]" % display_name
    _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _name_label.add_theme_font_size_override("font_size", 15)
    _name_label.add_theme_color_override("font_color", Color("edf9ff"))
    _name_label.add_theme_color_override("font_outline_color", Color("06101b"))
    _name_label.add_theme_constant_override("outline_size", 4)
    add_child(_name_label)

    queue_redraw()


func _draw() -> void:
    # เงา
    _draw_oval(Vector2(0, 2), Vector2(28, 9), Color(0, 0, 0, 0.28))

    # hologram body
    var body := PackedVector2Array([
        Vector2(-24, -92), Vector2(24, -92), Vector2(31, -34),
        Vector2(18, 0), Vector2(-18, 0), Vector2(-31, -34)
    ])
    draw_colored_polygon(body, Color(accent_color, 0.24))
    draw_polyline(body + PackedVector2Array([body[0]]), accent_color, 2.5, true)

    # head / core
    draw_circle(Vector2(0, -112), 19.0, Color(accent_color, 0.30))
    draw_arc(Vector2(0, -112), 19.0, 0, TAU, 28, accent_color, 2.5)
    draw_rect(Rect2(-8, -119, 16, 8), accent_color, true)

    # digital badge
    draw_rect(Rect2(-13, -70, 26, 18), Color("071927"), true)
    draw_rect(Rect2(-13, -70, 26, 18), accent_color, false, 2.0)
    draw_line(Vector2(-7, -61), Vector2(7, -61), accent_color, 2.0)


func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for i: int in range(24):
        var angle: float = TAU * float(i) / 24.0
        points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
    draw_colored_polygon(points, color)
