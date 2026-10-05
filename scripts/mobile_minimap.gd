class_name MobileMinimap
extends Panel
## แผนที่ย่ออ่านพิกัดโลกจริง ไม่ใช่ภาพแผนที่ที่ทำ marker ค้างไว้
@export var world_extent: Vector2 = Vector2(1280, 720)
var tamer: Tamer
var partner: PartnerMonster
var map_texture: Texture2D
var world_layout: OpenWorldLayout
var title: Label
var _redraw_left: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", ClassicUIStyle.frame(ClassicUIStyle.GOLD))
    title = ClassicUIStyle.label("", Vector2(8, 2), Vector2(200, 22), 12)
    add_child(title)
    QuestManager.zone_changed.connect(_on_zone_changed)
    visibility_changed.connect(_sync_processing)
    var legend: Label = ClassicUIStyle.label("● คุณ   ● คู่หู   ● ศัตรู", Vector2(8, 153), Vector2(200, 18), 10)
    add_child(legend)
    _sync_processing()

func configure(owner_tamer: Tamer, owner_partner: PartnerMonster, texture: Texture2D) -> void:
    tamer = owner_tamer
    partner = owner_partner
    map_texture = texture
    _on_zone_changed(QuestManager.current_zone)
    queue_redraw()

func _on_zone_changed(zone: StringName) -> void:
    var zone_names: Dictionary = {&"file_island": "File Island", &"server_continent": "Server Continent", &"odaiba": "Odaiba", &"spiral_mountain": "Spiral Mountain"}
    title.text = zone_names.get(zone, String(zone))

func _sync_processing() -> void:
    # ซ่อน minimap แล้วหยุด _process จริง ไม่เสีย CPU ไป queue_redraw ฉากที่มองไม่เห็น
    var active: bool = is_visible_in_tree()
    set_process(active)
    if active:
        _redraw_left = 0.0
        queue_redraw()

func _process(delta: float) -> void:
    # Web Mobile ลดจาก 10Hz เหลือ 4Hz; marker ยังอ่านทันสำหรับ minimap แต่ลด iteration มอนสเตอร์ลง 60%
    _redraw_left -= delta
    if _redraw_left <= 0.0:
        _redraw_left = 0.25 if HybridPlatform.is_web_mobile(get_viewport()) else 0.1
        queue_redraw()

func _map_rect() -> Rect2:
    return Rect2(8, 27, size.x - 16, size.y - 52)

func _point(world_position: Vector2) -> Vector2:
    var rect: Rect2 = _map_rect()
    var normalized: Vector2 = (world_position / world_extent).clamp(Vector2.ZERO, Vector2.ONE)
    return rect.position + normalized * rect.size

func _draw() -> void:
    var rect: Rect2 = _map_rect()
    if world_layout != null:
        # ผังมินิแมปสร้างจากพิกัดเดียวกับพื้น ถนน น้ำ และสะพานของฉากจริง
        draw_rect(rect, Color("668359"))
        var river_left: Vector2 = _point(Vector2(world_layout.river_x - world_layout.river_width * 0.5, 0))
        var river_right: Vector2 = _point(Vector2(world_layout.river_x + world_layout.river_width * 0.5, world_extent.y))
        draw_rect(Rect2(river_left, river_right - river_left), Color("488ea0"))
        for road: PackedVector2Array in world_layout.roads:
            var line := PackedVector2Array()
            for point: Vector2 in road:
                line.append(_point(point))
            draw_polyline(line, Color("d5be8e"), 2.0, true)
        var village: Vector2 = _point(world_layout.village_center)
        draw_circle(village, 7.0, Color("a2967f"))
        for y: float in world_layout.bridge_y:
            draw_line(_point(Vector2(world_layout.river_x - 160, y)), _point(Vector2(world_layout.river_x + 160, y)), Color("ead1a2"), 3.0)
    elif map_texture != null:
        draw_texture_rect(map_texture, rect, false, Color(0.62, 0.74, 0.84))
    else:
        draw_rect(rect, Color("123849"))
    for node: Node in get_tree().get_nodes_in_group("wild_monsters"):
        var enemy := node as WildMonster
        if is_instance_valid(enemy) and enemy.is_alive():
            draw_circle(_point(enemy.global_position), 2.5, Color("ee6269"))
    if is_instance_valid(partner):
        draw_circle(_point(partner.global_position), 3.5, Color("f0c774"))
    if is_instance_valid(tamer):
        if world_layout != null:
            var camera: Camera2D = get_viewport().get_camera_2d()
            if is_instance_valid(camera):
                var view_size: Vector2 = get_viewport_rect().size / camera.zoom
                var center: Vector2 = camera.get_screen_center_position()
                var corner: Vector2 = _point(center - view_size * 0.5)
                var end: Vector2 = _point(center + view_size * 0.5)
                draw_rect(Rect2(corner, end - corner), Color(0.9, 1, 0.95, 0.5), false, 1.0)
        var point: Vector2 = _point(tamer.global_position)
        draw_circle(point, 5.0, Color("07182e"))
        draw_circle(point, 3.5, Color("77f8d5"))

func _unhandled_input(event: InputEvent) -> void:
    # ซ่อนแล้วไม่กิน touch; ให้ปุ่มเมนูเหนือแผนที่รับก่อน
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch or event is InputEventScreenDrag:
        var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
        if Rect2(Vector2.ZERO, size).has_point(local):
            get_viewport().set_input_as_handled()
