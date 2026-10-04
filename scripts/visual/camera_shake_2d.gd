class_name PolishedCameraShake2D
extends Node
## Offset เสริม ไม่แก้ตำแหน่ง Tamer และไม่กระทบ Camera Smooth Follow
@export var camera: Camera2D
@export var stage: Node2D
var _camera_rest := Vector2.ZERO
var _stage_rest := Vector2.ZERO
var _elapsed: float = 0.0
var _duration: float = 0.0
var _strength: float = 0.0
var _active: bool = false
var _noise := FastNoiseLite.new()

func _ready() -> void:
    # คัตซีน pause โลก แต่ตัวขยับ offset ต้องเดินต่อด้วยเวลา UI
    process_mode = Node.PROCESS_MODE_ALWAYS
    _noise.seed = 2048
    _noise.frequency = 0.8
    set_process(false)

func shake(strength_px: float = 4.0, duration: float = 0.28) -> void:
    # เก็บฐานใหม่หลังยกเลิกรอบเก่า ป้องกันสะสม offset จนกล้องเลื่อนถาวร
    stop_shake()
    if not GameVisualSettings.motion_enabled or GameVisualSettings.low_effects:
        return
    if is_instance_valid(camera):
        _camera_rest = camera.offset
    if is_instance_valid(stage):
        _stage_rest = stage.position
    _strength = clampf(strength_px, 0.0, 8.0)
    _duration = maxf(0.05, duration)
    _elapsed = 0.0
    _active = true
    set_process(true)

func _process(delta: float) -> void:
    # Noise ต่อเนื่องให้สั่นเนียนกว่า randf ทุกเฟรม แล้วลดแรงกลับศูนย์อย่างนุ่มนวล
    _elapsed += delta
    var decay: float = pow(maxf(0.0, 1.0 - _elapsed / _duration), 2.0)
    var time: float = _elapsed * 38.0
    var offset: Vector2 = Vector2(_noise.get_noise_1d(time), _noise.get_noise_1d(time + 73.0)) * _strength * decay * 2.0
    if is_instance_valid(camera):
        camera.offset = _camera_rest + offset
        camera.force_update_scroll() # Camera ของโลกที่ถูก pause ยังแสดง offset ได้
    if is_instance_valid(stage):
        stage.position = _stage_rest + offset # ภาพคัตซีนใน CanvasLayer ไม่ตาม Camera2D จึงขยับ stage ด้วย
    if _elapsed >= _duration:
        stop_shake()

func stop_shake() -> void:
    # คืนฐานตรง ๆ เมื่อจบ/ยกเลิกคัตซีน ไม่ปล่อยเศษค่าของ noise ติดกล้อง
    if _active:
        if is_instance_valid(camera):
            camera.offset = _camera_rest
            camera.force_update_scroll()
        if is_instance_valid(stage):
            stage.position = _stage_rest
    _active = false
    set_process(false)

func _exit_tree() -> void:
    # ปิด Scene ระหว่าง burst ก็ต้องคืน offset ก่อน Node ถูกลบ
    stop_shake()

