@tool
class_name WorldLighting
extends Node2D
## แสงโลกแยกจาก CanvasLayer ของ HUD จึงไม่ทำให้หลอดเลือด/ปุ่มมืด
@export var dusk: bool = false
## ทิศที่เงาทอดไปบนจอ หน่วยองศา; ใช้ร่วมกับเงา Sprite ของ Actor และพร็อพ
@export var sun_direction_degrees: float = 35.0
@export_range(0.15, 1.2) var finite_shadow_length: float = 0.46
@export var sun_occlusion_enabled: bool = true
signal sun_changed
var ambient: CanvasModulate
var sun: DirectionalLight2D
var lamps: Array[PointLight2D] = []
var player: Node2D
var update_left: float = 0.0

func _ready() -> void:
    add_to_group("depth_lighting")
    ambient = CanvasModulate.new()
    ambient.name = "Ambient"
    add_child(ambient)
    sun = DirectionalLight2D.new()
    sun.name = "WarmSun"
    sun.color = Color(1.0, 0.95, 0.80)
    # Directional เป็นแสงขนาน เงาจริงทอดยาวไม่สิ้นสุด; ใช้ alpha ต่ำให้พื้นยังอ่านง่าย
    # เงา Sprite อีกชั้นกำหนดความยาวจำกัดตามความสูงของภาพ ช่วยให้ต้นไม้มีมวล
    sun.shadow_enabled = true
    sun.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    sun.shadow_filter_smooth = 1.0
    sun.shadow_color = Color(0.07, 0.12, 0.18, 0.28)
    sun.shadow_item_cull_mask = 1
    sun.max_distance = 1200.0
    sun.range_layer_min = 0
    sun.range_layer_max = 0
    add_child(sun)
    apply_time_of_day()
    if not Engine.is_editor_hint():
        refresh_quality()

func get_shadow_direction(_world_point: Vector2 = Vector2.ZERO) -> Vector2:
    # ส่งทิศเดียวกันทุกระบบ แดดขนานจึงไม่ขึ้นกับตำแหน่งของผู้รับแสง
    return Vector2.from_angle(deg_to_rad(sun_direction_degrees))

func get_shadow_length_ratio() -> float:
    # ค่านี้ใช้ฉายภาพเท่านั้น ไม่ใช่ DirectionalLight2D.height ซึ่งมีไว้กับ normal map
    return finite_shadow_length

func set_sun_direction(degrees: float) -> void:
    # เปลี่ยนเวลา/มุมแดดแล้วอัปเดตเงาพร็อพครั้งเดียว ไม่วนคำนวณทุกพร็อพทุกเฟรม
    sun_direction_degrees = degrees
    sun.rotation = deg_to_rad(degrees) - PI * 0.5
    sun_changed.emit()

func add_lantern(point: Vector2) -> void:
    # GradientTexture2D เป็น texture แสงจริง ไม่ต้องมี PNG สีขาวเพิ่ม
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 256
    texture.height = 256
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1, 0.5)
    var light := PointLight2D.new()
    light.position = point + Vector2(0, -76)
    light.texture = texture
    light.texture_scale = 2.0
    light.color = Color(1.0, 0.71, 0.36)
    light.shadow_enabled = false # เลือกโคมที่ใกล้กล้องที่สุดภายใต้งบด้านล่าง
    light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    light.shadow_filter_smooth = 1.5
    light.shadow_color = Color(0.09, 0.13, 0.22, 0.55)
    light.shadow_item_cull_mask = 1
    light.range_layer_min = 0
    light.range_layer_max = 0
    lamps.append(light)
    add_child(light)
    light.energy = 0.75 if dusk else 0.16
    if not Engine.is_editor_hint() and HybridPlatform.is_web_mobile(get_viewport()):
        light.enabled = false

func toggle_time_of_day() -> void:
    dusk = not dusk
    apply_time_of_day()

func apply_time_of_day() -> void:
    if ambient == null:
        return
    ambient.color = Color(0.43, 0.51, 0.68) if dusk else Color(0.80, 0.84, 0.88)
    sun.energy = 0.12 if dusk else 0.19
    finite_shadow_length = 0.70 if dusk else 0.46
    set_sun_direction(22.0 if dusk else 35.0)
    for light: PointLight2D in lamps:
        light.energy = 0.75 if dusk else 0.16

func _process(delta: float) -> void:
    # โคมมีจำนวนจำกัดและเปิดเฉพาะใกล้กล้อง ลดภาระแสงบนมือถือ
    if Engine.is_editor_hint():
        return
    update_left -= delta
    if update_left > 0.0:
        return
    update_left = 0.2
    refresh_quality()

func refresh_quality() -> void:
    # Web Mobile: ambient light อย่างเดียว ลด shadow pass และ PointLight draw cost
    if HybridPlatform.is_web_mobile(get_viewport()):
        sun.shadow_enabled = false
        for light: PointLight2D in lamps:
            light.enabled = false
            light.shadow_enabled = false
        return

    # Desktop/native ใช้คุณภาพเดิม
    sun.shadow_enabled = sun_occlusion_enabled and not GameVisualSettings.low_effects
    sun.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    var camera: Camera2D = get_viewport().get_camera_2d()
    var center: Vector2 = camera.get_screen_center_position() if camera != null else Vector2.ZERO
    if camera == null and is_instance_valid(player):
        center = player.global_position
    var closest: PointLight2D
    var closest_distance: float = 650.0 * 650.0
    for light: PointLight2D in lamps:
        var distance: float = center.distance_squared_to(light.global_position)
        light.enabled = distance < 720.0 * 720.0
        light.shadow_enabled = false
        if light.enabled and distance < closest_distance:
            closest_distance = distance
            closest = light
    if closest != null and not GameVisualSettings.low_effects:
        closest.shadow_enabled = true
