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

func set_level(level: int, exp: int = 0) -> void:
    # ปรับเฉพาะ Digimon ที่กำลัง active; PartnerRoster จะ capture กลับสมาชิกตัวนั้น
    partner.progress.restore_data({"level": level, "exp": exp})

func verify_service_first_open() -> void:
    # Regression: first tap on Archive / Shop / Incubator must produce a fully laid-out panel,
    # not only the backdrop/overlay. Each modal owns pause and must restore it on close.
    var shop := ShopUI.new()
    world.add_child(shop)
    shop.configure(ShopService.new())
    check(shop.open_screen(), "Merchant opens on first attempt")
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.36, true).timeout
    check(shop.root.visible and shop.panel.visible, "Merchant panel visible after first-open layout")
    check(shop.panel.size.x > 300.0 and shop.panel.size.y > 250.0 and shop.panel.modulate.a > 0.95, "Merchant first-open panel has stable geometry")
    shop.close_screen()
    await get_tree().process_frame

    var archive := DigimonArchiveUI.new()
    world.add_child(archive)
    archive.configure(roster)
    check(archive.open_screen(), "Archive opens on first attempt")
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.36, true).timeout
    check(archive.root.visible and archive.panel.visible, "Archive panel visible after first-open layout")
    check(archive.panel.size.x > 300.0 and archive.panel.size.y > 250.0 and archive.panel.modulate.a > 0.95, "Archive first-open panel has stable geometry")
    archive.close_screen()
    await get_tree().process_frame

    var hatch_service := IncubatorService.new()
    hatch_service.configure(roster)
    var incubator := IncubatorUI.new()
    world.add_child(incubator)
    incubator.configure(hatch_service, player)
    check(incubator.open_screen(), "Incubator opens on first attempt")
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.36, true).timeout
    check(incubator.root.visible and incubator.panel.visible, "Incubator panel visible after first-open layout")
    check(incubator.panel.size.x > 300.0 and incubator.panel.size.y > 250.0 and incubator.panel.modulate.a > 0.95, "Incubator first-open panel has stable geometry")
    incubator.close_screen()
    await get_tree().process_frame

    shop.queue_free()
    archive.queue_free()
    incubator.queue_free()


func run() -> void:
    QuestManager.save_path = "user://adventure_partners_test.json"
    QuestManager.reset_progress(false)
    # ชุดทดสอบนี้ทดสอบสายวิวัฒนาการ ไม่ใช่ลำดับเนื้อเรื่อง
    QuestManager.max_unlocked_stage = MonsterData.EvolutionStage.MEGA
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

    # EXP curve แยก owner: ช่วง Rookie เหมือนกันเพื่อ onboarding แต่หลัง Champion Digimon ช้ากว่า
    check(player.progress.exp_required(10) == 550 and partner.progress.exp_required(10) == 550, "Tamer and Digimon share early onboarding pace")
    check(player.progress.exp_required(30) == 1550 and partner.progress.exp_required(30) == 2225, "Digimon EXP curve separates after Champion")
    check(player.progress.exp_required(60) == 3050 and partner.progress.exp_required(60) == 7775, "Digimon high-level EXP curve is steeper than Tamer")
    check(partner.progress.level_cap == 90 and player.progress.level_cap == 99, "Digimon caps at 90 while Tamer keeps level 99 cap")

    player.position = Vector2(200, 200)
    partner.position = Vector2(280, 200)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    check(roster.add_partner(&"patamon") and roster.add_partner(&"gomamon"), "New lines fit the three-member party")
    await verify_service_first_open()

    # Level/EXP ต้องแยกกันจริง: ตัวที่ไม่ได้ลงสนามไม่โตตาม
    set_level(12, 34)
    check(roster.member_level(&"tailmon") == 12 and roster.member_level(&"patamon") == 1 and roster.member_level(&"gomamon") == 1, "Only active Tailmon gains level")
    check(roster.select_member(1) and partner.progress.level == 1, "Switching to Patamon restores its own Lv1")
    set_level(5, 20)
    check(roster.member_level(&"patamon") == 5 and roster.member_level(&"tailmon") == 12, "Patamon progression does not overwrite Tailmon")
    check(roster.select_member(0) and partner.progress.level == 12 and partner.progress.current_exp == 34, "Switching back restores Tailmon own Level/EXP")

    var independent_snapshot: Dictionary = roster.get_save_data().duplicate(true)
    roster.initialize(independent_snapshot)
    check(partner.progress.level == 12 and roster.member_level(&"patamon") == 5 and roster.member_level(&"gomamon") == 1, "Save restore preserves independent member progression")

    var ids: Array[StringName] = [&"tailmon", &"patamon", &"gomamon"]
    var mega_names: Array[String] = ["Holydramon", "Seraphimon", "Vikemon"]
    for member: int in range(ids.size()):
        print("ADVENTURE FAMILY: ", ids[member])
        if member > 0:
            check(roster.select_member(member), "Select " + String(ids[member]))
        set_level(1)
        var family: StarterPartnerData = GameManager.catalog.starter_by_id(ids[member])
        check(family.forms.size() == (3 if member == 0 else 4), "Correct evolution line length")
        check(partner.current_form == family.forms[0], "Old base form ID still loads")
        for index: int in range(family.forms.size()):
            var form: MonsterData = family.forms[index]
            check(form.validation_error().is_empty(), "Valid form " + form.monster_name)
            var required: int = EvolutionRules.minimum_level_for_form_index(index, form)
            check(required == (1 if index == 0 else [1, 11, 25, 41][form.evolution_stage]), "Canonical stage level " + form.monster_name)
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

    # Tampered Tailmon save: ปรับเฉพาะ Tailmon เป็น Lv60 ต้องไม่กระทบตัวอื่น
    var saved: Dictionary = roster.get_save_data().duplicate(true)
    for index: int in range(saved["members"].size()):
        if str(saved["members"][index].get("id", "")) == "tailmon":
            saved["members"][index]["progress"] = {"level": 60, "exp": 0}
    roster.initialize(saved)
    if roster.active_index != 0:
        check(roster.select_member(0), "Switch back to Tailmon line")
    check(partner.current_form.monster_name == "Holydramon", "Restore keeps Tailmon Mega unlocked at Lv60")

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
        var hatch_progress: Dictionary = roster.storage[-1].get("progress", {}) as Dictionary
        check(int(hatch_progress.get("level", 0)) == 1 and int(hatch_progress.get("exp", -1)) == 0, "New hatch starts with independent Lv1 EXP0")
    # Migration v3 Shared Partner Level: สมาชิกที่ไม่มี progress จะรับค่า shared เดิมครั้งเดียว
    var legacy_saved: Dictionary = roster.get_save_data().duplicate(true)
    legacy_saved["version"] = 3
    legacy_saved["shared_progress"] = {"level": 22, "exp": 44}
    for index: int in range(legacy_saved["members"].size()):
        legacy_saved["members"][index].erase("progress")
    roster.initialize(legacy_saved)
    check(roster.member_level(StringName(str(roster.members[0].get("id", "")))) == 22, "Legacy shared save migrates without losing level")
    check(int(roster.members[0].get("progress", {}).get("exp", 0)) == 44, "Legacy shared EXP migrates into member progress")

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
