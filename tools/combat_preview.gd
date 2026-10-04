extends Node
## F6 ดูแอคชั่นจริงในสนาม: ตีธรรมดา → สกิลแรก → สกิลประชิด แต่ละร่าง
## ใช้ Save แยกและปลดร่างเฉพาะฉากพรีวิว ไม่เปลี่ยนสิทธิ์ของผู้เล่นในเกมหลัก
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var enemy: WildMonster
var elapsed: float = 0.0
var current_demo: int = -1
var primary_used: bool = false
var secondary_used: bool = false
var running: bool = false
var capture_tick: int = 0
var capture_directory: String = ""
var caption: Label

func _ready() -> void:
    run.call_deferred()

func run() -> void:
    QuestManager.save_path = "user://combat_preview_v13.json"
    QuestManager.reset_progress(false)
    QuestManager.max_unlocked_stage = MonsterData.EvolutionStage.MEGA
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-combat="):
            capture_directory = argument.trim_prefix("--capture-combat=")
            DirAccess.make_dir_recursive_absolute(capture_directory)
    world = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    partner.set_physics_process(false)
    tamer.global_position = Vector2(460, 440)
    partner.global_position = Vector2(720, 420)
    tamer.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    for node: Node in get_tree().get_nodes_in_group("wild_monsters"):
        node.queue_free()
    world.get_node("Spawners").queue_free()
    await get_tree().process_frame
    enemy = preload("res://scenes/wild_monster.tscn").instantiate()
    enemy.max_hp = 10000
    enemy.exp_reward = 0
    enemy.monster_id = &"training_dummy"
    enemy.popup_layer = world.get_node("DamagePopups")
    world.get_node("Actors").add_child(enemy)
    enemy.set_physics_process(false)
    var layer := CanvasLayer.new()
    layer.layer = 12
    add_child(layer)
    caption = Label.new()
    caption.position = Vector2(400, 205)
    caption.add_theme_font_size_override("font_size", 25)
    caption.add_theme_color_override("font_outline_color", Color.BLACK)
    caption.add_theme_constant_override("outline_size", 6)
    layer.add_child(caption)
    running = true

func _physics_process(delta: float) -> void:
    if not running:
        return
    elapsed += delta
    var demo_index: int = int(elapsed / 2.2) % 4
    var phase: float = fposmod(elapsed, 2.2)
    partner._update_cooldowns(delta)
    if demo_index != current_demo:
        current_demo = demo_index
        primary_used = false
        secondary_used = false
        partner.cancel_battle()
        partner.load_monster_data(partner.forms[demo_index], false)
        partner._basic_cooldown = 0.0
        partner.skill_cooldowns.clear()
        tamer.ds = 100.0
        tamer.ds_changed.emit(tamer.ds, tamer.max_ds)
        enemy.hp = enemy.max_hp
        enemy.global_position = partner.global_position + Vector2.RIGHT * 55
        enemy.reset_physics_interpolation()
        partner.command_attack(enemy)
        partner._start_basic_attack()
        caption.text = partner.current_form.monster_name + " | BASIC ATTACK"
    if phase >= 0.65 and not primary_used and not partner.combat_action.busy:
        primary_used = true
        enemy.global_position = partner.global_position + Vector2.RIGHT * 140
        enemy.reset_physics_interpolation()
        partner._try_skill(0)
        caption.text = partner.current_form.monster_name + " | " + partner.active_skills[0].display_name
    if phase >= 1.4 and not secondary_used and not partner.combat_action.busy:
        secondary_used = true
        enemy.global_position = partner.global_position + Vector2.RIGHT * 55
        enemy.reset_physics_interpolation()
        partner._try_skill(1)
        caption.text = partner.current_form.monster_name + " | " + partner.active_skills[1].display_name

func _process(_delta: float) -> void:
    if running and not capture_directory.is_empty():
        capture_tick += 1
        if capture_tick % 3 == 0:
            _capture_frame.call_deferred(int(capture_tick / 3))
        if capture_tick >= 528:
            running = false
            _finish_capture.call_deferred()

func _capture_frame(index: int) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(capture_directory.path_join("frame_%03d.png" % index))

func _finish_capture() -> void:
    await RenderingServer.frame_post_draw
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    get_tree().quit()
