extends Node
## F6: ทดสอบงานภาพในสนามจริง; โหมด capture ใช้ renderer จริง ไม่วาด mockup แยก
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var hud: MobileHUD
var _capture_dir: String = ""
var _frames_dir: String = ""

func _ready() -> void:
    # Controller ยังทำงานขณะเกม pause แต่ตัว Survival ในสนามหยุดตามกติกาเดิม
    process_mode = Node.PROCESS_MODE_ALWAYS
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-visual="):
            _capture_dir = argument.trim_prefix("--capture-visual=")
            DirAccess.make_dir_recursive_absolute(_capture_dir)
        if argument.begins_with("--visual-frames="):
            _frames_dir = argument.trim_prefix("--visual-frames=")
            DirAccess.make_dir_recursive_absolute(_frames_dir)
    run.call_deferred()

func run() -> void:
    # แยกเซฟสาธิตจาก slot จริง จึงกดลอง damage/ฟื้นได้โดยไม่เสียตัวละครเดิม
    GameManager.gameplay_active = false
    QuestManager.save_path = "user://visual_preview_v20.json"
    QuestManager.reset_progress(false)
    world = preload("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    hud = world.get_node("MobileHUD")
    hud.preferences.save_path = "user://visual_preview_v20.cfg"
    hud.preferences.animations_enabled = true
    hud.preferences.blur_enabled = true
    hud.preferences.low_effects = false
    hud.preferences.combat_scale = 1.0
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
    if not _capture_dir.is_empty():
        await _capture()
    elif not _frames_dir.is_empty():
        await _capture_motion()
    else:
        _build_buttons()

func _build_buttons() -> void:
    # เมนูนี้เป็นเฉพาะฉากสาธิต ส่วน HUD ในเกมจริงยังสะอาดเหมือนเดิม
    var layer := CanvasLayer.new()
    layer.layer = 15
    add_child(layer)
    var row := HBoxContainer.new()
    layer.add_child(row)
    row.position = Vector2(398,20)
    row.theme = hud.get_node("Root").theme
    var actions: Array[Callable] = [_hurt,_restore,hud.inventory_screen.open_screen,hud._toggle_stats,tamer.command_digivolve]
    var captions: Array[String] = ["HP 19%","ฟื้นเต็ม","กระเป๋า","สถานะ","เปลี่ยนร่าง"]
    for i: int in range(captions.size()):
        var button := EquipmentButton.new()
        button.caption = captions[i]
        button.custom_minimum_size = Vector2(108,54)
        row.add_child(button)
        button.pressed.connect(actions[i])

func _freeze() -> void:
    # แช่เฉพาะนาฬิกา/Actor ระหว่างถ่ายภาพ ไม่หยุด AnimationPlayer/Tween ของ UI
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)

func _hurt() -> void:
    # ใช้ API จริง จึงเห็นการล็อกปุ่มกับ Vignette พร้อมกัน ไม่แก้แต่ภาพหลอด
    tamer.take_survival_damage(maxi(0,tamer.hp - maxi(1,int(floor(tamer.max_hp * 0.19)))))

func _restore() -> void:
    # ฟื้นข้อมูลจริงเพื่อดู Tween เพิ่มหลอดและขอบแดงค่อยกลับสู่การเล่นปกติ
    tamer.restore_hp(tamer.max_hp)
    tamer.set_survival_values(100,100)
    tamer.restore_ds(tamer.max_ds)
    partner.restore_mp(partner.digimon_max_mp)

func _shot(name_text: String, wait_seconds: float = 0.50) -> void:
    # frame_post_draw อ่าน framebuffer ที่วาดเสร็จจริง รวม blur/glow/particles
    await get_tree().create_timer(wait_seconds,true).timeout
    await RenderingServer.frame_post_draw
    var path: String = _capture_dir.path_join(name_text + ".png")
    print("CAPTURE ",path," error=",get_viewport().get_texture().get_image().save_png(path))

func _capture() -> void:
    # ชุดภาพเปรียบเทียบครอบคลุม modal, Cannot Battle และจุด burst ของคัตซีน
    _freeze()
    tamer.take_survival_damage(32)
    tamer.set_survival_values(64,73)
    partner.digimon_mp = 57
    partner.mp_changed.emit(partner.digimon_mp,partner.digimon_max_mp)
    GameChat.add_system("DIGITAL ADVENTURE • แตะ + เพื่อเปิดกระเป๋า / สถานะ")
    await _shot("Visual_v20_HUD")
    _hurt()
    await _shot("Visual_v20_Critical")
    hud.inventory_screen.open_screen()
    hud.inventory_screen._choose_slot(InventoryManager.index_of("digital_fruit"))
    await _shot("Visual_v20_Inventory")
    hud.inventory_screen.close_screen()
    _restore()
    hud._toggle_stats()
    await _shot("Visual_v20_Status")
    hud.smart_panel.close_screen()
    tamer.command_digivolve()
    await _shot("Visual_v20_Evolution",1.68)
    if is_instance_valid(hud.active_cutscene):
        hud.active_cutscene.cancel()
    await _cleanup()

func _capture_motion() -> void:
    # วิดีโอสาธิต 6s @24fps: press / drain / recover / popup / evolution ใช้เวลาเฟรมคงที่
    _freeze()
    var index: int = 0
    for frame: int in range(144):
        match frame:
            6: hud.attack_button.visual_fx.set_down(true)
            12: hud.attack_button.visual_fx.set_down(false)
            24: _hurt()
            40: _restore()
            52:
                hud.inventory_screen.open_screen()
                hud.inventory_screen._choose_slot(InventoryManager.index_of("digital_fruit"))
            68: hud.inventory_screen.close_screen()
            72: tamer.command_digivolve()
        await RenderingServer.frame_post_draw
        var path: String = _frames_dir.path_join("frame_%04d.png" % index)
        get_viewport().get_texture().get_image().save_png(path)
        index += 1
    await _cleanup()

func _cleanup() -> void:
    # สาธิตปิดกลางคัตซีนได้โดยไม่ทิ้ง pause/DS reservation ให้ run ถัดไป
    if is_instance_valid(hud.active_cutscene):
        hud.active_cutscene.cancel()
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    get_tree().quit()
