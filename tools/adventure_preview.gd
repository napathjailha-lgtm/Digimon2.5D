extends Node2D
## Render the actual game resources; optional --capture exits after two QA images.
var actors: Array[AnimatedSprite2D] = []

func _ready() -> void:
    get_window().size = Vector2i(1600, 1080)
    get_tree().root.content_scale_size = Vector2i(1600, 1080)
    RenderingServer.set_default_clear_color(Color("101f32"))
    add_label("ADVENTURE PARTNERS  /  EVOLUTION TO MEGA", Vector2(45, 20), 29)
    var catalog: PregameCatalog = load("res://data/pregame/catalog.tres")
    var tamers: Array[StringName] = [&"hikari", &"takeru", &"joe"]
    var families: Array[StringName] = [&"tailmon", &"patamon", &"gomamon"]
    for row: int in range(3):
        var baseline: float = 322 + row * 340
        var model: TamerModelData = catalog.tamer_by_id(tamers[row])
        add_sprite(model.sprite_frames, Vector2(150, baseline), 155)
        add_label(["HIKARI", "TAKERU", "JOE"][row], Vector2(60, baseline + 12), 22)
        var family: StarterPartnerData = catalog.starter_by_id(families[row])
        for index: int in range(family.forms.size()):
            var form: MonsterData = family.forms[index]
            var x: float = 470 + index * 300
            add_sprite(form.sprite_frames, Vector2(x, baseline), 200)
            add_label(form.monster_name, Vector2(x - 120, baseline + 12), 22)
            add_label("Lv.%d  /  %s" % [EvolutionRules.minimum_level_for_form_index(index, form), ["ROOKIE", "CHAMPION", "ULTIMATE", "MEGA"][form.evolution_stage]], Vector2(x - 120, baseline + 42), 16)
    if "--capture" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("user://adventure_idle.png")
        for actor: AnimatedSprite2D in actors:
            if actor.sprite_frames.has_animation(&"attack_right"):
                actor.animation = &"attack_right"
                actor.frame = 2
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("user://adventure_attack.png")
        print("CAPTURE: ", ProjectSettings.globalize_path("user://adventure_idle.png"))
        get_tree().quit()

func add_label(text: String, position: Vector2, size: int) -> void:
    var label := Label.new()
    label.text = text
    label.position = position
    label.add_theme_font_size_override("font_size", size)
    add_child(label)

func add_sprite(frames: SpriteFrames, position: Vector2, height: float) -> void:
    var actor := AnimatedSprite2D.new()
    actor.sprite_frames = frames
    actor.animation = &"idle_down"
    var texture: Texture2D = frames.get_frame_texture(&"idle_down", 0)
    actor.scale = Vector2.ONE * height / texture.get_height()
    actor.position = position
    actor.offset.y = -texture.get_height() * 0.5
    add_child(actor)
    actors.append(actor)
