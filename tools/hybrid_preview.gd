extends Node
## F6 หรือ --capture-hybrid=path: จับภาพ viewport จริงของ Godot ไม่ใช่ภาพจำลอง HUD
var directory: String = ""

func _ready() -> void:
    run.call_deferred()

func capture(name_text: String) -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join(name_text + ".png"))

func run() -> void:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-hybrid="):
            directory = argument.trim_prefix("--capture-hybrid=")
    if directory.is_empty():
        directory = ProjectSettings.globalize_path("res://preview/hybrid")
    DirAccess.make_dir_recursive_absolute(directory)
    QuestManager.save_path = "user://hybrid_visual_preview.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    GameManager.tamer_name = "Taichi"
    var world: Node = load("res://scenes/world.tscn").instantiate()
    add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var hud: MobileHUD = world.get_node("MobileHUD")
    var player: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = player.partner
    hud.preferences.minimap_visible = true
    hud.preferences.combat_scale = 1.0
    hud.preferences.chat_collapsed = true
    hud.chat_panel.set_collapsed(true)
    hud._layout()
    # ทีมตัวอย่างมีให้เฉพาะพรีวิว; เกมจริงเริ่มด้วย starter และรับเพื่อนเพิ่มจากไข่
    hud.party_roster.add_partner(&"gabumon")
    hud.party_roster.add_partner(&"piyomon")
    hud.party_roster.members[1].hp = roundi(hud.party_roster.members[1].max_hp * 0.56)
    hud.party_roster.members[2].hp = roundi(hud.party_roster.members[2].max_hp * 0.89)
    hud.party_roster.changed.emit()
    player.hp = roundi(player.max_hp * 0.88)
    player.ds = 76
    player.tamer_hunger = 83
    player.tamer_stamina = 91
    player.survival.set_process(false)
    player.set_physics_process(false)
    partner.hp = roundi(partner.max_hp * 0.72)
    partner.digimon_mp = 68
    partner.set_physics_process(false)
    partner.skill_cooldowns[partner.active_skills[0].id] = 2.3
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    hud._refresh_bars()
    await get_tree().create_timer(0.6).timeout
    await capture("HybridHUD_1280x720")
    # จอ 20:9 พร้อม notch จำลอง: เว้นพื้นที่จริงด้านซ้าย ไม่ขยายวงสกิลจนล้นขอบ
    get_tree().root.size = Vector2i(1600, 720)
    await get_tree().process_frame
    hud.safe_inset_override = Vector4(92, 20, 38, 24)
    hud.preferences.combat_scale = 1.15
    hud._layout()
    await get_tree().create_timer(0.25).timeout
    await capture("HybridHUD_Notch_1600x720")
    get_tree().root.size = Vector2i(1024, 768)
    await get_tree().process_frame
    hud.safe_inset_override = Vector4(-1, -1, -1, -1)
    hud.preferences.combat_scale = 1.0
    hud._layout()
    await get_tree().create_timer(0.25).timeout
    await capture("HybridHUD_Tablet_1024x768")
    hud._switch_party(1)
    await get_tree().create_timer(0.15).timeout
    await capture("HybridHUD_PartySwitch")
    # ปิดทุก Node ก่อน quit เพื่อให้ผลทดสอบไม่ทิ้ง paused state หรือ Save ของผู้เล่นจริง
    world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    get_tree().quit()
