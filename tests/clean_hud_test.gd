extends Node
## UX regression: ใช้ Touch จริงตรวจเมนู/Modal และทดสอบคำสั่งสกิลข้ามร่าง
var failures: int = 0
var requests: int = 0
func _ready() -> void:
    run.call_deferred()
func check(ok: bool, message: String) -> void:
    if ok: print("PASS: ",message)
    else:
        failures += 1
        push_error("FAIL: "+message)
func tap(control: Control) -> void:
    var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for down: bool in [true,false]:
        var event := InputEventScreenTouch.new()
        event.index = 8
        event.position = point
        event.pressed = down
        Input.parse_input_event(event)
        Input.flush_buffered_events()
func run() -> void:
    get_tree().root.size = Vector2i(1280,720)
    QuestManager.save_path = "user://clean_hud_test.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    hud.preferences.save_path = "user://clean_hud_preferences_test.cfg"
    hud.preferences.combat_scale = 1
    hud.preferences.animations_enabled = true
    hud._layout()
    hud.preferences.minimap_visible = false
    hud._layout() # v23 เปิดมินิแมพโดยปริยาย; suite นี้ทดสอบ preference ซ่อนโดยตรง
    hud.chat_panel.set_collapsed(true)
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    check(not hud.menu.drawer.visible,"เริ่มต้นซ่อน Grid คืนพื้นที่ฉาก")
    tap(hud.menu.toggle_button)
    # รอ Tween จบจริง ไม่ผูกกับ FPS/เฟรมเริ่มต้นที่กำลัง import ภาพ
    await hud.menu._tween.finished
    check(hud.menu.expanded and hud.inventory_button.is_visible_in_tree() and not hud.inventory_button.locked,"แตะปุ่มเดียวกางเมนูได้")
    check(hud.skill_panel.process_mode == Node.PROCESS_MODE_DISABLED,"เมนูกางแล้วไม่รับสกิลที่อยู่ใต้ Drawer")
    tap(hud.menu.toggle_button)
    tap(hud.menu.toggle_button)
    tap(hud.menu.toggle_button)
    await get_tree().create_timer(0.23).timeout
    check(not hud.menu.expanded and not hud.menu.drawer.visible,"กดเร็วระหว่าง Tween แล้วจบเป็นสถานะล่าสุด")
    hud.menu.set_expanded(true,false)
    await get_tree().process_frame
    tap(hud.stats_button)
    check(hud.digimon_screen.is_open and get_tree().paused and not hud.menu.drawer.visible,"แตะดิจิมอน เปิด modal และยุบเมนู")
    check(hud.digimon_screen.visual_fx.blur.visible and hud.digimon_screen.visual_fx.blur.material is ShaderMaterial,"ฉากหลัง modal ใช้ blur shader และไม่เบลอตัวหน้าต่าง")
    check(not hud.inventory_screen.open_screen(),"เปิด modal ซ้อนแล้วไม่แย่ง pause")
    await get_tree().create_timer(0.4, true).timeout
    tap(hud.digimon_screen.close_button)
    check(not get_tree().paused and not hud.digimon_screen.is_open,"ปิดด้วย touch แล้วคืนเวลาเกม")
    hud._menu_action(&"settings")
    await get_tree().process_frame
    await get_tree().process_frame
    tap(hud.smart_panel.buttons[&"size"])
    check(is_equal_approx(hud.combat.scale.x,1.15),"ตั้งค่าปุ่ม 115% ใช้งานได้จริง")
    tap(hud.smart_panel.buttons[&"motion"])
    check(not hud.menu.animations_enabled,"ลดการเคลื่อนไหวปิด Tween เมนู")
    var restored := HudPreferences.new()
    restored.save_path = hud.preferences.save_path
    restored.load_data()
    check(is_equal_approx(restored.combat_scale,1.15) and not restored.animations_enabled,"ตั้งค่าคงอยู่เมื่อโหลด Config ใหม่")
    hud.smart_panel.close_screen()
    for extent: Vector2i in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800),Vector2i(1280,640)]:
        get_tree().root.size = extent
        await get_tree().process_frame
        await get_tree().process_frame
        hud._layout()
        await get_tree().process_frame
        var bounds := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
        check(bounds.encloses(hud.attack_button.get_global_rect()),"Attack อยู่ในขอบจอ %s" % extent)
        check(not hud.chat_panel.get_global_rect().intersects(hud.joystick.get_global_rect()),"Chat ไม่ซ้อน Joystick %s" % extent)
        check(not hud.chat_panel.get_global_rect().intersects(hud.attack_button.get_global_rect()),"Chat ไม่ซ้อน Attack %s" % extent)
        check(hud.auto_button.get_global_rect().get_center().distance_to(hud.attack_button.get_global_rect().get_center()) < 150,"Auto อยู่ในช่วงนิ้วโป้ง %s" % extent)
    get_tree().root.size = Vector2i(1280,720)
    var panel: FormSkillPanel = hud.skill_panel
    var original_form: MonsterData = partner.current_form
    var original_hp: int = partner.hp
    var original_atk: int = partner.attack_power
    var original_ds: float = tamer.ds
    var old_button: TouchCommand = panel.buttons[0]
    var old_revision: int = panel._revision
    panel.form_skill_requested.connect(func(_form: MonsterData,_slot: int): requests += 1)
    tap(hud.cycle_button)
    check(partner.current_form == original_form and partner.hp == original_hp and partner.attack_power == original_atk and tamer.ds == original_ds,"สลับหน้าไม่เปลี่ยนร่าง/HP/ATK/DS")
    check(old_button.get_parent() == null,"ปุ่มหน้าเก่าถอดจาก tree ทันที")
    panel._request_slot(0,&"unknown",old_revision)
    check(requests == 0,"callback รุ่นเก่าไม่ออกคำสั่ง")
    var champion: MonsterData = partner.forms[1]
    check(panel.pages[panel.page_index].form == champion,"Skill Cycle เลือกชุด Champion ในร่าง Rookie")
    var enemy: WildMonster = world.get_node("Spawners/SpawnerA").current_monster
    partner.global_position = Vector2(500,350)
    enemy.global_position = Vector2(540,350)
    tamer.set_target(enemy)
    tamer.ds = tamer.max_ds
    var skill: MonsterSkill = champion.skills[0]
    var before_ds: float = tamer.ds
    var before_mp: float = partner.digimon_mp
    tap(panel.buttons[0])
    partner._battle_tick()
    check(requests == 1 and partner.combat_action.busy,"Touch ข้ามร่างส่งคำสั่งร่ายจริง")
    check(is_equal_approx(partner.digimon_mp,before_mp-skill.mp_cost) and tamer.ds == before_ds and partner.cooldown_remaining(skill)>0,"สกิลข้ามร่างหัก MP ไม่หัก DS/ตั้งคูลดาวน์เดิม")
    check(partner.current_form == original_form and partner.attack_power == original_atk,"ร่ายสกิลต่างร่างยังใช้ ATK ของร่างสนาม")
    check(partner._action_damage >= roundi(original_atk*skill.multiplier*.95)-1 and partner._action_damage <= roundi(original_atk*skill.multiplier*1.05)+1,"ดาเมจต่างร่างใช้ multiplier และค่าแกว่ง 5%")
    partner._cancel_combat_action()
    var cd: float = partner.cooldown_remaining(skill)
    panel.cycle_page()
    panel.cycle_page()
    check(is_equal_approx(partner.cooldown_remaining(skill),cd),"สลับหน้าไม่ล้างคูลดาวน์")
    var ultimate: MonsterData = partner.forms[2]
    check(not partner.can_use_skill_from_form(ultimate,0),"Ultimate ไม่ข้ามล็อกเควสต์")
    for index: int in range(panel.pages.size()):
        if panel.pages[index].form == ultimate:
            panel.page_index = index
            break
    panel._draw_page()
    check(panel.buttons[0].locked and hud.page_label.text.contains("ล็อกเควสต์"),"ดูหน้าร่างล็อกได้ แต่ปุ่มระบุและปิดใช้งาน")
    var locked_ds: float = tamer.ds
    partner.command_form_skill(ultimate,0,enemy)
    check(tamer.ds == locked_ds and not partner.combat_action.busy and partner._pending_page_skill == null,"เรียกคำสั่งตรงก็ไม่ข้ามล็อกหรือหัก DS")
    check(partner.active_skills[0] == original_form.skills[0],"Auto Battle ยังใช้สกิลร่างปัจจุบันหลังสลับหน้า")
    # มากกว่า 4 สกิล: การแบ่งหน้าไม่ทิ้งช่องสกิลที่ห้า
    var expanded_form: MonsterData = original_form.duplicate() as MonsterData
    expanded_form.skills = [skill,skill,skill,skill,skill]
    partner.forms.append(expanded_form)
    panel.rebuild(partner.active_skills)
    check(panel.pages.any(func(page: Dictionary): return page.form == expanded_form and page.offset == 4),"ชุด 5 สกิลมีหน้าที่สอง")
    hud._toggle_stats()
    hud.digimon_screen.queue_free()
    await get_tree().process_frame
    check(not get_tree().paused,"ลบ modal ที่เปิดอยู่ยังคืน pause")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(hud.preferences.save_path)) if is_instance_valid(hud) else DirAccess.remove_absolute(ProjectSettings.globalize_path("user://clean_hud_preferences_test.cfg"))
    print("RESULT: ",failures," failure(s)")
    get_tree().quit(1 if failures else 0)
