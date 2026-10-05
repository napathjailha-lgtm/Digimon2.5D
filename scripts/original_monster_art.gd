class_name OriginalMonsterArt
extends RefCounted
## สร้าง SpriteFrames แบบ static จากภาพต้นฉบับของโปรเจกต์
## ใช้ภาพเดียวซ้ำใน 4 ทิศ/Action เพื่อให้ระบบเล่นได้ทันที
## รอบถัดไปค่อยแทนด้วย sprite animation จริงโดยไม่ต้องเปลี่ยน MonsterData

static func make_static_frames(texture: Texture2D) -> SpriteFrames:
    var frames := SpriteFrames.new()
    if frames.has_animation(&"default"):
        frames.remove_animation(&"default")

    for direction: String in ["down", "right", "up", "left"]:
        _add_loop(frames, StringName("idle_" + direction), texture, 1, 2.0)
        _add_loop(frames, StringName("walk_" + direction), texture, 4, 6.0)
        _add_action(frames, StringName("attack_" + direction), texture, 4, 10.0)
        _add_action(frames, StringName("cast_" + direction), texture, 4, 10.0)

    return frames


static func _add_loop(frames: SpriteFrames, name: StringName, texture: Texture2D, count: int, fps: float) -> void:
    frames.add_animation(name)
    frames.set_animation_loop(name, true)
    frames.set_animation_speed(name, fps)
    for _i: int in range(count):
        frames.add_frame(name, texture)


static func _add_action(frames: SpriteFrames, name: StringName, texture: Texture2D, count: int, fps: float) -> void:
    frames.add_animation(name)
    frames.set_animation_loop(name, false)
    frames.set_animation_speed(name, fps)
    for _i: int in range(count):
        frames.add_frame(name, texture)
