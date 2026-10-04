extends Node
var failures: int = 0
var defeat_events: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func total_exp(progress: CharacterProgress) -> int:
    var result: int = progress.current_exp
    for at_level: int in range(1, progress.level):
        result += progress.exp_required(at_level)
    return result

func touch(button: Control, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 4
    event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
    event.pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func freeze(world: Node) -> void:
    world.get_node("Actors/Tamer").set_physics_process(false)
    world.get_node("Actors/Partner").set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)

func run() -> void:
    get_tree().root.content_scale_size = Vector2i(1280, 720)
    get_tree().root.size = Vector2i(1280, 720)
    QuestManager.save_path = "user://recovery_progress_cutscene_test.json"
    QuestManager.reset_progress(false)
    var progress := CharacterProgress.new()
    add_child(progress)
    progress.add_exp(400)
    check(progress.level == 3 and progress.current_exp == 150 and progress.max_exp == 200, "EXP ครั้งเดียวขึ้นหลายเลเวลและเก็บส่วนเกิน")
    var stats: Dictionary = progress.get_effective_stats()
    check(stats.max_hp == 220 and stats.attack == 25 and stats.speed == 242.0, "สเตตัสคำนวณจากฐานและโบนัสระดับ")
    progress.level_cap = 3
    progress.check_level_up()
    progress.add_exp(99999)
    check(progress.level == 3 and progress.current_exp == 0, "Level Cap ไม่สะสม EXP เพิ่ม")
    progress.queue_free()

    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    freeze(world)
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    var instance_id: int = partner.get_instance_id()
    partner.defeated.connect(func(): defeat_events += 1)
    partner.auto_battle = true
    partner.take_damage(99999)
    partner.take_damage(99999)
    check(partner.state == PartnerMonster.State.FAINTED and is_instance_valid(partner) and not partner.is_queued_for_deletion(), "HP 0 เปลี่ยนเป็น Fainted และไม่ลบ Node")
    await get_tree().create_timer(0.35).timeout
    check(partner.state == PartnerMonster.State.EGG and partner.egg_sprite.visible and not partner.sprite.visible, "Tween หดตัวแล้วแสดงไข่")
    check(defeat_events == 1 and not partner.auto_battle, "ความเสียหายซ้ำไม่ emit defeat ซ้ำ")
    check(hud.recover_button.visible and hud.party_status.partner_hp.value == 0, "UI แสดง Recover และหลอด HP 0")
    check(not partner.load_monster_data(partner.forms[0], false), "Loader ปกติไม่ชุบไข่ข้าม Recover")
    check(not partner.digivolve(), "ไข่เปลี่ยนร่างไม่ได้")
    var enemy: WildMonster = world.get_node("Spawners/SpawnerA").current_monster
    partner.command_attack(enemy)
    partner.command_skill(0, enemy)
    check(partner.state == PartnerMonster.State.EGG and partner.target == null, "ไข่ไม่รับ Attack/Skill")

    tamer.global_position = Vector2(800, 520)
    partner.global_position = Vector2(400, 520)
    var distance: float = partner.global_position.distance_to(tamer.global_position)
    var ds_before: float = tamer.ds
    partner.set_physics_process(true)
    await get_tree().create_timer(0.6).timeout
    partner.set_physics_process(false)
    check(partner.global_position.distance_to(tamer.global_position) < distance - 80, "ไข่ HP 0 ยังเดินตาม Navigation ได้")
    check(tamer.ds == ds_before, "ไข่ไม่ใช้ DS ต่อวินาที")

    partner.progress.add_exp(400)
    check(partner.progress.level == 3 and partner.hp == 0 and partner.state == PartnerMonster.State.EGG, "Level Up ระหว่างเป็นไข่ไม่ชุบชีวิต")
    touch(hud.recover_button, true)
    touch(hud.recover_button, false)
    await get_tree().process_frame
    check(partner.is_alive() and partner.hp == 220 and partner.form_index == 0 and partner.get_instance_id() == instance_id, "ปุ่ม Recover คืน Rookie HP เต็มและใช้ Node เดิม")
    check(partner.progress.level == 3 and partner.progress.current_exp == 150, "Recover เก็บ Level/EXP เดิม")
    partner.load_monster_data(partner.forms[1], false)
    check(partner.max_hp == 340, "Champion ใช้ฐานของร่างบวกโบนัสระดับ")
    partner.load_monster_data(partner.forms[0], false)
    check(partner.max_hp == 220, "กลับ Rookie ไม่บวกโบนัสซ้ำ")
    partner.enter_fainted(false)
    tamer.global_position = world.get_node("SafeZone").global_position
    await get_tree().physics_frame
    await get_tree().physics_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.15).timeout
    check(partner.is_alive() and partner.hp == partner.max_hp, "เข้า Safe Zone แล้วฟื้นฟูได้จริง")
    if not partner.is_alive():
        print("DIAGNOSTIC Safe Zone: ", world.get_node("SafeZone").get_overlapping_bodies(), " State: ", partner.state)
        get_tree().quit(1)
        return

    var tamer_total: int = total_exp(tamer.progress)
    var partner_total: int = total_exp(partner.progress)
    var reward: int = enemy.exp_reward
    enemy.take_damage(99999, partner)
    enemy.take_damage(99999, partner)
    check(total_exp(tamer.progress) == tamer_total + reward and total_exp(partner.progress) == partner_total + reward, "การฆ่าหนึ่งตัวให้ EXP ทั้งสองตัวครั้งเดียว")
    var spawner: MonsterSpawner = world.get_node("Spawners/SpawnerA")
    var tamer_enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
    world.get_node("Actors").add_child(tamer_enemy)
    tamer_total = total_exp(tamer.progress)
    tamer_enemy.take_damage(99999, tamer)
    check(total_exp(tamer.progress) == tamer_total + tamer_enemy.exp_reward, "รองรับเครดิตการฆ่าจาก Tamer")

    tamer.ds = 100
    var level_before: int = partner.progress.level
    tamer.command_digivolve()
    var cutscene: DigivolveCutscene = hud.active_cutscene
    check(is_instance_valid(cutscene) and get_tree().paused and partner.evolution_busy, "ปุ่ม Digivolve เปิด CanvasLayer และ pause เกม")
    check(partner.form_index == 0 and tamer.ds == 75, "จอง DS แล้วรอคัตซีนก่อนเปลี่ยนตัวในสนาม")
    tamer.command_digivolve()
    check(hud.active_cutscene == cutscene and tamer.ds == 75, "กดซ้ำไม่สร้างคัตซีนหรือหัก DS ซ้ำ")
    var respawn_left: float = spawner.get_respawn_time_left()
    await get_tree().create_timer(1.6, true).timeout
    check(cutscene.player.is_playing() and cutscene.new_sprite.modulate.a > 0.9 and cutscene.old_sprite.modulate.a < 0.1, "AnimationPlayer เล่นต่อขณะ pause และสลับภาพพรีวิว")
    check(absf(spawner.get_respawn_time_left() - respawn_left) < 0.05, "Timer Respawn ในสนามหยุดระหว่างคัตซีน")
    await get_tree().create_timer(1.3, true).timeout
    check(not get_tree().paused and not partner.evolution_busy and partner.form_index == 1, "คัตซีนจบแล้ว Commit ร่างและ Resume")
    check(tamer.ds == 75 and partner.progress.level == level_before and not is_instance_valid(hud.active_cutscene), "หัก DS ครั้งเดียว เก็บเลเวล และเก็บกวาดคัตซีน")

    partner.load_monster_data(partner.forms[0], false)
    tamer.ds = 100
    tamer.command_digivolve()
    cutscene = hud.active_cutscene
    cutscene.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    check(not get_tree().paused and not partner.evolution_busy and tamer.ds == 100 and partner.form_index == 0, "ลบคัตซีนกลางทางคืน DS และ Resume")
    get_tree().paused = true
    cutscene = preload("res://scenes/digivolve_cutscene.tscn").instantiate()
    get_tree().root.add_child(cutscene)
    check(not cutscene.play_for(partner), "ไม่เริ่มคัตซีนทับ pause ของระบบอื่น")
    cutscene.queue_free()
    await get_tree().process_frame
    check(get_tree().paused, "คัตซีนที่ไม่ได้ถือ pause ไม่ปลด pause ของระบบอื่น")
    get_tree().paused = false

    tamer.command_digivolve()
    check(get_tree().paused, "เริ่มคัตซีนสำหรับทดสอบออกจาก World")
    cutscene = hud.active_cutscene
    world.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    check(not get_tree().paused and not is_instance_valid(cutscene), "ออกจาก World ระหว่างคัตซีนไม่ทำให้ pause ค้าง")
    world = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    freeze(world)
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    check(tamer.ds == 100 and not partner.evolution_busy, "ออกจาก World กลางคัตซีนไม่บันทึก DS ที่จองไว้")

    partner.enter_fainted(false)
    var saved_level: int = partner.progress.level
    tamer.save_party_progress()
    world.queue_free()
    await get_tree().process_frame
    QuestManager.reset_progress(false)
    check(QuestManager.load_progress(), "โหลด Save ปาร์ตี้ร่วมกับเควสต์")
    world = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    freeze(world)
    partner = world.get_node("Actors/Partner")
    check(partner.state == PartnerMonster.State.EGG and partner.hp == 0 and partner.progress.level == saved_level, "เปิด Scene ใหม่คืนไข่ HP 0 และ Level เดิม")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
