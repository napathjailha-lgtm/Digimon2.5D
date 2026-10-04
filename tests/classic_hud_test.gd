extends Node
## ทดสอบข้อมูล HUD และการรับ touch จริง ไม่ทดสอบภาพโดยเทียบ implementation
var failures: int = 0
var requests: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    if ok:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func touch_at(position: Vector2, down: bool, finger: int = 8) -> void:
    var event := InputEventScreenTouch.new()
    event.index = finger
    event.position = position
    event.pressed = down
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func tap(control: Control) -> void:
    var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    touch_at(point, true)
    touch_at(point, false)

func run() -> void:
    get_tree().root.size = Vector2i(1280, 720)
    QuestManager.save_path = "user://classic_hud_test.json"
    QuestManager.reset_progress(false)
    var world: Node2D = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    # ตรวจค่าข้อมูลทันทีใน regression นี้; visual_polish_test ตรวจ Tween แยกด้วยเวลาจริง
    hud.preferences.animations_enabled = false
    hud._layout()
    hud.preferences.save_path = "user://classic_hud_preferences_test.cfg"
    var chat: MobileChatPanel = hud.chat_panel
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var enemy: WildMonster = world.get_node("Spawners/SpawnerA").current_monster
    check(hud.party_panel.buttons[0].icon != null and hud.party_status._tamer_name.text.contains(tamer.display_name), "ปาร์ตี้มี portrait และหลอดกลางมีชื่อ Tamer จริง")
    tamer.take_damage(30)
    partner.take_damage(25)
    tamer.consume_ds(12)
    check(hud.party_status.tamer_hp.value == tamer.hp and hud.party_status.partner_hp.value == partner.hp, "HP เปลี่ยนแล้วหลอดทั้งสองตาม Signal")
    check(hud.party_status.ds_bar.value == tamer.ds and hud.party_status.mp_bar.value == partner.digimon_mp, "DS ของ Tamer กับ MP คู่หูอัปเดตแยกหลอด")
    check(hud.party_status.tamer_hp.size.y == 7 and hud.exp_strip.size.y <= 6, "หลอด HP/EXP เป็นเส้นบาง ไม่ถูกขั้นต่ำ Theme ขยายทับกัน")
    tamer.progress.add_exp(120)
    check(hud.party_status._tamer_name.text.contains("Lv2") and hud.exp_strip.value == 20, "เลเวล/EXP อัปเดตพร้อมกัน")
    check(chat.log_view.get_parsed_text().contains("Tamer เลเวลเพิ่มเป็น 2"), "Level Up มีข้อความใน System Chat")
    var rookie_portrait: Texture2D = hud.party_panel.buttons[0].icon
    tamer.ds = 100
    check(partner.digivolve(), "เปลี่ยน Champion เพื่อทดสอบ portrait")
    check(hud.party_status._partner_name.text.contains("Champion") and hud.party_panel.buttons[0].icon != rookie_portrait, "Portrait/ชื่อเปลี่ยนตาม Digivolve")
    partner.enter_fainted(false)
    check(hud.party_status.partner_hp.value == 0 and hud.party_status._partner_name.text.contains("DIGITAMA"), "แพ้แล้วกรอบแสดงไข่และ HP 0")
    check(partner.recover() and hud.party_status._partner_name.text.contains("Rookie"), "Recover คืนชื่อและรูป Rookie")

    tamer.set_target(enemy)
    check(hud.target_card.visible and hud._target_bar.value == enemy.hp, "เลือกศัตรูแล้วแสดงกรอบเป้าหมาย")
    enemy.take_damage(10)
    await get_tree().create_timer(0.18).timeout
    check(hud._target_bar.value == enemy.hp, "กรอบเป้าหมายอ่าน HP ล่าสุด")
    tap(hud.party_status)
    hud.minimap.show()
    tap(hud.minimap)
    tap(chat)
    check(tamer.target == enemy, "แตะกรอบเลือด/แผนที่/แชตไม่เลือกศัตรูทะลุ UI")
    var round_map := hud.minimap as RoundMinimap
    check(round_map._point(round_map.world_extent * 0.5).is_equal_approx(round_map._center()), "ศูนย์กลางโลกตรงศูนย์กลางมินิแมพวงกลม")
    check(round_map._point(Vector2.ZERO).x < round_map._point(round_map.world_extent).x, "มินิแมพแปลงพิกัดโลกจริงจากซ้ายไปขวา")

    # ตั้งนิ้วเดินค้าง แล้วแตะช่องพิมพ์เพื่อให้ปล่อยและหยุดนำทาง
    touch_at(hud.joystick.get_global_transform_with_canvas() * Vector2(175, 100), true, 1)
    check(hud.joystick.move_vector.length() > 0.0, "นิ้วซ้ายกำลังสั่งเดินก่อนพิมพ์")
    chat.set_collapsed(false)
    await get_tree().process_frame
    await get_tree().process_frame
    tap(chat.line_edit)
    await get_tree().process_frame
    check(chat.line_edit.has_focus() and hud.chat_editing, "แตะช่องพิมพ์ได้ focus")
    check(hud.joystick.move_vector == Vector2.ZERO and not hud.joystick.visible and not tamer.is_auto_navigating(), "เริ่มพิมพ์แล้วปล่อย Joystick/ยกเลิกนำทาง")
    check(hud.skill_panel.process_mode == Node.PROCESS_MODE_DISABLED, "พิมพ์แล้วหยุดรับคำสั่งสกิล")
    check(not get_tree().paused, "พิมพ์แชตไม่ pause โลก")
    chat._apply_keyboard_height(320)
    check(chat.line_edit.get_global_rect().end.y <= 400, "ช่องพิมพ์ยกเหนือคีย์บอร์ดสูง 320px")
    chat._apply_keyboard_height(0)
    chat.line_edit.text = "[b]ข้อความทดสอบ[/b] สวัสดี"
    var before: int = GameChat.messages.size()
    tap(chat.send_button)
    await get_tree().process_frame
    check(GameChat.messages.size() == before + 1 and chat.line_edit.text.is_empty(), "แตะส่งเพิ่มข้อความครั้งเดียวและล้างช่องพิมพ์")
    check(chat.log_view.get_parsed_text().contains("[b]ข้อความทดสอบ[/b]"), "ข้อความผู้เล่นไม่ถูกตีความเป็น BBCode")
    check(not hud.chat_editing and hud.joystick.visible, "ส่งข้อความแล้วคืนการควบคุม")
    touch_at(Vector2.ZERO, false, 1)
    tap(chat.tabs[2])
    check(chat.active_filter == &"system" and not chat.log_view.get_parsed_text().contains("[b]ข้อความทดสอบ"), "แท็บระบบกรองข้อความทั่วไป")
    tap(chat.tabs[1])
    check(chat.active_filter == &"local" and chat.log_view.get_parsed_text().contains("ข้อความทดสอบ"), "แท็บทั่วไปแสดงข้อความผู้เล่น")
    tap(chat.fold_button)
    await get_tree().process_frame
    check(chat.collapsed and chat.size.y <= 52 and not chat.line_edit.is_visible_in_tree(), "พับ Chat คืนพื้นที่สนาม")
    tap(chat.fold_button)
    await get_tree().process_frame
    check(not chat.collapsed and chat.line_edit.is_visible_in_tree(), "เปิด Chat กลับได้")
    check(not GameChat.submit_local(" \n\t "), "ข้อความว่างไม่ถูกส่ง")
    GameChat.submit_local("a".repeat(300))
    check(String(GameChat.messages.back().body).length() == 160, "จำกัดข้อความยาว 160 ตัวอักษร")

    # ตรวจกรอบหลักกับ hit area ของการเดินและสกิลใน Landscape สองขนาด
    for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
        get_tree().root.size = extent
        await get_tree().process_frame
        await get_tree().process_frame
        check(not chat.get_global_rect().intersects(hud.joystick.get_global_rect()), "แชตไม่ซ้อน Joystick ที่ %s" % extent)
        check(not hud.minimap.get_global_rect().intersects(hud.evolve_button.get_global_rect()) and not hud.minimap.get_global_rect().intersects(hud.auto_button.get_global_rect()), "Minimap ไม่ซ้อน Digivolve/Auto ที่ %s" % extent)
        for button: TouchCommand in hud.skill_panel.buttons:
            check(not chat.get_global_rect().intersects(button.get_global_rect()), "Chat ไม่ซ้อนสกิล %s ที่ %s" % [button.name, extent])
    get_tree().root.size = Vector2i(1280, 720)
    hud._toggle_stats()
    check(hud.smart_panel.is_open and hud.skill_panel.process_mode == Node.PROCESS_MODE_DISABLED, "เปิด Status ไม่กดสกิลผ่านหน้าต่าง")
    hud._toggle_stats()
    check(not hud.smart_panel.is_open and hud.skill_panel.process_mode == Node.PROCESS_MODE_INHERIT, "ปิด Status คืนแผงสกิล")
    for index: int in range(110):
        GameChat.add_system("ข้อความ %d" % index)
    check(GameChat.messages.size() == 100, "ประวัติแชตเก็บได้สูงสุด 100 ข้อความ")
    var history_size: int = GameChat.messages.size()
    world.queue_free()
    await get_tree().process_frame
    check(GameChat.messages.size() == history_size, "ออกจาก World ไม่ทำประวัติแชตหาย")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://classic_hud_preferences_test.cfg"))
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
