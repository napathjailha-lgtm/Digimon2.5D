extends Node
## F6: ดูไอคอนและทดสอบสกิลกับศัตรูจำลองในฉากจริง ใช้ save แยกจากผู้เล่น
var directory: String = ""
var _world: Node

func _ready() -> void:
    run.call_deferred()

func capture(file_name: String) -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(directory.path_join(file_name + ".png"))

func run() -> void:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-art="):
            directory = argument.trim_prefix("--capture-art=")
    if directory.is_empty():
        directory = ProjectSettings.globalize_path("res://preview/skill_art")
    DirAccess.make_dir_recursive_absolute(directory)
    QuestManager.save_path = "user://skill_art_preview_only.json"
    QuestManager.reset_progress(false)
    GameManager.ensure_catalog()
    GameManager.gameplay_active = true
    GameManager.partner_selected = &"tentomon"
    GameManager.tamer_selected = &"taichi"
    GameManager.tamer_name = "Taichi"
    _world = load("res://scenes/world.tscn").instantiate()
    add_child(_world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var hud: MobileHUD = _world.get_node("MobileHUD")
    var player: Tamer = _world.get_node("Actors/Tamer")
    var partner: PartnerMonster = player.partner
    hud.preferences.minimap_visible = true
    hud.preferences.combat_scale = 1.0
    hud.preferences.chat_collapsed = true
    hud.chat_panel.set_collapsed(true)
    hud._layout()
    hud.party_roster.add_partner(&"agumon")
    hud.party_roster.add_partner(&"gabumon")
    player.survival.set_process(false)
    player.survival.autosave_enabled = false
    player.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    await get_tree().create_timer(0.5).timeout
    await capture("SkillArt_v24_HUD")
    # ตั้งตำแหน่งสำหรับสาธิตเท่านั้น ไม่เปลี่ยนจุดเกิดในเกมจริง
    player.position = Vector2(800, 1220)
    partner.position = Vector2(840, 1130)
    player.reset_physics_interpolation()
    partner.reset_physics_interpolation()
    var camera: Camera2D = player.get_node("Camera2D")
    camera.snap_to_party()
    var dummy: WildMonster = load("res://scenes/wild_monster.tscn").instantiate()
    dummy.position = Vector2(1010, 1130)
    dummy.max_hp = 99999
    _world.get_node("Actors").add_child(dummy)
    dummy.set_physics_process(false)
    dummy.set_selected(true)
    for spec: Array in [["tentomon", 0], ["agumon", 1], ["gabumon", 0], ["piyomon", 0], ["palmon", 0]]:
        var family: StarterPartnerData = hud.party_roster.family(StringName(spec[0]))
        partner.cancel_battle()
        partner.forms.assign(family.forms)
        partner.load_monster_data(family.forms[int(spec[1])])
        partner.target = dummy
        partner.digimon_mp = partner.digimon_max_mp
        partner.skill_cooldowns.clear()
        partner.velocity = Vector2.ZERO
        hud._refresh_bars()
        var skill: MonsterSkill = partner.active_skills[0]
        print("PREVIEW CAST ", skill.display_name, ": ", partner._try_skill_resource(skill))
        # จับเมื่อเริ่มเกิดภาพกระทบจาก projectile จริง ไม่สร้างดาเมจปลอม
        var frames: int = 0
        while get_tree().get_nodes_in_group("skill_vfx").is_empty() and frames < 120:
            await get_tree().process_frame
            frames += 1
        # ค้างภาพกระทบหนึ่งเฟรมเพื่อจับภาพนิ่งได้แม้เครื่องเรนเดอร์ช้า
        # ใช้ Node เอฟเฟกต์จาก hit จริง ไม่สร้างเอฟเฟกต์หรือตัวเลขดาเมจเพิ่ม
        for effect: Node in get_tree().get_nodes_in_group("skill_vfx"):
            effect.set_process(false)
            effect.elapsed = 0.14
            effect.queue_redraw()
        await capture("SkillArt_v24_" + spec[0])
        for effect: Node in get_tree().get_nodes_in_group("skill_vfx"):
            effect.set_process(true)
        await get_tree().create_timer(0.65).timeout
    _world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    await _gallery()
    await capture("SkillArt_v24_Icons")
    get_tree().quit()

func _gallery() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var background := ColorRect.new()
    background.color = Color("101824")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(background)
    var title := Label.new()
    title.text = "DIGITAL ADVENTURE  /  SKILL ART"
    title.position = Vector2(58, 32)
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color("efd6a5"))
    background.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "V24   •   Painted combat icons   •   Elemental effects"
    subtitle.position = Vector2(60, 76)
    subtitle.add_theme_font_size_override("font_size", 17)
    subtitle.modulate = Color("8fa1b5")
    background.add_child(subtitle)
    var keys: Array[String] = ["fire", "ice", "wind", "lightning", "nature", "claw", "missile", "wing", "astral", "evolve"]
    var names: Array[String] = ["FLAME", "ICE BLAST", "WIND", "LIGHTNING", "NATURE", "CLAW", "DESTROYER", "PHOENIX WING", "ASTRAL", "EVOLUTION"]
    for i: int in range(keys.size()):
        var column: int = i % 5
        var row: int = i / 5
        var button := HybridCommand.new()
        button.position = Vector2(85 + column * 238, 148 + row * 258)
        button.size = Vector2(160, 160)
        button.icon = load("res://assets/skills_painted/%s.png" % keys[i])
        button.illustrated = true
        button.caption = ""
        background.add_child(button)
        var label := Label.new()
        label.position = button.position + Vector2(-24, 172)
        label.size = Vector2(208, 28)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.text = names[i]
        label.add_theme_font_size_override("font_size", 17)
        label.modulate = Color("cfdae6")
        background.add_child(label)
    await get_tree().process_frame
