extends Node
## เกาะเดียว: กระจายจุดเกิดแบบ seed คงที่ และเปิด AI เฉพาะบริเวณผู้เล่น
@export_range(20, 500) var regular_population: int = 240
const SPAWNER: PackedScene = preload("res://scenes/monster_spawner.tscn")
const WILDS: Array[PackedScene] = [preload("res://scenes/wild_monster.tscn"), preload("res://scenes/wild_monster_crab.tscn")]
const FOREST_BYTE: PackedScene = preload("res://scenes/forest_byte.tscn")
const FOREST_CRAB: PackedScene = preload("res://scenes/forest_crab.tscn")
const CRIMSON_BYTE: PackedScene = preload("res://scenes/crimson_byte.tscn")
const IRON_SHELL: PackedScene = preload("res://scenes/iron_shell_crab.tscn")
const VOID_SENTINEL: PackedScene = preload("res://scenes/void_sentinel.tscn")
var created_regular: int = 0
var _centers: Array[Vector2] = []
var _environment: OpenWorldEnvironment
var _world: Node2D

func _ready() -> void:
    _world = get_parent() as Node2D
    _environment = _world.get_node("OpenWorldEnvironment") as OpenWorldEnvironment
    for node: Node in _world.get_node("Spawners").get_children():
        var spawner := node as MonsterSpawner
        if spawner == null:
            continue
        spawner.activation_radius = 1500.0
        _centers.append(spawner.position)
        if spawner.name == &"BossSpawner":
            _mark_boss(spawner, &"devimon")
        else:
            created_regular += 1
    var random := RandomNumberGenerator.new()
    random.seed = 2501
    var candidates: Array[Vector2] = []
    # รอบเมืองมีหลายกลุ่มทันที ไม่ต้องเดินหลายหน้าจอกว่าจะพบตัวแรก
    for radius: float in [660.0, 860.0, 1100.0]:
        for i: int in range(16):
            candidates.append(_environment.layout.village_center + Vector2.from_angle(i * TAU / 16.0) * radius)
    var field: Array[Vector2] = []
    for y: int in range(500, 6100, 420):
        for x: int in range(500, 10000, 440):
            field.append(Vector2(x, y) + Vector2(random.randf_range(-90, 90), random.randf_range(-90, 90)))
    # Fisher–Yates ใช้ RNG เฉพาะโลก ไม่กระทบ RNG ดาเมจ/ดรอป
    for i: int in range(field.size() - 1, 0, -1):
        var j: int = random.randi_range(0, i)
        var previous: Vector2 = field[i]
        field[i] = field[j]
        field[j] = previous
    candidates.append_array(field)
    for candidate: Vector2 in candidates:
        if created_regular >= regular_population:
            break
        var point: Vector2 = _walkable_near(candidate)
        if point == Vector2.INF or _too_close(point):
            continue
        _add_spawn("Habitat%03d" % created_regular, point, WILDS[created_regular % WILDS.size()], 90.0, 10.0)
        created_regular += 1
    _add_ep1_forest_population()
    _add_high_level_population()
    _add_boss("forest_guardian", Vector2(4100, 1900))
    _add_boss("etemon", Vector2(6200, 1600))
    _add_boss("myotismon", Vector2(8700, 3250))
    _add_boss("piedmon", Vector2(9250, 5450))
    _add_story_point("res://scenes/npc_emberclaw.tscn", Vector2(1500, 1060))
    _add_story_point("res://scenes/npc_gennai.tscn", Vector2(5600, 2650))
    _add_story_point("res://scenes/reach_odaiba_clue.tscn", Vector2(8000, 4000))

func _add_ep1_forest_population() -> void:
    # โซน Green Data Forest อยู่ถัดจาก ReachPoint ไปทางตะวันออก
    # ใช้จุดคงที่เพื่อให้ Quest Tracker และเส้นทางฟาร์มคาดเดาได้
    var byte_points: Array[Vector2] = [
        Vector2(2700, 1640), Vector2(2920, 1860), Vector2(3150, 1580),
        Vector2(3290, 2050), Vector2(3500, 1760), Vector2(3680, 2150),
        Vector2(2860, 2260), Vector2(3380, 2360), Vector2(3820, 1580)
    ]
    for i: int in range(byte_points.size()):
        var point: Vector2 = _walkable_near(byte_points[i])
        if point == Vector2.INF:
            continue
        var spawner := _add_spawn("EP1_ForestByte_%02d" % i, point, FOREST_BYTE, 72.0, 8.0)
        _mark_boss(spawner, &"forest_byte")

    var crab_points: Array[Vector2] = [
        Vector2(3020, 2460), Vector2(3440, 2570), Vector2(3890, 2380),
        Vector2(3720, 1320), Vector2(4050, 1450)
    ]
    for i: int in range(crab_points.size()):
        var point: Vector2 = _walkable_near(crab_points[i])
        if point == Vector2.INF:
            continue
        var spawner := _add_spawn("EP1_DataCrab_%02d" % i, point, FOREST_CRAB, 65.0, 10.0)
        _mark_boss(spawner, &"forest_crab")


func _add_high_level_population() -> void:
    # โซนกลาง-ปลายเกาะ: มอนขั้นต่ำ Lv18/Lv28/Lv42 พร้อม EXP และของดรอปเฉพาะ
    var crimson_points: Array[Vector2] = [Vector2(5050, 3300), Vector2(5350, 3550), Vector2(5650, 3150), Vector2(5900, 3500)]
    for i: int in range(crimson_points.size()):
        var p: Vector2 = _walkable_near(crimson_points[i])
        if p != Vector2.INF:
            _add_spawn("CrimsonByte_%02d" % i, p, CRIMSON_BYTE, 80.0, 12.0)

    var iron_points: Array[Vector2] = [Vector2(6700, 3900), Vector2(7050, 4200), Vector2(7350, 3750)]
    for i: int in range(iron_points.size()):
        var p: Vector2 = _walkable_near(iron_points[i])
        if p != Vector2.INF:
            _add_spawn("IronShell_%02d" % i, p, IRON_SHELL, 75.0, 15.0)

    var void_points: Array[Vector2] = [Vector2(8350, 4950), Vector2(8750, 5150), Vector2(9000, 4700)]
    for i: int in range(void_points.size()):
        var p: Vector2 = _walkable_near(void_points[i])
        if p != Vector2.INF:
            _add_spawn("VoidSentinel_%02d" % i, p, VOID_SENTINEL, 65.0, 18.0)


func _walkable_near(point: Vector2) -> Vector2:
    # พื้นที่ชนและพื้นที่เกิดอ้างอิง environment เดียวกัน กันเกิดในน้ำ/บ้าน
    if _environment.can_spawn_at(point, 45.0):
        return point
    for radius: float in [60.0, 120.0, 180.0]:
        for i: int in range(12):
            var offset: Vector2 = point + Vector2.from_angle(i * TAU / 12.0) * radius
            if _environment.can_spawn_at(offset, 45.0):
                return offset
    return Vector2.INF

func _too_close(point: Vector2) -> bool:
    for center: Vector2 in _centers:
        if point.distance_squared_to(center) < 160.0 * 160.0:
            return true
    return false

func _add_spawn(label: String, point: Vector2, scene: PackedScene, radius: float, respawn: float) -> MonsterSpawner:
    var spawner: MonsterSpawner = SPAWNER.instantiate() as MonsterSpawner
    spawner.name = label
    spawner.position = point
    spawner.monster_scene = scene
    spawner.spawn_radius = radius
    spawner.respawn_time = respawn
    spawner.activation_radius = 1500.0
    spawner.monster_parent = _world.get_node("Actors") as Node2D
    spawner.popup_layer = _world.get_node("DamagePopups") as Node2D
    _world.get_node("Spawners").add_child(spawner)
    _centers.append(point)
    return spawner

func _mark_boss(spawner: MonsterSpawner, id: StringName) -> void:
    # Tracker หาเป้าหมายได้แม้บอสยังไม่ถูกสร้างหรือกำลังรอเกิดใหม่
    var marker := QuestTarget.new()
    marker.name = "PermanentQuestTarget"
    marker.target_id = id
    spawner.add_child(marker)

func _add_boss(id: String, point: Vector2) -> void:
    var destination: Vector2 = _walkable_near(point)
    if destination == Vector2.INF:
        push_error("ไม่มีพื้นที่เกิดบอส " + id)
        return
    var scene: PackedScene = load("res://scenes/boss_" + id + ".tscn") as PackedScene
    _mark_boss(_add_spawn("Boss_" + id, destination, scene, 0.0, 25.0), StringName(id))

func _add_story_point(path: String, point: Vector2) -> void:
    var scene: PackedScene = load(path) as PackedScene
    var instance: Node2D = scene.instantiate() as Node2D
    var destination: Vector2 = _walkable_near(point)
    instance.position = destination if destination != Vector2.INF else point
    _world.get_node("StoryPoints").add_child(instance)
