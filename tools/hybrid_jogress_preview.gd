extends Node
## ภาพจาก Godot renderer จริง ใช้ข้อมูลทดสอบแยกเซฟผู้เล่น
func _ready() -> void:
    run.call_deferred()

func run() -> void:
    QuestManager.save_path = "user://jogress_preview.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"agumon"
    GameManager.tamer_selected = &"taichi"
    var world: Node2D = load("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var hud: MobileHUD = world.get_node("MobileHUD")
    var partner: PartnerMonster = tamer.partner
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.position = Vector2(480, 370)
    partner.position = Vector2(620, 400)
    hud.party_roster.add_partner(&"gabumon")
    partner.progress.restore_data({"level": 90})
    hud.party_roster.members[1]["progress"] = {"level": 90, "exp": 0}
    hud.jogress_manager._activate()
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    await get_tree().create_timer(0.4).timeout
    DirAccess.make_dir_recursive_absolute("res://preview/hybrid_jogress")
    await capture("field")
    for action: StringName in [&"attack", &"cast"]:
        partner.animator.play_action(action, Vector2.RIGHT, action)
        partner.sprite.pause()
        partner.sprite.frame = 2
        await capture(String(action))
        partner.animator.reset_actions()
    partner.sprite.play(&"idle")
    hud.digimon_screen.open_screen()
    await get_tree().create_timer(0.3).timeout
    await capture("status")
    hud.digimon_screen.close_screen()
    get_tree().quit()

func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_jpg("res://preview/hybrid_jogress/" + label + ".jpg", 0.88)
