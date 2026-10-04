extends Node
## ทดสอบพฤติกรรมใหม่จริง: hit หลังเดินทาง, ไม่ซ้ำ, pause, ผนัง และชุดปุ่มเก่า
var failures: int = 0
var requests: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, description: String) -> void:
    if ok:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func enemy_at(world: Node2D, point: Vector2) -> WildMonster:
    # สนามทดสอบแยก ไม่ใช้ Spawner จึงไม่มีมอนสเตอร์อื่นแทรกในวิถีลูกไฟ
    var enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
    enemy.max_hp = 1000
    enemy.position = point
    world.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func projectile_count() -> int:
    return get_tree().get_nodes_in_group("skill_projectiles").size()

func run() -> void:
    QuestManager.save_path = "user://v11_projectile_test.json"
    QuestManager.reset_progress(false)
    var world := Node2D.new()
    add_child(world)
    var tamer: Tamer = preload("res://scenes/tamer.tscn").instantiate()
    var partner: PartnerMonster = preload("res://scenes/partner.tscn").instantiate()
    tamer.partner = partner
    partner.tamer = tamer
    tamer.position = Vector2(50, 200)
    partner.position = Vector2(100, 200)
    world.add_child(tamer)
    world.add_child(partner)
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    var primary: WildMonster = enemy_at(world, Vector2(260, 200))
    var nearby: WildMonster = enemy_at(world, Vector2(310, 200))
    var outside: WildMonster = enemy_at(world, Vector2(440, 200))
    await get_tree().physics_frame
    await get_tree().process_frame
    var baby: MonsterSkill = partner.forms[0].skills[0]
    var mega: MonsterSkill = partner.forms[1].skills[0]
    check(baby.projectile_speed == 460.0 and mega.projectile_speed == 360.0,
        "Resource Rookie/Champion ใช้ความเร็วลูกไฟคนละค่า")
    check(mega.effect_size > baby.effect_size and mega.impact_radius > 0.0,
        "Mega Flame ลูกใหญ่และมี AoE แยกจาก Baby Flame")
    var bad: MonsterSkill = baby.duplicate()
    bad.projectile_speed = -1.0
    check(not bad.validation_error().is_empty(), "ปฏิเสธ Resource ความเร็วลูกไฟติดลบ")
    partner.target = primary
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner._try_skill(0), "ยิง Baby Flame ได้")
    check(primary.hp == 1000 and projectile_count() == 0, "เริ่มชาร์จยังไม่ปล่อยลูกไฟ")
    await get_tree().create_timer(0.27).timeout
    check(primary.hp == 1000 and projectile_count() == 1, "Release frame สร้างลูกไฟ แต่ยังไม่หัก HP จนกว่าจะชน")
    check(partner.digimon_mp == 95.0 and partner.cooldown_remaining(baby) == 3.0,
        "หัก MP/CD ตอน cast เพียงครั้งเดียว")
    check(not partner._try_skill(0) and partner.digimon_mp == 95.0, "กดซ้ำระหว่าง CD ไม่สร้างลูกไฟเพิ่ม")
    check(partner.digivolve(), "เปลี่ยน Champion ระหว่างลูกไฟ Rookie กำลังบินได้")
    await get_tree().create_timer(0.5).timeout
    var rookie_damage: int = 1000 - primary.hp
    check(rookie_damage >= 17 and rookie_damage <= 19,
        "ลูกไฟเก่ายังคง ATK Rookie ไม่แปลงเป็นดาเมจ Champion")
    check(nearby.hp == 1000 and projectile_count() == 0, "Baby Flame เป้าหมายเดียว และลูกไฟลบหลังชน")
    await get_tree().create_timer(0.15).timeout
    check(primary.hp == 1000 - rookie_damage, "ชนแล้วไม่สร้างดาเมจซ้ำเฟรมถัดไป")

    primary.hp = 1000
    partner.skill_cooldowns.clear()
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner._try_skill(0), "ยิง Mega Flame ได้")
    await get_tree().create_timer(0.27).timeout
    var projectile := get_tree().get_first_node_in_group("skill_projectiles") as SkillProjectile
    var before_pause: Vector2 = projectile.global_position
    get_tree().paused = true
    await get_tree().create_timer(0.2, true).timeout
    check(projectile.global_position == before_pause and primary.hp == 1000,
        "pause หยุดลูกไฟและดาเมจพร้อมสนาม")
    get_tree().paused = false
    await get_tree().create_timer(0.6).timeout
    var champion_damage: int = 1000 - primary.hp
    check(champion_damage >= 71 and champion_damage <= 79, "Mega Flame ใช้ ATK30 * 2.5 +/-5%")
    check(nearby.hp == primary.hp and outside.hp == 1000, "AoE ลงครั้งเดียวกับศัตรูในวง")
    check(partner.digimon_mp == 90.0, "ตอนลูกไฟชนไม่หัก MP รอบสอง")

    primary.hp = 1000
    nearby.hp = 1000
    partner.skill_cooldowns.clear()
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner._try_skill(0), "ยิงก่อนมีผนังเข้ามาขวาง")
    await get_tree().create_timer(0.27).timeout
    var wall := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(6, 120)
    collision.shape = rectangle
    wall.add_child(collision)
    wall.position = Vector2(180, 200)
    world.add_child(wall)
    await get_tree().create_timer(0.6).timeout
    check(primary.hp == 1000 and nearby.hp == 1000 and projectile_count() == 0,
        "ผนังที่เข้ามาขวางระหว่างบินหยุดลูกไฟ ไม่มี AoE ทะลุผนัง")
    wall.queue_free()
    await get_tree().physics_frame
    partner.skill_cooldowns.clear()
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner._try_skill(0), "ยิงเพื่อทดสอบเป้าหมายตายก่อนชน")
    primary.hp = 0
    await get_tree().create_timer(0.1).timeout
    check(nearby.hp == 1000 and projectile_count() == 0, "เป้าหมายตาย ลูกไฟยกเลิกโดยไม่ระเบิดใส่ตัวอื่น")
    primary.hp = 1000
    partner.cancel_battle()
    partner.target = primary
    var expiring := SkillProjectile.new()
    expiring.setup(partner, primary, mega, 50)
    expiring.speed = 1.0
    expiring.lifetime = 0.03
    expiring.position = partner.position
    world.add_child(expiring)
    await get_tree().create_timer(0.1).timeout
    check(projectile_count() == 0 and primary.hp == 1000, "ลูกไฟหมดอายุลบตัวเองโดยไม่ทำดาเมจ")
    var high_speed := SkillProjectile.new()
    high_speed.setup(partner, primary, mega, 50)
    high_speed.speed = 50000.0 # วิ่งไกลกว่าเป้าหมายในหนึ่ง physics frame
    high_speed.position = partner.position
    var thin_wall := StaticBody2D.new()
    var thin_collision := CollisionShape2D.new()
    var thin_rectangle := RectangleShape2D.new()
    thin_rectangle.size = Vector2(2, 100)
    thin_collision.shape = thin_rectangle
    thin_wall.add_child(thin_collision)
    thin_wall.position = Vector2(180, 200)
    world.add_child(thin_wall)
    world.add_child(high_speed)
    await get_tree().create_timer(0.1).timeout
    check(projectile_count() == 0 and primary.hp == 1000,
        "ลูกไฟเร็วมากไม่ทะลุกำแพงบางระหว่างสองเฟรม")
    thin_wall.queue_free()
    await get_tree().physics_frame
    partner.skill_cooldowns.clear()
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner._try_skill(0), "ยิงก่อนผู้ยิงสลบ")
    partner.enter_fainted(false)
    await get_tree().create_timer(0.1).timeout
    check(projectile_count() == 0 and primary.hp == 1000, "ผู้ยิงสลบ ลูกไฟถูกยกเลิกโดยไม่ลงดาเมจ")
    check(partner.recover(), "ผู้ยิงฟื้นฟูแล้วใช้งานระบบต่อได้")

    # ปุ่มชุดก่อนห้ามส่งคำสั่ง แม้ rebuild กลับมาชุด ID เดิม
    var panel := FormSkillPanel.new()
    add_child(panel)
    panel.configure(partner, tamer)
    panel.skill_requested.connect(func(_slot: int): requests += 1)
    var old_button: TouchCommand = panel.buttons[0]
    panel.rebuild(partner.active_skills)
    old_button.pressed.emit()
    check(requests == 0, "revision กัน callback เก่าแม้สกิล ID เดียวกัน")
    panel.buttons[0].pressed.emit()
    check(requests == 1, "ปุ่มชุดปัจจุบันส่งคำสั่งได้")
    var saved_skills: Array[MonsterSkill] = []
    saved_skills.assign(partner.active_skills)
    partner.active_skills = [null, mega]
    partner.skill_cooldowns.clear()
    panel.rebuild(partner.active_skills)
    check(panel.buttons.size() == 1 and int(panel.buttons[0].get_meta("skill_slot")) == 1,
        "ข้ามช่องว่างแล้วปุ่มยังผูกกับ slot จริง")
    partner.skill_cooldowns[mega.id] = 2.0
    panel._refresh_buttons()
    check(panel.buttons[0].locked and panel.buttons[0].caption == "2.0s",
        "CD อ่านจาก slot จริงหลังข้ามช่องว่าง")
    partner.active_skills.assign(saved_skills)
    panel.rebuild(partner.active_skills)

    # ทดสอบการคง phase เมื่อจำนวนเฟรมและระยะเวลาเฟรมไม่เท่ากัน
    var frames := SpriteFrames.new()
    var texture := GradientTexture2D.new()
    for direction: String in ["right", "up"]:
        frames.add_animation("walk_" + direction)
        frames.set_animation_loop("walk_" + direction, true)
        for index: int in range(4 if direction == "right" else 8):
            frames.add_frame("walk_" + direction, texture)
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = frames
    add_child(sprite)
    var animator := DirectionalAnimator.new()
    animator.sprite = sprite
    add_child(animator)
    animator.update_motion(Vector2.RIGHT * 240.0, 240.0)
    sprite.set_frame_and_progress(2, 0.5) # 62.5% ของรอบ 4 เฟรม
    animator.update_motion(Vector2.UP * 240.0, 240.0)
    check(sprite.frame == 5 and is_zero_approx(sprite.frame_progress),
        "เดิน4เฟรม→8เฟรม คง phase 62.5% ไม่คัดลอกเลขเฟรมเก่า")
    frames.set_frame(&"walk_up", 0, texture, 3.0)
    animator.update_motion(Vector2.RIGHT * 240.0, 240.0)
    sprite.set_frame_and_progress(2, 0.0) # 50% ของรอบ
    animator.update_motion(Vector2.UP * 240.0, 240.0)
    check(sprite.frame == 3 and is_zero_approx(sprite.frame_progress),
        "phase คำนึงถึงเฟรมที่มี duration ต่างกัน")
    world.queue_free()
    panel.queue_free()
    sprite.queue_free()
    animator.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
