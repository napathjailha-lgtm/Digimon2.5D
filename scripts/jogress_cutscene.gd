class_name JogressCutscene
extends CanvasLayer
## คัตซีน Jogress แบบ runtime ไม่ต้องมี Scene แยก:
## WarGreymon + MetalGarurumon -> Digital Burst -> Omegamon

signal finished(success: bool)

const AGUMON_MEGA: MonsterData = preload("res://data/pregame/agumon_3.tres")
const GABUMON_MEGA: MonsterData = preload("res://data/pregame/gabumon_3.tres")

var _owns_pause: bool = false
var _previous_paused: bool = false
var _running: bool = false
var _root: Control
var _flash: ColorRect
var _left: TextureRect
var _right: TextureRect
var _omega: TextureRect
var _title: Label
var _caption: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 120


func play(partner: PartnerMonster, omegamon: MonsterData) -> bool:
    if _running or not is_instance_valid(partner) or omegamon == null:
        return false
    if get_tree().paused:
        return false

    var omega_texture: Texture2D = omegamon.sprite_frames.get_frame_texture(
        omegamon.idle_animation, 0
    )
    if omega_texture == null:
        return false

    _build_ui()
    _left.texture = WalkTextureTools.visible_texture(
        AGUMON_MEGA.sprite_frames.get_frame_texture(
            AGUMON_MEGA.idle_animation, 0
        )
    )
    _right.texture = WalkTextureTools.visible_texture(
        GABUMON_MEGA.sprite_frames.get_frame_texture(
            GABUMON_MEGA.idle_animation, 0
        )
    )
    _omega.texture = WalkTextureTools.visible_texture(omega_texture)

    _running = true
    _previous_paused = get_tree().paused
    _owns_pause = true
    get_tree().paused = true

    _animate()
    return true


func _build_ui() -> void:
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_root)

    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.015, 0.025, 0.07, 0.96)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(bg)

    # เส้นแสงดิจิทัลกลางฉาก
    for index: int in range(14):
        var line := ColorRect.new()
        line.color = Color(0.18, 0.65, 1.0, 0.10 + float(index % 3) * 0.04)
        line.position = Vector2(0, 34.0 + index * 45.0)
        line.size = Vector2(2000, 2 + index % 2)
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _root.add_child(line)

    _left = _portrait()
    _right = _portrait()
    _omega = _portrait()
    _root.add_child(_left)
    _root.add_child(_right)
    _root.add_child(_omega)

    _left.anchor_left = 0.5
    _left.anchor_top = 0.5
    _right.anchor_left = 0.5
    _right.anchor_top = 0.5
    _omega.anchor_left = 0.5
    _omega.anchor_top = 0.5

    _left.position = Vector2(-430, -165)
    _right.position = Vector2(170, -165)
    _omega.position = Vector2(-130, -190)
    _omega.size = Vector2(260, 380)

    _left.modulate.a = 0.0
    _right.modulate.a = 0.0
    _omega.modulate.a = 0.0
    _omega.scale = Vector2(0.42, 0.42)
    _omega.pivot_offset = _omega.size * 0.5

    _title = Label.new()
    _title.text = "JOGRESS EVOLUTION"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 38)
    _title.add_theme_color_override("font_color", Color("8feaff"))
    _title.add_theme_constant_override("outline_size", 8)
    _title.add_theme_color_override("font_outline_color", Color("071528"))
    _title.anchor_left = 0.5
    _title.anchor_right = 0.5
    _title.offset_left = -360
    _title.offset_right = 360
    _title.offset_top = 60
    _title.offset_bottom = 118
    _root.add_child(_title)

    _caption = Label.new()
    _caption.text = "WarGreymon  +  MetalGarurumon"
    _caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caption.add_theme_font_size_override("font_size", 22)
    _caption.add_theme_constant_override("outline_size", 5)
    _caption.add_theme_color_override("font_outline_color", Color("071528"))
    _caption.anchor_left = 0.5
    _caption.anchor_right = 0.5
    _caption.anchor_top = 1.0
    _caption.anchor_bottom = 1.0
    _caption.offset_left = -430
    _caption.offset_right = 430
    _caption.offset_top = -105
    _caption.offset_bottom = -62
    _root.add_child(_caption)

    _flash = ColorRect.new()
    _flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _flash.color = Color.WHITE
    _flash.modulate.a = 0.0
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_flash)


func _portrait() -> TextureRect:
    var result := TextureRect.new()
    result.size = Vector2(260, 330)
    result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return result


func _animate() -> void:
    # 1) สองร่าง Mega ปรากฏ
    var intro := create_tween()
    intro.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    intro.set_parallel(true)
    intro.tween_property(_left, "modulate:a", 1.0, 0.32)
    intro.tween_property(_right, "modulate:a", 1.0, 0.32)
    intro.tween_property(_left, "position:x", -350.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    intro.tween_property(_right, "position:x", 90.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    await intro.finished

    # 2) พุ่งเข้าหากัน
    var merge := create_tween()
    merge.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    merge.set_parallel(true)
    merge.tween_property(_left, "position:x", -150.0, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    merge.tween_property(_right, "position:x", -10.0, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    merge.tween_property(_left, "modulate", Color(0.6, 0.9, 1.5, 0.15), 0.48)
    merge.tween_property(_right, "modulate", Color(1.5, 0.75, 0.35, 0.15), 0.48)
    await merge.finished

    # 3) Digital flash
    var burst := create_tween()
    burst.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    burst.tween_property(_flash, "modulate:a", 0.98, 0.10)
    burst.tween_interval(0.12)
    burst.tween_property(_flash, "modulate:a", 0.0, 0.30)
    await burst.finished

    _left.hide()
    _right.hide()
    _omega.modulate = Color.WHITE
    _omega.modulate.a = 1.0
    _caption.text = "OMEGAMON"
    _caption.add_theme_font_size_override("font_size", 30)

    # 4) Omegamon reveal
    var reveal := create_tween()
    reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    reveal.tween_property(_omega, "scale", Vector2(1.12, 1.12), 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    reveal.tween_property(_omega, "scale", Vector2.ONE, 0.20)
    reveal.tween_interval(0.48)
    await reveal.finished

    _finish(true)


func cancel() -> void:
    if not _running:
        return
    _finish(false)


func _finish(success: bool) -> void:
    if not _running:
        return
    _running = false

    if _owns_pause:
        get_tree().paused = _previous_paused
        _owns_pause = false

    finished.emit(success)
    queue_free()


func _exit_tree() -> void:
    if _owns_pause:
        get_tree().paused = _previous_paused
        _owns_pause = false
