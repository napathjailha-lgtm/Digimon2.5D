extends Node
## ตรวจพฤติกรรมจริง: พิกัดพื้นไม่สะสม, pause, ความเร็วหลังชน, และงบเงาไฟ
var failures: int = 0
var assertions: int = 0
var warnings_finished: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(ok: bool, description: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func run() -> void:
    get_tree().root.size = Vector2i(1280, 720)
    get_tree().root.content_scale_size = Vector2i(1280, 720)
    GameVisualSettings.motion_enabled = true
    GameVisualSettings.low_effects = false
    var origin := Vector2(9, 13)
    var basis: Transform2D = GroundProjection.make_transform(0.46, 0.12, 0, origin)
    check(basis.origin == origin and basis.x == Vector2.RIGHT and basis.y.is_equal_approx(Vector2(0.12, 0.46)), "ฐานพื้นบีบ Y และเฉือน X โดยรักษาจุดเท้า")
    for angle: float in [0.0, 0.4, 1.2]:
        var matrix: Transform2D = GroundProjection.make_transform(0.46, 0.12, angle, origin)
        var point := Vector2(25, -19)
        check((matrix.affine_inverse() * (matrix * point)).is_equal_approx(point) and matrix.determinant() > 0.0, "ฐานพื้นหมุนแล้วกลับพิกัดเดิมได้ angle=%s" % angle)
    var holder := Node2D.new()
    get_tree().root.add_child(holder)
    var actor: CharacterBody2D = CharacterBody2D.new()
    actor.set_script(preload("res://tests/fixtures/depth_motion_actor.gd"))
    actor.position = Vector2(900, 850)
    actor.collision_layer = 2
    actor.collision_mask = 1
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 16
    collision.shape = shape
    actor.add_child(collision)
    holder.add_child(actor)
    var buddy := Node2D.new()
    buddy.position = Vector2(1200, 850)
    holder.add_child(buddy)
    var shadow := DynamicFootShadow.new()
    actor.add_child(shadow)
    shadow.set_physics_process(false)
    check(shadow.blob.texture != null and shadow.z_index < 0 and not shadow.z_as_relative, "เงา Sprite อยู่ใต้ Actor เสมอและใช้ texture จริง")
    var old_transform: Transform2D = shadow.blob.transform
    for i: int in range(30):
        shadow.update_shadow(Vector2(190, 0), 1.0 / 30.0)
    check(not shadow.blob.transform.is_equal_approx(old_transform) and actor.scale == Vector2.ONE and shape.radius == 16, "เงาตอบสนองต่อการเดินโดยไม่ยืด body/collision")
    var shadow_b := DynamicFootShadow.new()
    actor.add_child(shadow_b)
    shadow_b.set_physics_process(false)
    for i: int in range(60):
        shadow_b.update_shadow(Vector2(190, 0), 1.0 / 60.0)
    check(shadow.blob.transform.x.distance_to(shadow_b.blob.transform.x) < 0.005, "เงาที่อัปเดต 30/60 Hz ให้ผลใกล้กัน")
    check(shadow.blob.material == shadow_b.blob.material and shadow.blob.texture == shadow_b.blob.texture, "เงาทุกตัวใช้ texture และ material ร่วมกัน")
    shadow.visual_height = 140
    for i: int in range(30):
        shadow.update_shadow(Vector2.ZERO, 1.0 / 30.0)
    check(shadow.blob.modulate.a < shadow.opacity and shadow.blob.position.length() > 10, "ภาพลอยสูงทำให้เงาจางและเลื่อนตามแสง")
    shadow.visual_height = 0
    var ring := GroundSkillIndicator.new()
    ring.position = Vector2(900, 850)
    ring.radius = 100
    holder.add_child(ring)
    var ring_basis: Transform2D = ring.visual.transform
    for i: int in range(20):
        ring.refresh_visual()
    check(ring.visual.transform.is_equal_approx(ring_basis) and ring.position == Vector2(900, 850), "refresh วงซ้ำไม่สะสมการบีบหรือย้ายจุดล็อกเป้า")
    check(ring.contains_world_point(ring.global_position + Vector2(70, 0)) and not ring.contains_world_point(ring.global_position + Vector2(0, 60)), "ฟังก์ชันพื้นที่วงใหม่ตรงกับวงรีที่แสดงจริง")
    var camera := PartyDepthCamera.new()
    camera.tamer = actor
    camera.partner = buddy
    actor.add_child(camera)
    check(camera.top_level and camera.party_focus().is_equal_approx(Vector2(952.8, 818)), "กล้องเฉลี่ยตำแหน่งคู่หูและจำกัดแรงดึงเมื่ออยู่ไกล")
    camera.set_physics_process(false)
    var resting_position: Vector2 = camera.global_position
    actor.global_position += Vector2(20, 0)
    check(camera.global_position == resting_position, "Camera ลูกของ Tamer ไม่รับ transform การเคลื่อนที่ซ้ำ")
    camera.set_physics_process(true)
    actor.set("commanded_velocity", Vector2(190, 0))
    await get_tree().create_timer(1.0).timeout
    check(camera.zoom.x < 0.88 and camera.zoom.x >= camera.moving_zoom - 0.005, "เคลื่อนเร็วแล้ว Tween ซูมออกเล็กน้อย")
    actor.set("commanded_velocity", Vector2.ZERO)
    await get_tree().create_timer(1.25).timeout
    check(absf(camera.zoom.x - camera.rest_zoom) < 0.006, "หยุดเดินแล้ว Tween ซูมคืน")
    ring.warning_finished.connect(func(): warnings_finished += 1)
    ring.start_warning(0.8)
    await get_tree().create_timer(0.12).timeout
    var previous_progress: float = ring.visual.progress
    var previous_camera: Vector2 = camera.global_position
    get_tree().paused = true
    await get_tree().create_timer(0.2, true).timeout
    check(is_equal_approx(ring.visual.progress, previous_progress) and camera.global_position == previous_camera, "เวลาเตือนและกล้องหยุดพร้อมโลกระหว่าง modal")
    get_tree().paused = false
    await ring.warning_finished
    check(warnings_finished == 1 and is_equal_approx(ring.visual.progress, 1), "วงเตือนจบครั้งเดียวหลังคืนเวลาเกม")
    ring.start_warning(0.12)
    ring.cancel_warning()
    await get_tree().create_timer(0.2).timeout
    check(warnings_finished == 1 and not ring.visual.warning, "ยกเลิกวงเตือนไม่มี callback เก่าหลงเหลือ")
    camera.offset = Vector2(2, 1)
    GameVisualSettings.motion_enabled = false
    actor.set("commanded_velocity", Vector2(80, 0))
    await get_tree().create_timer(0.1).timeout
    check(camera.zoom == Vector2.ONE * camera.rest_zoom and camera.offset == Vector2(2, 1), "Reduce Motion ปิดซูมและไม่เขียนทับ offset ของ Camera Shake")
    actor.set("commanded_velocity", Vector2.ZERO)
    var wall := StaticBody2D.new()
    wall.position = actor.position + Vector2(50, 0)
    var wall_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(10, 200)
    wall_shape.shape = rectangle
    wall.add_child(wall_shape)
    holder.add_child(wall)
    shadow.set_physics_process(true)
    actor.set("commanded_velocity", Vector2(190, 0))
    await get_tree().create_timer(0.8).timeout
    check(actor.get_real_velocity().length() < 1 and shadow._smoothed_velocity.length() < 2, "ดันติดกำแพงแล้วเงาหยุดตอบสนองต่อการเดินที่ไม่เกิดจริง")
    holder.queue_free()
    await get_tree().process_frame
    await _world_checks()
    print("PSEUDO3D RESULT assertions=", assertions, " failures=", failures)
    get_tree().quit(1 if failures > 0 else 0)

func _world_checks() -> void:
    GameManager.gameplay_active = false
    QuestManager.save_path = "user://pseudo3d_test_v21.json"
    QuestManager.reset_progress(false)
    var world := preload("res://scenes/world.tscn").instantiate() as Node2D
    get_tree().root.add_child(world)
    for i: int in range(4):
        await get_tree().physics_frame
    GameVisualSettings.motion_enabled = true
    GameVisualSettings.low_effects = false
    var env: OpenWorldEnvironment = world.get_node("OpenWorldEnvironment")
    var sun: WorldLighting = env.lighting
    sun.refresh_quality()
    var count: int = 0
    var positioned_correctly: bool = true
    for prop: Node2D in env.props:
        var occluder: LightOccluder2D = prop.get_node_or_null("LightOccluder2D")
        if occluder != null:
            count += 1
            positioned_correctly = positioned_correctly and occluder.show_behind_parent and occluder.occluder_light_mask == 1 and occluder.occluder.polygon[0].length() < 200
    check(count > 150 and positioned_correctly, "พร็อพมี Occluder พิกัด local ที่ฐานและ mask ตรงกับแสง")
    check(sun.sun.shadow_enabled and sun.sun.range_layer_max == 0, "แดดสร้างเงาจริงเฉพาะ canvas โลก ไม่ฉายทับ HUD")
    var shadow_lights: int = 0
    for lamp: PointLight2D in sun.lamps:
        if lamp.shadow_enabled:
            shadow_lights += 1
    check(shadow_lights <= 1, "โคมสร้างเงาจริงอย่างมาก 1 ดวงต่อเฟรม")
    var first_shadow: Sprite2D = env.shadows.get_child(0)
    var before: Transform2D = first_shadow.transform
    sun.set_sun_direction(140)
    check(not first_shadow.transform.is_equal_approx(before), "เปลี่ยนทิศแดดแล้วเงาพร็อพอัปเดตทันที")
    await get_tree().physics_frame
    var foot: DynamicFootShadow = world.get_node("Actors/Tamer/FootShadow")
    check(foot.light_source == sun, "เงาใต้เท้าอ่านผู้ให้ทิศแสงเดียวกับพร็อพ")
    var layers: DepthParallax = env.get_node("DepthLayers")
    check(layers.far.repeat_size.x == 2048 and layers.far.ignore_camera_scroll and not layers.far.follow_viewport, "ภูเขา repeat และไม่รับการเลื่อนกล้องสองครั้ง")
    check(layers.far.scroll_scale.x < layers.near.scroll_scale.x and layers.foreground.scroll_scale.x > 1, "ภูเขาไกลเลื่อนช้ากว่า และฉากหน้าเลื่อนเร็วกว่าโลก")
    check(world.get_node("Actors").y_sort_enabled and world.get_node("Actors/Tamer").scale == Vector2.ONE, "Actor ยังซ้อนภาพตามจุดเท้าโดยไม่บิด body")
    GameVisualSettings.low_effects = true
    sun.refresh_quality()
    await get_tree().process_frame
    await get_tree().process_frame # process_frame ส่งก่อน _process ของ DepthParallax
    var no_lamp_shadows: bool = true
    for lamp: PointLight2D in sun.lamps:
        no_lamp_shadows = no_lamp_shadows and not lamp.shadow_enabled
    check(not sun.sun.shadow_enabled and no_lamp_shadows and not layers.foreground.visible, "Low FX ปิดเงาไฟและฉากหน้าตกแต่ง")
    check(foot.blob.visible and env.shadows.get_child_count() > 100, "Low FX ยังมีเงาใต้เท้าและเงาพร็อพแบบสไปรต์")
    var tamer: Tamer = world.get_node("Actors/Tamer")
    tamer.survival.autosave_enabled = false
    var camera: PartyDepthCamera = tamer.get_node("Camera2D")
    tamer.position = Vector2(4200, 600)
    camera.snap_to_party()
    check(camera.global_position.distance_to(camera.party_focus()) < 0.01, "Warp คืนตำแหน่งเฉลี่ยกล้องและ interpolation")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    GameVisualSettings.low_effects = false
    GameVisualSettings.motion_enabled = true
