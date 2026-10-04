extends Node
## ทดสอบจังหวะ hit/release จริงและการยกเลิกแอคชั่น ไม่ใช่แค่จำนวนภาพ
var failures: int = 0
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, description: String) -> void:
    if ok:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func make_enemy(point: Vector2) -> WildMonster:
    var enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
    enemy.max_hp = 10000
    enemy.position = point
    world.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func projectiles() -> Array[Node]:
    var live: Array[Node] = []
    for node: Node in get_tree().get_nodes_in_group("skill_projectiles"):
        if not node.is_queued_for_deletion():
            live.append(node)
    return live

func reset_action(enemy: WildMonster) -> void:
    partner.cancel_battle()
    partner._basic_cooldown = 0.0
    partner.skill_cooldowns.clear()
    for node: Node in projectiles():
        node.queue_free()
    partner.target = enemy
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp

func run() -> void:
    QuestManager.save_path = "user://combat_actions_v13_test.json"
    QuestManager.reset_progress(false)
    world = Node2D.new()
    add_child(world)
    tamer = preload("res://scenes/tamer.tscn").instantiate()
    partner = preload("res://scenes/partner.tscn").instantiate()
    tamer.partner = partner
    partner.tamer = tamer
    tamer.position = Vector2(50, 200)
    partner.position = Vector2(100, 200)
    world.add_child(tamer)
    world.add_child(partner)
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    var enemy: WildMonster = make_enemy(Vector2(145, 200))
    var second: WildMonster = make_enemy(Vector2(170, 200))
    await get_tree().physics_frame
    for form: MonsterData in partner.forms:
        check(form.validation_error().is_empty(), String(form.id) + " ผ่าน validation ของภาพแอคชั่น")
        for direction: String in ["down", "right", "up", "left"]:
            for prefix: String in ["attack", "cast"]:
                var key := StringName(prefix + "_" + direction)
                check(form.sprite_frames.get_frame_count(key) == 4 and not form.sprite_frames.get_animation_loop(key),
                    String(form.id) + " " + String(key) + " มี 4 เฟรมและปิด Loop")
    var bad: MonsterData = partner.forms[0].duplicate()
    bad.sprite_frames = bad.sprite_frames.duplicate()
    bad.sprite_frames.set_animation_loop(&"cast_right", true)
    check(not bad.validation_error().is_empty(), "ปฏิเสธ Cast ที่เปิด Loop ป้องกันแอคชั่นค้าง")
    bad = partner.forms[0].duplicate()
    bad.skills = bad.skills.duplicate()
    bad.skills[0] = bad.skills[0].duplicate()
    bad.skills[0].release_frame = 999
    check(not bad.validation_error().is_empty(), "ปฏิเสธ release_frame นอกชุดภาพ")

    reset_action(enemy)
    check(partner._start_basic_attack(), "เริ่มตีธรรมดา")
    check(enemy.hp == 10000 and partner.sprite.animation == &"attack_right", "เริ่มเตรียมท่ายังไม่หัก HP และหันถูกทิศ")
    partner.sprite.frame = 1
    check(enemy.hp == 10000, "เฟรมง้างยังไม่ลงดาเมจ")
    partner.sprite.frame = 2
    check(enemy.hp == 10000 - partner.attack_power, "เฟรม Strike ลงดาเมจธรรมดาหนึ่งครั้ง")
    partner.sprite.frame = 3
    partner.sprite.frame = 2
    partner.combat_action._on_frame_changed()
    check(enemy.hp == 10000 - partner.attack_power, "ย้อนเฟรม/สัญญาณซ้ำไม่ทำ hit ซ้ำ")
    await get_tree().create_timer(0.25).timeout
    check(not partner.combat_action.busy and String(partner.sprite.animation).begins_with("idle_"), "แอนิเมชันจบคืน Idle และปลดล็อกจริง")
    check(partner.sprite.scale == partner.current_form.sprite_scale, "คืนสเกลเดินหลัง action")

    reset_action(enemy)
    check(partner._try_skill(0), "เริ่ม Baby Flame")
    check(partner.sprite.animation == &"cast_right" and projectiles().is_empty(), "สกิลใช้ Cast แยกจาก Attack ยังไม่ยิงตอนเริ่ม")
    var saved_attack: int = partner.attack_power
    partner.attack_power = 999
    partner.sprite.frame = 1
    check(projectiles().is_empty(), "ชาร์จเฟรมแรกยังไม่ยิง")
    partner.sprite.frame = 2
    var shots: Array[Node] = projectiles()
    check(shots.size() == 1 and enemy.hp == 10000 - saved_attack, "Release สร้างลูกไฟ แต่ยังไม่ลงดาเมจจนกว่าจะชน")
    check(shots.size() == 1 and (shots[0] as SkillProjectile).damage >= 17 and (shots[0] as SkillProjectile).damage <= 19,
        "เก็บ ATK ตอนเริ่ม ไม่ใช้ ATK ที่เปลี่ยนระหว่างชาร์จ")
    check(partner.digimon_mp == 95.0 and not partner._try_skill(1), "หัก MP ครั้งเดียวและไม่เล่นอีกสกิลทับท่า")
    partner.attack_power = saved_attack
    await get_tree().create_timer(0.4).timeout
    check(enemy.hp < 10000 - saved_attack and projectiles().is_empty(), "ลูกไฟชนแล้วลงดาเมจและลบตัวเอง")

    reset_action(enemy)
    check(partner._try_skill(1) and partner.sprite.animation == &"attack_right", "Quick Bite ใช้ท่า Attack ตาม Resource ของสกิล")
    partner.sprite.frame = 2
    check(enemy.hp < 10000 - saved_attack - 17, "สกิลระยะประชิดลงดาเมจที่ Strike frame")
    reset_action(enemy)
    check(partner._try_skill(0), "เริ่มท่าก่อน pause")
    partner.sprite.frame = 1
    var hp_before: int = enemy.hp
    var frame_before: int = partner.sprite.frame
    get_tree().paused = true
    await get_tree().create_timer(0.25, true).timeout
    check(partner.sprite.frame == frame_before and enemy.hp == hp_before and projectiles().is_empty(), "pause หยุดท่า/เอฟเฟกต์/Release พร้อมสนาม")
    get_tree().paused = false
    partner.sprite.frame = 2
    check(projectiles().size() == 1, "Resume แล้วปล่อยลูกไฟที่เฟรม Release ได้")

    reset_action(enemy)
    partner._try_skill(0)
    partner.command_attack(second)
    partner.sprite.frame = 2
    check(not partner.combat_action.busy and enemy.hp == hp_before and second.hp == 10000 and projectiles().is_empty(), "เปลี่ยนเป้าขณะชาร์จยกเลิก hit เก่า")
    reset_action(enemy)
    partner._try_skill(0)
    check(partner.load_monster_data(partner.forms[1]), "เปลี่ยนร่างขณะชาร์จได้")
    check(not partner.combat_action.busy and projectiles().is_empty(), "โหลดร่างใหม่ล้าง action เก่า")
    partner.load_monster_data(partner.forms[0])
    reset_action(enemy)
    partner._try_skill(0)
    partner.enter_fainted(false)
    partner.sprite.frame = 2
    check(partner.state == PartnerMonster.State.EGG and projectiles().is_empty() and enemy.hp == hp_before, "สลบก่อน Release ไม่ยิงและไม่มี hit ค้าง")
    check(partner.recover() and not partner.combat_action.busy, "ฟื้นจากไข่แล้วใช้แอคชั่นใหม่ได้")

    reset_action(enemy)
    check(partner._start_basic_attack(), "เริ่มท่าก่อนเป้าหมายหนี")
    enemy.global_position = Vector2(500, 200)
    partner.sprite.frame = 2
    check(enemy.hp == hp_before, "ศัตรูหนีออกจากระยะก่อน Strike แล้วตีพลาด")
    enemy.global_position = Vector2(145, 200)
    reset_action(enemy)
    partner._try_skill(0)
    var wall := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(4, 100)
    collision.shape = shape
    wall.position = Vector2(123, 200)
    wall.add_child(collision)
    world.add_child(wall)
    await get_tree().physics_frame
    partner.sprite.frame = 2
    check(projectiles().is_empty() and enemy.hp == hp_before, "ผนังเข้ามาขวางก่อน Release ไม่ยิงทะลุ")
    wall.queue_free()
    await get_tree().physics_frame
    var freed: WildMonster = make_enemy(Vector2(140, 200))
    reset_action(freed)
    partner._try_skill(0)
    freed.free()
    partner.sprite.frame = 2
    check(projectiles().is_empty(), "เป้าหมายถูก free ระหว่างชาร์จไม่ส่ง freed reference ต่อ")
    partner.cancel_battle()
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
