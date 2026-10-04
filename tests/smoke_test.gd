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
## ทดสอบพฤติกรรมข้ามระบบในฉากจริง ใช้ --headless -s res://tests/smoke_test.gd
var failures: int = 0

func _ready() -> void:
    run.call_deferred()

func check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func touch(index: int, position: Vector2, down: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = down
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func run() -> void:
    quest_manager = root.get_node("QuestManager")
    quest_manager.save_path = "user://smoke_test_story.json"
    quest_manager.reset_progress(false)
    var world: Node2D = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    world.get_node("Spawners/BossSpawner").free()
    root.content_scale_size = Vector2i(1280, 720)
    root.size = Vector2i(1280, 720)
    root.add_child(world)
    await process_frame
    await physics_frame
    await physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var enemy: WildMonster = (world.get_node("Spawners/SpawnerA") as MonsterSpawner).current_monster
    var hud: MobileHUD = world.get_node("MobileHUD")
    for wild: Node in get_nodes_in_group("wild_monsters"):
        wild.set_physics_process(false)
    tamer.set_physics_process(false)
    partner.set_physics_process(false)

    check(partner.hp == 120 and partner.current_form.skills.size() == 2, "เริ่มด้วย HP และชุดสกิลร่างพื้นฐาน")
    var database: MonsterDatabase = load("res://data/monster_database.tres")
    check(database.find_by_id(&"rookie") == partner.forms[0] and database.find_by_id(&"missing") == null, "แค็ตตาล็อกโหลดตาม id และคืน null เมื่อไม่พบ")
    check(partner.max_hp == 120 and partner.attack_power == 15 and partner.move_speed == 240.0, "โหลดค่าระหว่างเล่นจาก MonsterData")
    var bad_data: MonsterData = partner.forms[1].duplicate() as MonsterData
    bad_data.max_hp = 0
    var saved_next: MonsterData = partner.forms[1]
    partner.forms[1] = bad_data
    check(not partner.digivolve() and tamer.ds == 100.0 and partner.form_index == 0, "ร่างข้อมูลผิดไม่เปลี่ยนค่าเดิมและไม่หัก DS")
    check(not partner.load_monster_data(null) and partner.max_hp == 120, "โหลด null ไม่ทำให้สถานะเดิมเสียหาย")
    partner.forms[1] = saved_next
    var other: PartnerMonster = load("res://scenes/partner.tscn").instantiate()
    world.add_child(other)
    other.set_physics_process(false)
    partner.take_damage(60)
    check(other.hp == 120 and partner.forms[0].max_hp == 120, "สอง instance แชร์ Resource แต่ HP ไม่กระทบกัน")
    partner.active_skills.remove_at(0)
    check(partner.forms[0].skills.size() == 2, "แก้ Array สกิลระหว่างเล่นไม่แก้ Array ของ Resource")
    partner.load_monster_data(partner.forms[0])
    other.queue_free()
    tamer.ds = 10.0
    check(not partner.digivolve() and partner.form_index == 0 and tamer.ds == 10.0, "DS ไม่พอ: ไม่เปลี่ยนร่างและไม่หัก DS")
    tamer.ds = 100.0
    check(partner.digivolve(), "เปลี่ยนร่างสำเร็จ")
    check(partner.sprite.sprite_frames == partner.current_form.sprite_frames and String(partner.sprite.animation).begins_with("idle_") and partner.sprite.is_playing(), "โหลดร่างใหม่สลับ SpriteFrames และเล่น Idle ตามทิศทันที")
    check(partner.max_hp == 240 and partner.attack_power == 30 and partner.move_speed == 270.0 and partner.active_skills.size() == 4, "เปลี่ยนค่าต่อสู้และชุดสกิลพร้อมกัน")
    check(partner.hp == 120 and tamer.ds == 75.0, "รักษา HP 50% และหัก DS 25")
    check(partner.current_form.skills.size() == 4 and partner.sprite.scale == partner.current_form.sprite_scale, "สลับสกิลและขนาด Sprite")
    check(not partner.digivolve() and tamer.ds == 75.0, "ร่าง Ultimate ที่ยังล็อกไม่หัก DS")
    partner.set_physics_process(true)
    tamer.ds = 0.0
    await physics_frame
    await physics_frame
    check(partner.form_index == 0 and partner.hp == 60, "DS หมดกลับร่างพื้นฐานพร้อมรักษา HP")
    partner.set_physics_process(false)
    tamer.ds = 100.0

    # ทดสอบ input pipeline จริง: นิ้วแรกคุม Joystick นิ้วที่สองกด Digivolve
    var joystick_center: Vector2 = hud.joystick.get_global_transform_with_canvas() * (hud.joystick.size * 0.5)
    touch(0, joystick_center + Vector2(60, 0), true)
    await process_frame
    check(hud.joystick.move_vector.x > 0.5, "Joystick รับ finger 0")
    var evolve_center: Vector2 = hud.evolve_button.get_global_transform_with_canvas() * (hud.evolve_button.size * 0.5)
    touch(1, evolve_center, true)
    await process_frame
    check(partner.evolution_busy and get_tree().paused, "finger 1 เปิดคัตซีนขณะ finger 0 เดิน")
    touch(1, evolve_center, false)
    touch(0, joystick_center, false)
    await create_timer(2.9, true).timeout
    check(partner.form_index == 1 and not get_tree().paused, "คัตซีนจบแล้วเปลี่ยนร่างและ Resume")
    check(hud.joystick.move_vector == Vector2.ZERO, "นิ้วที่ปล่อยระหว่างคัตซีนไม่ทำให้ Joystick ค้าง")
    touch(0, joystick_center + Vector2(60, 0), true)
    await process_frame
    check(hud.joystick.move_vector.x > 0.5, "กลับจากคัตซีนแล้วรับ Joystick ใหม่ได้")
    touch(0, joystick_center, false)
    await process_frame

    # Follow ใช้ NavigationAgent ในฉากจริง
    tamer.global_position = Vector2(550, 380)
    partner.global_position = Vector2(300, 380)
    var initial_distance: float = partner.global_position.distance_to(tamer.global_position)
    partner.set_physics_process(true)
    await create_timer(0.7).timeout
    check(partner.global_position.distance_to(tamer.global_position) < initial_distance - 50.0, "Follow เคลื่อนที่ตาม waypoint ของ NavigationAgent")
    partner.set_physics_process(false)

    # Touch target ต้องเกิดบน world และโชว์วงแหวน
    enemy.global_position = Vector2(700, 350)
    partner.global_position = Vector2(650, 350)
    await physics_frame
    await physics_frame
    touch(2, enemy.global_position, true)
    await process_frame
    check(tamer.target == enemy and partner.target == enemy and enemy.ring.visible, "แตะศัตรูส่ง Target และแสดงวงล็อก")
    touch(2, enemy.global_position, false)
    await process_frame
    var attack_center: Vector2 = hud.attack_button.get_global_transform_with_canvas() * (hud.attack_button.size * 0.5)
    touch(3, attack_center, true)
    await process_frame
    check(tamer.target == enemy, "กด UI ไม่ล้าง Target หรือเลือกทะลุ UI")
    touch(3, attack_center, false)
    await process_frame
    var original_hp: int = enemy.hp
    tamer.ds = 100.0
    tamer.command_skill(0)
    partner.set_physics_process(true)
    await create_timer(1.0).timeout
    check(enemy.hp < original_hp and partner.cooldown_remaining(partner.current_form.skills[0]) > 0.0, "คู่หูสร้างความเสียหายและเริ่มคูลดาวน์สกิล")
    partner.set_physics_process(false)
    var used_skill: MonsterSkill = partner.current_form.skills[0]
    var cooldown_before: float = partner.cooldown_remaining(used_skill)
    partner._apply_form(0, true)
    tamer.ds = 100.0
    partner.digivolve()
    check(partner.cooldown_remaining(used_skill) == cooldown_before, "เปลี่ยนร่างไม่ล้างคูลดาวน์สกิลเดิม")
    var partner_hp_before: int = partner.hp
    enemy.set_physics_process(true)
    await create_timer(0.1).timeout
    check(partner.hp < partner_hp_before, "ศัตรูโต้กลับและคู่หูเป็นผู้รับความเสียหาย")
    enemy.set_physics_process(false)
    enemy.take_damage(9999, partner)
    await process_frame
    partner.set_physics_process(true)
    await physics_frame
    await physics_frame
    check(not is_instance_valid(partner.target), "ศัตรูถูกลบแล้วล้างเป้าหมายได้โดยไม่เกิด error")

    var second_enemy: WildMonster = (world.get_node("Spawners/SpawnerB") as MonsterSpawner).current_monster
    second_enemy.global_position = partner.global_position + Vector2(100, 0)
    partner.auto_battle = true
    partner._search_left = 0.0
    await create_timer(0.1).timeout
    check(is_instance_valid(partner.target) and partner.state == PartnerMonster.State.BATTLE, "Auto-Battle หาเป้าหมายในระยะแล้วเข้า Battle")

    # คู่หูล้มต้องยกเลิก Auto และไม่สามารถชุบชีวิตด้วย Digivolve
    partner.auto_battle = true
    partner.take_damage(9999)
    check(not partner.is_alive() and not partner.auto_battle and not partner.digivolve(), "คู่หูล้ม: หยุดต่อสู้และห้ามเปลี่ยนร่าง")
    partner.load_monster_data(partner.forms[0])
    check(partner.hp == 0 and not partner.sprite.is_playing(), "โหลดร่างใหม่โดย preserve_hp ไม่ชุบคู่หูที่ล้มแล้ว")
    world.queue_free()
    await process_frame
    print("RESULT: ", failures, " failure(s)")
    quit(1 if failures > 0 else 0)
