extends Node
## F6: เปิดหน้าต่างจากเกมจริง ใช้เซฟพรีวิวแยก ผู้เล่นแตะใส่/ถอดได้เอง
var world: Node2D
var tamer: Tamer
var ui: EquipmentScreen
var tick: int = 0
var capture_directory: String = ""
var running: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func run() -> void:
    QuestManager.save_path = "user://equipment_preview_v15.json"
    QuestManager.reset_progress(false)
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-equipment="):
            capture_directory = argument.trim_prefix("--capture-equipment=")
            DirAccess.make_dir_recursive_absolute(capture_directory)
    world = preload("res://scenes/world.tscn").instantiate()
    world.process_mode = Node.PROCESS_MODE_PAUSABLE
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    ui = (world.get_node("MobileHUD") as MobileHUD).equipment_screen
    # สถานะสาธิตใช้ธุรกรรมจริง ไม่วาดตัวเลข/ไอคอนหลอกบนภาพ
    for item_id: StringName in [&"field_cap", &"goggles", &"field_jacket", &"cargo_pants", &"trail_gloves", &"trail_boots", &"travel_pack", &"memory_pendant", &"azure_ring", &"signal_band", &"field_belt", &"hope_charm", &"digi_device", &"power_chip", &"vital_chip"]:
        tamer.equipment.put_on(item_id)
    ui.open_screen()
    ui.select_bag_item(&"reinforced_cap")
    running = not capture_directory.is_empty()

func _process(_delta: float) -> void:
    if not running:
        return
    tick += 1
    if tick == 180:
        tamer.equipment.put_on(&"reinforced_cap")
        ui.select_slot(&"head")
    if tick == 270:
        ui._rotate_preview()
    if tick == 360:
        ui._select_tab(1)
        ui.select_bag_item(&"runner_chip")
    if tick == 480:
        ui.select_slot(&"chip_b")
        ui.select_bag_item(&"runner_chip")
        ui._equip_selected()
        ui.select_slot(&"chip_b")
    if tick == 600:
        ui._select_tab(2)
    if tick == 720:
        ui.close_screen()
    if tick % 3 == 0:
        _capture_frame.call_deferred(tick / 3)
    if tick >= 780:
        running = false
        _finish.call_deferred()

func _capture_frame(index: int) -> void:
    await RenderingServer.frame_post_draw
    var image: Image = get_viewport().get_texture().get_image()
    image.save_png(capture_directory.path_join("frame_%03d.png" % index))
    if index == 30:
        image.save_png(capture_directory.path_join("Equipment_Tamer_v15.png"))
    if index == 185:
        image.save_png(capture_directory.path_join("Equipment_Digivice_v15.png"))

func _finish() -> void:
    await RenderingServer.frame_post_draw
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    get_tree().quit()
