extends Node
## ทดสอบความเร็วภาพจริง การสลับ Resource และการรับสัมผัสหลังเปลี่ยนร่าง
var failures: int = 0
var requests: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func sample_frames() -> SpriteFrames:
    # เฟรมสี 2 เฟรมสำหรับทดสอบ state/phase โดยไม่ขึ้นกับชุดภาพ production
    var frames := SpriteFrames.new()
    var texture := GradientTexture2D.new()
    texture.width = 32
    texture.height = 48
    texture.gradient = Gradient.new()
    for direction: String in ["down", "right", "up", "left"]:
        for prefix: String in ["idle", "walk", "attack"]:
            var key := StringName(prefix + "_" + direction)
            frames.add_animation(key)
            frames.set_animation_speed(key, 8.0)
            frames.set_animation_loop(key, prefix != "attack")
            frames.add_frame(key, texture)
            frames.add_frame(key, texture)
    return frames

func press(button: TouchCommand, down: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 6
    event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
    event.pressed = down
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func run() -> void:
    get_tree().root.content_scale_size = Vector2i(1280, 720)
    get_tree().root.size = Vector2i(1280, 720)
    QuestManager.save_path = "user://form_skills_animation_test.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    var panel: FormSkillPanel = hud.skill_panel
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    panel.skill_requested.connect(func(_slot: int): requests += 1)

    check(tamer.sprite is AnimatedSprite2D, "Tamer ใช้ AnimatedSprite2D")
    check(panel.buttons.size() == 4 and panel.buttons[2].locked and panel.buttons[3].locked, "Rookie มีสี่ตำแหน่งคงที่และปิดสองช่องที่ไม่มีสกิล")
    var seen: Array[StringName] = []
    for form: MonsterData in partner.forms:
        check(form.validation_error().is_empty(), "Resource %s ถูกต้อง" % form.id)
        for skill: MonsterSkill in form.skills:
            check(skill.id not in seen and skill.icon != null, "สกิล %s มี ID/ไอคอนแยกจากทุกร่าง" % skill.id)
            seen.append(skill.id)
    var rookie_skill: MonsterSkill = partner.forms[0].skills[0]
    check(rookie_skill.multiplier == 1.2 and rookie_skill.cooldown == 3.0, "Baby Flame: 120%, CD 3s")
    var champion_skill: MonsterSkill = partner.forms[1].skills[0]
    check(champion_skill.multiplier == 2.5 and champion_skill.cooldown == 6.0 and champion_skill.impact_radius > 0.0, "Mega Flame: 250%, CD 6s, AoE")
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    var low: int = 99999
    var high: int = 0
    for iteration: int in range(500):
        var amount: int = champion_skill.roll_damage(100, rng)
        low = mini(low, amount)
        high = maxi(high, amount)
    check(low >= 238 and high <= 263 and low < high, "ดาเมจสุ่ม +/-5% ของ ATK*Multiplier")
    check(champion_skill.roll_damage(0, rng) == 0, "ATK 0 ไม่สร้างดาเมจ")

    # ทดสอบ 4 ทิศ+ความเร็ว+รักษาจังหวะเดิน โดยใช้ frame จริง 2 เฟรม
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = sample_frames()
    add_child(sprite)
    var animator := DirectionalAnimator.new()
    animator.sprite = sprite
    add_child(animator)
    for index: int in range(4):
        var direction: Vector2 = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][index]
        var suffix: String = ["down", "right", "up", "left"][index]
        animator.update_motion(direction * 120.0, 240.0)
        check(sprite.animation == StringName("walk_" + suffix) and not sprite.flip_h, "เลือก walk_%s โดยไม่ flip ซ้ำ" % suffix)
        check(is_equal_approx(sprite.speed_scale, 0.5), "ความเร็วครึ่งหนึ่ง = speed_scale 0.5")
        animator.update_motion(Vector2.ZERO, 240.0)
        check(sprite.animation == StringName("idle_" + suffix), "หยุดแล้วจำทิศ %s" % suffix)
    animator.update_motion(Vector2.RIGHT * 240.0, 240.0)
    sprite.set_frame_and_progress(1, 0.4)
    animator.update_motion(Vector2.UP * 240.0, 240.0)
    check(sprite.frame == 1 and is_equal_approx(sprite.frame_progress, 0.4), "เปลี่ยนทิศไม่รีเซ็ตเฟรมก้าว")
    animator.update_motion(Vector2(240, -240), 240.0)
    check(animator.facing == &"up", "ทิศเฉียงเท่ากันรักษาแกนล่าสุด ลด jitter")
    animator.update_motion(Vector2.RIGHT * 480.0, 240.0)
    check(is_equal_approx(sprite.speed_scale, 2.0), "วิ่งเร็วสองเท่า = speed_scale 2")
    check(animator.play_attack(Vector2.LEFT), "เริ่ม Attack ทิศซ้าย")
    animator.update_motion(Vector2.DOWN * 240.0, 240.0)
    check(sprite.animation == &"attack_left" and sprite.speed_scale == 1.0, "Walk ไม่ทับ Attack และ Attack ไม่ใช้ความเร็วเดิน")
    await get_tree().create_timer(0.35).timeout
    animator.update_motion(Vector2.ZERO, 240.0)
    check(not animator.action_locked and sprite.animation == &"idle_left", "Attack จบปลด lock และกลับ Idle ล่าสุด")
    sprite.queue_free()
    animator.queue_free()

    # ใช้ CharacterBody2D จริงชนกำแพง ตรวจความเร็วหลัง slide แทน input
    var wall := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(10, 100)
    shape.shape = rectangle
    wall.add_child(shape)
    world.add_child(wall)
    wall.global_position = Vector2(640, 480)
    tamer.global_position = Vector2(600, 480)
    for frame: int in range(24):
        await get_tree().physics_frame
        tamer.velocity = Vector2.RIGHT * 190.0
        tamer.move_and_slide()
        tamer.animator.update_motion(tamer.get_real_velocity(), 190.0)
    check(tamer.get_real_velocity().length() < 2.0 and tamer.sprite.animation == &"idle_right", "ชนกำแพงแล้ว Idle แม้คำสั่งเดินยังเป็น RIGHT")
    wall.queue_free()

    # เปลี่ยนร่างถอดปุ่มทันที สัญญาณเก่าไม่สั่งสกิลใหม่ผิดช่อง
    var old_button: TouchCommand = panel.buttons[0]
    var old_id: StringName = partner.active_skills[0].id
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner.digivolve(), "เปลี่ยน Champion สำเร็จ")
    check(panel.buttons.size() == 4 and not old_button.is_inside_tree(), "ปุ่ม Rookie ถูกถอดและแทนด้วย Champion 4 ปุ่มทันที")
    check(panel.buttons[0].icon == champion_skill.icon, "ไอคอนใหม่ตรงกับ Mega Flame")
    old_button.pressed.emit()
    check(requests == 0, "callback ของปุ่มเก่าไม่ส่งคำสั่งร่างใหม่")
    await get_tree().process_frame
    await get_tree().process_frame
    press(panel.buttons[0], true)
    press(panel.buttons[0], false)
    check(requests == 1, "แตะปุ่มสกิลใหม่ส่งคำสั่งครั้งเดียว")
    partner.cancel_battle()
    # สี่ช่องแยกพื้นที่สัมผัสจาก Main Attack และอยู่ในจอ Landscape
    await get_tree().process_frame
    var attack_rect: Rect2 = hud.attack_button.get_global_rect()
    for button: TouchCommand in panel.buttons:
        check(not button.get_global_rect().intersects(attack_rect), "พื้นที่สัมผัส %s ไม่ซ้อน Main Attack" % button.name)
    get_tree().root.size = Vector2i(1600, 720)
    await get_tree().process_frame
    await get_tree().process_frame
    for button: TouchCommand in panel.buttons:
        check(button.get_global_rect().end.x <= 1600.0, "ปุ่ม %s อยู่ในจอ Landscape กว้าง" % button.name)
    get_tree().root.size = Vector2i(1280, 720)
    await get_tree().process_frame

    # ATK รวมโบนัสเลเวล เปลี่ยนฐานของร่างและไม่บวกโบนัสซ้ำ
    partner.progress.add_exp(100)
    check(partner.attack_power == 35, "Champion Lv2 ATK = ฐาน30+โบนัส5")
    QuestManager.max_unlocked_stage = MonsterData.EvolutionStage.MEGA
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner.digivolve() and partner.attack_power == 55, "Ultimate Lv2 ATK = ฐาน50+โบนัส5")
    check(panel.buttons[0].icon == partner.forms[2].skills[0].icon, "Ultimate ใช้ไอคอนและชุดสกิลของตัวเอง")
    check(partner.load_monster_data(partner.forms[1]) and partner.attack_power == 35, "กลับ Champion ไม่สะสมโบนัสซ้ำ")

    # AoE: เป้าหมายในระยะโดนทั้งหมด; ด้านนอกไม่โดน; หัก DS/CD ครั้งเดียว
    partner.global_position = Vector2(600, 480)
    var victims: Array[WildMonster] = []
    for index: int in range(3):
        var enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
        enemy.max_hp = 10000
        world.get_node("Actors").add_child(enemy)
        enemy.set_physics_process(false)
        enemy.global_position = Vector2(700 + [0, 50, 120][index], 480)
        victims.append(enemy)
    await get_tree().physics_frame
    partner.target = victims[0]
    partner.skill_cooldowns.clear()
    tamer.ds = 100.0
    partner.digimon_mp = partner.digimon_max_mp
    check(partner._try_skill(0), "cast Mega Flame สำเร็จ")
    check(victims[0].hp == 10000, "ลูกไฟยังไม่ชนจึงไม่ลงดาเมจตอน cast")
    await get_tree().create_timer(0.65).timeout
    var first_damage: int = 10000 - victims[0].hp
    check(first_damage >= 83 and first_damage <= 92, "Mega Flame ใช้ ATK Lv2 35 * 2.5 พร้อมแกว่ง5%")
    check(victims[1].hp == victims[0].hp and victims[2].hp == 10000, "AoE โดนตัวใกล้ด้วยดาเมจเดียวกัน แต่ไม่โดนตัวนอกรัศมี")
    check(partner.digimon_mp == 90.0 and partner.cooldown_remaining(champion_skill) == 6.0, "AoE หัก MP และตั้ง CD เพียงครั้งเดียว")
    check(not partner._try_skill(0) and partner.digimon_mp == 90.0, "กดซ้ำระหว่าง CD ไม่หัก MP ซ้ำ")
    partner.load_monster_data(partner.forms[0])
    partner.load_monster_data(partner.forms[1])
    check(partner.cooldown_remaining(champion_skill) == 6.0, "สลับร่างไม่รีเซ็ตคูลดาวน์สกิลเดิม")
    partner.enter_fainted(false)
    check(not partner._try_skill(0), "ไข่เรียกสกิลตรงก็ไม่ได้")
    check(partner.recover() and panel.buttons.size() == 4 and panel.buttons[2].locked, "Recover กลับชุดสกิล Rookie พร้อมสล็อตว่าง")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
