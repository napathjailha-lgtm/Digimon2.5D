extends Node
## ทดสอบความรู้สึกที่วัดได้: เวลาเร่ง/เบรก, analog และการตามต่อเนื่อง
var failures: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, description: String) -> void:
    if ok:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func run() -> void:
    # ค่าที่เหมือนกันเมื่อ physics delta ต่างกัน
    var slow := Vector2.ZERO
    var fast := Vector2.ZERO
    for tick: int in range(6):
        slow = SmoothMotion.step(slow, Vector2.RIGHT * 190.0, 1600.0, 2800.0, 1.0 / 60.0)
    for tick: int in range(12):
        fast = SmoothMotion.step(fast, Vector2.RIGHT * 190.0, 1600.0, 2800.0, 1.0 / 120.0)
    check(slow.is_equal_approx(fast) and slow.x < 190.0, "เร่งตาม delta ไม่กระโดดเป็นความเร็วเต็มในเฟรมแรก")
    for tick: int in range(8):
        slow = SmoothMotion.step(slow, Vector2.ZERO, 1600.0, 2800.0, 1.0 / 60.0)
    check(slow == Vector2.ZERO, "ปล่อยนิ้วแล้วหยุดภายใน 0.14s ไม่ไหลต่อยาว")
    check(SmoothMotion.arrival_speed(20.0, 20.0, 240.0, 3000.0) == 0.0,
        "ระยะถึงจุดหยุดไม่สั่งวิ่งต่อ")
    check(SmoothMotion.arrival_speed(22.0, 20.0, 240.0, 3000.0) < 240.0,
        "ใกล้เป้าหมายแล้วลดความเร็วตามระยะเบรก")
    QuestManager.save_path = "user://smooth_walk_test.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.global_position = Vector2(350, 460)
    partner.global_position = Vector2(250, 460)
    tamer.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    check(tamer.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING and partner.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING,
        "ทั้งสองตัวใช้ Floating สำหรับ top-down")
    check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "เปิด physics interpolation")
    tamer.joystick.move_vector = Vector2.RIGHT * 0.5
    tamer.velocity = Vector2.ZERO
    tamer._physics_process(1.0 / 60.0)
    check(tamer.velocity.x > 0.0 and tamer.velocity.x < 95.0, "ครึ่งอนาล็อกยังค่อย ๆ เร่ง")
    for tick: int in range(8):
        tamer._physics_process(1.0 / 60.0)
    check(is_equal_approx(tamer.velocity.length(), 95.0), "ครึ่งอนาล็อกวิ่งครึ่งความเร็ว ไม่ normalize ทิ้ง")
    tamer.joystick.move_vector = Vector2.ZERO
    for tick: int in range(6):
        tamer._physics_process(1.0 / 60.0)
    check(tamer.velocity == Vector2.ZERO and String(tamer.sprite.animation).begins_with("idle_"),
        "เบรกจบแล้วเปลี่ยนเป็น Idle ทิศล่าสุด")

    # เดินตรง 2 วินาทีและวัดคู่หูหลังพ้นช่วงเร่ง ต้องไม่หยุดเป็นระยะ
    tamer.global_position = Vector2(350, 460)
    partner.global_position = Vector2(250, 460)
    tamer.velocity = Vector2.ZERO
    partner.velocity = Vector2.ZERO
    partner.state = PartnerMonster.State.FOLLOW
    tamer.joystick.move_vector = Vector2.RIGHT
    var stopped_frames: int = 0
    var smallest_gap: float = INF
    var largest_gap: float = 0.0
    for tick: int in range(120):
        await get_tree().physics_frame
        tamer._physics_process(1.0 / 60.0)
        partner._physics_process(1.0 / 60.0)
        if tick > 30:
            if partner.get_real_velocity().length() < 2.0:
                stopped_frames += 1
            var gap: float = tamer.global_position.distance_to(partner.global_position)
            smallest_gap = minf(smallest_gap, gap)
            largest_gap = maxf(largest_gap, gap)
    check(stopped_frames == 0, "คู่หูตาม Tamer ที่เดินต่อเนื่องโดยไม่มีเฟรมหยุด")
    check(smallest_gap > 40.0 and largest_gap < 110.0, "รักษาระยะตาม ไม่ทับตัว Tamer หรือหลุดไกล")
    print("FOLLOW METRICS: stopped_frames=", stopped_frames, " gap=", smallest_gap, "..", largest_gap)

    for direction: String in ["down", "right", "up", "left"]:
        var key := StringName("walk_" + direction)
        check(tamer.sprite.sprite_frames.get_frame_count(key) >= 4, "Tamer มีเฟรมเดินจริงอย่างน้อย4เฟรม " + direction)
        for form: MonsterData in partner.forms:
            check(form.sprite_frames.has_animation(key) and form.sprite_frames.get_frame_count(key) >= 4,
                String(form.id) + " มี Walk 4ทิศ " + direction)
    tamer.joystick.release_input()
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
