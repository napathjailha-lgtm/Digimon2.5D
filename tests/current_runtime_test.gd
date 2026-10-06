extends Node
## Boot without input, real touch menu actions, and the repaired Fusion resource.
var failures: int = 0
var assertions: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + message)

func tap(control: Control) -> void:
    var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = 3
        event.position = point
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func run() -> void:
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    QuestManager.save_path = "user://current_runtime_test.json"
    QuestManager.reset_progress(false)
    GameManager.logout()
    get_tree().change_scene_to_file("res://scenes/splash_screen.tscn")
    var deadline: int = Time.get_ticks_msec() + 15000
    while Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
        var current: Node = get_tree().current_scene
        if current != null and current.scene_file_path == GameManager.LOGIN_SCENE:
            break
    check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == GameManager.LOGIN_SCENE,
        "Splash reaches Login automatically without click or key")
    await get_tree().create_timer(1.0, true).timeout
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    get_tree().change_scene_to_file("res://tests/fixtures/arena_v13.tscn")
    await get_tree().scene_changed
    for frame: int in range(4):
        await get_tree().physics_frame
    var world: Node = get_tree().current_scene
    var player: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = player.partner
    var hud: MobileHUD = world.get_node("MobileHUD")
    player.set_physics_process(false)
    partner.set_physics_process(false)
    player.survival.set_process(false)
    player.survival.autosave_enabled = false
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    hud.menu.animations_enabled = false
    tap(hud.menu.more_button)
    check(hud.menu.expanded and hud.menu.drawer.visible, "More opens with touch")
    var outside := InputEventScreenTouch.new()
    outside.position = Vector2(5, 5)
    outside.pressed = true
    hud.menu._unhandled_input(outside)
    check(not hud.menu.expanded and not hud.menu.drawer.visible, "Outside touch closes More without type errors")
    tap(hud.stats_button)
    check(hud.digimon_screen.is_open and get_tree().paused, "Status opens and pauses gameplay")
    hud.digimon_screen.close_screen()
    check(not get_tree().paused, "Closing Status restores gameplay")
    var fusion: MonsterData = hud.fusion_manager._build_fusion_form()
    check(fusion != null and fusion.validation_error().is_empty(), "Fusion art and animation data load")
    if fusion != null:
        check(fusion.sprite_frames.get_frame_count(&"attack") == 4, "Fusion retains attack impact frames")
        check(fusion.skills.size() == 2, "Fusion retains both skills")
    world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("CURRENT RUNTIME RESULT: %d failures / %d assertions" % [failures, assertions])
    get_tree().quit(1 if failures else 0)
