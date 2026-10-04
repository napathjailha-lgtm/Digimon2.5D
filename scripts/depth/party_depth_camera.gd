class_name PartyDepthCamera
extends Camera2D
## กล้อง orthographic สร้างความรู้สึกมีมิติด้วยการจัดเฟรม/ซูมเพียงเล็กน้อย
@export var tamer: CharacterBody2D
@export var partner: Node2D
@export_range(0.0, 0.5) var partner_weight: float = 0.22
@export var max_partner_pull: float = 240.0
@export var framing_offset := Vector2(0, -32)
@export_range(1.0, 20.0) var follow_response: float = 8.0
@export var rest_zoom: float = 0.92
@export var moving_zoom: float = 0.865
@export var reference_speed: float = 190.0
@export var zoom_duration: float = 0.45
var _zoom_tween: Tween
var _requested_zoom: float = 0.92
var _zoom_timer: float = 0.0
var _filtered_speed: float = 0.0

func _ready() -> void:
    # ยังอยู่ที่ Tamer/Camera2D ให้ Cutscene หาเจอ แต่ไม่รับ transform ของ Tamer
    top_level = true
    if tamer == null:
        tamer = get_parent() as CharacterBody2D
    if partner == null and is_instance_valid(tamer):
        partner = tamer.get_parent().get_node_or_null("Partner") as Node2D
    process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
    process_physics_priority = 10 # ตาม Actor หลัง move_and_slide() ใน tick เดียวกัน
    position_smoothing_enabled = false # ทำ smoothing เอง ไม่เพิ่ม lag สองชั้น
    zoom = Vector2.ONE * rest_zoom
    _requested_zoom = rest_zoom
    snap_to_party()

func party_focus() -> Vector2:
    # ค่าเฉลี่ยถ่วงน้ำหนัก จำกัดระยะดึงกล้องถ้าคู่หูติดทางหรืออยู่ไกล
    if not is_instance_valid(tamer):
        return global_position
    var focus: Vector2 = tamer.global_position
    if is_instance_valid(partner):
        focus += (partner.global_position - focus).limit_length(max_partner_pull) * partner_weight
    return focus + framing_offset

func snap_to_party() -> void:
    # เรียกหลัง Warp/โหลดแผนที่ ไม่เลื่อนกล้องผ่านผนังจากตำแหน่งเก่า
    global_position = party_focus()
    reset_physics_interpolation()
    reset_smoothing()
    force_update_scroll()

func _physics_process(delta: float) -> void:
    if not is_instance_valid(tamer):
        return
    var desired: Vector2 = party_focus()
    var motion: bool = GameVisualSettings.motion_enabled
    var speed: float = tamer.get_real_velocity().length()
    _filtered_speed = lerpf(_filtered_speed, speed, 1.0 - exp(-5.0 * delta))
    # มองนำทิศเดินเล็กน้อย เห็นทางข้างหน้าโดยไม่ให้คู่หูหลุดเฟรม
    if motion:
        desired += tamer.get_real_velocity().limit_length(reference_speed) * 0.10
    if global_position.distance_squared_to(desired) > 800.0 * 800.0:
        snap_to_party()
    elif motion:
        global_position = global_position.lerp(desired, 1.0 - exp(-follow_response * delta))
    else:
        global_position = desired
    # ขอ Tween ใหม่อย่างมาก 5 ครั้ง/วินาที และเมื่อเป้าซูมต่างจริงเท่านั้น
    _zoom_timer -= delta
    if not motion:
        _request_zoom(rest_zoom, false)
    elif _zoom_timer <= 0.0:
        _zoom_timer = 0.2
        var ratio: float = clampf(_filtered_speed / maxf(1.0, reference_speed), 0, 1)
        _request_zoom(lerpf(rest_zoom, moving_zoom, smoothstep(0.15, 0.90, ratio)), true)

func _request_zoom(value: float, animate: bool) -> void:
    # ค่ายิ่งเล็ก = เห็นพื้นที่กว้างขึ้นใน Godot; offset สงวนให้ Camera Shake
    if animate and absf(value - _requested_zoom) < 0.004:
        return
    _requested_zoom = value
    if _zoom_tween != null and _zoom_tween.is_valid():
        _zoom_tween.kill()
    if not animate:
        zoom = Vector2.ONE * value
        return
    _zoom_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
    _zoom_tween.tween_property(self, "zoom", Vector2.ONE * value, zoom_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

