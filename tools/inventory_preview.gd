extends Node
## F6 ใช้เซฟสาธิตแยกจากผู้เล่นจริง แสดง Loot และหน้ากระเป๋า Native ของเกม
var directory: String = ""
var frame_index: int = 0
var capture_video: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-inventory="):
            directory = argument.trim_prefix("--capture-inventory=")
            DirAccess.make_dir_recursive_absolute(directory)
    run.call_deferred()

func _process(_delta: float) -> void:
    if capture_video:
        frame_index += 1
        if frame_index % 3 == 0:
            save_frame.call_deferred(frame_index / 3)

func save_frame(index: int) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join("frame_%04d.png" % index))

func screenshot(name_text: String) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join(name_text + ".png"))

func tap(control: Control) -> void:
    var at: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = 3
        event.position = at
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds, true).timeout

func run() -> void:
    QuestManager.save_path = "user://inventory_preview_v17.json"
    QuestManager.reset_progress(false)
    GameManager.gameplay_active = false
    var world: Node2D = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await wait(0.3)
    var player: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var actor_layer: Node2D = player.get_parent()
    var table := LootTable.new()
    for id: String in ["meat", "data_chip", "digitama"]:
        var entry := LootDropEntry.new()
        entry.item = InventoryManager.catalog.find_item(id)
        entry.chance = 1.0 # กำหนดเฉพาะสาธิต; เกมจริงใช้ 75/35/8%
        entry.min_quantity = 10 if id == "meat" else (3 if id == "data_chip" else 1)
        entry.max_quantity = entry.min_quantity
        table.entries.append(entry)
    var enemy: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
    enemy.position = actor_layer.to_local(player.global_position + Vector2(110, 100))
    enemy.drop_table = table
    enemy.exp_reward = 0
    actor_layer.add_child(enemy)
    enemy.set_physics_process(false)
    capture_video = not directory.is_empty()
    enemy.take_damage(999, partner)
    await wait(1.0)
    if not directory.is_empty():
        await screenshot("Ground_Loot_v17")
    await wait(0.6)
    player.global_position += Vector2(110, 100)
    await wait(1.2)
    partner.take_damage(100)
    tap(hud.inventory_button)
    await wait(0.4)
    tap(hud.inventory_screen.slots[0])
    await wait(0.6)
    if not directory.is_empty():
        await screenshot("Inventory_v17")
    await wait(1.0)
    tap(hud.inventory_screen.use_button)
    await wait(0.8)
    if not directory.is_empty():
        await screenshot("Inventory_Use_v17")
    tap(hud.inventory_screen.slots[2])
    await wait(0.5)
    if not directory.is_empty():
        await screenshot("Inventory_Egg_v17")
    await wait(0.8)
    if not directory.is_empty():
        capture_video = false
        hud.inventory_screen.close_screen()
        world.queue_free()
        await get_tree().process_frame
        get_tree().quit()
