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
const THUNDER_LYNX: PackedScene = preload("res://scenes/thunder_lynx.tscn")
const MAGMA_RAM: PackedScene = preload("res://scenes/magma_ram.tscn")
const TIDECOIL_MANTA: PackedScene = preload("res://scenes/tidecoil_manta.tscn")
const VERDANT_BULWARK: PackedScene = preload("res://scenes/verdant_bulwark.tscn")
const NIGHTTALON_HARRIER: PackedScene = preload("res://scenes/nighttalon_harrier.tscn")
const FIELD_QUEST_NPC: PackedScene = preload("res://scenes/field_quest_npc.tscn")
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
    _add_elite_population()
    _add_boss("forest_guardian", Vector2(4100, 1900))
    _add_boss("etemon", Vector2(6200, 1600))
    _add_boss("myotismon", Vector2(8700, 3250))
    _add_boss("piedmon", Vector2(9250, 5450))
    _add_story_point("res://scenes/npc_emberclaw.tscn", Vector2(1500, 1060))
    _add_story_point("res://scenes/npc_gennai.tscn", Vector2(5600, 2650))
    _add_story_point("res://scenes/reach_odaiba_clue.tscn", Vector2(8000, 4000))

    # Frontier Operations: NPC ใหม่ 10 คน กระจายตามเส้นทางหลังเนื้อเรื่องหลัก
    _add_quest_npc(&"frontier_mira", "Mira", Vector2(5750, 2380), Color("62d8ff"))
    _add_quest_npc(&"frontier_nami", "Nami", Vector2(4920, 2920), Color("70d6c3"))
    _add_quest_npc(&"frontier_rook", "Rook", Vector2(6280, 2350), Color("88aaff"))
    _add_quest_npc(&"frontier_bramm", "Bramm", Vector2(6760, 3380), Color("ff9c62"))
    _add_quest_npc(&"frontier_torque", "Torque", Vector2(7110, 4090), Color("e6c56b"))
    _add_quest_npc(&"frontier_liora", "Liora", Vector2(7650, 4470), Color("7fe28d"))
    _add_quest_npc(&"frontier_cyra", "Cyra", Vector2(8180, 4660), Color("c69cff"))
    _add_quest_npc(&"frontier_sena", "Sena", Vector2(8580, 4860), Color("8fd0ff"))
    _add_quest_npc(&"frontier_orion", "Orion", Vector2(9160, 5220), Color("f0b6ff"))
    _add_quest_npc(&"frontier_pax", "Pax", Vector2(9620, 5520), Color("ffd36a"))

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
            var spawner := _add_spawn("CrimsonByte_%02d" % i, p, CRIMSON_BYTE, 80.0, 12.0)
            _mark_boss(spawner, &"crimson_byte")

    var iron_points: Array[Vector2] = [Vector2(6700, 3900), Vector2(7050, 4200), Vector2(7350, 3750)]
    for i: int in range(iron_points.size()):
        var p: Vector2 = _walkable_near(iron_points[i])
        if p != Vector2.INF:
            var spawner := _add_spawn("IronShell_%02d" % i, p, IRON_SHELL, 75.0, 15.0)
            _mark_boss(spawner, &"iron_shell_crab")

    var void_points: Array[Vector2] = [Vector2(8350, 4950), Vector2(8750, 5150), Vector2(9000, 4700)]
    for i: int in range(void_points.size()):
        var p: Vector2 = _walkable_near(void_points[i])
        if p != Vector2.INF:
            var spawner := _add_spawn("VoidSentinel_%02d" % i, p, VOID_SENTINEL, 65.0, 18.0)
            _mark_boss(spawner, &"void_sentinel")


func _add_elite_population() -> void:
    # Elite ชุดใหม่เริ่มมองเห็นได้จากรอบนอก Data Harbor แล้วค่อยไล่ระดับไปปลายเกาะ
    # ใช้ activation radius มากกว่ามอนทั่วไปเล็กน้อย เพื่อไม่ให้ผู้เล่นเดินผ่านโซนแล้วเห็นพื้นที่ว่าง
    var tide_points: Array[Vector2] = [
        Vector2(4580, 2550), Vector2(4720, 3050), Vector2(4850, 2050)
    ]
    for i: int in range(tide_points.size()):
        var p: Vector2 = _walkable_near(tide_points[i])
        if p != Vector2.INF:
            var spawner := _add_elite_spawn("TidecoilManta_%02d" % i, p, TIDECOIL_MANTA, 92.0, 13.0)
            _mark_boss(spawner, &"tidecoil_manta")

    var thunder_points: Array[Vector2] = [
        Vector2(6300, 2500), Vector2(6350, 3150), Vector2(6150, 3550)
    ]
    for i: int in range(thunder_points.size()):
        var p: Vector2 = _walkable_near(thunder_points[i])
        if p != Vector2.INF:
            var spawner := _add_elite_spawn("ThunderLynx_%02d" % i, p, THUNDER_LYNX, 105.0, 12.0)
            _mark_boss(spawner, &"thunder_lynx")

    var magma_points: Array[Vector2] = [
        Vector2(6650, 3550), Vector2(6950, 3900), Vector2(7200, 4300)
    ]
    for i: int in range(magma_points.size()):
        var p: Vector2 = _walkable_near(magma_points[i])
        if p != Vector2.INF:
            var spawner := _add_elite_spawn("MagmaRam_%02d" % i, p, MAGMA_RAM, 88.0, 15.0)
            _mark_boss(spawner, &"magma_ram")

    var verdant_points: Array[Vector2] = [
        Vector2(7480, 4550), Vector2(7850, 5000)
    ]
    for i: int in range(verdant_points.size()):
        var p: Vector2 = _walkable_near(verdant_points[i])
        if p != Vector2.INF:
            var spawner := _add_elite_spawn("VerdantBulwark_%02d" % i, p, VERDANT_BULWARK, 78.0, 20.0)
            _mark_boss(spawner, &"verdant_bulwark")

    var night_points: Array[Vector2] = [
        Vector2(8250, 5000), Vector2(8650, 5350), Vector2(9150, 5000)
    ]
    for i: int in range(night_points.size()):
        var p: Vector2 = _walkable_near(night_points[i])
        if p != Vector2.INF:
            var spawner := _add_elite_spawn("NighttalonHarrier_%02d" % i, p, NIGHTTALON_HARRIER, 110.0, 18.0)
            _mark_boss(spawner, &"nighttalon_harrier")


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

func _add_elite_spawn(label: String, point: Vector2, scene: PackedScene, radius: float, respawn: float) -> MonsterSpawner:
    var spawner: MonsterSpawner = _add_spawn(label, point, scene, radius, respawn)
    spawner.activation_radius = 2300.0
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

func _add_quest_npc(id: StringName, display_name: String, point: Vector2, accent: Color) -> void:
    var npc := FIELD_QUEST_NPC.instantiate() as FieldQuestNPC
    npc.name = "FrontierNPC_" + String(id)
    npc.npc_id = id
    npc.display_name = display_name
    npc.accent_color = accent
    var destination: Vector2 = _walkable_near(point)
    npc.position = destination if destination != Vector2.INF else point
    _world.get_node("StoryPoints").add_child(npc)


func _add_story_point(path: String, point: Vector2) -> void:
    var scene: PackedScene = load(path) as PackedScene
    var instance: Node2D = scene.instantiate() as Node2D
    var destination: Vector2 = _walkable_near(point)
    instance.position = destination if destination != Vector2.INF else point
    _world.get_node("StoryPoints").add_child(instance)
