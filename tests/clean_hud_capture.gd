extends Node
## ภาพจริงจาก renderer; ใช้ save/preferences แยกเพื่อไม่แก้ข้อมูลผู้เล่น
func _ready() -> void:
    run.call_deferred()
func shot(name: String) -> void:
    await get_tree().create_timer(0.35,true).timeout
    await RenderingServer.frame_post_draw
    var path: String = OS.get_environment("HUD_CAPTURE_DIR").path_join(name+".png")
    print("CAPTURE ",path," error=",get_viewport().get_texture().get_image().save_png(path))
func run() -> void:
    get_tree().root.size = Vector2i(1280,720)
    QuestManager.save_path = "user://clean_hud_capture.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    hud.preferences.save_path = "user://clean_hud_capture.cfg"
    hud.preferences.combat_scale = 1
    hud.preferences.animations_enabled = true
    hud.preferences.minimap_visible = false
    hud.chat_panel.set_collapsed(true)
    hud._layout()
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    tamer.progress.restore_data({"level":12,"exp":340})
    tamer.apply_progress_stats()
    tamer.hp = 642
    tamer.ds = 88
    partner.progress.restore_data({"level":14,"exp":480})
    partner.load_monster_data(partner.forms[1],false)
    partner.hp = 760
    tamer.global_position = Vector2(480,420)
    partner.global_position = Vector2(590,420)
    tamer.hp_changed.emit(tamer.hp,tamer.max_hp)
    partner.hp_changed.emit(partner.hp,partner.max_hp)
    GameChat.add_system("แตะเควสต์เพื่อเดินนำทาง • เมนู + เปิดเครื่องมือ")
    await shot("HUD_v18_Gameplay")
    hud.menu.set_expanded(true)
    await shot("HUD_v18_Menu")
    hud.menu.set_expanded(false,false)
    hud._toggle_stats()
    await shot("HUD_v18_Status")
    hud.smart_panel.close_screen()
    InventoryManager.add_item(InventoryManager.catalog.find_item("meat"),10)
    InventoryManager.add_item(InventoryManager.catalog.find_item("digitama"),1)
    InventoryManager.add_item(InventoryManager.catalog.find_item("data_chip"),3)
    hud.inventory_screen.open_screen()
    hud.inventory_screen._choose_slot(0)
    await shot("HUD_v18_Inventory")
    hud.inventory_screen.close_screen()
    hud._menu_action(&"settings")
    await shot("HUD_v18_Settings")
    hud.smart_panel.close_screen()
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://clean_hud_capture.cfg"))
    get_tree().quit()
