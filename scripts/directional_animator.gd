class_name DirectionalAnimator
extends Node
## Component ภาพเท่านั้น ไม่แก้ velocity หรือ State ของเจ้าของ
## เรียก update_motion() หลัง move_and_slide() โดยส่ง get_real_velocity()
@export var sprite: AnimatedSprite2D
@export_range(0.1, 20.0) var idle_threshold: float = 2.0
@export_range(1.0, 2.0) var direction_bias: float = 1.15
@export var align_feet: bool = true
var facing: StringName = &"down"
var action_locked: bool = false
var motion_scale: Vector2 = Vector2.ONE
var action_scales: Dictionary = {}
var _scales_configured: bool = false

func configure_scales(walk_scale: Vector2, attack_scale: Vector2, cast_scale: Vector2) -> void:
    # ภาพแต่ละชุดมีขนาดต้นฉบับต่างกัน จึงกำหนดสเกลแยกจากภาพเดิน
    motion_scale = walk_scale
    action_scales = {&"attack": attack_scale, &"cast": cast_scale}
    _scales_configured = true

func _ready() -> void:
    # Attack ปิด Loop จึงส่ง animation_finished แล้วกลับไป Idle/Walk ได้
    if is_instance_valid(sprite):
        sprite.animation_finished.connect(_on_animation_finished)
        sprite.frame_changed.connect(_align_feet)

func face_direction(direction: Vector2) -> void:
    # จำทิศล่าสุดเมื่อหยุด และมี hysteresis ลดการสลับทิศรัวที่มุม 45 องศา
    if direction.length_squared() < 0.0001:
        return
    var horizontal: bool = facing in [&"left", &"right"]
    var ax: float = absf(direction.x)
    var ay: float = absf(direction.y)
    if ax > ay * direction_bias:
        horizontal = true
    elif ay > ax * direction_bias:
        horizontal = false
    facing = (&"right" if direction.x > 0.0 else &"left") if horizontal else (&"down" if direction.y > 0.0 else &"up")

func update_motion(real_velocity: Vector2, reference_speed: float,
        idle_fallback: StringName = &"idle", walk_fallback: StringName = &"walk") -> void:
    # ชนกำแพงแล้วความเร็วจริงเป็น 0 แม้ Joystick ยังชี้ไปข้างหน้า
    if not is_instance_valid(sprite) or sprite.sprite_frames == null or action_locked:
        return
    if _scales_configured:
        sprite.scale = motion_scale
    var actual_speed: float = real_velocity.length()
    var walking: bool = actual_speed > idle_threshold
    if walking:
        face_direction(real_velocity)
    var prefix: String = "walk" if walking else "idle"
    var fallback: StringName = walk_fallback if walking else idle_fallback
    var animation: StringName = resolve_animation(prefix, fallback)
    if animation == &"":
        return
    # สเกลจาก FPS ของ SpriteFrames: ชุดเดิน 12 FPS เมื่อวิ่งครึ่งความเร็วจะเล่น 6 FPS
    sprite.speed_scale = actual_speed / maxf(1.0, reference_speed) if walking else 1.0
    var keep_gait: bool = walking and String(sprite.animation).begins_with("walk")
    var gait_phase: float = _get_cycle_phase() if keep_gait else 0.0
    if sprite.animation != animation:
        sprite.play(animation)
        if keep_gait:
            _restore_cycle_phase(animation, gait_phase)
    elif not sprite.is_playing():
        sprite.play(animation)
    _align_feet()

func _get_cycle_phase() -> float:
    # แปลงเฟรมเดิมเป็นสัดส่วนรอบเดิน รวม duration ของแต่ละเฟรม
    # เช่น เดินขวา 4 เฟรม → เดินขึ้น 8 เฟรม จะรักษาจังหวะก้าวเดียวกัน
    var total: float = 0.0
    var elapsed: float = 0.0
    var frames: SpriteFrames = sprite.sprite_frames
    for index: int in range(frames.get_frame_count(sprite.animation)):
        var weight: float = frames.get_frame_duration(sprite.animation, index)
        total += weight
        if index < sprite.frame:
            elapsed += weight
        elif index == sprite.frame:
            elapsed += weight * sprite.frame_progress
    return fposmod(elapsed / maxf(total, 0.001), 1.0)

func _restore_cycle_phase(animation: StringName, phase: float) -> void:
    # แปลงสัดส่วนกลับเป็น frame/frame_progress ของชุดใหม่
    var frames: SpriteFrames = sprite.sprite_frames
    var count: int = frames.get_frame_count(animation)
    var total: float = 0.0
    for index: int in range(count):
        total += frames.get_frame_duration(animation, index)
    var cursor: float = phase * total
    for index: int in range(count):
        var weight: float = frames.get_frame_duration(animation, index)
        if cursor < weight or index == count - 1:
            sprite.set_frame_and_progress(index, clampf(cursor / maxf(weight, 0.001), 0.0, 1.0))
            return
        cursor -= weight

func resolve_animation(prefix: String, fallback: StringName) -> StringName:
    # ชอบชื่อ 4 ทิศก่อน; ภาพเก่าไม่ครบใช้ชื่อเดิมเพื่อให้โปรเจกต์ยังเปิดได้
    var directional := StringName(prefix + "_" + String(facing))
    if _has_frames(directional):
        # Atlas อนิเมะใช้ภาพด้านขวาร่วมกับด้านซ้าย ช่วยลดขนาด texture บนมือถือ
        # Resource รุ่นเดิมที่มีภาพซ้ายจริงไม่มี metadata นี้ จึงไม่ถูกกลับภาพซ้ำ
        sprite.flip_h = facing == &"left" and bool(sprite.sprite_frames.get_meta(&"mirror_left", false))
        return directional
    if _has_frames(fallback):
        sprite.flip_h = facing == &"left"
        return fallback
    return &""

func play_attack(direction: Vector2, fallback: StringName = &"attack") -> bool:
    return play_action(&"attack", direction, fallback)

func play_action(prefix: StringName, direction: Vector2, fallback: StringName) -> bool:
    # ล็อกท่า Attack ไม่ให้ Walk ทับ และใช้ความเร็วปกติเสมอ
    if not is_instance_valid(sprite) or sprite.sprite_frames == null:
        return false
    face_direction(direction)
    var animation: StringName = resolve_animation(String(prefix), fallback)
    if animation == &"" or sprite.sprite_frames.get_animation_loop(animation):
        return false
    action_locked = true
    if _scales_configured:
        sprite.scale = action_scales.get(prefix, motion_scale)
    sprite.speed_scale = 1.0
    sprite.stop()
    sprite.play(animation)
    _align_feet()
    return true

func reset_actions() -> void:
    # เปลี่ยนร่าง/สลบต้องล้าง lock ของชุดภาพเก่า
    action_locked = false
    if is_instance_valid(sprite):
        sprite.speed_scale = 1.0
        if _scales_configured:
            sprite.scale = motion_scale

func _has_frames(animation: StringName) -> bool:
    # ตรวจทั้งชื่อและจำนวนเฟรมก่อน play เพื่อไม่ให้เกิด error จาก Resource ว่าง
    return is_instance_valid(sprite) and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation) and sprite.sprite_frames.get_frame_count(animation) > 0

func _align_feet() -> void:
    # ปิด align_feet หากเฟรมมีพื้นที่โปร่งใสใต้เท้า แล้วตั้ง offset เอง
    if not align_feet or not is_instance_valid(sprite) or not _has_frames(sprite.animation):
        return
    var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
    if texture != null:
        sprite.offset.y = -texture.get_height() * 0.5

func _on_animation_finished() -> void:
    # เจ้าของอัปเดต Idle/Walk อีกครั้งใน physics frame ถัดไป
    action_locked = false
