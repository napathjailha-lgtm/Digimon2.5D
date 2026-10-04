class_name RoundMinimap
extends MobileMinimap
## มินิแมพวงกลมใช้ข้อมูลถนน/แม่น้ำของฉากจริงและตำแหน่ง actor ปัจจุบัน
## ตัดเส้นกับขอบวงกลมด้วยคณิตศาสตร์ ไม่ต้องมี SubViewport กล้องตัวที่สอง

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    title = Label.new()
    title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    title.offset_top = -17
    title.offset_bottom = 7
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_constant_override("outline_size", 2)
    add_child(title)
    QuestManager.zone_changed.connect(_on_zone_changed)

func _center() -> Vector2:
    return Vector2(size.x * 0.5, (size.y - 18) * 0.5)

func _radius() -> float:
    return minf(size.x, size.y - 18) * 0.46

func _point(world_position: Vector2) -> Vector2:
    # ใช้สเกลเดียวทั้งแกนเพื่อรักษาสัดส่วนถนน ไม่ยืดโลกให้กลายเป็นวงรี
    var factor: float = _radius() * 1.82 / maxf(world_extent.x, world_extent.y)
    return _center() + (world_position - world_extent * 0.5) * factor

func _draw() -> void:
    var center: Vector2 = _center()
    var radius: float = _radius()
    draw_circle(center, radius, Color(0.16, 0.25, 0.20, 0.88))
    if world_layout != null:
        # เส้นแม่น้ำ/ถนนถูก clip ไม่วาดทะลุขอบวงกลม
        var factor: float = radius * 1.82 / maxf(world_extent.x, world_extent.y)
        _line(_point(Vector2(world_layout.river_x, 0)), _point(Vector2(world_layout.river_x, world_extent.y)), Color("598f9d"), maxf(3.0, world_layout.river_width * factor))
        for road: PackedVector2Array in world_layout.roads:
            for index: int in range(road.size() - 1):
                _line(_point(road[index]), _point(road[index + 1]), Color("c9b791"), 2)
        _dot(world_layout.village_center, Color("f3d6a3"), 4)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        if is_instance_valid(enemy) and enemy is WildMonster and enemy.is_alive() and enemy.visible:
            _dot(enemy.global_position, Color("e99388"), 2)
    if is_instance_valid(partner):
        _dot(partner.global_position, Color("f8d787"), 3)
    if is_instance_valid(tamer):
        _dot(tamer.global_position, Color("b5f1d6"), 4)
    draw_arc(center, radius, 0, TAU, 64, Color("eee1c1"), 2, true)
    draw_arc(center, radius - 3, 0, TAU, 64, Color(1, 1, 1, 0.15), 1, true)

func _dot(world_position: Vector2, color: Color, radius: float) -> void:
    var point: Vector2 = _point(world_position)
    if point.distance_to(_center()) + radius < _radius():
        draw_circle(point, radius + 1, Color("172823"))
        draw_circle(point, radius, color)

func _line(start: Vector2, end: Vector2, color: Color, width: float) -> void:
    # หาจุดตัดของ segment กับวงกลมด้วยสมการกำลังสอง แล้ว clamp ช่วง t อยู่ใน [0,1]
    var delta: Vector2 = end - start
    var origin: Vector2 = start - _center()
    var a: float = delta.length_squared()
    if a < 0.001:
        return
    var radius: float = maxf(1.0, _radius() - width * 0.5 - 2)
    var b: float = 2.0 * origin.dot(delta)
    var c: float = origin.length_squared() - radius * radius
    var discriminant: float = b * b - 4.0 * a * c
    if discriminant < 0:
        return
    var start_t: float = maxf(0, (-b - sqrt(discriminant)) / (2 * a))
    var end_t: float = minf(1, (-b + sqrt(discriminant)) / (2 * a))
    if start_t <= end_t:
        draw_line(start + delta * start_t, start + delta * end_t, color, width, true)
