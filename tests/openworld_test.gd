extends Node
## ทดสอบฉากโลกกว้างจริงเพิ่มเติมจาก fixture ระบบต่อสู้เดิม
var failures: int = 0
var assertions: int = 0

func _ready() -> void:
    run.call_deferred()

func check(condition: bool, description: String) -> void:
    assertions += 1
    if condition:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func run() -> void:
    QuestManager.save_path = "user://openworld_test_v14.json"
    QuestManager.reset_progress(false)
    var world: Node2D = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    get_tree().current_scene = world
    for i: int in range(4):
        await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var environment: OpenWorldEnvironment = world.get_node("OpenWorldEnvironment")
    var hud: MobileHUD = world.get_node("MobileHUD")
    var layout: OpenWorldLayout = environment.layout
    var camera: Camera2D = tamer.get_node("Camera2D")
    check(world.get("world_extent") == Vector2(10240, 6400) and camera.limit_right == 10240 and camera.limit_bottom == 6400, "โลกและขอบกล้องใช้ขนาด 10240x6400")
    check(environment.navigation_ready, "Bake navigation จากสิ่งกีดขวางได้จริง")
    check(environment.props.size() > 150 and environment.shadows.get_child_count() > 100, "พร็อพแยกจากพื้นพร้อมเงาตามรูปร่าง")
    check(hud.minimap.world_extent == layout.extent and hud.minimap._point(layout.extent * 0.5).is_equal_approx((hud.minimap as RoundMinimap)._center()), "มินิแมปอ่านขอบโลกใหม่")
    check(hud.minimap.world_layout == layout, "มินิแมปใช้ผังถนนและสะพานเดียวกับสนาม")
    check(not environment.can_spawn_at(layout.village_center), "ไม่มีมอนสเตอร์เกิดในหมู่บ้าน")
    check(not environment.can_spawn_at(Vector2(layout.river_x, 1700)), "ไม่มีมอนสเตอร์เกิดกลางแม่น้ำ")
    var frontier_npcs: int = 0
    for node: Node in world.get_node("StoryPoints").get_children():
        if node is FieldQuestNPC:
            frontier_npcs += 1
    check(frontier_npcs == 10, "Frontier Operations สร้าง NPC ภาคสนามใหม่ครบ 10 คน")
    var quest_target_ids: Dictionary = {}
    for node: Node in get_tree().get_nodes_in_group("quest_targets"):
        var target := node as QuestTarget
        if target != null:
            quest_target_ids[target.target_id] = true
    var frontier_targets: Array[StringName] = [
        &"frontier_mira", &"frontier_nami", &"frontier_rook", &"frontier_bramm",
        &"frontier_torque", &"frontier_liora", &"frontier_cyra", &"frontier_sena",
        &"frontier_orion", &"frontier_pax", &"crimson_byte", &"tidecoil_manta",
        &"thunder_lynx", &"magma_ram", &"iron_shell_crab", &"verdant_bulwark",
        &"nighttalon_harrier", &"void_sentinel"
    ]
    var all_frontier_targets: bool = true
    for target_id: StringName in frontier_targets:
        all_frontier_targets = all_frontier_targets and quest_target_ids.has(target_id)
    check(all_frontier_targets, "NPC และมอนสเตอร์ของ Frontier Operations มี QuestTarget สำหรับ Tracker ครบ")
    var spawns_safe: bool = true
    var spawned: int = 0
    for node: Node in world.get_node("Spawners").get_children():
        var spawner := node as MonsterSpawner
        if spawner == null:
            continue
        spawned += 1
        if not environment.can_spawn_at(spawner.global_position) or (is_instance_valid(spawner.current_monster) and not environment.can_spawn_at(spawner.current_monster.global_position)):
            spawns_safe = false
    check(spawned == 244 and spawns_safe, "244 จุดเกิดวางศัตรูในพื้นที่ปลอดสิ่งกีดขวาง")
    var map: RID = tamer.navigation_agent.get_navigation_map()
    # map sync อาจเสร็จช้ากว่า 4 เฟรมเมื่อรันทดสอบหลายโปรเซสพร้อมกัน
    # ใช้เงื่อนไขเดียวกับ AI จริง แทนสมมติว่ารอจำนวนเฟรมคงที่แล้วจะพร้อม
    for i: int in range(120):
        if NavigationServer2D.map_get_iteration_id(map) > 0:
            break
        await get_tree().physics_frame
    var path: PackedVector2Array = NavigationServer2D.map_get_path(map, Vector2(2650, 1800), Vector2(3230, 1800), true)
    print("RIVER PATH: ", path)
    var via_bridge: bool = false
    for point: Vector2 in path:
        if absf(point.y - 2250) < 120.0 or absf(point.y - 1000) < 120.0:
            via_bridge = true
    check(path.size() > 2 and via_bridge, "เส้นทางข้ามแม่น้ำอ้อมผ่านสะพาน")
    for node: Node in get_tree().get_nodes_in_group("wild_monsters"):
        node.set_physics_process(false)
    # ทดสอบเดินระยะไกลจากหมู่บ้านไปจุดเควสต์ ไม่ใช้ teleport แทนการเดิน
    QuestManager.report_event(StoryQuest.Objective.TALK, &"agumon")
    tamer.start_auto_navigation(world.get_node("StoryPoints/ReachPoint/QuestTarget"))
    for i: int in range(1000):
        await get_tree().physics_frame
        if not tamer.is_auto_navigating():
            break
    check(QuestManager.is_completed(&"q02_friends"), "Auto-Navigation จากหมู่บ้านไปเควสต์ระยะไกลผ่านฉากจริง")
    check(partner.global_position.distance_to(tamer.global_position) < 125, "คู่หูไม่หลุดระหว่างเดินเควสต์ระยะไกล")
    # ทดสอบกำแพงน้ำด้วยการบังคับเดินเอง ไม่ใช่ทดสอบ path อย่างเดียว
    tamer.global_position = Vector2(2740, 1700)
    tamer.velocity = Vector2.ZERO
    tamer.joystick.move_vector = Vector2.RIGHT
    for i: int in range(90):
        await get_tree().physics_frame
    check(tamer.global_position.x < layout.river_x - layout.river_width * 0.5, "เดินเองชนริมฝั่ง ไม่เดินทะลุแม่น้ำ")
    tamer.joystick.release_input()
    tamer.global_position = Vector2(2630, 1000)
    tamer.velocity = Vector2.ZERO
    partner.global_position = Vector2(2550, 1000)
    tamer.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    var goal := Marker2D.new()
    goal.position = Vector2(3220, 1000)
    world.add_child(goal)
    tamer.start_auto_navigation(goal)
    for i: int in range(330):
        await get_tree().physics_frame
    check(tamer.global_position.x > 3100 and not tamer.is_auto_navigating(), "Tamer เดินข้ามสะพานจริงและจบ Auto-Navigation")
    check(partner.global_position.x > 3000 and partner.global_position.distance_to(tamer.global_position) < 120, "คู่หูตามผ่านสะพานจริง")
    check(camera.get_screen_center_position().x > 2900, "กล้องเลื่อนตามตัวละครออกจากหน้าจอเริ่มต้น")
    # ทดสอบการเลือกเป้าหมายหลังกล้องเลื่อน ไม่ใช้ world position แทน screen position
    var enemy: WildMonster = (world.get_node("Spawners/SpawnerA") as MonsterSpawner).current_monster
    enemy.global_position = tamer.global_position + Vector2(120, -10)
    enemy.reset_physics_interpolation()
    await get_tree().process_frame
    tamer.select_at_screen(get_viewport().get_canvas_transform() * enemy.global_position)
    check(tamer.get_target() == enemy, "Touch Target ใช้ canvas transform ของกล้องที่เลื่อนแล้ว")
    var old_frames: SpriteFrames = partner.sprite.sprite_frames
    check(partner.digivolve() and partner.current_form.id == &"champion" and partner.sprite.sprite_frames != old_frames, "Digivolve และชุดสกิลเดิมยังทำงานในโลกกว้าง")
    var lighting: WorldLighting = environment.lighting
    var day: Color = lighting.ambient.color
    lighting.toggle_time_of_day()
    check(lighting.dusk and lighting.ambient.color != day and lighting.lamps.size() == 15, "สลับบรรยากาศช่วงเย็นและมีไฟโคมจริง")
    var shadow_lights: int = 0
    for lamp: PointLight2D in lighting.lamps:
        shadow_lights += int(lamp.shadow_enabled)
    check(shadow_lights <= 2, "จำกัดไฟ shadow PCF5 ไว้ 2 ดวง")
    check(hud.layer > 0 and hud.get_node("Root").modulate == Color.WHITE, "HUD อยู่ CanvasLayer แยกจากแสงโลก")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.global_position = Vector2(10000, 6240)
    camera.force_update_scroll()
    check(camera.get_screen_center_position().x <= 10240 - 600 and camera.get_screen_center_position().y <= 6400 - 300, "กล้องหยุดที่ขอบโลก ไม่เปิดเผยนอกแผนที่")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("ASSERTIONS: ", assertions)
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
