extends Node
## F6 ดูหน้าจอจริงของ v25; ใช้เซฟทดสอบแยกจากผู้เล่น
var world: Node
var directory: String
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()
func capture(file: String) -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join(file))
func run() -> void:
    directory = ProjectSettings.globalize_path("res://preview/single_world")
    DirAccess.make_dir_recursive_absolute(directory)
    QuestManager.save_path = "user://single_world_preview_only.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    GameManager.tamer_name = "Taichi"
    world = load("res://scenes/world.tscn").instantiate()
    add_child(world)
    for i: int in range(5):
        await get_tree().physics_frame
    var hud: MobileHUD = world.get_node("MobileHUD")
    var player: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = player.partner
    player.survival.set_process(false)
    player.survival.autosave_enabled = false
    hud.chat_panel.set_collapsed(true)
    player.set_physics_process(false)
    partner.set_physics_process(false)
    player.position = Vector2(1600, 1500)
    partner.position = Vector2(1520, 1470)
    player.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    var camera: Camera2D = player.get_node("Camera2D")
    camera.snap_to_party()
    await get_tree().create_timer(1.0).timeout
    await capture("SingleWorld_v25_Field.png")
    partner.load_monster_data(partner.forms[1])
    hud._toggle_stats()
    await get_tree().create_timer(0.5, true).timeout
    await capture("SingleWorld_v25_Digimon.png")
    hud.digimon_screen.close_screen()
    hud.hide()
    camera.set_physics_process(false)
    camera.set_process(false)
    camera.top_level = true
    camera.position = Vector2(5120, 3200)
    camera.limit_left = -100000
    camera.limit_top = -100000
    camera.limit_right = 100000
    camera.limit_bottom = 100000
    world.get_node("OpenWorldEnvironment/DepthLayers").hide()
    camera.zoom = Vector2(0.105, 0.105)
    camera.force_update_scroll()
    await get_tree().create_timer(0.2).timeout
    await capture("SingleWorld_v25_Map.png")
    world.queue_free()
    await get_tree().process_frame
    get_tree().quit()
