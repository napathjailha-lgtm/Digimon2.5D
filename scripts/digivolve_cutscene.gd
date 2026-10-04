class_name DigivolveCutscene
extends CanvasLayer
## CanvasLayer อยู่ใต้ root ของ SceneTree และทำงาน ALWAYS ระหว่างเกม pause
signal finished(success: bool)
@onready var player: AnimationPlayer = $AnimationPlayer
@onready var old_sprite: Sprite2D = $Root/Stage/OldSprite
@onready var new_sprite: Sprite2D = $Root/Stage/NewSprite
@onready var stage: Node2D = $Root/Stage
var dust: DigitalPixelDust
var shake_fx: PolishedCameraShake2D
var visual_fx: ModalVisualFX
var _partner: PartnerMonster
var _tree: SceneTree
var _old_scale: Vector2 = Vector2.ONE
var _new_scale: Vector2 = Vector2.ONE
var _previous_paused: bool = false
var _owns_pause: bool = false
var _finished: bool = false

@export var old_size_multiplier: float = 1.0:
    set(value):
        old_size_multiplier = value
        if is_instance_valid(old_sprite):
            old_sprite.scale = _old_scale * value
@export var new_size_multiplier: float = 1.0:
    set(value):
        new_size_multiplier = value
        if is_instance_valid(new_sprite):
            new_sprite.scale = _new_scale * value
@export var flash_amount: float = 0.0:
    set(value):
        flash_amount = value
        if is_instance_valid(old_sprite) and old_sprite.material != null:
            old_sprite.material.set_shader_parameter("white_flash", value)

func _ready() -> void:
    # ลูก AnimationPlayer และ Timer สืบทอด ALWAYS จึงไม่หยุดพร้อมสนาม
    process_mode = Node.PROCESS_MODE_ALWAYS
    _tree = get_tree()
    player.animation_finished.connect(_on_animation_finished)
    $Watchdog.timeout.connect(cancel)
    var material := ShaderMaterial.new()
    material.shader = preload("res://assets/white_flash.gdshader")
    old_sprite.material = material
    $Root.resized.connect(_layout_cutscene)
    _layout_cutscene()
    dust = DigitalPixelDust.new()
    dust.position = Vector2(0, 100)
    stage.add_child(dust)
    stage.move_child(dust, 0)
    shake_fx = PolishedCameraShake2D.new()
    shake_fx.stage = stage
    add_child(shake_fx)
    visual_fx = ModalVisualFX.attach($Root, $Root/Title)

func _layout_cutscene() -> void:
    # รองรับ Landscape ที่กว้างกว่า 16:9 เมื่อใช้ stretch/aspect=expand
    if is_instance_valid(shake_fx):
        shake_fx.stop_shake()
    stage.position = $Root.size * 0.5 + Vector2(0, -10)
    old_sprite.position = Vector2.ZERO
    new_sprite.position = Vector2.ZERO

func play_for(partner: PartnerMonster) -> bool:
    # ไม่ซ้อนคัตซีนหรือเปิดทับ pause จากเมนูอื่น และตรวจสิทธิ์ก่อนเริ่ม
    if _owns_pause or _tree.paused or not is_instance_valid(partner):
        return false
    var next_data: MonsterData = partner.prepare_digivolve()
    if next_data == null:
        return false
    _partner = partner
    _partner.tree_exiting.connect(cancel)
    old_sprite.texture = WalkTextureTools.visible_texture(partner.current_form.sprite_frames.get_frame_texture(partner.current_form.idle_animation, 0))
    new_sprite.texture = WalkTextureTools.visible_texture(next_data.sprite_frames.get_frame_texture(next_data.idle_animation, 0))
    _old_scale = Vector2.ONE * (220.0 / maxf(old_sprite.texture.get_width(), old_sprite.texture.get_height()))
    _new_scale = Vector2.ONE * (300.0 / maxf(new_sprite.texture.get_width(), new_sprite.texture.get_height()))
    $Root/Caption.text = partner.current_form.monster_name + "  →  " + next_data.monster_name
    # ล้างนิ้วที่ปล่อยระหว่าง pause จะไม่ส่ง release กลับถึง Joystick
    if is_instance_valid(partner.tamer):
        partner.tamer.cancel_auto_navigation()
        partner.tamer.velocity = Vector2.ZERO
        if is_instance_valid(partner.tamer.joystick):
            partner.tamer.joystick.release_input()
    _previous_paused = _tree.paused
    _owns_pause = true
    _tree.paused = true
    # GPUParticles และเอฟเฟกต์ UI อยู่ใน ALWAYS จึงปล่อยละอองต่อได้ขณะโลกหยุด
    shake_fx.camera = partner.tamer.get_node_or_null("Camera2D") as Camera2D if is_instance_valid(partner.tamer) else null
    dust.start_dust()
    visual_fx.animate_open()
    # เริ่ม Evolution Theme พร้อมหรี่ BGM ฉากหลัก โดย AudioManager ทำงานต่อแม้ SceneTree pause
    AudioManager.play_evolution_theme()
    player.play(&"evolve")
    player.advance(0.0)
    $Watchdog.start()
    return true

func energy_burst() -> void:
    # AnimationPlayer เรียกตรงจุดแฟลช 1.37s จึงซิงก์ SFX กับคีย์เฟรมจริง ไม่ใช้ Timer เดาเวลา
    shake_fx.shake(5.0, 0.32)
    AudioManager.play_sfx(&"evolution_burst", -4.0)

func _input(event: InputEvent) -> void:
    # กิน touch ทั้งจอ ป้องกันการสั่งโจมตี/เลือกเป้าหมายทะลุคัตซีน
    if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
        get_viewport().set_input_as_handled()

func _on_animation_finished(animation: StringName) -> void:
    # เปลี่ยนตัวจริงเฉพาะเมื่อ AnimationPlayer เล่นจนจบ
    if animation == &"evolve" and not _finished:
        var success: bool = is_instance_valid(_partner) and _partner.finish_digivolve()
        _finish(success)

func cancel() -> void:
    # ใช้เมื่อเปลี่ยน Scene/ปิดคัตซีน หรือ Watchdog พบว่า Animation ไม่จบ
    if not _finished:
        _finish(false)

func _finish(success: bool) -> void:
    # ทำครั้งเดียว ป้องกัน animation_finished และ timeout เรียกซ้อนกัน
    if _finished:
        return
    _finished = true
    dust.stop_dust()
    shake_fx.stop_shake()
    visual_fx.reset()
    $Watchdog.stop()
    if not success and is_instance_valid(_partner):
        _partner.abort_digivolve()
        if is_instance_valid(_partner.tamer):
            _partner.tamer.save_party_progress()
    # success/cancel ต้องคืน BGM เสมอ เพื่อไม่ทิ้ง Evolution Theme ค้างบน Web
    AudioManager.finish_evolution_theme()
    _restore_pause()
    finished.emit(success)
    queue_free()

func _restore_pause() -> void:
    # คืนสถานะเดิมเฉพาะ pause ที่คัตซีนนี้เป็นผู้ถือครอง
    if _owns_pause and is_instance_valid(_tree):
        _tree.paused = _previous_paused
    _owns_pause = false

func _exit_tree() -> void:
    # เผื่อมีผู้เรียก queue_free() โดยตรง: ต้องไม่ทิ้งสนามไว้ในสถานะ pause
    if is_instance_valid(_partner) and _partner.evolution_busy:
        _partner.abort_digivolve()
        if is_instance_valid(_partner.tamer):
            _partner.tamer.save_party_progress()
    _restore_pause()
