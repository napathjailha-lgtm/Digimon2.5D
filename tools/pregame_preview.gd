extends Node
## F6: สาธิต Flow จริงด้วยบัญชี/เซฟพรีวิวแยก เก็บภาพ UI Native จาก Godot
var directory: String = ""
var phase: int = 0
var elapsed: float = 0.0
var tick: int = 0
var running: bool = false
var _snapshots: Dictionary = {}
var _acted: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func run() -> void:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-pregame="):
            directory = argument.trim_prefix("--capture-pregame=")
            DirAccess.make_dir_recursive_absolute(directory)
    get_tree().current_scene = null
    GameManager.profile_root = "user://pregame_preview_v16"
    GameManager.logout()
    # บัญชีสาธิตมีชื่อใหม่ต่อการรัน ป้องกันการสร้างไปลง slot เก่าของพรีวิวก่อนหน้า
    GameManager.loading_target = GameManager.LOGIN_SCENE
    get_tree().change_scene_to_file(GameManager.LOADING_SCENE)
    running = true

func tap(control: Control) -> void:
    # กดผ่าน pipeline Touch → Mouse ของเมนู แทนการวาดภาพปุ่มเลือกไว้เอง
    var position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = 0
        event.position = position
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func _process(delta: float) -> void:
    if not running:
        return
    tick += 1
    elapsed += delta
    var scene: Node = get_tree().current_scene
    if scene != null:
        var path: String = scene.get_script().resource_path
        if phase == 0 and path.ends_with("loading_screen.gd") and not _snapshots.has("Loading_v16") and elapsed > 0.15:
            _snapshot("Loading_v16")
        if phase <= 1 and path.ends_with("login_screen.gd"):
            if phase == 0:
                phase = 1
                elapsed = 0
                scene.username_input.text = "Demo" + str(Time.get_ticks_msec())
                scene.password_input.text = "demo"
            if elapsed > 0.4 and not _snapshots.has("Login_v16"):
                _snapshot("Login_v16")
            if elapsed > 2.3 and not _acted.has("login"):
                _acted["login"] = true
                tap(scene.login_button)
        elif phase <= 2 and path.ends_with("character_selection.gd"):
            if phase == 1:
                phase = 2
                elapsed = 0
                tap(scene.model_buttons[2])
                scene.name_input.text = "SkyTamer"
            if elapsed > 0.4 and not _snapshots.has("Tamer_Selection_v16"):
                _snapshot("Tamer_Selection_v16")
            if elapsed > 2.5 and not _acted.has("create"):
                _acted["create"] = true
                tap(scene.action_button)
        elif phase <= 3 and path.ends_with("starter_selection.gd"):
            if phase == 2:
                phase = 3
                elapsed = 0
                tap(scene.card_buttons[0])
            if elapsed > 0.4 and not _snapshots.has("Starter_Selection_v16"):
                _snapshot("Starter_Selection_v16")
            if elapsed > 2.2 and not _acted.has("change_starter"):
                _acted["change_starter"] = true
                tap(scene.card_buttons[1])
            if elapsed > 4.1 and not _acted.has("confirm"):
                _acted["confirm"] = true
                tap(scene.confirm_button)
        elif scene.has_node("Actors/Tamer"):
            if phase < 4:
                phase = 4
                elapsed = 0
                var player: Tamer = scene.get_node("Actors/Tamer")
                player.start_auto_navigation(scene.get_node("StoryPoints/NPC/QuestTarget")) if scene.has_node("StoryPoints/NPC/QuestTarget") else player.cancel_auto_navigation()
            if elapsed > 0.6 and not _snapshots.has("Gameplay_v16"):
                _snapshot("Gameplay_v16")
            if elapsed > 2.5 and not directory.is_empty():
                running = false
                _finish.call_deferred()
    if not directory.is_empty() and tick % 3 == 0:
        _frame.call_deferred(tick / 3)
    if not directory.is_empty() and tick > 1800:
        push_error("Pregame preview timeout")
        get_tree().quit(1)

func _snapshot(name_text: String) -> void:
    _snapshots[name_text] = true
    if not directory.is_empty():
        _save_snapshot.call_deferred(name_text)

func _save_snapshot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join(name_text + ".png"))

func _frame(index: int) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join("frame_%04d.png" % index))

func _finish() -> void:
    await RenderingServer.frame_post_draw
    get_tree().quit()
