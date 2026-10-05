extends Node
## Runtime regression: short Champion-start line, combat impacts, hatching and saves.
var failures: int = 0
var assertions: int = 0
var world: Node2D
var player: Tamer
var partner: PartnerMonster
var roster: PartnerRoster

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    print("ADVENTURE START")
    run.call_deferred()

func check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + label)

func set_level(level: int) -> void:
    partner.progress.restore_data({"level": level, "exp": 0})
    roster.shared_progress = {"level": level, "exp": 0}

func run() -> void:
    QuestManager.save_path = "user://adventure_partners_test.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"tailmon"
    GameManager.tamer_selected = &"hikari"
    world = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    for frame: int in range(3):
        await get_tree().physics_frame
    player = world.get_node("Actors/Tamer")
    partner = player.partner
    roster = player.party_roster
    player.set_physics_process(false)
    player.survival.set_process(false)
    player.survival.autosave_enabled = false
    partner.set_physics_process(false)
    roster.set_process(false)
    player.position = Vector2(200, 200)
    partner.position = Vector2(280, 200)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    check(roster.add_partner(&"patamon") and roster.add_partner(&"gomamon"), "New lines fit the three-member party")
    var ids: Array[StringName] = [&"tailmon", &"patamon", &"gomamon"]
    var mega_names: Array[String] = ["Holydramon", "Seraphimon", "Vikemon"]
    for member: int in range(ids.size()):
        print("ADVENTURE FAMILY: ", ids[member])
        set_level(1)
        if member > 0:
            check(roster.select_member(member), "Select " + String(ids[member]))
        var family: StarterPartnerData = GameManager.catalog.starter_by_id(ids[member])
        check(family.forms.size() == (3 if member == 0 else 4), "Correct evolution line length")
        check(partner.current_form == family.forms[0], "Old base form ID still loads")
        for index: int in range(family.forms.size()):
            var form: MonsterData = family.forms[index]
            check(form.validation_error().is_empty(), "Valid form " + form.monster_name)
            var required: int = EvolutionRules.minimum_level_for_form_index(index, form)
            check(required == (1 if index == 0 else [1, 15, 60, 90][form.evolution_stage]), "Canonical stage level " + form.monster_name)
            if index > 0:
                set_level(required - 1)
                player.ds = player.max_ds
                var before: float = player.ds
                check(partner.prepare_digivolve() == null and player.ds == before, "Locked form spends no MP")
                check(not partner.load_monster_data(form), "Direct load cannot bypass level lock")
                set_level(required)
                check(partner.prepare_digivolve() == form, "Reserve " + form.monster_name)
                check(partner.finish_digivolve(), "Finish evolution " + form.monster_name)
                check(partner.current_form == form, "Correct evolved form")
            check(partner.active_skills.size() == form.skills.size(), "Only current-form skills equipped")
            var enemy: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
            enemy.max_hp = 10000
            enemy.position = partner.position + Vector2(75, 0)
            world.get_node("Actors").add_child(enemy)
            enemy.set_physics_process(false)
            await get_tree().physics_frame
            for slot: int in range(form.skills.size()):
                partner.cancel_battle()
                partner.digimon_mp = 100
                partner.skill_cooldowns.clear()
                partner.command_attack(enemy)
                var hp_before: int = enemy.hp
                var skill: MonsterSkill = form.skills[slot]
                check(partner._try_skill(slot), "Start " + skill.display_name)
                check(enemy.hp == hp_before, "No damage before animation impact")
                await get_tree().create_timer(0.65).timeout
                check(enemy.hp < hp_before, "Animation releases damage: " + skill.display_name)
                check(is_equal_approx(partner.digimon_mp, 100 - skill.mp_cost), "Skill spends MP once")
                check(partner.cooldown_remaining(skill) > 0, "Skill starts cooldown")
            partner.cancel_battle()
            enemy.queue_free()
            await get_tree().process_frame
        check(partner.current_form.monster_name == mega_names[member] and partner.get_next_form() == null, "Mega is final form")
        check(partner.active_skills.size() == 2, "Mega has two skills")
        var hud: MobileHUD = world.get_node("MobileHUD")
        check(hud.skill_panel.pages.size() == 1 and hud.skill_panel.pages[0].form == family.forms[-1], "Skill UI exposes only active Mega skills")
        check(hud.digimon_screen.open_screen(), "Open Mega status")
        check(hud.digimon_screen.title_name.text == mega_names[member] and hud.digimon_screen.stage_label.text == "MEGA", "Status shows correct Mega")
        check(hud.digimon_screen.preview.sprite.sprite_frames == family.forms[-1].sprite_frames, "Status uses current form art")
        hud.digimon_screen.close_screen()
        var snapshot: Dictionary = roster.get_save_data().duplicate(true)
        roster.initialize(snapshot)
        check(partner.current_form == family.forms[-1], "Save restore preserves Mega")

    # Tampered/older Tailmon save must not restore Mega at the Ultimate threshold.
    var saved: Dictionary = roster.get_save_data().duplicate(true)
    saved["shared_progress"] = {"level": 60, "exp": 0}
    roster.initialize(saved)
    if roster.active_index != 0:
        check(roster.select_member(0), "Switch back to Tailmon line")
    check(partner.current_form.monster_name == "Angewomon", "Restore clamps Tailmon Mega to Ultimate at Lv60")

    var service := IncubatorService.new()
    service.configure(roster)
    for id: StringName in ids:
        var egg: ItemData = InventoryManager.catalog.find_item("digitama_" + String(id))
        check(egg != null and egg.egg_partner_id == id, "Species egg resolves " + String(id))
        if egg == null:
            continue
        InventoryManager.add_item(egg, 1)
        check(service.select_egg(egg.item_id), "Select egg")
        var size_before: int = roster.storage.size()
        check(service._complete_hatch(egg), "Hatch into full-party archive")
        check(roster.storage.size() == size_before + 1 and roster.storage[-1].id == String(id), "Hatch returns exact family")
    var loot: LootTable = load("res://data/items/default_loot.tres")
    var egg_chance: float = 0.0
    var egg_count: int = 0
    for entry: LootDropEntry in loot.entries:
        if entry.item.item_type == ItemData.ItemType.EGG:
            egg_count += 1
            egg_chance += entry.chance
    check(egg_count == 8 and is_equal_approx(egg_chance, 0.1), "All eight eggs share unchanged 10% drop pool")
    world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("ADVENTURE RESULT: %d failures / %d assertions" % [failures, assertions])
    get_tree().quit(1 if failures else 0)
