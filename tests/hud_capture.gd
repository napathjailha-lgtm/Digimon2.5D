extends Node
## ใช้สร้างภาพจากเกมจริงสำหรับตรวจหน้าตา HUD ไม่ใช่ภาพจำลอง
func _ready() -> void:
    run.call_deferred()

func run() -> void:
    get_tree().root.size = Vector2i(1280, 720)
    QuestManager.save_path = "user://hud_capture_demo.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    tamer.progress.restore_data({"level": 12, "exp": 340})
    tamer.apply_progress_stats()
    tamer.hp = 642
    tamer.ds = 88.0
    partner.progress.restore_data({"level": 14, "exp": 480})
    partner.load_monster_data(partner.forms[1], false)
    partner.hp = 760
    tamer.global_position = Vector2(480, 420)
    partner.global_position = Vector2(590, 420)
    tamer.hp_changed.emit(tamer.hp, tamer.max_hp)
    partner.hp_changed.emit(partner.hp, partner.max_hp)
    var enemy: WildMonster = world.get_node("Spawners/SpawnerA").current_monster
    enemy.global_position = Vector2(810, 345)
    enemy.hp = int(enemy.max_hp * 0.65)
    tamer.set_target(enemy)
    GameChat.add_system("แผนที่: File Island — แตะเควสต์เพื่อเดินนำทาง")
    GameChat.submit_local("ไปลุยกัน! พร้อมแล้ว")
    await get_tree().create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    var output: String = OS.get_environment("HUD_CAPTURE_PATH")
    if output.is_empty():
        output = "user://hud_preview_v10.png"
    var error: Error = get_viewport().get_texture().get_image().save_png(output)
    print("CAPTURE: ", output, " error=", error)
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    await RenderingServer.frame_post_draw
    get_tree().quit(int(error))
