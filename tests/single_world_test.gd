extends Node
## ตรวจความต่อเนื่องของเกาะ, จุดเกิด lazy, สถานะจริง และการย้ายเซฟ v24
var failures: int = 0
var assertions: int = 0
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()
func check(ok: bool, detail: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", detail)
    else:
        failures += 1
        push_error("FAIL: " + detail)
func tap(button: Control) -> void:
    var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = 3
        event.position = point
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func run() -> void:
    get_tree().root.size = Vector2i(1280,720)
    QuestManager.save_path = "user://single_world_v25_test.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    var world: Node2D = load("res://scenes/world.tscn").instantiate()
    add_child(world)
    for i: int in range(6):
        await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = tamer.partner
    var hud: MobileHUD = world.get_node("MobileHUD")
    var environment: OpenWorldEnvironment = world.get_node("OpenWorldEnvironment")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    check(environment.layout.extent == Vector2(10240,6400), "ขนาดโลกเพิ่มพื้นที่เป็นสี่เท่า")
    check(get_tree().get_nodes_in_group("story_portals").is_empty() and not world.has_node("StoryPoints/NextPortal"), "ไม่มีประตูวาร์ปบนเกาะ")
    check(world.get_node("WorldPopulation").created_regular == 240 and world.get_node("Spawners").get_child_count() == 244, "240 จุดเกิดปกติ และ 4 บอส")
    var safe: bool = true
    for node: MonsterSpawner in world.get_node("Spawners").get_children():
        safe = safe and environment.can_spawn_at(node.global_position)
    check(safe, "ศูนย์จุดเกิดทุกจุดอยู่บนพื้นที่เดินได้")
    check(get_tree().get_nodes_in_group("wild_monsters").size() >= 20 and get_tree().get_nodes_in_group("wild_monsters").size() < 100, "มีมอนสเตอร์รอบเมืองจำนวนมาก แต่ไม่สร้างทั้งแมพพร้อมกัน")
    var nav: RID = tamer.navigation_agent.get_navigation_map()
    for i: int in range(120):
        if NavigationServer2D.map_get_iteration_id(nav) > 0:
            break
        await get_tree().physics_frame
    for y: float in [1000.0,2250.0,4000.0,5400.0]:
        var path: PackedVector2Array = NavigationServer2D.map_get_path(nav, Vector2(2650,y), Vector2(3250,y), true)
        check(path.size() >= 2 and path[-1].distance_to(Vector2(3250,y)) < 40, "Nav ข้ามสะพาน %.0f" % y)
    var targets: bool = true
    for quest: StoryQuest in QuestManager.catalog.quests:
        var destination: Node2D = hud._tracker._resolve_destination(quest)
        targets = targets and quest.zone_id == &"file_island" and is_instance_valid(destination)
        if destination != null:
            var path: PackedVector2Array = NavigationServer2D.map_get_path(nav,tamer.position,destination.global_position,true)
            check(not path.is_empty() and path[-1].distance_to(destination.global_position) < 40, "Nav ถึงเควสต์ " + String(quest.id))
    check(targets, "Tracker หาเป้าทั้ง 8 เควสต์ได้แม้บอสไกลยังไม่สร้าง")
    var distant: MonsterSpawner = world.get_node("Spawners/Boss_piedmon")
    check(not is_instance_valid(distant.current_monster), "บอสไกลยังไม่สร้างตอนเริ่มเกม")
    var original: Vector2 = tamer.position
    tamer.position = distant.position + Vector2(-100,0)
    distant._process(1.0)
    await get_tree().process_frame
    await get_tree().process_frame
    check(is_instance_valid(distant.current_monster), "เข้าใกล้แล้วสร้างบอส")
    var remembered: WildMonster = distant.current_monster
    remembered.hp -= 17
    var damaged_hp: int = remembered.hp
    tamer.position = original
    distant._process(1.0)
    check(not remembered.visible and remembered.process_mode == Node.PROCESS_MODE_DISABLED, "ไกลแล้วหยุด AI และซ่อน")
    tamer.position = distant.position + Vector2(-100,0)
    distant._process(1.0)
    check(remembered == distant.current_monster and remembered.hp == damaged_hp and remembered.visible, "กลับมาเป็นตัวเดิม HP ไม่รีเซ็ต")
    distant.respawn_time = 0.1
    tamer.position = original
    remembered.take_damage(999999)
    await get_tree().create_timer(0.2).timeout
    check(distant._respawn_ready and not is_instance_valid(distant.current_monster), "ตายไกลนับเวลาเสร็จแต่รอเข้าใกล้ค่อยเกิด")
    tamer.position = distant.position + Vector2(-100,0)
    distant._process(1.0)
    await get_tree().process_frame
    await get_tree().process_frame
    var new_id: int = distant.current_monster.get_instance_id()
    distant._spawn_monster()
    check(distant.current_monster.get_instance_id() == new_id, "เกิดใหม่หนึ่งตัว ไม่ซ้ำเมื่อถูกเรียกอีก")
    tamer.position = original
    check(hud.menu.buttons.has(&"digimon") and not hud.menu.buttons.has(&"status"), "แทนปุ่ม Status ด้วยดิจิมอน")
    var screen: DigimonStatusScreen = hud.digimon_screen
    check(screen.open_screen() and get_tree().paused, "เปิดหน้าดิจิมอนแล้วถือ pause")
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.4, true).timeout
    check(screen.values.HP.text == "%d / %d" % [partner.hp,partner.max_hp] and screen.values.AT.text == str(partner.attack_power), "สเตตัสแสดงค่าจริงของคู่หู")
    check(screen.skill_buttons[0].icon == partner.active_skills[0].icon and screen.skill_buttons[4].disabled, "ภาพสกิลจริง และ Memory ที่ยังไม่มีถูกปิด")
    screen.detail_label.text = ""
    tap(screen.skill_buttons[0])
    check(screen.detail_label.text.contains(partner.active_skills[0].display_name), "แตะสกิลอ่านรายละเอียดได้")
    tap(screen.close_button)
    check(not get_tree().paused, "ปิดแล้วคืนเวลาให้ฉาก")
    partner.evolution_busy = true
    check(not screen.open_screen(), "ไม่แย่ง pause ระหว่างคัตซีน")
    partner.evolution_busy = false
    var original_form: MonsterData = partner.current_form
    partner.current_form = original_form.duplicate() as MonsterData
    check(partner.roll_outgoing_damage(100) == 100 and partner.resolve_incoming_damage(100) == 100, "สเตตัสเริ่มต้นไม่เปลี่ยนสมดุลดาเมจเดิม")
    partner.current_form.critical_chance = 100
    check(partner.roll_outgoing_damage(100) == 150, "CT100 ทำคริติคอลตามตัวคูณ")
    partner.current_form.hit_chance = 0
    check(partner.roll_outgoing_damage(100) == 0, "HT0 โจมตีพลาด")
    partner.current_form.evasion_chance = 100
    check(partner.resolve_incoming_damage(100) == 0, "EV100 หลบได้")
    partner.current_form.evasion_chance = 0
    partner.current_form.defense = 20
    partner.current_form.block_chance = 100
    check(partner.resolve_incoming_damage(100) == 40 and partner.resolve_incoming_damage(0) == 0, "เกราะแล้วบล็อกครึ่งหนึ่ง และไม่สร้างดาเมจจากศูนย์")
    partner.current_form = original_form
    for extent: Vector2i in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768),Vector2i(1280,640)]:
        get_tree().root.size = extent
        hud.safe_inset_override = Vector4(92,20,38,24)
        hud._layout()
        await get_tree().process_frame
        screen.open_screen()
        await get_tree().create_timer(0.4, true).timeout
        var view: Vector2 = get_viewport().get_visible_rect().size
        check(Rect2(92,20,view.x-130,view.y-44).encloses(screen.panel.get_global_rect()), "หน้าดิจิมอนอยู่ใน Safe Area " + str(extent))
        screen.close_screen()
    # ผ่านทุกเควสต์ต่อเนื่องบนเกาะเดียว ไม่ต้องเปลี่ยน zone เพื่อปลดล็อกร่าง
    for quest: StoryQuest in QuestManager.catalog.quests:
        check(QuestManager.report_event(quest.objective,quest.target_id), "เคลียร์บนเกาะเดียว " + String(quest.id))
    check(QuestManager.max_unlocked_stage == MonsterData.EvolutionStage.MEGA, "เควสต์ยังปลดล็อก Mega")
    QuestManager.party_profile = {"hp":71,"partner_progress":{"level":9,"exp":13}}
    QuestManager.current_zone = &"spiral_mountain"
    QuestManager.save_progress()
    check(QuestManager.load_progress() and QuestManager.current_zone == &"file_island" and QuestManager.party_profile.hp == 71 and QuestManager.is_completed(&"q08_piedmon"), "เซฟโซนเก่าย้ายมาเกาะเดียวและคงความคืบหน้า")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("ASSERTIONS: ", assertions)
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
