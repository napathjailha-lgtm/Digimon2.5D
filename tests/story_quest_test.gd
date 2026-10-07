extends Node
# รันเป็น Scene หลัง Autoload พร้อม เพื่อให้ทดสอบ dependency ของ QuestManager ได้ครบ
var root: Window:
    get: return get_tree().root
var current_scene: Node:
    get: return get_tree().current_scene
    set(value): get_tree().current_scene = value
var paused: bool:
    get: return get_tree().paused
    set(value): get_tree().paused = value
var process_frame: Signal:
    get: return get_tree().process_frame
var physics_frame: Signal:
    get: return get_tree().physics_frame

func create_timer(seconds: float, process_always: bool = true) -> SceneTreeTimer:
    return get_tree().create_timer(seconds, process_always)

func get_nodes_in_group(group: StringName) -> Array[Node]:
    return get_tree().get_nodes_in_group(group)

func get_processed_tweens() -> Array[Tween]:
    return get_tree().get_processed_tweens()

func quit(code: int = 0) -> void:
    get_tree().quit(code)
var quest_manager: Variant
## ทดสอบ Quest, touch navigation, gate, save และ story unlock ผ่าน Scene จริง
var failures: int = 0
var completed_signals: int = 0

func _ready() -> void:
    run.call_deferred()

func check(condition: bool, description: String) -> void:
    if condition:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func touch_tracker(tracker: QuestTracker) -> void:
    var shortcut: Control = tracker.get_parent().get_node("Safe/Layout/TopLeft/QuestShortcut")
    var event := InputEventScreenTouch.new()
    event.index = 5
    event.position = shortcut.get_global_transform_with_canvas() * (shortcut.size * 0.5)
    event.pressed = true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    event = InputEventScreenTouch.new()
    event.index = 5
    event.position = shortcut.get_global_transform_with_canvas() * (shortcut.size * 0.5)
    event.pressed = false
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func freeze_enemies() -> void:
    for monster: Node in get_nodes_in_group("wild_monsters"):
        monster.set_physics_process(false)

func current_tracker(world: Node) -> QuestTracker:
    return world.get_node("MobileHUD/Root/QuestTracker") as QuestTracker

func run() -> void:
    quest_manager = root.get_node("QuestManager")
    quest_manager.save_path = "user://story_quest_test.json"
    quest_manager.reset_progress(false)
    quest_manager.quest_completed.connect(func(_id: StringName) -> void: completed_signals += 1)
    check(quest_manager.get_current_quest().id == &"q01_agumon" and quest_manager.get_status(&"q03_devimon") == quest_manager.Status.LOCKED, "เริ่มเควสต์แรกและล็อกเควสต์ขั้นถัดไป")
    check(not quest_manager.report_event(StoryQuest.Objective.KILL, &"devimon"), "ฆ่าบอสก่อน Active ไม่นับข้ามเควสต์")
    var angemon: MonsterData = load("res://data/angemon_example.tres")
    var ultimate: MonsterData = load("res://data/ultimate.tres")
    check(not quest_manager.can_use_form(angemon) and not quest_manager.can_use_form(ultimate), "ล็อกเฉพาะ Angemon และระดับ Ultimate ตั้งแต่เริ่ม")

    # จำลองเควสต์หลาย count เพื่อทดสอบ partial save และ event ซ้ำ
    var first: StoryQuest = quest_manager.get_current_quest()
    first.required_count = 2
    check(quest_manager.report_event(StoryQuest.Objective.TALK, &"agumon", 1, "talk-1"), "รับความคืบหน้าที่ตรง Objective")
    check(not quest_manager.report_event(StoryQuest.Objective.TALK, &"agumon", 1, "talk-1") and quest_manager.get_progress(first.id) == 1, "event id ซ้ำไม่นับซ้ำ")
    quest_manager.reset_progress(false)
    check(quest_manager.load_progress() and quest_manager.get_progress(first.id) == 1, "บันทึกและโหลด partial progress")
    check(not quest_manager.report_event(StoryQuest.Objective.TALK, &"agumon", 1, "talk-1"), "โหลด Save แล้วยังจำ event ที่นับแล้ว")
    first.required_count = 1
    quest_manager.reset_progress(false)
    completed_signals = 0

    root.size = Vector2i(1280, 720)
    root.content_scale_size = Vector2i(1280, 720)
    var world: Node2D = load("res://scenes/world.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await process_frame
    await physics_frame
    await physics_frame
    freeze_enemies()
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var portal: StoryPortal = world.get_node("StoryPoints/NextPortal")
    var tracker: QuestTracker = current_tracker(world)
    check(not portal.can_enter() and not partner.load_monster_data(ultimate), "ประตูและ direct form load เคารพเงื่อนไขเนื้อเรื่อง")
    tamer.global_position = world.get_node("StoryPoints/NPC").global_position + Vector2(-90, 50)
    tamer.reset_physics_interpolation()
    touch_tracker(tracker)
    await process_frame
    check(tamer.is_auto_navigating(), "แตะ Tracker ผ่าน input pipeline เริ่ม Auto-Navigation")
    await create_timer(0.8).timeout
    check(quest_manager.is_completed(&"q01_agumon") and not tamer.is_auto_navigating(), "นำทางถึง NPC และจบบทสนทนาตัวอย่าง")
    check(completed_signals == 1 and tracker.title_label.text.contains("พลัดหลง"), "Signal สำเร็จครั้งเดียวและ Tracker แสดงเควสต์ถัดไป")

    # Joystick ต้องชนะคำสั่งเดินอัตโนมัติ
    tamer.start_auto_navigation(world.get_node("StoryPoints/ReachPoint/QuestTarget"))
    tamer.joystick.move_vector = Vector2.RIGHT
    await physics_frame
    await physics_frame
    check(not tamer.is_auto_navigating(), "Joystick ยกเลิก Auto-Navigation")
    tamer.joystick.move_vector = Vector2.ZERO
    tamer.global_position = world.get_node("StoryPoints/ReachPoint").global_position + Vector2(-90, 0)
    tamer.reset_physics_interpolation()
    touch_tracker(tracker)
    await create_timer(1.0).timeout
    check(quest_manager.is_completed(&"q02_friends"), "Reach Area นับเมื่อ Tamer เดินถึงจริง")

    var boss: WildMonster = (world.get_node("Spawners/BossSpawner") as MonsterSpawner).current_monster
    boss.take_damage(9999, partner)
    await process_frame
    check(quest_manager.is_completed(&"q03_devimon") and quest_manager.can_use_form(angemon) and portal.can_enter(), "ฆ่า Devimon ปลดล็อก Angemon และประตู Server")
    check(not quest_manager.can_use_form(ultimate), "Devimon ไม่ปลดล็อก Ultimate โดยผิดขั้น")
    var signals_before: int = completed_signals
    quest_manager.report_event(StoryQuest.Objective.KILL, &"devimon")
    check(completed_signals == signals_before, "บอสเดิมไม่แจก reward หรือ complete signal ซ้ำ")
    check(tracker._resolve_destination(quest_manager.get_current_quest()) == portal.get_node("QuestTarget"), "เป้าหมายคนละโซนเลือกประตูที่เปิดแล้ว")

    partner.digivolve()
    partner.hp = 120
    tamer.ds = 60.0
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.global_position = portal.global_position
    check(portal.try_enter(tamer), "ประตูยอมให้ผ่านเมื่อเควสต์หลักสำเร็จ")
    await process_frame
    await process_frame
    await physics_frame
    world = current_scene
    freeze_enemies()
    check(quest_manager.current_zone == &"server_continent" and quest_manager.get_current_quest().id == &"q04_gennai", "เปลี่ยน Scene แล้วยังเก็บ quest_manager และความคืบหน้า")
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    check(absf(tamer.ds - 60.0) < 1.0 and partner.form_index == 1 and partner.hp == 120, "DS/HP/ร่างคู่หูคงอยู่ระหว่างเปลี่ยนโซน")
    quest_manager.report_event(StoryQuest.Objective.TALK, &"gennai")
    boss = (world.get_node("Spawners/BossSpawner") as MonsterSpawner).current_monster
    boss.take_damage(9999, partner)
    await process_frame
    check(quest_manager.max_unlocked_stage == MonsterData.EvolutionStage.ULTIMATE and partner.max_story_stage == MonsterData.EvolutionStage.ULTIMATE, "Etemon ส่ง signal ปลดล็อก Ultimate ถึง Partner")
    check(partner.digivolve() and partner.form_index == 2, "หลังปลดล็อกสามารถ Digivolve Ultimate ได้จริง")
    quest_manager.save_progress()
    quest_manager.reset_progress(false)
    check(quest_manager.load_progress() and quest_manager.is_completed(&"q05_etemon") and quest_manager.can_use_form(ultimate), "โหลด Save คืนเควสต์และคำนวณ unlock ใหม่จากเควสต์ที่จบ")

    # เดินเรื่องอีกสองโซนเพื่อทดสอบประตูและบทสุดท้าย
    portal = world.get_node("StoryPoints/NextPortal")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.global_position = portal.global_position
    portal.try_enter(tamer)
    await process_frame
    await process_frame
    await physics_frame
    world = current_scene
    freeze_enemies()
    check(quest_manager.current_zone == &"odaiba", "วาร์ปไป Odaiba หลังเคลียร์ Server")
    quest_manager.report_event(StoryQuest.Objective.REACH, &"odaiba_clue")
    partner = world.get_node("Actors/Partner")
    boss = (world.get_node("Spawners/BossSpawner") as MonsterSpawner).current_monster
    boss.take_damage(9999, partner)
    await process_frame
    check(quest_manager.max_unlocked_stage == MonsterData.EvolutionStage.MEGA and quest_manager.is_zone_unlocked(&"spiral_mountain"), "จบ Odaiba เปิด Mega และ Spiral Mountain")
    tamer = world.get_node("Actors/Tamer")
    portal = world.get_node("StoryPoints/NextPortal")
    tamer.set_physics_process(false)
    tamer.global_position = portal.global_position
    portal.try_enter(tamer)
    await process_frame
    await process_frame
    await physics_frame
    world = current_scene
    freeze_enemies()
    partner = world.get_node("Actors/Partner")
    boss = (world.get_node("Spawners/BossSpawner") as MonsterSpawner).current_monster
    boss.take_damage(9999, partner)
    await process_frame
    check(quest_manager.has_flag(&"adventure_complete"), "จบเนื้อเรื่องหลักเดิมและรับ flag adventure_complete")
    check(quest_manager.catalog.quests.size() == 32, "Catalog มีเควสต์เดิม 12 + Frontier Operations ใหม่ 20 เควสต์")
    check(quest_manager.get_current_quest() != null and quest_manager.get_current_quest().id == &"q09_mira_briefing", "หลัง Piedmon มี Frontier Operations ต่อทันที")
    world.queue_free()
    await process_frame
    quest_manager.reset_progress(false)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(quest_manager.save_path))
    print("RESULT: ", failures, " failure(s)")
    quit(1 if failures > 0 else 0)
