class_name DynamicFootShadow
extends Node2D
## เงาสีดำโปร่งแสงติดจุดเท้า รับทิศแสงและความเร็วจริงหลังชนกำแพง
@export var actor: CharacterBody2D
@export var light_source: Node2D
@export_range(6.0, 80.0) var radius: float = 18.0
@export_range(0.0, 1.0) var opacity: float = 0.32
@export_range(1.0, 30.0) var response: float = 10.0
@export var reference_speed: float = 190.0
## ความสูงทางภาพสำหรับกระโดด/ลอย ไม่ยก Collision
@export_range(0.0, 200.0) var visual_height: float = 0.0
const SHADOW_TEXTURE: Texture2D = preload("res://assets/depth/soft_shadow.png")
var blob: Sprite2D
var _smoothed_velocity := Vector2.ZERO
var _heading: float = 0.0
var _visual_scale := Vector2.ONE
static var _unlit_material: CanvasItemMaterial

func _ready() -> void:
    # Sprite เดียวต่อ Actor ใช้ texture ร่วมกันทุกตัว ไม่สร้างภาพใหม่ทุกเฟรม
    if actor == null:
        actor = get_parent() as CharacterBody2D
    if light_source == null:
        light_source = get_tree().get_first_node_in_group("depth_lighting") as Node2D
    z_as_relative = false
    z_index = -20
    blob = Sprite2D.new()
    blob.name = "ShadowSprite"
    blob.texture = SHADOW_TEXTURE
    blob.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    if _unlit_material == null:
        _unlit_material = CanvasItemMaterial.new()
        _unlit_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    blob.material = _unlit_material
    add_child(blob)
    update_shadow(Vector2.ZERO, 1.0)

func _physics_process(delta: float) -> void:
    # ความเร็วจริงไม่ทำให้เงาแกว่งต่อเมื่อดัน Joystick ติดกำแพง
    var movement: Vector2 = actor.get_real_velocity() if is_instance_valid(actor) else Vector2.ZERO
    update_shadow(movement, delta)

func update_shadow(movement: Vector2, delta: float) -> void:
    # Exponential smoothing ให้ผลใกล้กันบน 30/60/120 Hz และไม่ overshoot
    var blend: float = 1.0 - exp(-response * maxf(0.0, delta))
    _smoothed_velocity = _smoothed_velocity.lerp(movement, blend)
    var speed: float = clampf(_smoothed_velocity.length() / maxf(1.0, reference_speed), 0, 1)
    var rays := Vector2(0.82, 0.57)
    var length_ratio: float = 0.42
    if is_instance_valid(light_source) and light_source.has_method("get_shadow_direction"):
        rays = light_source.call("get_shadow_direction", global_position)
        length_ratio = float(light_source.call("get_shadow_length_ratio"))
    # ทิศแสงบนจอแปลงกลับสู่ระนาบก่อนหมุนฐานของวงเงา
    var on_ground := Vector2(rays.x, rays.y / 0.34).normalized()
    var walk: Vector2 = _smoothed_velocity.normalized()
    _heading = lerp_angle(_heading, on_ground.angle() + walk.x * speed * 0.08, blend)
    var parallel: float = absf(walk.dot(on_ground)) * speed
    var height_ratio: float = clampf(visual_height / 160.0, 0, 1)
    var wanted_scale := Vector2(1.10 + length_ratio * 0.4 + parallel * 0.12,
        1.0 - speed * 0.07) * lerpf(1.0, 0.65, height_ratio)
    _visual_scale = _visual_scale.lerp(wanted_scale, blend)
    # เปลี่ยนรูปเล็กน้อยให้เงามีน้ำหนัก ไม่สั่นจุดเท้าของ Actor
    var stretch := Transform2D(0.0,
        _visual_scale * (radius * 2.0 / SHADOW_TEXTURE.get_width()), 0.0, Vector2.ZERO)
    var center: Vector2 = rays * (3.0 + visual_height * 0.2) - walk * speed * 0.8
    blob.transform = GroundProjection.make_transform(0.34,
        0.04 + walk.x * speed * 0.05, _heading, center) * stretch
    blob.modulate = Color(0.015, 0.025, 0.035, opacity * lerpf(1.0, 0.45, height_ratio))
