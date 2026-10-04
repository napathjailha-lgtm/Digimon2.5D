extends Node
## F6: พรีวิวเดินจริงผ่านหมู่บ้าน ทุ่ง สะพาน ป่า และหมู่บ้านยามเย็น
## เปลี่ยนตำแหน่งเฉพาะตัดบทพรีวิว ไม่ใช้ teleport ในเกมหลัก
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var caption: Label
var marker: Marker2D
var running: bool = false
var elapsed: float = 0.0
var chapter: int = -1
var capture_tick: int = 0
var capture_directory: String = ""

func _ready() -> void:
    run.call_deferred()

func run() -> void:
    QuestManager.save_path = "user://openworld_preview_v14.json"
    QuestManager.reset_progress(false)
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-world="):
            capture_directory = argument.trim_prefix("--capture-world=")
            DirAccess.make_dir_recursive_absolute(capture_directory)
    world = preload("res://scenes/world.tscn").instantiate()
    add_child(world)
    marker = Marker2D.new()
    world.add_child(marker)
    var layer := CanvasLayer.new()
    layer.layer = 12
    add_child(layer)
    caption = Label.new()
    caption.position = Vector2(385, 134)
    caption.size = Vector2(510, 36)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_override("font", preload("res://assets/fonts/NotoSansThai.ttf"))
    caption.add_theme_font_size_override("font_size", 22)
    caption.add_theme_color_override("font_outline_color", Color("122533"))
    caption.add_theme_constant_override("outline_size", 5)
    layer.add_child(caption)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    running = true

func _physics_process(delta: float) -> void:
    if not running:
        return
    elapsed += delta
    var next: int = int(elapsed / 5.0) % 5
    if next != chapter:
        chapter = next
        var starts: Array[Vector2] = [Vector2(850, 980), Vector2(1630, 1020), Vector2(2590, 1000), Vector2(3500, 1000), Vector2(850, 1080)]
        var goals: Array[Vector2] = [Vector2(1450, 950), Vector2(2390, 1010), Vector2(3340, 1000), Vector2(4180, 730), Vector2(1090, 900)]
        var captions: Array[String] = ["หมู่บ้าน • แผนที่ต่อเนื่อง 5,120 × 3,200", "ออกสำรวจทุ่ง • กล้องตามตัวละคร", "ข้ามแม่น้ำ • สะพานและเส้นทางจริง", "ป่าตะวันออก • เงาต้นไม้บนพื้น", "หมู่บ้านช่วงเย็น • แสงโคมและเงา"]
        tamer.cancel_auto_navigation()
        partner.cancel_battle()
        tamer.global_position = starts[next]
        tamer.velocity = Vector2.ZERO
        partner.global_position = starts[next] - Vector2(76, 0)
        partner.velocity = Vector2.ZERO
        tamer.reset_physics_interpolation()
        partner.reset_physics_interpolation()
        var camera: Camera2D = tamer.get_node("Camera2D")
        camera.reset_smoothing()
        camera.force_update_scroll()
        marker.global_position = goals[next]
        tamer.start_auto_navigation(marker)
        caption.text = captions[next]
        var lighting: WorldLighting = (world.get_node("OpenWorldEnvironment") as OpenWorldEnvironment).lighting
        lighting.dusk = next == 4
        lighting.apply_time_of_day()
        (world.get_node("MobileHUD/Root/TimeOfDay") as ClassicCommand).set_caption("แสง: ช่วงเย็น" if lighting.dusk else "แสง: กลางวัน")

func _process(_delta: float) -> void:
    if not running or capture_directory.is_empty():
        return
    capture_tick += 1
    if capture_tick % 3 == 0:
        _capture_frame.call_deferred(int(capture_tick / 3))
    if capture_tick >= 1497:
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
