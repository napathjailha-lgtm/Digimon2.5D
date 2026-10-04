extends Node
## F6 ดูร่าง Mega บนฉากจริงและบันทึกภาพ ใช้ไฟล์เซฟพรีวิวแยกจากผู้เล่น
var world: Node
var directory: String

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func capture(name: String) -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png"))

func run() -> void:
    directory = ProjectSettings.globalize_path("res://preview/mega_v26")
    DirAccess.make_dir_recursive_absolute(directory)
    QuestManager.save_path = "user://mega_preview_v26_only.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    GameManager.tamer_name = "Taichi"
    while not QuestManager.is_completed(&"q07_myotismon"):
        var q: StoryQuest = QuestManager.get_current_quest()
        QuestManager.report_event(q.objective, q.target_id, q.required_count, "preview_v26_" + String(q.id))
    world = load("res://scenes/world.tscn").instantiate()
    add_child(world)
    for i: int in range(5):
        await get_tree().physics_frame
    var player: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = player.partner
    var hud: MobileHUD = world.get_node("MobileHUD")
    player.survival.set_process(false)
    player.survival.autosave_enabled = false
    player.set_physics_process(false)
    partner.set_physics_process(false)
    hud.party_roster.set_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    player.position = Vector2(1600,1500)
    partner.position = Vector2(1510,1470)
    player.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    player.get_node("Camera2D").snap_to_party()
    hud.chat_panel.set_collapsed(true)
    hud.party_roster.add_partner(&"gabumon")
    for index: int in range(2):
        if index == 1:
            hud.party_roster.select_member(index)
        partner.load_monster_data(partner.forms[3], false)
        partner.animator.face_direction(Vector2.RIGHT)
        partner.animator.update_motion(Vector2.ZERO, partner.move_speed, partner.current_form.idle_animation, partner.current_form.walk_animation)
        await get_tree().create_timer(0.4, true).timeout
        await capture(partner.current_form.monster_name + "_Field")
        hud.digimon_screen.open_screen()
        await get_tree().create_timer(0.4, true).timeout
        await capture(partner.current_form.monster_name + "_Status")
        hud.digimon_screen.close_screen()
    world.queue_free()
    await get_tree().process_frame
    get_tree().quit()
