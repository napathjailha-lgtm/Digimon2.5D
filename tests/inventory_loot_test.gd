extends Node
## ทดสอบผ่าน World จริง การชน Area2D, Tween, UI Touch และเซฟของตัวละคร
var assertions: int = 0
var failures: int = 0
var world: Node2D
var player: Tamer
var partner: PartnerMonster
var hud: MobileHUD

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func frames(count: int = 4) -> void:
    for index: int in range(count):
        await get_tree().physics_frame

func tap(control: Control) -> void:
    var at: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = 7
        event.position = at
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func run() -> void:
    get_tree().root.size = Vector2i(1280, 720)
    GameManager.gameplay_active = false
    QuestManager.save_path = "user://inventory_loot_test_v17.json"
    QuestManager.reset_progress(false)
    world = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await frames()
    player = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    hud = world.get_node("MobileHUD")
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var manager: Node = InventoryManager
    var meat: ItemData = manager.catalog.find_item("meat")
    var egg: ItemData = manager.catalog.find_item("digitama")
    var chip: ItemData = manager.catalog.find_item("data_chip")
    check(manager.player_node() == player and manager.items().is_empty(), "เริ่มกระเป๋าว่างและ bind Tamer ปัจจุบัน")
    check(manager.catalog.items.size() >= 16 and meat.item_texture != null and manager.catalog.find_item("tamer_mp_potion") != null, "ฐานข้อมูลไอเทมปัจจุบันพร้อม Texture และยา MP Tamer")
    check(not manager.add_item(null, 1) and not manager.add_item(meat, 0) and not manager.add_item(meat, -1), "ปฏิเสธข้อมูล/จำนวนไม่ถูกต้อง")
    var unknown := ItemData.new()
    unknown.item_id = "unknown"
    check(not manager.add_item(unknown, 1), "ปฏิเสธ ID ที่ไม่อยู่ใน catalog")
    check(manager.add_item(meat, 10) and manager.add_item(meat, 2), "เพิ่มเนื้อสองครั้ง")
    check(manager.items().size() == 1 and manager.count("meat") == 12, "ซ้อนจำนวนเป็น stack เดียว")
    var copy: Array[Dictionary] = manager.items()
    copy[0].quantity = 999
    check(manager.count("meat") == 12, "แก้สำเนา UI ไม่แก้กระเป๋าจริง")
    var canonical_effect: int = meat.effect_value
    check(not manager.use_item(-1) and not manager.use_item(999), "index เก่า/นอกขอบไม่ผิดพลาด")
    check(not manager.use_item(0) and manager.count("meat") == 12, "HP เต็มไม่กินเนื้อ")
    partner.take_damage(100)
    var before: int = partner.hp
    check(manager.use_item(0) and partner.hp == mini(partner.max_hp, before + 80), "ใช้เนื้อฟื้น HP คู่หูตามค่าที่ขาด")
    check(manager.count("meat") == 11 and meat.effect_value == canonical_effect, "ลดหนึ่งชิ้นและไม่แก้ Resource")
    var saved: Dictionary = QuestManager.party_profile
    check(saved.get("inventory", {}).get("stacks", [])[0].quantity == 11 and int(saved.hp) == partner.hp, "save HP กับจำนวนหลัง commit พร้อมกัน")
    partner.evolution_busy = true
    check(not manager.use_item(0) and manager.count("meat") == 11, "คัตซีนไม่กินเนื้อ")
    partner.evolution_busy = false
    partner.enter_fainted(false)
    check(not manager.use_item(0) and manager.count("meat") == 11 and partner.hp == 0, "ไข่ไม่ถูกเนื้อชุบฟรี")
    check(partner.recover(), "Recover เดิมยังทำงาน")
    check(manager.add_item(egg, 1) and manager.add_item(chip, 3), "เก็บไข่กับชิปข้อมูล")
    var hp_before_hatch: int = partner.hp
    check(not manager.use_item(manager.index_of("digitama")) and manager.count("digitama") == 1 and partner.hp == hp_before_hatch, "Digitama ใช้จากกระเป๋าไม่ได้ ต้องนำไป Incubator")
    check(not manager.use_item(manager.index_of("data_chip")), "ชิปเควสต์ใช้เป็นเนื้อไม่ได้")
    var cap: int = manager.max_stack
    manager.max_stack = 12
    check(not manager.add_item(meat, 2) and manager.count("meat") == 11, "เกินเพดาน stack ไม่รับบางส่วน")
    manager.max_stack = cap
    var table := LootTable.new()
    var guaranteed := LootDropEntry.new()
    guaranteed.item = meat
    guaranteed.chance = 1.0
    guaranteed.min_quantity = 2
    guaranteed.max_quantity = 4
    var never := LootDropEntry.new()
    never.item = egg
    never.chance = 0.0
    table.entries.assign([guaranteed, never])
    var rng := RandomNumberGenerator.new()
    rng.seed = 44
    var good_rolls: bool = true
    for index: int in range(100):
        var result: Array[Dictionary] = table.roll(rng)
        good_rolls = good_rolls and result.size() == 1 and result[0].item == meat and int(result[0].quantity) >= 2 and int(result[0].quantity) <= 4
    check(good_rolls, "100 rolls: 100%/0% และช่วงจำนวนถูกต้อง")
    var actor_layer: Node2D = player.get_parent()
    var enemy: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
    enemy.drop_table = table
    enemy.position = actor_layer.to_local(player.global_position + Vector2(240, 0))
    enemy.exp_reward = 0
    actor_layer.add_child(enemy)
    enemy.set_physics_process(false)
    var old_loot_count: int = get_tree().get_nodes_in_group("ground_loot").size()
    enemy.take_damage(999, partner)
    enemy.take_damage(999, partner)
    check(get_tree().get_nodes_in_group("ground_loot").size() == old_loot_count + 1, "ฆ่าศัตรูดรอปครั้งเดียวแม้โดน hit ซ้ำ")
    var dropped: LootItem = get_tree().get_nodes_in_group("ground_loot").back()
    check(dropped.get_parent() == actor_layer, "Loot เป็นลูก Actors ไม่เป็นลูกศัตรู")
    await frames()
    check(not is_instance_valid(enemy) and is_instance_valid(dropped), "ศัตรู free แล้ว Loot ยังอยู่")
    var original_loot_position: Vector2 = dropped.global_position
    player.global_position += Vector2(15, 0)
    check(dropped.global_position == original_loot_position, "ของยังคงพิกัดโลกเมื่อผู้เล่นเดิน")
    var before_count: int = manager.count("meat")
    var quantity: int = dropped.quantity
    player.global_position = dropped.global_position
    await frames(15)
    check(dropped._claimed and manager.count("meat") == before_count + quantity, "Area2D ชน Tamer จริงแล้วเก็บของ")
    dropped._on_body_entered(player)
    check(manager.count("meat") == before_count + quantity, "callback ซ้ำไม่แจกเพิ่ม")
    await get_tree().create_timer(0.5).timeout
    check(not is_instance_valid(dropped), "Tween จบแล้ว Loot queue_free")
    manager.restore_data({})
    manager.max_slots = 1
    manager.add_item(chip, 1)
    var blocked: LootItem = manager.create_loot(meat, 2, actor_layer, player.global_position, 0.0) as LootItem
    await frames(6)
    check(is_instance_valid(blocked) and not blocked._claimed and manager.count("meat") == 0, "กระเป๋าเต็มไม่ลบ Loot")
    manager.restore_data({})
    blocked._notice_left = 0.0
    await frames(35)
    check(manager.count("meat") == 2, "retry เก็บเมื่อมีช่องว่างโดยไม่เดินออก Area")
    await get_tree().create_timer(0.5).timeout
    manager.max_slots = 24
    manager.restore_data({"stacks":[{"id":"meat","quantity":1},{"id":"meat","quantity":4},{"id":"unknown","quantity":99},{"id":"digitama","quantity":-3},{"id":"data_chip","quantity":1.5},{"id":"data_chip","quantity":"2"}]})
    check(manager.count("meat") == 5 and manager.items().size() == 1, "restore รวม ID ซ้ำและกรองเซฟเสีย")
    var json_copy: Dictionary = JSON.parse_string(JSON.stringify(manager.get_save_data()))
    manager.restore_data(json_copy)
    check(manager.count("meat") == 5, "JSON round-trip จำนวนตรง")
    check(not manager.drop_item(-1) and not manager.drop_item(0, 6), "ทิ้ง index/จำนวนผิดไม่ได้")
    manager.add_item(egg, 1)
    partner.take_damage(60)
    var ui: InventoryUI = hud.inventory_screen
    hud.menu.set_expanded(true, false)
    await get_tree().process_frame
    await get_tree().process_frame
    tap(hud.inventory_button)
    await get_tree().process_frame
    check(ui.is_open and get_tree().paused, "Touch เปิดกระเป๋าและ pause")
    check(ui.slots.size() == 24 and ui.grid.columns == 6, "Grid 6x4 มี 24 ช่อง")
    tap(ui.slots[0])
    check(ui.selected_id == "meat" and ui.popup.visible, "Touch สล็อตแสดง Popup")
    # Container จัดขนาดใหม่หลัง Popup show ต้องรอ layout ก่อนส่งตำแหน่ง Touch ครั้งถัดไป
    await get_tree().process_frame
    await get_tree().process_frame
    var panel: Control = ui.get_node("Root/Panel")
    # scale Tween ใช้ขนาดบนจอหลัง transform; raw size เป็นหน่วย local ของ Container
    var panel_rect: Rect2 = panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.size)
    var viewport_rect: Rect2 = get_viewport().get_visible_rect()
    check(viewport_rect.encloses(panel_rect), "หน้ากระเป๋าไม่ล้นจอ Landscape 1280x720")
    var use_rect: Rect2 = ui.use_button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ui.use_button.size)
    var drop_rect: Rect2 = ui.drop_button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ui.drop_button.size)
    check(panel_rect.encloses(use_rect) and panel_rect.encloses(drop_rect) and not use_rect.intersects(drop_rect), "ปุ่ม Use/Drop อยู่ในกรอบและไม่ทับกัน")
    var previous_hp: int = partner.hp
    tap(ui.use_button)
    await get_tree().process_frame
    check(partner.hp > previous_hp and manager.count("meat") == 4, "Touch Use ฟื้น HP และลดจำนวนขณะ pause")
    tap(ui.slots[1])
    check(ui.selected_id == "digitama" and ui.use_button.locked and ui.use_button.caption == "ไป Incubator", "เลือกไข่ UI ชี้ไป Incubator และไม่ให้ฟักจากกระเป๋า")
    tap(ui.drop_button)
    await get_tree().process_frame
    check(manager.count("digitama") == 0 and not ui.popup.visible and ui.selected_id == "", "ทิ้งชิ้นสุดท้ายปิด Popup ไม่ใช้ไอเทมอื่นแทน")
    var ground_egg: LootItem = get_tree().get_nodes_in_group("ground_loot").back()
    check(ground_egg.item.item_id == "digitama" and ground_egg.pickup_delay == 1.0, "ทิ้งสร้าง Loot จริงมี pickup delay")
    check(not hud.equipment_screen.open_screen(), "ไม่เปิดอุปกรณ์ซ้อน pause กระเป๋า")
    tap(ui.close_button)
    check(not ui.is_open and not get_tree().paused and ui.close_button._finger == -1, "ปิดคืน pause/finger")
    check(hud.equipment_screen.open_screen(), "อุปกรณ์เดิมยังเปิดหลังปิดกระเป๋า")
    check(not ui.open_screen(), "ไม่แย่ง pause ของอุปกรณ์")
    hud.equipment_screen.close_screen()
    player.save_party_progress()
    var data: Dictionary = QuestManager.party_profile.duplicate(true)
    var file := FileAccess.open(QuestManager.save_path, FileAccess.READ)
    var disk: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    check(int(disk.party.inventory.stacks[0].quantity) == 4, "จำนวนอยู่ในเซฟจริงบนดิสก์")
    QuestManager.party_snapshot = data
    world.queue_free()
    await frames()
    check(manager.player_node() == null, "WeakRef ไม่อ้าง Tamer ที่ free")
    check(not manager.use_item(0), "ใช้ของหลังเจ้าของออก Scene ไม่ crash")
    world = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await frames()
    player = world.get_node("Actors/Tamer")
    check(manager.count("meat") == 4 and manager.player_node() == player, "เปลี่ยน Scene คืนกระเป๋าเดิม")
    player.partner.take_damage(10)
    check(manager.use_item(manager.index_of("meat")) and player.partner.hp == player.partner.max_hp and manager.count("meat") == 3, "heal_requested ผูกคู่หูใหม่หลัง Scene เดิมถูก free")
    QuestManager.party_snapshot = {}
    QuestManager.reset_progress(false)
    world.queue_free()
    await frames()
    world = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await frames()
    check(manager.items().is_empty(), "ตัวละคร/เซฟใหม่ไม่รับกระเป๋าของคนก่อน")
    hud = world.get_node("MobileHUD")
    check(hud.inventory_screen.open_screen(), "เปิดก่อนเปลี่ยน Scene")
    world.queue_free()
    await get_tree().process_frame
    check(not get_tree().paused, "free หน้ากระเป๋าคืน pause")
    QuestManager.reset_progress(false)
    DirAccess.remove_absolute(QuestManager.save_path)
    print("INVENTORY_LOOT_TEST assertions=%d failures=%d" % [assertions, failures])
    get_tree().quit(0 if failures == 0 else 1)
