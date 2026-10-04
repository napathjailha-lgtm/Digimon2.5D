extends Node
## F6: ฉาก 2.5D ที่ใช้ World/Actor/แสง/กล้องจริง; ไม่ใช้เซฟผู้เล่น
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var hud: MobileHUD
var camera: PartyDepthCamera
var lighting: WorldLighting
var _capture_dir: String = ""
var _frames_dir: String = ""
var _warnings: Array[GroundSkillIndicator] = []

func _ready() -> void:
    # Controller ยังปิดฉากได้ขณะ modal pause แต่โลกยังหยุดตามกติกาเดิม
    process_mode = Node.PROCESS_MODE_ALWAYS
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-depth="):
            _capture_dir = argument.trim_prefix("--capture-depth=")
            DirAccess.make_dir_recursive_absolute(_capture_dir)
        if argument.begins_with("--depth-frames="):
            _frames_dir = argument.trim_prefix("--depth-frames=")
            DirAccess.make_dir_recursive_absolute(_frames_dir)
    run.call_deferred()

func run() -> void:
    # ใช้ชื่อ save สาธิตใหม่ ไม่เขียนทับ slot หลักของผู้เล่น
    GameManager.gameplay_active = false
    QuestManager.save_path = "user://depth_preview_v21.json"
    QuestManager.reset_progress(false)
    world = preload("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    hud = world.get_node("MobileHUD")
    camera = tamer.get_node("Camera2D")
    lighting = world.get_node("OpenWorldEnvironment/Lighting")
    hud.preferences.save_path = "user://depth_preview_v21.cfg"
    hud.preferences.animations_enabled = true
    hud.preferences.low_effects = false
    hud.preferences.minimap_visible = false
    hud.chat_panel.set_collapsed(true)
    hud._layout()
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    _village()
    if not _capture_dir.is_empty():
        await _capture()
    elif not _frames_dir.is_empty():
        await _capture_motion()
    else:
        _build_buttons()

func _warp(point: Vector2) -> void:
    # Warp คืน interpolation ทั้งตัวละครและกล้อง ไม่เลื่อนจากจุดเก่าไปจุดใหม่
    tamer.joystick.release_input()
    tamer.cancel_auto_navigation()
    tamer.global_position = point
    partner.global_position = point + Vector2(-105, 6)
    tamer.velocity = Vector2.ZERO
    partner.velocity = Vector2.ZERO
    tamer.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    camera.snap_to_party()

func _village() -> void:
    _clear_warnings()
    lighting.dusk = false
    lighting.apply_time_of_day()
    _warp(Vector2(1020, 1130))

func _north() -> void:
    _clear_warnings()
    lighting.dusk = false
    lighting.apply_time_of_day()
    _warp(Vector2(1800, 165))

func _rings() -> void:
    # วงตัวอย่างไม่มีดาเมจ ใช้ดูความเอียง/การเติมระหว่างเคลื่อนไหว
    _clear_warnings()
    _warp(Vector2(930, 1000))
    for pair: Array in [[Vector2(840, 1130), 85.0, Color("50e2ee")],
            [Vector2(1050, 1000), 95.0, Color("ff695f")]]:
        var ring := GroundSkillIndicator.new()
        ring.position = pair[0]
        ring.radius = pair[1]
        ring.tint = pair[2]
        ring.fill_alpha = 0.12
        world.add_child(ring)
        ring.start_warning(6.0)
        _warnings.append(ring)
    var enemy: WildMonster = world.get_node("Spawners/SpawnerA").current_monster
    enemy.global_position = Vector2(900, 1080)
    enemy.velocity = Vector2.ZERO
    enemy.reset_physics_interpolation()
    tamer.set_target(enemy)
    var boss: WildMonster = world.get_node("Spawners/BossSpawner").current_monster
    boss.global_position = Vector2(1050, 1000)
    boss.velocity = Vector2.ZERO
    boss.reset_physics_interpolation()

func _clear_warnings() -> void:
    for ring: GroundSkillIndicator in _warnings:
        if is_instance_valid(ring):
            ring.queue_free()
    _warnings.clear()
    tamer.set_target(null)
    # คืนศัตรูไปจุดเกิดเมื่อออกจากโหมดวงสาธิต ไม่ทิ้งบอสไว้กลางหมู่บ้าน
    for spawner_name: String in ["SpawnerA", "BossSpawner"]:
        var spawner: MonsterSpawner = world.get_node("Spawners/" + spawner_name)
        if is_instance_valid(spawner.current_monster):
            spawner.current_monster.global_position = spawner.global_position
            spawner.current_monster.reset_physics_interpolation()

func _build_buttons() -> void:
    # เมนูสาธิตแยกจาก HUD เกมจริง เปลี่ยนมุมแดด/คุณภาพได้ทันที
    var layer := CanvasLayer.new()
    layer.layer = 15
    add_child(layer)
    var row := HBoxContainer.new()
    row.position = Vector2(398, 18)
    row.theme = hud.get_node("Root").theme
    layer.add_child(row)
    var actions: Array[Callable] = [_village, _north, _rings,
        lighting.toggle_time_of_day, _turn_sun, _toggle_quality]
    var captions: Array[String] = ["หมู่บ้าน", "วิวเกาะ", "วงสกิล", "เช้า/เย็น", "มุมแสง", "Low FX"]
    for i: int in range(captions.size()):
        var button := EquipmentButton.new()
        button.caption = captions[i]
        button.custom_minimum_size = Vector2(96, 52)
        row.add_child(button)
        button.pressed.connect(actions[i])

func _turn_sun() -> void:
    lighting.set_sun_direction(lighting.sun_direction_degrees + 55.0)

func _toggle_quality() -> void:
    GameVisualSettings.low_effects = not GameVisualSettings.low_effects
    lighting.refresh_quality()

func _freeze() -> void:
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)

func _shot(file_name: String) -> void:
    # อ่านภาพหลัง render เสร็จ เพื่อเห็น shadow pass และ parallax ของจริง
    await get_tree().create_timer(0.5).timeout
    await RenderingServer.frame_post_draw
    var path: String = _capture_dir.path_join(file_name + ".png")
    print("CAPTURE ", path, " error=", get_viewport().get_texture().get_image().save_png(path))

func _capture() -> void:
    _freeze()
    await _shot("Pseudo3D_v21_Village")
    _rings()
    await _shot("Pseudo3D_v21_GroundSkills")
    _clear_warnings()
    _warp(Vector2(1020, 1130))
    lighting.toggle_time_of_day()
    await _shot("Pseudo3D_v21_Dusk")
    _north()
    await _shot("Pseudo3D_v21_Parallax")
    await _cleanup()

func _capture_motion() -> void:
    # 5 วินาที @24fps: เคลื่อนจริงให้กล้อง/เงาติดตาม และเปลี่ยนมุมแดดระหว่างเดิน
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    _rings()
    for frame: int in range(120):
        match frame:
            6: tamer.joystick.move_vector = Vector2(0.8, -0.08)
            64: lighting.toggle_time_of_day()
            100: tamer.joystick.release_input()
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(_frames_dir.path_join("frame_%04d.png" % frame))
    await _cleanup()

func _cleanup() -> void:
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    get_tree().quit()
