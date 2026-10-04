class_name PartnerCombatAction
extends Node
## เตรียมท่า → Impact frame → คืนท่า; ผูก hit กับ frame_changed จริง
signal impact
signal finished
signal canceled
@export var sprite: AnimatedSprite2D
@export var animator: DirectionalAnimator
var busy: bool = false
var _animation: StringName = &""
var _frames: SpriteFrames
var _hit_frame: int = 0
var _impact_sent: bool = false
var _starting: bool = false

func _ready() -> void:
    sprite.frame_changed.connect(_on_frame_changed)
    sprite.animation_finished.connect(_on_animation_finished)
    sprite.animation_changed.connect(_on_animation_changed)

func can_begin(prefix: StringName, direction: Vector2, fallback: StringName) -> bool:
    # ตรวจภาพก่อนหัก DS/CD และไม่เริ่มท่าใหม่ทับท่าที่กำลังเล่น
    if busy or not is_instance_valid(sprite) or sprite.sprite_frames == null:
        return false
    animator.face_direction(direction)
    var animation: StringName = animator.resolve_animation(String(prefix), fallback)
    return animation != &"" and not sprite.sprite_frames.get_animation_loop(animation)

func begin(prefix: StringName, direction: Vector2, fallback: StringName, hit_frame: int) -> bool:
    # เจ้าของต้องเตรียมเป้าหมาย/ดาเมจก่อน begin เพราะ hit_frame=0 อาจ emit ทันที
    if not can_begin(prefix, direction, fallback):
        return false
    _animation = animator.resolve_animation(String(prefix), fallback)
    _frames = sprite.sprite_frames
    _hit_frame = clampi(hit_frame, 0, _frames.get_frame_count(_animation) - 1)
    _impact_sent = false
    busy = true
    _starting = true
    var started: bool = animator.play_action(prefix, direction, fallback)
    _starting = false
    if not started:
        cancel()
        return false
    _on_frame_changed()
    return true

func cancel() -> void:
    # ยกเลิกเมื่อเปลี่ยนเป้า/ร่าง สลบ หรือเข้าคัตซีน ไม่มี callback ลงดาเมจภายหลัง
    if not busy:
        return
    busy = false
    _animation = &""
    _frames = null
    animator.reset_actions()
    sprite.stop()
    canceled.emit()

func _on_frame_changed() -> void:
    # ตั้ง latch ก่อน emit กัน signal ที่เรียกกลับมาสร้าง hit ซ้ำ
    if not busy or _starting or _impact_sent or get_tree().paused:
        return
    if sprite.sprite_frames != _frames or sprite.animation != _animation:
        cancel()
        return
    if sprite.frame >= _hit_frame:
        _impact_sent = true
        impact.emit()

func _on_animation_finished() -> void:
    # Attack/Cast ต้องปิด Loop จึงจะได้ animation_finished
    if not busy or sprite.animation != _animation:
        return
    busy = false
    _animation = &""
    _frames = null
    animator.reset_actions()
    finished.emit()

func _on_animation_changed() -> void:
    # ป้องกันระบบอื่น play() ทับโดยไม่ได้ยกเลิกแอคชั่นก่อน
    if busy and not _starting and sprite.animation != _animation:
        cancel()
