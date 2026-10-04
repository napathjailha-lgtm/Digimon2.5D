extends Node
## Integration regression: ฉากจริง + input จำลอง + save round-trip โดยไม่ใช้เซฟผู้เล่น
var assertions: int = 0
var failures: int = 0
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var hud: MobileHUD
var roster: PartnerRoster
var jogress: JogressManager

func check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + message)
    else:
        print("PASS: " + message)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func open_world() -> void:
    world = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    await get_tree().process_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = tamer.partner
    hud = world.get_node("MobileHUD")
    roster = hud.party_roster
    jogress = hud.jogress_manager
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    for node: Node in get_tree().get_nodes_in_group("wild_monsters"):
        node.set_physics_process(false)
    tamer.position = Vector2(440, 380)
    partner.position = Vector2(500, 380)
    await get_tree().physics_frame

func key(code: Key, pressed: bool = true) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = pressed
    return event

func run() -> void:
    QuestManager.save_path = "user://hybrid_progression_test.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    for entry: Array in [[1,0],[14,0],[15,1],[59,1],[60,2],[89,2],[90,3],[999,3]]:
        check(EvolutionRules.max_form_index_for_level(entry[0]) == entry[1], "Evolution boundary %d" % entry[0])
    for rate: float in [0.0, 6.0, 10.0, 8.0]:
        check(is_equal_approx(EvolutionRules.ds_drain(rate), rate * 0.5), "DS rate %.1f halved exactly once" % rate)
    HybridInput.ensure_actions()
    var count: int = InputMap.action_get_events(&"move_left").size()
    HybridInput.ensure_actions()
    check(InputMap.action_get_events(&"move_left").size() == count, "Input mapping idempotent")
    for entry: Array in [[KEY_A,"move_left"],[KEY_LEFT,"move_left"],[KEY_W,"move_up"],[KEY_UP,"move_up"],[KEY_S,"move_down"],[KEY_DOWN,"move_down"],[KEY_D,"move_right"],[KEY_RIGHT,"move_right"],[KEY_1,"skill_1"],[KEY_2,"skill_2"],[KEY_3,"skill_3"],[KEY_4,"skill_4"],[KEY_SPACE,"basic_attack"],[KEY_J,"jogress"]]:
        check(key(entry[0]).is_action_pressed(entry[1]), "Physical mapping " + entry[1])
    await open_world()
    check(partner.progress.level_cap == 90, "Digimon level cap 90")
    check(roster.add_partner(&"gabumon"), "Add Gabumon")
    partner.progress.restore_data({"level": 90})
    check(roster.member_level(&"agumon") == 90 and roster.member_level(&"gabumon") == 1, "Training active does not level reserve")
    check(not jogress.can_jogress(), "90 + 1 cannot fuse")
    check(roster.select_member(1), "Switch to Gabumon")
    check(partner.progress.level == 1, "Switch restores own level")
    for entry: Array in [[14,1,false],[15,1,true],[59,2,false],[60,2,true],[89,3,false],[90,3,true]]:
        partner.progress.restore_data({"level": entry[0]})
        check(partner.load_monster_data(partner.forms[entry[1]]) == entry[2], "Loader boundary %d / stage %d" % [entry[0],entry[1]])
    check(hud.skill_panel.pages.size() == 1, "HUD only current form")
    for source: MonsterData in partner.forms:
        check(partner.can_use_skill_from_form(source, 0) == (source == partner.current_form), "Skill isolation " + source.monster_name)
    check(not partner._try_skill_resource(partner.forms[0].skills[0]), "Direct foreign skill denied")
    partner.progress.restore_data({"level": 89})
    check(not jogress.can_jogress(), "90 + 89 cannot fuse")
    partner.progress.add_exp(1000000)
    check(partner.progress.level == 90 and partner.progress.current_exp == 0, "Huge EXP caps at 90")
    check(jogress.can_jogress(), "90 + 90 unlocks fusion without quest gates")
    roster.members[0]["egg"] = true
    check(not jogress.can_jogress(), "Fainted reserve cannot fuse")
    roster.members[0]["egg"] = false
    check(jogress.request_jogress(), "Start cancellable fusion")
    jogress._cutscene.cancel()
    await get_tree().process_frame
    check(not jogress.active and not partner.evolution_busy and not get_tree().paused, "Cancel releases pause and does not commit")

    var rogue := MonsterData.new()
    rogue.id = &"omegamon"
    check(not partner._form_unlocked(rogue), "Omegamon ID alone cannot bypass manager")
    partner.hp = partner.max_hp / 2
    var ratio: float = float(partner.hp) / partner.max_hp
    check(jogress.request_jogress(), "J/HUD entry starts cutscene")
    check(partner.evolution_busy and not roster.select_member(0), "Cutscene locks member switching")
    await get_tree().create_timer(4.0, true).timeout
    check(jogress.active and partner.current_form.id == &"omegamon", "Cutscene commits Omegamon")
    check(not get_tree().paused and not partner.evolution_busy, "Cutscene releases pause/busy")
    check(absf(float(partner.hp) / partner.max_hp - ratio) < 0.001, "Fusion preserves HP ratio")
    check(partner.current_form.max_hp == 1200 and partner.current_form.attack == 155, "Top tier base stats")
    check(partner.active_skills.size() == 2 and partner.active_skills[0].display_name == "Grey Sword" and partner.active_skills[1].display_name == "Garuru Cannon", "Omegamon replaces whole skill set")
    check(not roster.select_member(0), "Fusion cannot duplicate through party switching")
    var omega_frames: SpriteFrames = partner.current_form.sprite_frames
    check(omega_frames.get_frame_texture(&"idle", 0) != omega_frames.get_frame_texture(&"attack", 2), "Sword has distinct art")
    check(omega_frames.get_frame_texture(&"attack", 2) != omega_frames.get_frame_texture(&"cast", 2), "Cannon has distinct art")
    check(hud.party_panel.buttons[roster.active_index].caption == "Omegamon", "Active portrait identifies Omegamon")

    check(hud.skill_panel.pages.size() == 1 and hud.skill_panel.pages[0].form == partner.current_form, "Omegamon HUD updates immediately")
    var enemy: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
    # เป้าทดสอบสองสกิลต้องอยู่รอดจากท่าแรก แม้ปรับสมดุลศัตรูให้เบาลง
    enemy.max_hp = 10000
    enemy.position = partner.position + Vector2(70,0)
    world.get_node("Actors").add_child(enemy)
    enemy.set_physics_process(false)
    await get_tree().physics_frame
    for slot: int in range(2):
        partner.cancel_battle()
        partner.skill_cooldowns.clear()
        partner.digimon_mp = 100
        tamer.set_target(enemy)
        var before_hp: int = enemy.hp
        var before_ds: float = tamer.ds
        hud.skill_panel._refresh_buttons()
        hud._unhandled_input(key(KEY_1 if slot == 0 else KEY_2))
        check(partner.combat_action.busy, "Keyboard starts Omega skill %d" % slot)
        partner.sprite.frame = 2
        await get_tree().create_timer(0.65).timeout
        check(enemy.hp < before_hp, "Omega impact damage %d" % slot)
        check(partner.digimon_mp < 100 and is_equal_approx(tamer.ds, before_ds), "Skill spends partner MP only %d" % slot)
    partner.cancel_battle()
    var ds_before: float = tamer.ds
    partner._physics_process(0.5)
    check(is_equal_approx(ds_before - tamer.ds, 2.0), "Omega drain 8 -> 4 DS/sec")
    var saved: Dictionary = tamer.capture_party_state().duplicate(true)
    check(saved.partner_roster.members[1].form_id == "gabumon_3", "Roster saves valid component Mega ID")
    QuestManager.party_profile = saved
    QuestManager.save_progress()
    world.queue_free()
    await get_tree().process_frame
    QuestManager.party_profile = {}
    QuestManager.load_progress()
    await open_world()
    check(jogress.active and partner.current_form.id == &"omegamon", "Disk save restores Omegamon")
    check(partner.active_skills[0].id == &"omegamon_grey_sword", "Reload restores skill set")
    var saved_cd: float = partner.cooldown_remaining(partner.active_skills[1])
    check(saved_cd > 0, "Reload keeps Omega cooldown")
    check(jogress.request_jogress() and not jogress.active, "J toggles dissolve")
    check(partner.current_form.id == &"gabumon_3", "Dissolve returns component Mega")
    check(jogress._activate(), "Re-fuse checks ingredients")
    tamer.ds = 0.01
    partner._physics_process(0.1)
    check(not jogress.active and partner.form_index == 0 and tamer.ds == 0.0, "DS depletion returns Rookie and clears fusion")
    tamer.ds = tamer.max_ds
    check(jogress._activate(), "Ready ingredients can fuse again")
    partner.enter_fainted(false)
    check(not jogress.active and partner.hp == 0, "Death clears fusion")
    check(partner.recover() and partner.form_index == 0, "Recover safely returns Rookie")
    check(roster.select_member(0) and partner.progress.level == 90, "Other component still has its own progression")
    # Spawn/update are both computed from immutable bases, without multiplying again
    var wild: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
    wild.position = Vector2(900, 380)
    world.get_node("Actors").add_child(wild)
    wild.set_physics_process(false)
    check(wild.max_hp == 3008 and wild.attack_damage == 129, "Lv90 gentler scaling")
    wild.hp = wild.max_hp / 2
    partner.progress.restore_data({"level": 10})
    check(wild.max_hp == 448 and wild.hp == 224 and wild.attack_damage == 21, "Live rescale preserves half HP")
    partner.progress.restore_data({"level": 10, "exp": 1})
    check(wild.max_hp == 448 and wild.hp == 224, "Repeated progress events do not compound")
    wild.hp = 1
    partner.progress.restore_data({"level": 1})
    check(wild.hp == 1, "Downscale cannot round living enemy to death")
    for id: String in ["devimon", "etemon", "myotismon", "piedmon"]:
        var boss: WildMonster = load("res://scenes/boss_" + id + ".tscn").instantiate()
        world.get_node("Actors").add_child(boss)
        boss.set_physics_process(false)
        check(boss.is_world_boss and boss.max_hp == 400 and boss.attack_damage == 23, "Boss 2.5x rounded " + id)
        boss.queue_free()
    # Keyboard + joystick coexist, text/menu explicitly blocks raw polling
    Input.action_press(&"move_right")
    tamer.velocity = Vector2.ZERO
    hud.joystick.move_vector = Vector2.LEFT
    tamer._physics_process(0.1)
    check(tamer.velocity.x > 0, "Keyboard wins over joystick drift")
    Input.action_release(&"move_right")
    tamer.velocity = Vector2.ZERO
    tamer._physics_process(0.1)
    check(tamer.velocity.x < 0, "Joystick still drives movement")
    hud.joystick.release_input()
    var field := LineEdit.new()
    hud.get_node("Root").add_child(field)
    field.grab_focus()
    Input.action_press(&"move_right")
    tamer.velocity = Vector2.ZERO
    tamer._physics_process(0.1)
    check(tamer.velocity.is_zero_approx(), "Typing does not move character")
    field.release_focus()
    field.queue_free()
    tamer.controls_blocked = true
    tamer._physics_process(0.1)
    check(tamer.velocity.is_zero_approx(), "Menu blocks movement polling")
    tamer.controls_blocked = false
    Input.action_release(&"move_right")
    await get_tree().physics_frame
    # Test native mouse branch, then emulated touch branch (same transformed point)
    var screen: Vector2 = get_viewport().get_canvas_transform() * wild.global_position
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = screen
    Input.emulate_touch_from_mouse = false
    tamer._unhandled_input(click)
    check(tamer.get_target() == wild, "Native left click targets wild")
    tamer.set_target(null)
    Input.emulate_touch_from_mouse = true
    var touch := InputEventScreenTouch.new()
    touch.position = screen
    touch.pressed = true
    tamer._unhandled_input(touch)
    check(tamer.get_target() == wild, "Touch/emulated click targets wild")
    partner.cancel_battle()
    tamer.set_target(null)
    tamer._unhandled_input(click)
    check(tamer.get_target() == null, "Emulated mouse is not handled twice")
    var report := {"assertions": assertions, "failures": failures, "engine": Engine.get_version_info().string}
    var file := FileAccess.open("res://docs/HYBRID_PROGRESSION_RESULTS.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    print("HYBRID_PROGRESSION_RESULTS: ", JSON.stringify(report))
    world.queue_free()
    await get_tree().process_frame
    get_tree().quit(1 if failures > 0 else 0)
