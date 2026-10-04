extends Node
## F6: สนามสาธิต Survival ใช้ไฟล์เซฟแยกจากตัวละครจริง
## เปิดผ่าน tools/survival_preview.tscn เพื่อทดสอบอาหาร, MP และ HP ต่ำได้ทันที
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var hud: MobileHUD
var _capture_dir: String = ""

func _ready() -> void:
    # ตัวควบคุมสาธิตอยู่ต่อได้ขณะเปิด Inventory แต่ Survival ใต้ Tamer หยุดตามสนาม
    process_mode = Node.PROCESS_MODE_ALWAYS
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-survival="):
            _capture_dir = argument.trim_prefix("--capture-survival=")
            DirAccess.make_dir_recursive_absolute(_capture_dir)
    run.call_deferred()

func run() -> void:
    # จำกัดผลของการสาธิตให้อยู่ในไฟล์ของมัน ไม่แก้ slot จากหน้า Login
    GameManager.gameplay_active = false
    QuestManager.save_path = "user://survival_preview_v19.json"
    QuestManager.reset_progress(false)
    world = preload("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    hud = world.get_node("MobileHUD")
    hud.preferences.save_path = "user://survival_preview_v19.cfg"
    hud.preferences.combat_scale = 1
    hud.preferences.minimap_visible = false
    hud.chat_panel.set_collapsed(true)
    hud._layout()
    tamer.global_position = Vector2(1420,1120)
    partner.global_position = Vector2(1530,1120)
    tamer.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    InventoryManager.add_item(InventoryManager.catalog.find_item("digital_fruit"),7)
    InventoryManager.add_item(InventoryManager.catalog.find_item("mp_drink"),3)
    InventoryManager.add_item(InventoryManager.catalog.find_item("meat"),10)
    if _capture_dir.is_empty():
        _build_demo_buttons()
        GameChat.add_system("Survival Demo • หิว 0 จะเสีย HP ทุก 3s • อาหารอยู่ในกระเป๋า")
    else:
        await _capture()

func _build_demo_buttons() -> void:
    # ปุ่มทดสอบวางกลางบน แยกจาก HUD หลักและปิดคำสั่งระหว่างหน้าต่าง modal
    var layer := CanvasLayer.new()
    layer.layer = 15
    layer.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    var row := HBoxContainer.new()
    root.add_child(row)
    row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    row.offset_left = -176
    row.offset_right = 176
    row.offset_top = 22
    row.offset_bottom = 76
    row.add_theme_constant_override("separation",8)
    row.theme = hud.get_node("Root").theme
    var callbacks: Array[Callable] = [_empty_hunger,_critical_hp,_restore_demo]
    var captions: Array[String] = ["หิวหมด","HP 19%","ฟื้นเต็ม"]
    for index: int in range(captions.size()):
        var button := EquipmentButton.new()
        button.caption = captions[index]
        button.custom_minimum_size = Vector2(112,54)
        row.add_child(button)
        button.pressed.connect(callbacks[index])

func _empty_hunger() -> void:
    # ทดลองนับ 3s หลังหิวหมด โดยไม่ทำดาเมจให้คู่หู
    tamer.set_survival_values(0,tamer.tamer_stamina)
    hud._show_message("หิวหมดแล้ว • เปิดเมนู + / กระเป๋า / กินผลไม้")

func _critical_hp() -> void:
    # ใช้ API ดาเมจจริงให้ Signal ยกเลิก combat และกลับ Rookie ทันที
    var threshold_hp: int = maxi(1,int(floor(tamer.max_hp * 0.19)))
    tamer.take_survival_damage(maxi(0,tamer.hp-threshold_hp))

func _restore_demo() -> void:
    # คืนค่าทดสอบ ไม่เปิด Auto/เป้าเดิมเอง ผู้เล่นยังต้องสั่งต่อสู้ใหม่
    tamer.restore_hp(tamer.max_hp)
    tamer.set_survival_values(100,100)
    if not partner.is_alive():
        partner.recover()
    partner.restore_hp(partner.max_hp)
    partner.restore_mp(partner.digimon_max_mp)
    tamer.restore_ds(tamer.max_ds)

func _shot(name_text: String) -> void:
    # ใช้ภาพจาก renderer จริง ไม่วาดภาพ HUD จำลองแยกจากเกม
    await get_tree().create_timer(0.4,true).timeout
    await RenderingServer.frame_post_draw
    var path: String = _capture_dir.path_join(name_text + ".png")
    print("CAPTURE ",path," error=",get_viewport().get_texture().get_image().save_png(path))

func _capture() -> void:
    # แช่ Actor/นาฬิกาเฉพาะตอนถ่าย เพื่อให้ตัวเลขอ่านได้และภาพทำซ้ำได้
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    tamer.global_position = Vector2(1420,1120)
    partner.global_position = Vector2(1530,1120)
    tamer.ds = 78
    tamer.hp = 168
    tamer.set_survival_values(64,73)
    partner.digimon_mp = 57
    partner.load_monster_data(partner.forms[1],false)
    tamer.hp_changed.emit(tamer.hp,tamer.max_hp)
    tamer.ds_changed.emit(tamer.ds,tamer.max_ds)
    partner.mp_changed.emit(partner.digimon_mp,partner.digimon_max_mp)
    GameChat.add_system("DS สำหรับเปลี่ยนร่าง • MP สำหรับสกิล • อาหารฟื้น Tamer")
    await _shot("Survival_v19_HUD")
    _critical_hp()
    tamer.set_survival_values(0,0)
    await _shot("Survival_v19_CannotBattle")
    hud.inventory_screen.open_screen()
    hud.inventory_screen._choose_slot(InventoryManager.index_of("digital_fruit"))
    await _shot("Survival_v19_Food")
    hud.inventory_screen.close_screen()
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    get_tree().quit()
