class_name DepthParallax
extends Node2D
## ฉากไกลบน CanvasLayer -1 อยู่หลังพื้นจริง; ฉากหน้ารับกล้องแต่เลื่อนเร็วกว่า
@export var camera: Camera2D
@export var world_extent := Vector2(5120, 3200)
@export var foreground_texture: Texture2D
var far: Parallax2D
var near: Parallax2D
var foreground: Parallax2D
const FAR_TEXTURE: Texture2D = preload("res://assets/depth/mountains_far.png")
const NEAR_TEXTURE: Texture2D = preload("res://assets/depth/mountains_near.png")
const SKY_TEXTURE: Texture2D = preload("res://assets/depth/sky_gradient.png")

func _ready() -> void:
    # CanvasLayer นี้ไม่มี Input/HUD และไม่ตาม zoom ของโลก ภูเขาจึงอยู่ไกลมาก
    var vista := CanvasLayer.new()
    vista.name = "FarVista"
    vista.layer = -1
    add_child(vista)
    var sky := TextureRect.new()
    sky.name = "Sky"
    sky.texture = SKY_TEXTURE
    sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vista.add_child(sky)
    far = _mountain_layer(vista, "FarMountains", FAR_TEXTURE, Vector2(0.12, 0.02), 35.0)
    near = _mountain_layer(vista, "NearMountains", NEAR_TEXTURE, Vector2(0.24, 0.04), 115.0)
    var cliff := DepthCliffEdge.new()
    cliff.name = "NorthCliffEdge"
    cliff.width = world_extent.x
    cliff.z_index = -95
    add_child(cliff)
    # ต้นไม้ด้านหน้าไม่มี collision; รากอยู่นอกทางเล่นและสีจาง ไม่บังเป้าหมาย
    foreground = Parallax2D.new()
    foreground.name = "ForegroundCanopy"
    foreground.scroll_scale = Vector2(1.07, 1.07)
    foreground.z_index = 150
    add_child(foreground)
    for point: Vector2 in [Vector2(375, 1490), Vector2(4300, 1770)]:
        if foreground_texture == null:
            break
        var sprite := Sprite2D.new()
        sprite.texture = foreground_texture
        sprite.offset.y = -foreground_texture.get_height() * 0.5
        sprite.position = point
        sprite.scale = Vector2.ONE * (390.0 / foreground_texture.get_height())
        sprite.modulate = Color(0.55, 0.78, 0.71, 0.26)
        foreground.add_child(sprite)

func _mountain_layer(parent: CanvasLayer, node_name: String, texture: Texture2D,
        scroll: Vector2, altitude: float) -> Parallax2D:
    # CanvasLayer อยู่คนละ canvas กับ Camera จึงส่ง scroll เองจากกล้องที่ clamp แล้ว
    # ignore_camera_scroll ป้องกันการเลื่อนอัตโนมัติซ้ำกับค่าที่ส่งจาก _process
    var layer := Parallax2D.new()
    layer.name = node_name
    layer.follow_viewport = false
    layer.ignore_camera_scroll = true
    layer.scroll_scale = scroll
    layer.repeat_size = Vector2(2048, 0)
    layer.repeat_times = 2
    parent.add_child(layer)
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.centered = false
    sprite.position = Vector2(-1024, altitude)
    sprite.scale = Vector2(2, 1)
    layer.add_child(sprite)
    return layer

func _process(_delta: float) -> void:
    # พื้นเดินจริงเลื่อน 1:1 เสมอ เฉพาะภูเขา/ยอดไม้ตกแต่งจึงมี parallax
    if not is_instance_valid(camera):
        return
    var center: Vector2 = camera.get_screen_center_position()
    far.scroll_offset = -center * far.scroll_scale
    near.scroll_offset = -center * near.scroll_scale
    foreground.visible = not GameVisualSettings.low_effects
    # Reduce Motion ให้ฉากหน้าเลื่อนเท่าพื้น เพื่อลด motion ที่ไม่จำเป็น
    foreground.scroll_scale = Vector2.ONE * (1.07 if GameVisualSettings.motion_enabled else 1.0)
