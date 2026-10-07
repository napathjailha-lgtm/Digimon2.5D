extends Node

var failures: int = 0
var assertions: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func run() -> void:
    QuestManager.save_path = "user://frontier_quests_test.json"
    QuestManager.reset_progress(false)

    check(QuestManager.catalog.quests.size() == 32, "Quest catalog contains 12 existing + 20 Frontier quests")
    var expected_ids: Array[StringName] = [
        &"q09_mira_briefing", &"q10_crimson_sweep", &"q11_nami_tide_report", &"q12_tidecoil_patrol",
        &"q13_rook_storm_watch", &"q14_thunder_lynx_hunt", &"q15_bramm_forge_call", &"q16_magma_ram_control",
        &"q17_torque_shell_scan", &"q18_iron_shell_break", &"q19_liora_green_archive", &"q20_verdant_wall",
        &"q21_cyra_twilight", &"q22_nighttalon_intercept", &"q23_sena_void_research", &"q24_void_sentinel_suppression",
        &"q25_orion_last_signal", &"q26_void_aftershock", &"q27_pax_frontier_oath", &"q28_frontier_final_trial"
    ]

    for i: int in range(12):
        QuestManager._completed.append(QuestManager.catalog.quests[i].id)
    QuestManager._rebuild_unlocks()
    QuestManager.current_zone = &"file_island"

    check(QuestManager.get_current_quest().id == expected_ids[0], "Existing completed save continues directly into q09")

    for expected_id: StringName in expected_ids:
        var quest: StoryQuest = QuestManager.get_current_quest()
        check(quest != null and quest.id == expected_id, "Frontier chain active: " + String(expected_id))
        if quest == null:
            break
        for amount_index: int in range(quest.required_count):
            var event_id: String = "%s-%d" % [String(quest.id), amount_index]
            var accepted: bool = QuestManager.report_event(quest.objective, quest.target_id, 1, event_id)
            check(accepted, "Progress accepted: %s %d/%d" % [String(quest.id), amount_index + 1, quest.required_count])

    check(QuestManager.get_current_quest() == null, "All 20 Frontier quests can complete in sequence")
    check(QuestManager.has_flag(&"frontier_operations_complete"), "Final Frontier completion flag granted")

    QuestManager.reset_progress(false)
    var world := load("res://scenes/world.tscn").instantiate() as Node2D
    get_tree().root.add_child(world)
    for frame: int in range(6):
        await get_tree().physics_frame

    var npc_ids: Dictionary = {}
    for node: Node in world.get_node("StoryPoints").get_children():
        if node is FieldQuestNPC:
            var npc := node as FieldQuestNPC
            npc_ids[npc.npc_id] = true

    var expected_npcs: Array[StringName] = [
        &"frontier_mira", &"frontier_nami", &"frontier_rook", &"frontier_bramm", &"frontier_torque",
        &"frontier_liora", &"frontier_cyra", &"frontier_sena", &"frontier_orion", &"frontier_pax"
    ]
    var all_npcs: bool = npc_ids.size() == expected_npcs.size()
    for npc_id: StringName in expected_npcs:
        all_npcs = all_npcs and npc_ids.has(npc_id)
    check(all_npcs, "World spawns all 10 Frontier NPCs")

    var target_ids: Dictionary = {}
    for node: Node in get_tree().get_nodes_in_group("quest_targets"):
        var target := node as QuestTarget
        if target != null:
            target_ids[target.target_id] = true
    var expected_targets: Array[StringName] = [
        &"crimson_byte", &"tidecoil_manta", &"thunder_lynx", &"magma_ram",
        &"iron_shell_crab", &"verdant_bulwark", &"nighttalon_harrier", &"void_sentinel"
    ]
    var all_targets: bool = true
    for target_id: StringName in expected_targets:
        all_targets = all_targets and target_ids.has(target_id)
    check(all_targets, "Quest Tracker targets exist for all Frontier hunt monsters")

    world.queue_free()
    await get_tree().process_frame
    QuestManager.reset_progress(false)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("FRONTIER_QUEST_TEST assertions=%d failures=%d" % [assertions, failures])
    get_tree().quit(0 if failures == 0 else 1)
