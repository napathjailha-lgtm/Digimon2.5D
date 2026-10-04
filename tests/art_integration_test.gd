extends Node
var failures: int = 0

func _ready() -> void:
    run.call_deferred()

func check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: ", message)
    else:
        failures += 1
        push_error(message)

func run() -> void:
    QuestManager.save_path = "user://art_integration_test.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    check(world.get_node("WorldArtwork").texture != null, "Scene โหลดภาพพื้นหลังจริง")

    for index: int in range(4):
        tamer.velocity = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][index] * 100.0
        tamer.animator.update_motion(tamer.velocity, tamer.animation_reference_speed)
        var image: AnimatedSprite2D = tamer.get_node("AnimatedSprite2D")
        check(image.sprite_frames.get_frame_texture(image.animation, 0) == tamer.directional_textures[index], "Tamer แสดงภาพทิศ %d ถูกต้อง" % index)
        check(is_zero_approx(image.offset.y + image.sprite_frames.get_frame_texture(image.animation, 0).get_height() * 0.5), "เท้าตรง Origin หลังเปลี่ยนทิศ %d" % index)

    var monster: WildMonster = world.get_node("Spawners/SpawnerA").current_monster
    var image: Sprite2D = monster.get_node("Sprite2D")
    var upper_body: Vector2 = monster.global_position + Vector2(0, -image.texture.get_height() * image.scale.y * 0.75)
    check(monster.global_position.distance_to(upper_body) > 24.0, "พิกัดทดสอบอยู่นอก Collider ใต้เท้า")
    tamer.select_at_screen(get_viewport().get_canvas_transform() * upper_body)
    check(tamer.target == monster, "แตะภาพส่วนบนของศัตรูแล้วเลือกได้ผ่าน TouchTarget")

    var npc: StoryNPC = world.get_node("StoryPoints/NPC")
    tamer.global_position = npc.global_position + Vector2(20, 0)
    var npc_image: Sprite2D = npc.get_node("Sprite2D")
    var npc_head: Vector2 = npc.global_position + Vector2(0, -npc_image.texture.get_height() * npc_image.scale.y * 0.7)
    tamer.select_at_screen(get_viewport().get_canvas_transform() * npc_head)
    check(QuestManager.is_completed(&"q01_agumon"), "แตะภาพส่วนบน NPC เริ่มบทสนทนาได้")

    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
