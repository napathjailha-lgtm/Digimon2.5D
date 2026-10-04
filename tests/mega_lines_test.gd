extends Node
## ตรวจการเล่นจริง: เงื่อนไขเควสต์, คัตซีน, สกิล, ปาร์ตี้และการโหลดเซฟ
var failures: int = 0
var assertions: int = 0
var world: Node2D
var player: Tamer
var partner: PartnerMonster
var hud: MobileHUD

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(ok: bool, label: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", label)
    else:
        failures += 1
        push_error("FAIL: " + label)

func complete_until(id: StringName) -> void:
    while not QuestManager.is_completed(id):
        var q: StoryQuest = QuestManager.get_current_quest()
        if q == null:
            check(false, "Missing quest " + String(id))
            return
        QuestManager.report_event(q.objective, q.target_id, q.required_count, "mega_v26_" + String(q.id))

func open_world() -> void:
    world = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    for i: int in range(3):
        await get_tree().physics_frame
    player = world.get_node("Actors/Tamer")
    partner = player.partner
    hud = world.get_node("MobileHUD")
    player.set_physics_process(false)
    player.survival.set_process(false)
    player.survival.autosave_enabled = false
    partner.set_physics_process(false)
    hud.party_roster.set_process(false)
    player.position = Vector2(200, 200)
    partner.position = Vector2(280, 200)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    await get_tree().physics_frame

func check_ui(form: MonsterData) -> void:
    check(hud.skill_panel.pages.size() == 4 and hud.skill_panel.pages[hud.skill_panel.page_index].form == form,
        form.monster_name + " has the active Mega skill page")
    check(hud.digimon_screen.open_screen(), "Open Mega status")
    check(hud.digimon_screen.title_name.text == form.monster_name and hud.digimon_screen.stage_label.text == "MEGA", "Status shows correct Mega name/stage")
    check(hud.digimon_screen.preview.sprite.sprite_frames == form.sprite_frames, "Status uses actual Mega art")
    check(hud.digimon_screen.skill_buttons[0].icon == form.skills[0].icon, "Status uses actual Mega skill icons")
    hud.digimon_screen.close_screen()

func check_skills() -> void:
    var enemy: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
    enemy.max_hp = 10000
    enemy.position = partner.position + Vector2(80, 0)
    world.get_node("Actors").add_child(enemy)
    enemy.set_physics_process(false)
    await get_tree().physics_frame
    for slot: int in range(partner.active_skills.size()):
        partner.cancel_battle()
        partner.digimon_mp = 100
        partner.skill_cooldowns.clear()
        partner.command_attack(enemy)
        var skill: MonsterSkill = partner.active_skills[slot]
        var hp_before: int = enemy.hp
        var ds_before: float = player.ds
        check(partner._try_skill(slot), "Cast " + skill.display_name)
        partner.sprite.frame = skill.release_frame
        await get_tree().create_timer(0.55).timeout
        check(enemy.hp < hp_before, skill.display_name + " deals damage on impact")
        check(is_equal_approx(partner.digimon_mp, 100 - skill.mp_cost) and is_equal_approx(player.ds, ds_before), "Skill spends MP once and preserves DS")
        check(partner.cooldown_remaining(skill) > 0, "Skill cooldown is active")
    partner.cancel_battle()
    enemy.queue_free()
    await get_tree().process_frame

func run() -> void:
    QuestManager.save_path = "user://mega_lines_v26_test.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    var agumon: StarterPartnerData = GameManager.catalog.starter_by_id(&"agumon")
    var gabumon: StarterPartnerData = GameManager.catalog.starter_by_id(&"gabumon")
    check(agumon.evolution_path() == "Agumon → Greymon → MetalGreymon → WarGreymon", "Agumon selection has all four forms")
    check(gabumon.evolution_path() == "Gabumon → Garurumon → WereGarurumon → MetalGarurumon", "Gabumon selection has all four forms")
    for family: StarterPartnerData in [agumon, gabumon]:
        check(family.forms.size() == 4 and not QuestManager.can_use_form(family.forms[3]), "Mega initially quest-locked: " + family.display_name)
        for form: MonsterData in family.forms:
            check(form.validation_error().is_empty(), "Valid animation/action/skill data: " + form.monster_name)
    await open_world()
    player.ds = 100
    check(partner.digivolve() and partner.current_form == agumon.forms[1], "Agumon evolves to Greymon")
    check(not partner.digivolve(), "Ultimate blocked before Etemon quest")
    complete_until(&"q05_etemon")
    player.ds = 100
    check(partner.digivolve() and partner.current_form == agumon.forms[2], "Greymon evolves to MetalGreymon")
    var old_ds: float = player.ds
    check(not partner.digivolve() and player.ds == old_ds, "Mega blocked before Myotismon without spending DS")
    complete_until(&"q07_myotismon")
    check(QuestManager.can_use_form(agumon.forms[3]) and QuestManager.can_use_form(gabumon.forms[3]), "Myotismon quest unlocks both Mega forms")
    partner.hp = roundi(partner.max_hp * 0.5)
    var ratio: float = float(partner.hp) / partner.max_hp
    var old_mp: float = partner.digimon_mp
    player.ds = 24
    check(partner.prepare_digivolve() == null and not partner.evolution_busy, "Insufficient DS blocks Mega")
    player.ds = 100
    var reservation_ds: float = player.ds
    check(partner.prepare_digivolve() == agumon.forms[3] and partner.evolution_busy, "WarGreymon reserved for cutscene")
    check(partner.current_form == agumon.forms[2] and is_equal_approx(player.ds, reservation_ds - agumon.forms[3].evolution_cost), "Cutscene reserves DS once and preserves current form")
    check(partner.finish_digivolve() and partner.current_form == agumon.forms[3], "WarGreymon committed after cutscene")
    check(absf(float(partner.hp) / partner.max_hp - ratio) < 0.005 and partner.digimon_mp == old_mp, "Mega preserves HP ratio and MP")
    check(partner.get_next_form() == null, "WarGreymon is final form")
    check_ui(agumon.forms[3])
    await check_skills()
    partner.hp = 301
    partner.digimon_mp = 42
    partner.skill_cooldowns[agumon.forms[3].skills[0].id] = 7
    check(hud.party_roster.add_partner(&"gabumon") and hud.party_roster.select_member(1), "Switch to Gabumon party member")
    for index: int in range(1, 4):
        player.ds = 100
        check(partner.digivolve() and partner.current_form == gabumon.forms[index], "Gabumon evolves to " + gabumon.forms[index].monster_name)
    check(partner.get_next_form() == null, "MetalGarurumon is final form")
    check_ui(gabumon.forms[3])
    check(gabumon.forms[3].portrait_texture != null and hud.party_panel.buttons[1].icon == gabumon.forms[3].portrait_texture, "MetalGarurumon party slot shows face portrait instead of tail")
    await check_skills()
    partner.hp = 271
    partner.digimon_mp = 38
    check(hud.party_roster.select_member(0) and partner.current_form == agumon.forms[3] and partner.hp == 301 and partner.digimon_mp == 42, "Party switch preserves WarGreymon HP/MP/form")
    check(is_equal_approx(partner.cooldown_remaining(agumon.forms[3].skills[0]), 7), "WarGreymon cooldown is separate")
    check(hud.party_roster.select_member(1) and partner.current_form == gabumon.forms[3] and partner.hp == 271, "Party switch preserves MetalGarurumon")
    player.save_party_progress()
    world.queue_free()
    await get_tree().process_frame
    QuestManager.party_profile.clear()
    check(QuestManager.load_progress(), "Read Mega save from disk")
    await open_world()
    check(partner.current_form == gabumon.forms[3] and partner.hp == 271 and partner.digimon_mp == 38, "Reload preserves active MetalGarurumon HP/MP")
    check(hud.party_roster.select_member(0) and partner.current_form == agumon.forms[3] and partner.hp == 301, "Reload preserves reserve WarGreymon")
    player.take_survival_damage(player.max_hp)
    check(partner.current_form == agumon.forms[0] and not partner.can_battle(), "Low Tamer HP still reverts Mega to Rookie")
    player.restore_hp(player.max_hp)
    check(hud.party_roster.select_member(1) and partner.load_monster_data(gabumon.forms[2]), "Old Ultimate form ID remains valid")
    player.save_party_progress()
    world.queue_free()
    await get_tree().process_frame
    check(QuestManager.load_progress(), "Load save containing old Ultimate ID")
    await open_world()
    check(partner.current_form == gabumon.forms[2] and partner.forms.size() == 4, "Old Ultimate save gains Mega without recreating character")
    world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s), ", assertions, " assertions")
    get_tree().quit(1 if failures else 0)
