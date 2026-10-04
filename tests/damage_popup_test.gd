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
## ทดสอบการเชื่อม HP, Popup, Tween และการลบศัตรูใน Scene จริง
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
    quest_manager.save_path = "user://damage_popup_test_story.json"
    quest_manager.reset_progress(false)
    seed(12345)
    root.size = Vector2i(1280, 720)
    var world: Node2D = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    world.get_node("Spawners/BossSpawner").free()
    root.add_child(world)
    await process_frame
    await physics_frame
    for node: Node in world.get_node("Actors").get_children():
        node.set_physics_process(false)
    var enemy: WildMonster = (world.get_node("Spawners/SpawnerA") as MonsterSpawner).current_monster
    var layer: Node2D = world.get_node("DamagePopups")
    # ใช้ transform ต่างจากศัตรูเพื่อจับข้อผิดพลาด global/local
    layer.position = Vector2(130, 20)
    layer.scale = Vector2(1.3, 1.2)
    var head_position: Vector2 = enemy.damage_origin.global_position

    enemy.take_damage(0)
    enemy.take_damage(-10)
    check(enemy.hp == 160 and layer.get_child_count() == 0, "damage ศูนย์/ติดลบไม่ลด HP และไม่สร้าง Popup")
    enemy.take_damage(25)
    check(enemy.hp == 135 and layer.get_child_count() == 1, "take_damage แบบหนึ่ง argument ลด HP และสร้าง Popup")
    var popup: DamagePopup = layer.get_child(0)
    check(popup.label.text == "25" and popup.label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ข้อความดาเมจถูกต้องและไม่บล็อก Touch Target")
    check(absf(popup.global_position.y - head_position.y) < 0.01 and absf(popup.global_position.x - head_position.x) <= popup.spawn_spread * layer.scale.x, "เริ่มเหนือหัวถูกพิกัดแม้ layer มี transform")
    var popup_start: Vector2 = popup.global_position
    enemy.global_position += Vector2(100, 80)
    check(popup.global_position.is_equal_approx(popup_start), "ศัตรูเดินแล้ว Popup ไม่เคลื่อนตาม")
    await create_timer(0.12).timeout
    check(popup.scale.x > 1.0 and popup.global_position.y < popup_start.y, "Tween ขยาย Pop และลอยขึ้นพร้อมกัน")
    check(is_equal_approx(popup.modulate.a, 1.0), "ยังไม่ Fade ก่อนถึงช่วงท้าย")

    enemy.take_damage(9999)
    var final_popup: DamagePopup = layer.get_child(1)
    check(final_popup.label.text == "9999", "hit สุดท้ายแสดงดาเมจที่ได้รับแม้เกิน HP คงเหลือ")
    await process_frame
    check(not is_instance_valid(enemy) and is_instance_valid(final_popup), "ศัตรูถูกลบแต่ Popup ของ hit สุดท้ายยังอยู่")

    var other: WildMonster = (world.get_node("Spawners/SpawnerB") as MonsterSpawner).current_monster
    var positions: Array[float] = []
    for index: int in range(8):
        other.take_damage(1)
        var burst_popup: DamagePopup = layer.get_child(layer.get_child_count() - 1)
        positions.append(burst_popup.position.x)
    check(layer.get_child_count() == 10 and other.hp == 152, "โจมตีรัวสร้างหลาย Popup และคิด HP ครบทุก hit")
    positions.sort()
    check(positions[0] < positions[-1], "จุดเริ่ม Popup กระจายซ้าย/ขวา")
    await create_timer(0.45).timeout
    check(is_instance_valid(popup) and popup.modulate.a > 0.0 and popup.modulate.a < 1.0, "Fade เริ่มในช่วงท้ายของ lifetime")
    await create_timer(0.5).timeout
    await process_frame
    check(layer.get_child_count() == 0 and not is_instance_valid(final_popup), "Tween จบแล้ว queue_free ลบ Popup ทุกตัว")
    check(get_processed_tweens().is_empty(), "ไม่มี Tween ค้างหลัง Popup ถูกลบ")
    world.queue_free()
    await process_frame
    print("RESULT: ", failures, " failure(s)")
    quit(1 if failures > 0 else 0)
