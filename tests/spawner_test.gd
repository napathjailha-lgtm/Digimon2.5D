extends Node
# รันเป็น Scene หลัง Autoload พร้อม เพื่อให้ทดสอบ dependency ของ QuestManager ได้ครบ
var root: Window:
    get: return get_tree().root
var current_scene: Node:
    get: return get_tree().current_scene
    set(value): get_tree().current_scene = value
var paused: bool:
    get: return get_tree().paused
    set(value): get_tree().paused = value
var process_frame: Signal:
    get: return get_tree().process_frame
var physics_frame: Signal:
    get: return get_tree().physics_frame

func create_timer(seconds: float, process_always: bool = true) -> SceneTreeTimer:
    return get_tree().create_timer(seconds, process_always)

func get_nodes_in_group(group: StringName) -> Array[Node]:
    return get_tree().get_nodes_in_group(group)

func get_processed_tweens() -> Array[Tween]:
    return get_tree().get_processed_tweens()

func quit(code: int = 0) -> void:
    get_tree().quit(code)
var quest_manager: Variant
## ทดสอบวงจรเกิด/ตาย/เกิดใหม่ และ lifecycle ใน Scene จริง
var failures: int = 0

func _ready() -> void:
    run.call_deferred()

func check(condition: bool, description: String) -> void:
    if condition:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func run() -> void:
    quest_manager = root.get_node("QuestManager")
    quest_manager.save_path = "user://spawner_test_story.json"
    quest_manager.reset_progress(false)
    seed(54321)
    root.size = Vector2i(1280, 720)
    var world: Node2D = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    world.get_node("Spawners/BossSpawner").free()
    root.add_child(world)
    await process_frame
    await process_frame
    var a: MonsterSpawner = world.get_node("Spawners/SpawnerA")
    var b: MonsterSpawner = world.get_node("Spawners/SpawnerB")
    var c: MonsterSpawner = world.get_node("Spawners/SpawnerC")
    for node: Node in world.get_node("Actors").get_children():
        node.set_physics_process(false)
    for spawner: MonsterSpawner in [a, b, c]:
        spawner.monster_spawned.connect(func(monster: WildMonster) -> void: monster.set_physics_process(false))
    check(get_nodes_in_group("wild_monsters").size() == 3, "เริ่มเกมแต่ละ Spawner สร้างหนึ่งตัว")
    check(a.current_monster != b.current_monster and b.current_monster != c.current_monster, "Spawner แต่ละจุดมี instance แยกกัน")
    check(a.current_monster.global_position.distance_to(a.global_position) <= a.spawn_radius, "สุ่มตำแหน่งเกิดในวงรัศมี")
    check(a.current_monster._home == a.global_position and a.current_monster.wander_radius == a.spawn_radius, "บ้านและพื้นที่ Wander ใช้ศูนย์กลาง Spawner")
    a._spawn_monster()
    check(get_nodes_in_group("wild_monsters").size() == 3, "เรียก spawn ซ้ำไม่สร้างตัวซ้อน")

    # จำลองศพมี death animation: died ก่อน แล้ว tree_exited ช้ากว่า
    a.respawn_time = 0.25
    var old: WildMonster = a.current_monster
    var old_id: int = old.get_instance_id()
    var b_id: int = b.current_monster.get_instance_id()
    old.hp = 0
    old.died.emit(old)
    check(a.current_monster == null and a.get_respawn_time_left() > 0.0, "เริ่ม Timer ทันทีเมื่อ died")
    await create_timer(0.1).timeout
    old.queue_free()
    await process_frame
    await process_frame
    check(a.get_respawn_time_left() < 0.18, "tree_exited ตามหลัง died ไม่รีเซ็ตเวลา")
    await create_timer(0.18).timeout
    await process_frame
    check(is_instance_valid(a.current_monster) and a.current_monster.get_instance_id() != old_id, "ครบเวลาเกิด instance ใหม่")
    check(a.current_monster.hp == a.current_monster.max_hp and a.respawn_timer.is_stopped(), "ตัวใหม่ HP เต็มและ Timer หยุดรอการตายครั้งถัดไป")
    check(b.current_monster.get_instance_id() == b_id, "Respawn ของ A ไม่กระทบจุด B")

    # ทดสอบพิกัดใต้ parent ที่มี transform และรัศมีศูนย์
    var actors: Node2D = world.get_node("Actors")
    actors.position = Vector2(50, 30)
    actors.scale = Vector2(1.2, 1.1)
    a.spawn_radius = 0.0
    a.respawn_time = 0.1
    a.current_monster.take_damage(9999)
    await create_timer(0.16).timeout
    await process_frame
    check(is_instance_valid(a.current_monster) and a.current_monster.global_position.is_equal_approx(a.global_position), "รัศมีศูนย์เกิดตรงจุดแม้ Actors มี transform")
    check(get_nodes_in_group("wild_monsters").size() == 3, "ตายและเกิดใหม่หลายรอบยังมีหนึ่งตัวต่อจุด")

    b.respawn_time = 0.1
    b.current_monster.queue_free()
    await create_timer(0.17).timeout
    await process_frame
    check(is_instance_valid(b.current_monster) and b.current_monster.get_instance_id() != b_id, "ลบโดยตรงใช้ tree_exited เพื่อ Respawn")

    c.respawn_time = 0.2
    c.current_monster.take_damage(9999)
    paused = true
    var time_before: float = c.get_respawn_time_left()
    await create_timer(0.25, true).timeout
    check(absf(c.get_respawn_time_left() - time_before) < 0.02 and c.current_monster == null, "Pause เกมแล้ว Timer Respawn หยุดนับ")
    paused = false
    await create_timer(0.26).timeout
    await process_frame
    check(is_instance_valid(c.current_monster), "Resume แล้วนับต่อและเกิดใหม่")

    var standalone: MonsterSpawner = load("res://scenes/monster_spawner.tscn").instantiate()
    standalone.position = Vector2(150, 150)
    standalone.spawn_radius = 0.0
    world.add_child(standalone)
    await process_frame
    await process_frame
    var standalone_monster: WildMonster = standalone.current_monster
    check(is_instance_valid(standalone_monster) and standalone_monster.get_parent() == standalone, "Spawner แบบ standalone ใช้ตัวเองเป็น parent ได้")
    standalone.queue_free()
    await process_frame
    await process_frame
    check(not is_instance_valid(standalone_monster), "ลบ Spawner แล้วเก็บกวาดมอนสเตอร์ที่ดูแล")

    a.current_monster.take_damage(9999)
    world.queue_free()
    await process_frame
    await create_timer(0.3).timeout
    check(get_nodes_in_group("wild_monsters").is_empty(), "ออกจาก World ขณะรอ Respawn ไม่มีมอนสเตอร์เกิดค้าง")
    print("RESULT: ", failures, " failure(s)")
    quit(1 if failures > 0 else 0)
