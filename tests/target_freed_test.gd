extends Node
## จำลองศัตรูตายหลังถูกล็อกเป้า โดย AI ไม่ได้มีโอกาสล้าง target
var failures: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, description: String) -> void:
    if ok:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func accepts_live_or_null(enemy: WildMonster) -> bool:
    # พารามิเตอร์ typed ใช้ยืนยันว่า getter คืน null จริง ไม่ใช่ freed Object
    return enemy == null or is_instance_valid(enemy)

func spawn_enemy(world: Node2D, point: Vector2) -> WildMonster:
    var enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
    enemy.position = point
    world.get_node("Actors").add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func run() -> void:
    QuestManager.save_path = "user://target_freed_test.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    var enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
    enemy.position = Vector2(600, 400)
    world.get_node("Actors").add_child(enemy)
    enemy.set_physics_process(false)
    tamer.set_target(enemy)
    var stale: Variant = enemy # จำ reference เก่าเพื่อจำลอง callback ที่มาช้า
    partner.target = enemy
    partner.state = PartnerMonster.State.BATTLE
    check(hud.target_card.visible, "ล็อกศัตรูแล้ว HUD แสดงหลอดเป้าหมาย")
    enemy.take_damage(99999, partner)
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.35).timeout
    check(tamer.target == null, "ศัตรูตายแล้วล้าง Tamer.target แม้ AI หยุดทำงาน")
    check(partner.target == null, "ศัตรูตายแล้วล้าง Partner.target")
    check(not hud.target_card.visible, "ศัตรูตายแล้วซ่อนหลอดเป้าหมาย")
    check(accepts_live_or_null(tamer.get_target()), "getter คืน null จริงที่ส่งเข้าฟังก์ชัน typed ได้")
    hud._refresh_target(stale)
    check(not hud.target_card.visible, "HUD รับ freed reference โดยตรงแล้วซ่อนแถบได้")
    hud._refresh_target("wrong type")
    hud._refresh_target(world)
    check(not hud.target_card.visible, "HUD รับชนิดที่ไม่ใช่ศัตรูแล้วล้างแถบ")
    # จำลองระบบเก่าเขียน reference ลง property โดยไม่เรียก set_target
    var bypass_enemy: WildMonster = spawn_enemy(world, Vector2(680, 400))
    tamer.target = bypass_enemy # เลี่ยง set_target จึงไม่ได้เชื่อม tree_exiting
    bypass_enemy.free()
    check(accepts_live_or_null(tamer.get_target()), "getter ล้าง reference เก่าที่ระบบอื่นเขียนตรงได้")
    tamer.set_target(stale)
    check(accepts_live_or_null(tamer.target), "set_target รับ freed reference แล้วเก็บ null จริง")
    # คำสั่งสกิลหลังเป้าหมายหายต้องไม่ส่ง freed Object เข้าพารามิเตอร์ typed
    var skill_enemy: WildMonster = spawn_enemy(world, Vector2(680, 400))
    tamer.target = skill_enemy
    skill_enemy.free()
    tamer.command_skill(0)
    check(accepts_live_or_null(tamer.target), "กดสกิลหลังเป้าหมายถูกลบไม่ส่ง freed Object ต่อ")
    partner.cancel_battle()

    var old_enemy: WildMonster = spawn_enemy(world, Vector2(620, 400))
    var new_enemy: WildMonster = spawn_enemy(world, Vector2(660, 400))
    tamer.set_target(old_enemy)
    tamer.set_target(new_enemy)
    old_enemy.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    check(tamer.get_target() == new_enemy and hud.target_card.visible,
        "ศัตรูตัวเก่าออกจากฉากไม่ล้างเป้าที่เลือกใหม่")
    new_enemy.hp -= 10
    hud._refresh_target(new_enemy)
    await get_tree().create_timer(0.4).timeout # ภาพหลอด Tween แต่ target/status จริงเปลี่ยนทันที
    check(hud._target_bar.value == new_enemy.hp, "เป้าหมายใหม่ยังอัปเดตเลือดได้")
    new_enemy.queue_free()
    hud._refresh_target(new_enemy)
    check(not hud.target_card.visible, "Node รอ queue_free ถูกซ่อนก่อน free จริง")
    await get_tree().process_frame
    await get_tree().process_frame
    check(accepts_live_or_null(tamer.target), "ลบ Node ตรงโดยไม่ตายก็ล้าง Target")
    var removed_enemy: WildMonster = spawn_enemy(world, Vector2(640, 420))
    tamer.set_target(removed_enemy)
    removed_enemy.get_parent().remove_child(removed_enemy)
    check(tamer.get_target() == null and not hud.target_card.visible,
        "remove_child ล้างเป้าก่อนศัตรูถูก free")
    removed_enemy.free()
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
