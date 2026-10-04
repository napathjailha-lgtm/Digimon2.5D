extends Node
## ทดสอบพฤติกรรมที่ผู้เล่นเห็นจริง: touch, safe area, burst damage, ownership และ save/reload
var failures: int = 0
var assertions: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, description: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func tap(control: Control, finger: int = 1) -> void:
    var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = finger
        event.position = point
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func run() -> void:
    QuestManager.save_path = "user://hybrid_hud_test.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    var world: Node = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var hud: MobileHUD = world.get_node("MobileHUD")
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = tamer.partner
    tamer.set_physics_process(false)
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    hud.preferences.minimap_visible = true
    hud.preferences.animations_enabled = true
    hud.preferences.combat_scale = 1.0
    hud.chat_panel.set_collapsed(true)
    hud._layout()
    var roster: PartnerRoster = hud.party_roster
    roster.set_process(false)
    check(roster.members.size() == 1 and hud.party_panel.buttons.size() == 3,
        "เริ่มด้วย starter จริงและสล็อตว่างอีกสองช่อง ไม่แจกสมาชิกปลอม")
    check(hud.skill_panel.buttons.size() == 4 and hud.skill_panel.buttons[1].locked,
        "สี่ตำแหน่งคงที่ ช่องไม่มีสกิลกดไม่ได้")
    var attack_center: Vector2 = hud.attack_button.position + hud.attack_button.size * 0.5
    var first: Vector2 = hud.skill_panel.buttons[0].position + hud.skill_panel.buttons[0].size * 0.5 - attack_center
    var last: Vector2 = hud.skill_panel.buttons[3].position + hud.skill_panel.buttons[3].size * 0.5 - attack_center
    check(first.normalized().dot(last.normalized()) < -0.999, "ปลายโค้งอยู่ตรงข้ามกัน 180 องศาจริง")
    for button: TouchCommand in hud.skill_panel.buttons:
        check(is_equal_approx((button.position + button.size * 0.5).distance_to(attack_center), 126),
            "สกิลทุกปุ่มอยู่ห่างศูนย์กลางโจมตีเท่ากัน")
    var inset: Vector4 = HudSafeArea.logical_insets(Vector2(1280,720), Vector2(2560,1440), Rect2(160,0,2320,1400))
    check(inset == Vector4(98,18,64,40), "แปลง notch พิกเซลจริงเป็นหน่วย HUD และเพิ่มพื้นที่นิ้ว")
    var old_preferences := ConfigFile.new()
    var preference_path: String = "user://hybrid_preferences_migration_test.cfg"
    old_preferences.set_value("hud","minimap",false)
    old_preferences.set_value("hud","animations",false)
    old_preferences.save(preference_path)
    var migrated := HudPreferences.new()
    migrated.save_path = preference_path
    migrated.load_data()
    check(migrated.minimap_visible and not migrated.animations_enabled, "อัปเดตดีไซน์แสดงแผนที่และคง Reduce Motion ของผู้เล่น")
    migrated.minimap_visible = false
    migrated.save_data()
    migrated.load_data()
    check(not migrated.minimap_visible, "การซ่อนแผนที่ที่ตั้งหลังอัปเดตไม่ถูกรีเซ็ตอีก")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path))
    for extent: Vector2i in [Vector2i(1280,720), Vector2i(1600,720), Vector2i(1024,768), Vector2i(1280,640)]:
        get_tree().root.size = extent
        hud.safe_inset_override = Vector4(92,20,38,24)
        hud.preferences.combat_scale = 1.15
        await get_tree().process_frame
        hud._layout()
        await get_tree().process_frame
        await get_tree().process_frame
        var viewport_size: Vector2 = get_viewport().get_visible_rect().size
        var safe := Rect2(92,20,viewport_size.x-130,viewport_size.y-44)
        var in_bounds: bool = true
        var no_overlap: bool = true
        var controls: Array[Control] = [hud.attack_button, hud.evolve_button, hud.cycle_button, hud.auto_button]
        for button: TouchCommand in hud.skill_panel.buttons:
            controls.append(button)
        for button: Control in controls:
            in_bounds = in_bounds and safe.encloses(button.get_global_rect())
            no_overlap = no_overlap and not hud.party_status.get_global_rect().intersects(button.get_global_rect())
            for slot: HybridCommand in hud.party_panel.buttons:
                no_overlap = no_overlap and not slot.get_global_rect().intersects(button.get_global_rect())
        check(in_bounds, "ปุ่มทั้งหมดอยู่ใน safe area +115%% จอ %s" % extent)
        check(no_overlap, "หลอดกลาง/ปาร์ตี้ไม่ทับปุ่มต่อสู้ จอ %s" % extent)
        check(not hud.chat_panel.get_global_rect().intersects(hud.joystick.get_global_rect()), "แชตไม่ทับ Joystick จอ %s" % extent)
    get_tree().root.size = Vector2i(1280,720)
    hud.safe_inset_override = Vector4(-1,-1,-1,-1)
    hud.preferences.combat_scale = 1.0
    hud._layout()
    var initial_hp: int = tamer.hp
    tamer.take_survival_damage(30)
    check(tamer.hp == initial_hp - 30 and hud.party_status.tamer_hp.value > tamer.hp, "ดาเมจจริงทันที แต่ภาพหลอดค่อยลด")
    tamer.restore_hp(5)
    tamer.take_survival_damage(10)
    await get_tree().create_timer(0.4).timeout
    check(is_equal_approx(hud.party_status.tamer_hp.value,tamer.hp), "Tween เก่าไม่เขียนทับดาเมจ/ฟื้นฟูครั้งล่าสุด")
    var skill: MonsterSkill = partner.active_skills[0]
    partner.skill_cooldowns[skill.id] = 2.1
    hud.skill_panel._refresh_buttons()
    var skill_button: HybridCommand = hud.skill_panel.buttons[0] as HybridCommand
    check(skill_button.locked and skill_button._countdown.text == "3" and skill_button._countdown.visible,
        "คูลดาวน์จริงมี overlay เลขปัดขึ้นและล็อกปุ่ม")
    tap(hud.cycle_button)
    check(partner.cooldown_remaining(skill) == 2.1 and partner.current_form == partner.forms[0],
        "เปลี่ยนหน้าสกิลไม่ล้าง CD และไม่เปลี่ยนร่างจริง")
    var egg: ItemData = InventoryManager.catalog.find_item("digitama")
    InventoryManager.add_item(egg, 2)
    check(InventoryManager.use_item(InventoryManager.index_of("digitama")) and roster.members.size() == 2,
        "ใช้ไข่รับคู่หูจริงเข้า roster และกินไข่หนึ่งใบ")
    check(int(roster.members[1].progress.level) == partner.progress.level,
        "คู่หูที่เพิ่มใหม่รับ Shared Partner Level ปัจจุบันทันที")
    check(InventoryManager.use_item(InventoryManager.index_of("digitama")) and roster.members.size() == 3,
        "ไข่ใบถัดไปไม่ซ้ำ starter/สมาชิกเดิม")
    InventoryManager.add_item(egg, 1)
    check(not InventoryManager.use_item(InventoryManager.index_of("digitama")) and InventoryManager.count("digitama") == 1,
        "ทีมเต็มแล้วไข่ไม่สูญหาย")
    partner.progress.restore_data({"level":45,"exp":17})
    partner.refresh_equipment_stats()
    partner.hp = 55
    partner.digimon_mp = 31
    partner.skill_cooldowns[skill.id] = 5.0
    tamer.ds = 63
    tap(hud.party_panel.buttons[1])
    check(roster.active_index == 1 and partner.forms[0] == roster.family(StringName(roster.members[1].id)).forms[0],
        "แตะปาร์ตี้สลับ actor/สายพัฒนาจริง")
    check(partner.progress.level == 45 and partner.digimon_mp == 100 and tamer.ds == 63,
        "สมาชิกใหม่รับ Shared Partner Level เดิมทันที และไม่เปลี่ยน Tamer MP")

    partner.hp = 41
    partner.digimon_mp = 29
    roster._process(2.0)
    tap(hud.party_panel.buttons[0])
    check(partner.hp == 55 and partner.digimon_mp == 31 and partner.progress.level == 45,
        "สลับกลับสมาชิกเดิมยังใช้ Shared Partner Level เดิม")
    check(is_equal_approx(partner.cooldown_remaining(skill),3.0), "CD ตัวสำรองยังนับเวลาเกม")
    check(hud.party_status.partner_hp.value == partner.hp, "สลับตัว snap HP ทันที ไม่ไหลจากค่าตัวอื่น")
    get_tree().paused = true
    check(not roster.select_member(1), "เรียก backend ตรงระหว่าง pause ก็สลับไม่ได้")
    get_tree().paused = false
    partner.evolution_busy = true
    check(not roster.select_member(1), "จอง DS คัตซีนอยู่ก็สลับไม่ได้")
    partner.evolution_busy = false
    partner.enter_fainted(false)
    check(roster.select_member(1) and partner.is_alive(), "ตัวเดิมเป็นไข่ยังเลือกเพื่อนที่มีชีวิตได้")
    check(roster.select_member(0) and partner.hp == 0 and partner.state == PartnerMonster.State.EGG,
        "สลับกลับตัวที่แพ้คง HP0 และร่างไข่")
    check(partner.recover() and partner.current_form == partner.forms[0], "Recover ของ Node เดิมยังใช้งานหลังสลับทีม")
    # ขอบเขตสำคัญ: ตัวสำรองมี HP1 ในร่างใหญ่ การบังคับ Rookie ต้องไม่ปัด HP เป็น 0
    var original_reserve: Dictionary = roster.members[1].duplicate(true)
    var reserve_family: StarterPartnerData = roster.family(StringName(original_reserve.id))
    roster.members[1].form_id = String(reserve_family.forms[1].id)
    roster.members[1].max_hp = reserve_family.forms[1].max_hp
    roster.members[1].hp = 1
    tamer.hp = maxi(1, tamer.max_hp / 10)
    check(roster.select_member(1) and partner.form_index == 0 and partner.hp == 1 and partner.is_alive(),
        "ตัวสำรอง HP1 ถูกลด Rookie ยังมีชีวิต ไม่สลบจากการปัดเศษ")
    roster.select_member(0)
    roster.members[1] = original_reserve
    tamer.restore_hp(tamer.max_hp)
    var saved: Dictionary = JSON.parse_string(JSON.stringify(tamer.capture_party_state()))
    var expected_id: String = str(roster.members[0].id)
    world.queue_free()
    await get_tree().process_frame
    QuestManager.party_profile = saved
    world = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    hud = world.get_node("MobileHUD")
    tamer = world.get_node("Actors/Tamer")
    partner = tamer.partner
    check(hud.party_roster.members.size() == 3 and str(hud.party_roster.members[0].id) == expected_id,
        "ทีมสามตัวรอด JSON และโหลดฉากใหม่")
    check(hud.party_roster.members[1].hp == 41 and hud.party_roster.members[1].mp == 29,
        "HP/MP ตัวสำรองไม่ถูกแทนด้วยค่าตัว active เมื่อ reload")
    check(partner.progress.level == 45 and hud.party_roster.shared_progress.level == 45,
        "Shared Partner Level รอด reload และการสลับตัว")
    world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ",failures," failure(s), ",assertions," assertions")
    get_tree().quit(1 if failures else 0)
