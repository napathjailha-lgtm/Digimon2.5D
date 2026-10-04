extends Node
## F6 ดูการเดินจริงใน World: สั่ง Joystick วนสี่เหลี่ยมแล้วหยุด
## ใช้ไฟล์ Save แยกเพื่อไม่ทับความคืบหน้าของผู้เล่น
var world: Node2D
var tamer: Tamer
var elapsed: float = 0.0
var running: bool = false
var capture_tick: int = 0
var capture_directory: String = ""

func _ready() -> void:
    run.call_deferred()

func run() -> void:
    QuestManager.save_path = "user://movement_preview_v12.json"
    QuestManager.reset_progress(false)
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-movement="):
            capture_directory = argument.trim_prefix("--capture-movement=")
            DirAccess.make_dir_recursive_absolute(capture_directory)
    world = preload("res://scenes/world.tscn").instantiate()
    add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    tamer.global_position = Vector2(450, 360)
    partner.global_position = Vector2(370, 360)
    tamer.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    running = true

func _physics_process(delta: float) -> void:
    if not running:
        return
    elapsed += delta
    var cycle: float = fposmod(elapsed, 4.3)
    if cycle < 1.2:
        tamer.joystick.move_vector = Vector2.RIGHT
    elif cycle < 1.85:
        tamer.joystick.move_vector = Vector2.DOWN
    elif cycle < 3.05:
        tamer.joystick.move_vector = Vector2.LEFT
    elif cycle < 3.7:
        tamer.joystick.move_vector = Vector2.UP
    else:
        tamer.joystick.move_vector = Vector2.ZERO

func _process(_delta: float) -> void:
    if running and not capture_directory.is_empty():
        capture_tick += 1
        if capture_tick % 3 == 0:
            _capture_frame.call_deferred(int(capture_tick / 3))
        if capture_tick >= 258:
            running = false
            _finish_capture.call_deferred()

func _capture_frame(index: int) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(capture_directory.path_join("frame_%03d.png" % index))

func _finish_capture() -> void:
    await RenderingServer.frame_post_draw
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    get_tree().quit()
