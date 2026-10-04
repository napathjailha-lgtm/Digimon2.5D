extends Node
## ทดสอบผลลัพธ์กับ Signal/touch/pause จริง ไม่เพียงตรวจชื่อ Node
var failures: int = 0

func _ready() -> void:
    # UI test ต้องเดินต่อได้ขณะเปิด modal ที่หยุดโลก
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    # รวมความผิดพลาดให้เห็นทุกประเด็นในหนึ่ง run
    if ok:
        print("PASS: ",message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func touch(control: Control, finger: int, down: bool, canceled: bool = false) -> void:
    # ส่งเข้า input pipeline จริง เพื่อจับการแย่งนิ้ว/ปล่อยนิ้วหลัง pause
    var event := InputEventScreenTouch.new()
    event.index = finger
    event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
    event.pressed = down
    event.canceled = canceled
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func run() -> void:
    get_tree().root.size = Vector2i(1280,720)
    get_tree().root.content_scale_size = Vector2i(1280,720)
    # เซฟทดสอบอยู่คนละชื่อกับตัวละครจริง และเลือกค่าภาพแน่นอนทุกครั้ง
    QuestManager.save_path = "user://visual_polish_test.json"
    QuestManager.reset_progress(false)
    GameVisualSettings.motion_enabled = true
    var world := preload("res://tests/fixtures/arena_v13.tscn").instantiate() as Node2D
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var tamer := world.get_node("Actors/Tamer") as Tamer
    var partner := world.get_node("Actors/Partner") as PartnerMonster
    # สนาม fixture เดิมไม่มี Camera แต่ world จริงมี: เพิ่มเฉพาะ test ให้ตรวจ offset ได้
    var test_camera := Camera2D.new()
    test_camera.name = "Camera2D"
    test_camera.process_callback = 0
    tamer.add_child(test_camera)
    var hud := world.get_node("MobileHUD") as MobileHUD
    hud.preferences.save_path = "user://visual_polish_test.cfg"
    hud.preferences.animations_enabled = true
    hud.preferences.blur_enabled = true
    hud.preferences.low_effects = false
    hud._layout()
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    tamer.survival.set_process(false)
    tamer.survival.autosave_enabled = false
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var bar: HybridVitalsBar = hud.party_status.tamer_hp
    var initial: int = tamer.hp
    tamer.take_survival_damage(50)
    check(tamer.hp == initial - 50 and bar.value > tamer.hp,"HP จริงลดทันที ภาพหลอดเริ่มไหลโดยไม่เลื่อนกติกาเกม")
    await get_tree().create_timer(0.10,true).timeout
    tamer.restore_hp(10)
    tamer.take_survival_damage(20)
    await get_tree().create_timer(0.40,true).timeout
    check(is_equal_approx(bar.value,tamer.hp),"damage/heal ถี่ ๆ จบที่ค่าล่าสุด ไม่ถูก Tween เก่าเขียนทับ")
    tamer.ds = 100
    tamer.ds_changed.emit(tamer.ds,tamer.max_ds)
    hud._toggle_stats()
    check(get_tree().paused and hud.smart_panel.is_open,"Status ถือ pause ระหว่าง UI ทำงาน")
    await get_tree().create_timer(0.40,true).timeout
    check(is_equal_approx(hud.smart_panel.panel.scale.x,1.0),"popup จบที่ scale 1.0 แม้โลก pause")
    check(not hud.inventory_screen.open_screen(),"Inventory ไม่เปิดทับ Status หรือแย่ง pause")
    hud.smart_panel.close_screen()
    check(not get_tree().paused,"ปิด popup แล้วคืนเวลาเกม")
    tamer.hp = 20
    tamer.check_battle_permission()
    tamer.hp_changed.emit(tamer.hp,tamer.max_hp)
    await get_tree().process_frame
    check(not tamer.can_battle() and hud.critical_fx._rect.visible and hud.attack_button.locked,"Cannot Battle ล็อกปุ่มและแสดงขอบแดงจากข้อมูลจริง")
    tamer.restore_hp(tamer.max_hp)
    check(not hud.critical_fx._rect.visible,"HP ฟื้นถึงเกณฑ์แล้วขอบแดงดับ")
    var skill: TouchCommand = hud.cycle_button
    touch(hud.joystick,0,true)
    touch(skill,1,true)
    await get_tree().create_timer(0.10,true).timeout
    check(skill.scale.x < 1.0 and hud.joystick._finger == 0,"กดนิ้วที่สองแล้วปุ่มยุบ โดยจอยยังถือ finger 0")
    touch(skill,1,false,true)
    touch(hud.joystick,0,false)
    await get_tree().create_timer(0.30,true).timeout
    check(is_equal_approx(skill.scale.x,1.0) and skill._finger == -1,"touch canceled คืนสเกลและนิ้วได้")
    tamer.ds = 100
    tamer.command_digivolve()
    var cutscene: DigivolveCutscene = hud.active_cutscene
    check(is_instance_valid(cutscene) and cutscene.dust.gpu.emitting,"คัตซีนเริ่ม GPUParticles2D จริงพร้อม pause")
    if is_instance_valid(cutscene):
        var camera := tamer.get_node("Camera2D") as Camera2D
        var rest: Vector2 = camera.offset
        cutscene.energy_burst()
        await get_tree().create_timer(0.09,true).timeout
        check(not camera.offset.is_equal_approx(rest),"กล้องสั่นต่อได้ขณะโลก pause")
        cutscene.cancel()
        check(camera.offset.is_equal_approx(rest) and not get_tree().paused and tamer.ds == 100,"ยกเลิก burst คืน offset, DS และ pause")
    # โหมดเอฟเฟกต์น้อยต้องเปลี่ยนผลการวาด ไม่ใช่เพียงเปลี่ยนข้อความใน Settings
    hud.preferences.low_effects = true
    hud._layout()
    tamer.command_digivolve()
    cutscene = hud.active_cutscene
    check(is_instance_valid(cutscene) and cutscene.dust.cpu.emitting and not cutscene.dust.gpu.emitting,"เอฟเฟกต์น้อยใช้ CPU 24 เม็ดแทน GPU 56 เม็ด")
    if is_instance_valid(cutscene):
        cutscene.energy_burst()
        check(not cutscene.shake_fx._active,"เอฟเฟกต์น้อยไม่สั่นกล้อง")
        cutscene.cancel()
    hud.inventory_screen.open_screen()
    check(hud.inventory_screen.visual_fx.blur.material == null,"เอฟเฟกต์น้อยใช้หรี่แสงแทนอ่าน screen texture")
    hud.inventory_screen.close_screen()
    hud.preferences.low_effects = false
    # BaseButton ที่สร้างทีหลังในหน้าเมนูต้องรับสคริปต์เอฟเฟกต์ร่วมกันด้วย
    var standard := Button.new()
    standard.size = Vector2(160,56)
    add_child(standard)
    await get_tree().process_frame
    await get_tree().process_frame
    standard.button_down.emit()
    await get_tree().create_timer(0.12,true).timeout
    check(standard.get_node_or_null("VisualFX") != null and standard.scale.x < 1.0,"ปุ่ม BaseButton มาตรฐานรับ FX อัตโนมัติ")
    standard.button_up.emit()
    standard.queue_free()
    hud.preferences.animations_enabled = false
    hud._layout()
    tamer.take_survival_damage(30)
    check(is_equal_approx(bar.value,tamer.hp),"Reduce Motion แสดง HP ใหม่ทันที")
    touch(hud.cycle_button,1,true)
    check(is_equal_approx(hud.cycle_button.scale.x,1.0),"Reduce Motion ไม่ย่อปุ่ม")
    touch(hud.cycle_button,1,false)
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ",failures," failure(s)")
    get_tree().quit(1 if failures else 0)
