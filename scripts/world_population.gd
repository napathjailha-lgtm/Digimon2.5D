extends Node
## เกาะเดียว: กระจายจุดเกิดแบบ seed คงที่ และเปิด AI เฉพาะบริเวณผู้เล่น
@export_range(20, 500) var regular_population: int = 240
const SPAWNER: PackedScene = preload("res://scenes/monster_spawner.tscn")
const WILDS: Array[PackedScene] = [preload("res://scenes/wild_monster.tscn"), preload("res://scenes/wild_monster_crab.tscn")]
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
            _mark_boss(spawner, &"void_warden")
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
    _add_boss("iron_howler", Vector2(6200, 1600))
    _add_boss("night_regent", Vector2(8700, 3250))
    _add_boss("masked_harbinger", Vector2(9250, 5450))
    _add_story_point("res://scenes/npc_archivist_eon.tscn", Vector2(5600, 2650))
    _add_story_point("res://scenes/reach_signal_ruins.tscn", Vector2(8000, 4000))

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
