extends Node2D
## เปิด walk_preview.tscn ด้วย F6 เพื่อดูเฟรมจริงทุกตัวพร้อมกัน
## ฉากนี้แสดงแอนิเมชันเท่านั้น ไม่แตะ Save และไม่ใช้ AI ของสนาม
const ACTORS: Array[String] = ["tamer", "rookie", "champion", "ultimate", "mega"]
const DIRECTIONS: Array[Vector2] = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
const DIRECTION_NAMES: Array[String] = ["DOWN", "RIGHT", "UP", "LEFT"]
var animators: Array[DirectionalAnimator] = []
var sprites: Array[AnimatedSprite2D] = []
var elapsed: float = 0.0
var capture_tick: int = 0
var capture_directory: String = ""
var direction_label: Label

func _ready() -> void:
    # --capture-walk=/tmp/path เก็บ PNG จาก renderer จริงสำหรับตรวจภาพ
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-walk="):
            capture_directory = argument.trim_prefix("--capture-walk=")
            DirAccess.make_dir_recursive_absolute(capture_directory)
    var title := Label.new()
    title.text = "v12 | Four-direction walk animation preview"
    title.position = Vector2(55, 35)
    title.add_theme_font_size_override("font_size", 28)
    add_child(title)
    direction_label = Label.new()
    direction_label.position = Vector2(55, 86)
    direction_label.add_theme_font_size_override("font_size", 22)
    add_child(direction_label)
    for index: int in range(ACTORS.size()):
        var actor: String = ACTORS[index]
        var frames: SpriteFrames = load("res://data/%s_frames.tres" % actor)
        var sprite := AnimatedSprite2D.new()
        sprite.sprite_frames = frames
        sprite.animation = &"idle_down"
        sprite.position = Vector2(140 + index * 250, 430)
        sprite.offset.y = -256.0
        sprite.scale = Vector2(0.25, 0.25) if index == 0 else (load("res://data/%s.tres" % actor) as MonsterData).sprite_scale
        add_child(sprite)
        sprites.append(sprite)
        var animator := DirectionalAnimator.new()
        animator.sprite = sprite
        add_child(animator)
        animators.append(animator)
        var label := Label.new()
        label.text = actor.to_upper()
        label.position = Vector2(65 + index * 250, 485)
        label.size.x = 150
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 20)
        add_child(label)
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    var direction_index: int = int(elapsed / 1.5) % DIRECTIONS.size()
    var moving: bool = fposmod(elapsed, 1.5) < 1.3
    direction_label.text = "%s | %s" % [DIRECTION_NAMES[direction_index], "WALK" if moving else "IDLE"]
    for index: int in range(animators.size()):
        animators[index].update_motion(DIRECTIONS[direction_index] * 190.0 if moving else Vector2.ZERO, 190.0)
    if not capture_directory.is_empty():
        capture_tick += 1
        if capture_tick % 3 == 0:
            _capture_frame.call_deferred(int(capture_tick / 3))
        if capture_tick >= 360:
            _finish_capture.call_deferred()

func _capture_frame(index: int) -> void:
    # รอ renderer วาดเสร็จ ไม่สร้างภาพจำลองของ SpriteFrames เอง
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(capture_directory.path_join("frame_%03d.png" % index))

func _finish_capture() -> void:
    await RenderingServer.frame_post_draw
    get_tree().quit()

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("102635"))
    for index: int in range(ACTORS.size()):
        draw_ellipse_shadow(Vector2(140 + index * 250, 430))
        draw_line(Vector2(35 + index * 250, 431), Vector2(245 + index * 250, 431), Color("3b6277"), 1.0)

func draw_ellipse_shadow(center: Vector2) -> void:
    # วงเล็กใต้จุดเท้าช่วยตรวจว่าทุกเฟรมยังอยู่ origin เดียวกัน
    draw_circle(center, 7.0, Color("83bdd5"))
