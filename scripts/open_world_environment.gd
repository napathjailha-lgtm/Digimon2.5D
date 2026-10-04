@tool
class_name OpenWorldEnvironment
extends Node2D
## แผนที่ผืนเดียว: ภาพพื้น พร็อพ ทางน้ำ collision และ nav ใช้ layout เดียวกัน
## ไม่ยืดภาพลานเดิม; พื้นซ้ำเป็น material และพร็อพวางแยกตามความลึก
@export var layout: OpenWorldLayout
const TERRAIN_SHADER: Shader = preload("res://shaders/world_terrain.gdshader")
const SHADOW_SHADER: Shader = preload("res://shaders/projected_shadow.gdshader")
const PROP_SCRIPT: Script = preload("res://scripts/world_prop.gd")
var obstruction_rects: Array[Rect2] = []
var props: Array[Node2D] = []
var ground: Node2D
var shadows: Node2D
var actors: Node2D
var lighting: WorldLighting
var atlas: Texture2D
var textures: Dictionary = {}
var navigation_ready: bool = false
var _shadow_sources: Array[Dictionary] = []

func _ready() -> void:
    if layout == null:
        layout = OpenWorldLayout.new()
    actors = get_parent().get_node("Actors") as Node2D
    get_parent().set("world_extent", layout.extent)
    var camera: Camera2D = actors.get_node_or_null("Tamer/Camera2D") as Camera2D
    if camera != null:
        camera.limit_right = int(layout.extent.x)
        camera.limit_bottom = int(layout.extent.y)
    atlas = load("res://assets/openworld/terrain_v14.png") as Texture2D
    for kind: String in ["tree_a", "tree_b", "pine", "bush", "rocks", "flowers", "cottage", "inn", "well", "arch", "lantern", "bridge"]:
        textures[kind] = load("res://assets/openworld/" + kind + ".tres")
    ground = Node2D.new()
    ground.name = "Terrain"
    ground.z_index = -100
    add_child(ground)
    shadows = Node2D.new()
    shadows.name = "ProjectedShadows"
    shadows.z_index = -30
    add_child(shadows)
    lighting = WorldLighting.new()
    lighting.name = "Lighting"
    add_child(lighting)
    lighting.sun_changed.connect(_refresh_projected_shadows)
    if not Engine.is_editor_hint():
        lighting.player = actors.get_node("Tamer") as Node2D
    _build_terrain()
    _build_village()
    _build_outposts()
    _scatter_nature()
    _build_boundaries()
    _bake_navigation()
    if not Engine.is_editor_hint():
        _adjust_spawner_positions()
        # วงดิจิตอลบนพื้นเมืองเป็นการตกแต่งเท่านั้น ไม่แย่งแสงหรือบัง sprite
        var digital_ring := DigitalWorldAccents.new()
        digital_ring.position = layout.village_center + Vector2(0, 95)
        add_child(digital_ring)
        var depth_layers := DepthParallax.new()
        depth_layers.name = "DepthLayers"
        depth_layers.camera = camera
        depth_layers.world_extent = layout.extent
        depth_layers.foreground_texture = textures["tree_b"]
        add_child(depth_layers)

func _adjust_spawner_positions() -> void:
    # ขยับจุดเกิดที่วางทับพร็อพเพียงเล็กน้อย ให้ fallback ตรงศูนย์ปลอดภัยเสมอ
    for node: Node in get_parent().get_node("Spawners").get_children():
        var spawner := node as MonsterSpawner
        if spawner == null or can_spawn_at(spawner.global_position):
            continue
        var center: Vector2 = spawner.global_position
        var found: bool = false
        for radius: float in [40.0, 80.0, 120.0, 160.0]:
            for i: int in range(16):
                var candidate: Vector2 = center + Vector2.from_angle(float(i) * TAU / 16.0) * radius
                if can_spawn_at(candidate):
                    spawner.global_position = candidate
                    found = true
                    break
            if found:
                break

func _terrain_material(quadrant: Vector2, feather: bool = false, river: bool = false) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = TERRAIN_SHADER
    material.set_shader_parameter("terrain_atlas", atlas)
    material.set_shader_parameter("quadrant", quadrant)
    material.set_shader_parameter("feather_edges", feather)
    material.set_shader_parameter("river", river)
    material.set_shader_parameter("tile_size", 420.0 if quadrant == Vector2.ZERO else 280.0)
    return material

func _surface(points: PackedVector2Array, material: Material, tint: Color = Color.WHITE) -> Polygon2D:
    var polygon := Polygon2D.new()
    polygon.polygon = points
    polygon.texture = atlas
    polygon.material = material
    polygon.color = tint
    ground.add_child(polygon)
    return polygon

func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i: int in range(48):
        points.append(center + Vector2.from_angle(float(i) * TAU / 48.0) * radii)
    return points

func _build_terrain() -> void:
    _surface(layout.polygon_for_rect(Rect2(Vector2.ZERO, layout.extent)), _terrain_material(Vector2.ZERO))
    # แบ่งบรรยากาศของพื้นที่ใหม่ด้วยสีพื้น แต่เดินต่อถึงกันได้ทั้งหมด
    _surface(_ellipse(Vector2(6300, 1650), Vector2(1600, 1100)), _terrain_material(Vector2.ZERO), Color("d8d5ab"))
    _surface(_ellipse(Vector2(8550, 3450), Vector2(1300, 1150)), _terrain_material(Vector2.ZERO), Color("9ebeb0"))
    _surface(_ellipse(Vector2(8050, 5550), Vector2(1750, 650)), _terrain_material(Vector2.ZERO), Color("c5b7a1"))
    # ถนน ribbon ใช้ UV ขวางถนนสำหรับขอบฟุ้ง ข้อมูลพิกัดอยู่ใน Resource
    var dirt: ShaderMaterial = _terrain_material(Vector2(1, 0), true)
    for road: PackedVector2Array in layout.roads:
        var points := PackedVector2Array()
        var uv := PackedVector2Array()
        for side: int in [1, -1]:
            for step: int in range(road.size()):
                var i: int = step if side == 1 else road.size() - 1 - step
                var previous: Vector2 = road[maxi(0, i - 1)]
                var following: Vector2 = road[mini(road.size() - 1, i + 1)]
                var normal: Vector2 = (following - previous).normalized().orthogonal()
                points.append(road[i] + normal * layout.road_width * 0.58 * side)
                uv.append(Vector2(float(i), 1.0 if side == 1 else 0.0) * atlas.get_size())
        var ribbon: Polygon2D = _surface(points, dirt)
        ribbon.uv = uv
    _surface(_ellipse(layout.village_center, Vector2(450, 300)), _terrain_material(Vector2(0, 1)))
    # ริมฝั่งและน้ำเป็น surface จริงที่รับแสง โคมไฟจึงส่องบนพื้นได้
    var bank_rect := Rect2(layout.river_x - layout.river_width * 0.5 - 27, 0, layout.river_width + 54, layout.extent.y)
    _surface(layout.polygon_for_rect(bank_rect), _terrain_material(Vector2(1, 0)))
    var water_rect := Rect2(layout.river_x - layout.river_width * 0.5, 0, layout.river_width, layout.extent.y)
    _surface(layout.polygon_for_rect(water_rect), _terrain_material(Vector2(1, 1), false, true))
    # เว้น collision + nav ตรงสะพานทั้งสองจุด ไม่อนุญาตให้เดินบนแม่น้ำ
    var start_y: float = 0.0
    for y: float in layout.bridge_y:
        _block(Rect2(water_rect.position.x, start_y, water_rect.size.x, y - layout.bridge_clearance * 0.5 - start_y))
        _add_prop("bridge", Vector2(layout.river_x, y + 128), 300.0, false, true)
        start_y = y + layout.bridge_clearance * 0.5
    _block(Rect2(water_rect.position.x, start_y, water_rect.size.x, layout.extent.y - start_y))

func _build_village() -> void:
    var center: Vector2 = layout.village_center
    _add_prop("cottage", center + Vector2(-300, -190), 245)
    _add_prop("inn", center + Vector2(290, -185), 285)
    _add_prop("cottage", center + Vector2(-350, 230), 230)
    _add_prop("cottage", center + Vector2(350, 245), 240)
    _add_prop("inn", center + Vector2(-60, -370), 250)
    _add_prop("well", center + Vector2(-145, 45), 94)
    for offset: Vector2 in [Vector2(-250, -35), Vector2(255, -35), Vector2(-225, 185), Vector2(235, 185)]:
        _add_prop("lantern", center + offset, 132, false)
        lighting.add_lantern(center + offset)
    # จุดพักกลางทางและประตูโบราณเป็น landmark ที่เดินไปถึงได้จริง
    _add_prop("well", Vector2(2380, 1830), 96)
    _add_prop("arch", Vector2(4270, 650), 210, false)
    _add_prop("arch", Vector2(4820, 680), 230, false)
    for point: Vector2 in [Vector2(2760, 1100), Vector2(3080, 1100), Vector2(2760, 2350), Vector2(3080, 2350)]:
        _add_prop("lantern", point, 130, false)
        lighting.add_lantern(point)

func _build_outposts() -> void:
    # จุดสังเกตบนแมพเดียว ไม่มีการโหลดฉากหรือวาร์ป
    for center: Vector2 in [Vector2(5600, 2600), Vector2(7100, 4000), Vector2(1600, 5000)]:
        _surface(_ellipse(center, Vector2(190, 130)), _terrain_material(Vector2(0, 1)))
        _add_prop("cottage", center + Vector2(-100, -80), 220)
        _add_prop("well", center + Vector2(100, 10), 85)
        _add_prop("lantern", center + Vector2(0, 100), 125, false)
        lighting.add_lantern(center + Vector2(0, 100))
    for center: Vector2 in [Vector2(6200, 1480), Vector2(8750, 3120), Vector2(9300, 5300)]:
        _surface(_ellipse(center + Vector2(0, 100), Vector2(190, 150)), _terrain_material(Vector2(0, 1)))
        _add_prop("arch", center, 245, false)
    for y: float in [4000.0, 5400.0]:
        for x: float in [2760.0, 3080.0]:
            _add_prop("lantern", Vector2(x, y + 100), 130, false)
            lighting.add_lantern(Vector2(x, y + 100))

func _scatter_nature() -> void:
    var random := RandomNumberGenerator.new()
    random.seed = layout.decoration_seed
    var placed: Array[Vector2] = []
    # ใช้ seed คงที่: เปิด Scene/Save ใหม่ รูปแบบโลกและเส้นทางไม่เปลี่ยน
    for attempt: int in range(5200):
        var point := Vector2(random.randf_range(90, layout.extent.x - 90), random.randf_range(120, layout.extent.y - 80))
        if point.distance_to(layout.village_center) < 650 or absf(point.x - layout.river_x) < 235:
            continue
        if layout.distance_to_roads(point) < 140:
            continue
        if point.distance_to(Vector2(4270, 730)) < 290 or point.distance_to(Vector2(4820, 700)) < 210:
            continue
        var spaced: bool = true
        for other: Vector2 in placed:
            if point.distance_squared_to(other) < 170.0 * 170.0:
                spaced = false
                break
        if not spaced:
            continue
        placed.append(point)
        var type_index: int = random.randi_range(0, 2)
        # ป่าฝั่งตะวันออกสูงทึบขึ้น ส่วนทุ่งตะวันตกโปร่ง
        var height: float = random.randf_range(205, 290) if point.x > 3100 else random.randf_range(185, 255)
        _add_prop(["tree_a", "tree_b", "pine"][type_index], point, height)
        if placed.size() >= 520:
            break
    # พุ่ม ดอกไม้ หินเล็ก ช่วยให้ทุ่งมีรายละเอียดโดยไม่ปิดทางหลัก
    for i: int in range(440):
        var point := Vector2(random.randf_range(100, layout.extent.x - 100), random.randf_range(130, layout.extent.y - 100))
        if absf(point.x - layout.river_x) < 205 or point.distance_to(layout.village_center) < 500:
            continue
        if layout.distance_to_roads(point) < 105:
            continue
        var kind: String = ["bush", "flowers", "rocks"][i % 3]
        _add_prop(kind, point, random.randf_range(48, 76), kind == "rocks")
    for offset: Vector2 in [Vector2(-440, -80), Vector2(460, -100), Vector2(-440, 290), Vector2(450, 300)]:
        _add_prop("tree_a", layout.village_center + offset, 220)
    for offset: Vector2 in [Vector2(-230, -165), Vector2(230, -160), Vector2(-250, 220), Vector2(255, 245)]:
        _add_prop("flowers", layout.village_center + offset, 40, false)

func _add_prop(kind: String, point: Vector2, height: float, blocking: bool = true, deck: bool = false) -> void:
    var texture: Texture2D = textures.get(kind)
    if texture == null:
        return
    var prop := Node2D.new()
    prop.name = "Prop_%s_%d" % [kind, props.size()]
    prop.set_script(PROP_SCRIPT)
    prop.position = point
    var sprite := Sprite2D.new()
    sprite.name = "Artwork"
    sprite.texture = texture
    sprite.offset.y = -texture.get_height() * 0.5
    sprite.scale = Vector2.ONE * (height / texture.get_height())
    prop.add_child(sprite)
    prop.set("sprite", sprite)
    prop.set("can_fade", kind.begins_with("tree") or kind == "pine")
    if not Engine.is_editor_hint():
        prop.set("player", actors.get_node("Tamer"))
    if deck:
        prop.z_index = -65
    actors.add_child(prop)
    props.append(prop)
    if not deck and kind != "flowers":
        _project_shadow(sprite, point)
    if blocking:
        var width: float = texture.get_width() * sprite.scale.x
        var footprint := Rect2(point + Vector2(-20, -12), Vector2(40, 26))
        if kind in ["cottage", "inn"]:
            footprint = Rect2(point + Vector2(-width * 0.40, -60), Vector2(width * 0.80, 75))
        elif kind == "rocks" or kind == "well":
            footprint = Rect2(point + Vector2(-width * 0.33, -18), Vector2(width * 0.66, 30))
        _block(footprint)
        # polygon ใช้พิกัดท้องถิ่นของพร็อพตาม footprint จริง ไม่ใช้กรอบยอดไม้ทั้งภาพ
        # ทำให้แสงทอดจากฐาน ไม่เกิดเงาดำทับใบหน้า/ยอดไม้ของตัวเอง
        var occluder := LightOccluder2D.new()
        occluder.name = "LightOccluder2D"
        occluder.occluder_light_mask = 1
        occluder.sdf_collision = false # ไม่มี shader SDF ใน preset นี้
        occluder.show_behind_parent = true
        var polygon := OccluderPolygon2D.new()
        polygon.polygon = layout.polygon_for_rect(Rect2(footprint.position - point, footprint.size))
        occluder.occluder = polygon
        prop.add_child(occluder)
        prop.move_child(occluder, 0)

func _project_shadow(source: Sprite2D, point: Vector2) -> void:
    var shadow := Sprite2D.new()
    shadow.texture = source.texture
    shadow.offset = source.offset
    var material := ShaderMaterial.new()
    material.shader = SHADOW_SHADER
    shadow.material = material
    shadows.add_child(shadow)
    _shadow_sources.append({"source": source, "shadow": shadow, "point": point})
    _update_prop_shadow(source, shadow, point)

func _update_prop_shadow(source: Sprite2D, shadow: Sprite2D, point: Vector2) -> void:
    # Pixel ที่สูงจากฐานมีค่า Y ติดลบ จึงใช้แกน Y เป็น -ทิศเงา
    # รักษา offset ฐานเดิมไว้ เงาจะไม่เลื่อนหนีต้นไม้เมื่อหมุนแดด
    var rays: Vector2 = lighting.get_shadow_direction(point)
    var axis_y: Vector2 = -rays * lighting.get_shadow_length_ratio() * source.scale.y
    shadow.transform = Transform2D(Vector2(0.95, 0.08) * source.scale.x,
        axis_y, point + rays * 4.0)

func _refresh_projected_shadows() -> void:
    # เรียกผ่าน signal ตอนเปลี่ยนมุม/เวลาเท่านั้น ใช้ texture เดิมทุกเงา
    for record: Dictionary in _shadow_sources:
        _update_prop_shadow(record.source, record.shadow, record.point)

func _block(rect: Rect2, for_navigation: bool = true) -> void:
    if rect.size.x <= 0 or rect.size.y <= 0:
        return
    var body := StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    body.position = rect.get_center()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    if for_navigation:
        obstruction_rects.append(rect)

func _build_boundaries() -> void:
    _block(Rect2(0, -32, layout.extent.x, 64), false)
    _block(Rect2(0, layout.extent.y - 32, layout.extent.x, 64), false)
    _block(Rect2(-32, 0, 64, layout.extent.y), false)
    _block(Rect2(layout.extent.x - 32, 0, 64, layout.extent.y), false)

func _bake_navigation() -> void:
    # Bake ครั้งเดียวจากรูปร่างเดียวกับ collision ไม่ใช่ polygon สี่เหลี่ยมทะลุบ้าน
    var source := NavigationMeshSourceGeometryData2D.new()
    source.add_traversable_outline(layout.polygon_for_rect(Rect2(Vector2(32, 32), layout.extent - Vector2(64, 64))))
    for rect: Rect2 in obstruction_rects:
        source.add_obstruction_outline(layout.polygon_for_rect(rect))
    var polygon := NavigationPolygon.new()
    polygon.agent_radius = 20.0
    NavigationServer2D.bake_from_source_geometry_data(polygon, source)
    var region: NavigationRegion2D = get_parent().get_node("NavigationRegion2D")
    region.navigation_polygon = polygon
    navigation_ready = polygon.get_polygon_count() > 0

func can_spawn_at(point: Vector2, radius: float = 28.0) -> bool:
    # Spawner/ศัตรูใช้เช็กพื้นที่เกิดและ Wander ไม่ให้เกิดในลำต้นหรือกลางน้ำ
    if not Rect2(Vector2(40, 40), layout.extent - Vector2(80, 80)).has_point(point):
        return false
    if point.distance_to(layout.village_center) < 530:
        return false
    for rect: Rect2 in obstruction_rects:
        if rect.grow(radius).has_point(point):
            return false
    return true
