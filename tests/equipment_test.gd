extends Node
## ทดสอบพฤติกรรมจริง: ใส่/ถอด, ไม่มี stacking/heal, ร่างไข่, JSON และ touch ขณะ pause
var failures: int = 0
var assertions: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(ok: bool, text: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", text)
    else:
        failures += 1
        push_error("FAIL: " + text)

func tap(control: Control) -> void:
    var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.index = 9
        event.position = point
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func run() -> void:
    get_tree().root.size = Vector2i(1280, 720)
    QuestManager.save_path = "user://equipment_test_v15.json"
    QuestManager.reset_progress(false)
    var world: Node2D = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    for i: int in range(4):
        await get_tree().physics_frame
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var hud: MobileHUD = world.get_node("MobileHUD")
    var inventory: EquipmentInventory = tamer.equipment
    var ui: EquipmentScreen = hud.equipment_screen
    for enemy: Node in get_tree().get_nodes_in_group("wild_monsters"):
        enemy.set_physics_process(false)
    var base_hp: int = tamer.max_hp
    var base_speed: float = tamer.move_speed
    var base_atk: int = partner.attack_power
    var base_partner_hp: int = partner.max_hp
    check(inventory.catalog.items.size() == 18 and inventory.equipped.is_empty(), "18 ไอเทมเริ่มในกระเป๋า ไม่เปลี่ยนฐาน v14")
    check(not inventory.put_on(&"missing"), "ไม่รับ ID ที่ไม่มี")
    check(not inventory.put_on(&"field_jacket", &"head") and inventory.count(&"field_jacket") == 1, "ช่องไม่ตรงไม่กินไอเทม")
    check(not inventory.put_on(&"crest_ring") and inventory.count(&"crest_ring") == 1, "ไอเทม Lv6 ปฏิเสธ Lv1")
    tamer.hp = 100
    tamer.ds = 40
    check(inventory.put_on(&"field_cap"), "สวมหมวก")
    check(tamer.max_hp == base_hp + 30 and tamer.hp == 100 and tamer.defense == 2, "หมวกเพิ่มฐานสูงสุด ไม่ฮีล")
    tamer.take_damage(10)
    check(tamer.hp == 92, "DF ลดความเสียหายจริง")
    tamer.take_damage(1)
    check(tamer.hp == 91, "ความเสียหายบวกมีขั้นต่ำ 1")
    tamer.take_damage(-20)
    check(tamer.hp == 91, "ความเสียหายติดลบไม่ฮีล")
    check(inventory.put_on(&"reinforced_cap"), "ใส่หมวกใหม่แทนช่องเดิม")
    check(inventory.count(&"field_cap") == 1 and inventory.count(&"reinforced_cap") == 0 and tamer.max_hp == base_hp + 65 and tamer.defense == 4, "ของเดิมคืน bag โบนัสแทนที่ไม่สะสม")
    check(not inventory.put_on(&"reinforced_cap"), "สวมสำเนาที่ไม่มีไม่ได้")
    for i: int in range(5):
        tamer.apply_progress_stats()
    check(tamer.max_hp == base_hp + 65, "รีเฟรชไม่บวกสเตตัสซ้ำ")
    check(inventory.put_on(&"trail_boots") and tamer.move_speed == base_speed + 12, "รองเท้าเปลี่ยนความเร็วสนาม")
    check(inventory.put_on(&"goggles") and tamer.max_ds == 110 and tamer.ds == 40, "แว่นเพิ่ม DS สูงสุด ไม่เติม DS ฟรี")
    tamer.ds = 110
    check(inventory.take_off(&"face") and tamer.max_ds == 100 and tamer.ds == 100, "ถอดแล้ว DS เกินเพดานถูก clamp")
    partner.hp = 40
    check(inventory.put_on(&"digi_device"), "ใส่ Digivice")
    check(partner.attack_power == base_atk + 8 and partner.max_hp == base_partner_hp + 50 and partner.hp == 40, "Digivice เพิ่ม HP/ATK คู่หู ไม่ฮีล")
    check(inventory.put_on(&"power_chip", &"chip_a") and inventory.put_on(&"vital_chip", &"chip_b"), "ชิปลงได้สองช่อง")
    check(partner.attack_power == base_atk + 20 and partner.max_hp == base_partner_hp + 130, "โบนัสชิปสองช่องรวมถูกต้อง")
    var old_damage: int = partner.attack_power
    check(partner.digivolve(), "เปลี่ยนร่างพร้อมอุปกรณ์")
    check(partner.attack_power == partner.current_form.attack + 20 and partner.attack_power > old_damage, "ATK ใช้ฐานร่างใหม่ + gear เดิม")
    partner.progress.add_exp(100)
    check(partner.attack_power == partner.current_form.attack + 25, "Level Up คง gear เพียงครั้งเดียว")
    var rng := RandomNumberGenerator.new()
    rng.seed = 80
    var damage: int = partner.active_skills[0].roll_damage(partner.attack_power, rng)
    check(damage >= floori(partner.attack_power * partner.active_skills[0].multiplier * 0.95), "ดาเมจสกิลใช้ ATK หลัง gear")
    partner.enter_fainted(false)
    check(inventory.take_off(&"device") and partner.hp == 0 and partner.state == PartnerMonster.State.EGG, "ถอด Digivice ขณะไข่ไม่ชุบชีวิต")
    check(inventory.put_on(&"digi_device") and partner.hp == 0 and not partner.is_alive(), "ใส่ขณะไข่ไม่ทำให้โจมตีได้")
    check(partner.recover() and partner.hp == partner.max_hp and partner.attack_power == partner.current_form.attack + 25, "Recover กลับ Rookie พร้อม gear + level")
    tamer.hp = tamer.max_hp
    check(inventory.take_off(&"head") and tamer.hp == base_hp and tamer.max_hp == base_hp, "ถอด HP gear clamp ไม่เหลือ HP เกินเพดาน")
    tamer.hp = 0
    check(inventory.put_on(&"field_cap") and tamer.hp == 0, "อุปกรณ์ไม่ชุบ Tamer HP0")
    tamer.hp = 120
    check(not inventory.grant_item(&"unknown") and inventory.grant_item(&"power_chip", 2), "API รางวัลตรวจ ID และเพิ่มจำนวน")
    tamer.progress.add_exp(100)
    check(tamer.max_hp == base_hp + 50 + 30 and tamer.move_speed == base_speed + 1 + 12, "Tamer Level Up รวม gear จากฐานใหม่")
    tamer.save_party_progress()
    var saved: Dictionary = JSON.parse_string(JSON.stringify(inventory.get_save_data()))
    var saved_profile: Dictionary = tamer.capture_party_state()
    var totals: Dictionary = inventory.total_bonuses()
    var other := EquipmentInventory.new()
    other.initialize(tamer)
    other.restore_data(saved)
    check(JSON.parse_string(JSON.stringify(other.get_save_data())) == saved and other.total_bonuses() == totals, "Equipment save JSON round trip")
    other.restore_data({"bag":{}, "equipped":{}})
    check(other.bag.is_empty() and other.equipped.is_empty(), "bag ว่างที่เซฟไว้ไม่รับ starter ซ้ำ")
    other.restore_data({"bag":{"unknown":5,"field_cap":-20},"equipped":{"head":"field_jacket","boots":"unknown","ring":"crest_ring"}})
    check(other.count(&"field_cap") == 0 and other.item_at(&"head") == null and other.item_at(&"boots") == null, "กรอง unknown/ผิดช่อง/จำนวนติดลบตอนโหลด")
    check(other.item_at(&"ring") == null and other.count(&"crest_ring") == 1, "เซฟของระดับสูงเกินคืนเข้ากระเป๋า")
    # ทดสอบ pipeline touch จริง ขณะ paused: ไม่เรียก callback โดยตรงแทนการแตะ
    tamer.set_target(null)
    tamer.joystick.move_vector = Vector2.RIGHT
    tamer.velocity = Vector2(100, 0)
    hud.menu.set_expanded(true, false)
    await get_tree().process_frame
    await get_tree().process_frame
    tap(hud.equipment_button)
    check(ui.is_open and get_tree().paused and not get_tree().quit_on_go_back, "แตะปุ่มอุปกรณ์ เปิด UI+pause และรับ Android Back")
    check(tamer.joystick.move_vector == Vector2.ZERO and tamer.velocity == Vector2.ZERO, "เปิดหน้าต่างล้างนิ้วจอย/ความเร็ว")
    var position: Vector2 = tamer.global_position
    var cooldown_before: Dictionary = partner.skill_cooldowns.duplicate()
    for i: int in range(8):
        await get_tree().process_frame
    check(tamer.global_position == position and partner.skill_cooldowns == cooldown_before, "โลกและคูลดาวน์หยุดขณะดูอุปกรณ์")
    tap(ui._bag_buttons["field_jacket"])
    check(ui.selected_item == &"field_jacket" and not ui._equip.locked, "เลือกจาก bag ผ่าน ScreenTouch")
    tap(ui._equip)
    check(inventory.item_at(&"chest").id == &"field_jacket" and ui._bag_buttons["field_jacket"].quantity == 0, "ปุ่มใส่ทำงานขณะ pause และจำนวน UI ตามจริง")
    tap(ui._slots["chest"])
    check(ui.selected_slot == &"chest" and not ui._unequip.locked, "เลือกอุปกรณ์ที่ใส่อยู่")
    tap(ui._unequip)
    check(inventory.item_at(&"chest") == null and inventory.count(&"field_jacket") == 1, "ปุ่มถอดคืน bag ขณะ pause")
    get_tree().root.size = Vector2i(1600, 720)
    await get_tree().process_frame
    check(ui._content.get_global_rect().position.x >= 0 and ui._content.get_global_rect().end.x <= 1600, "จอกว้าง 1600 ปรับหน้าต่างอยู่กลางและไม่ล้น")
    tap(ui._tabs[1])
    check(ui.active_tab == 1 and ui._slots["device"].visible and not ui._slots["head"].visible, "แท็บ Digivice มีช่องจริงแยกจากเสื้อผ้า")
    tap(ui._slots["chip_b"])
    tap(ui._bag_buttons["runner_chip"])
    tap(ui._equip)
    check(inventory.item_at(&"chip_b").id == &"runner_chip" and inventory.count(&"vital_chip") == 1, "เลือกเปลี่ยน Chip B โดยเฉพาะ ไม่ทับ Chip A")
    tap(ui._tabs[2])
    check(ui.active_tab == 2 and ui._skill_list.text.contains(partner.active_skills[0].display_name), "แท็บ Skill อ่านชุดร่างปัจจุบันจริง")
    var target_before: WildMonster = tamer.get_target()
    var touch := InputEventScreenTouch.new()
    touch.pressed = true
    touch.index = 10
    touch.position = Vector2(5, 500)
    Input.parse_input_event(touch)
    Input.flush_buffered_events()
    check(tamer.get_target() == target_before and ui.is_open, "แตะพื้นที่มืดไม่ทะลุเลือกศัตรู")
    tap(ui._close)
    check(not ui.is_open and not get_tree().paused and get_tree().quit_on_go_back, "ปิด X คืนเวลา/Android Back")
    get_tree().paused = true
    check(not ui.open_screen() and get_tree().paused, "ไม่เปิดอุปกรณ์แย่ง pause ของระบบอื่น")
    get_tree().paused = false
    partner.evolution_busy = true
    check(not ui.open_screen() and not inventory.take_off(&"head"), "ป้องกันแก้ gear ระหว่างเปลี่ยนร่าง")
    partner.evolution_busy = false
    check(ui.open_screen(), "เปิดซ้ำหลังปิดได้")
    var back := InputEventKey.new()
    back.keycode = KEY_ESCAPE
    back.pressed = true
    Input.parse_input_event(back)
    Input.flush_buffered_events()
    check(not ui.is_open and not get_tree().paused, "Esc ปิดผ่าน input จริง")
    var reopen_data: Dictionary = tamer.capture_party_state()
    world.queue_free()
    await get_tree().process_frame
    QuestManager.party_profile.clear()
    check(QuestManager.load_progress() and QuestManager.party_profile.has("equipment"), "โหลดไฟล์ user:// จริงมีข้อมูล equipment")
    var reloaded: Node2D = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(reloaded)
    var restored: Tamer = reloaded.get_node("Actors/Tamer")
    check(restored.equipment.get_save_data() == reopen_data.equipment, "เปลี่ยน Scene คืน bag/gear")
    check(restored.max_hp == tamer_max_from(reopen_data) and restored.hp == reopen_data.tamer_hp and restored.ds == reopen_data.ds, "โหลด gear ก่อน clamp HP/DS ไม่ล้างสถานะ")
    check(restored.partner.attack_power == restored.partner.current_form.attack + 25 and restored.partner.hp == reopen_data.hp, "partner คืนร่าง+level+gear+HP จากเซฟเดียวกัน")
    var restored_hud: MobileHUD = reloaded.get_node("MobileHUD")
    restored_hud.equipment_screen.open_screen()
    reloaded.queue_free()
    await get_tree().process_frame
    check(not get_tree().paused, "ลบ World ขณะเปิดหน้าต่างไม่ทำ pause ค้าง")
    QuestManager.party_profile = saved_profile
    QuestManager.party_profile.erase("equipment")
    var migrated: Node2D = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(migrated)
    await get_tree().process_frame
    var old_tamer: Tamer = migrated.get_node("Actors/Tamer")
    check(old_tamer.equipment.count(&"field_cap") == 1 and old_tamer.equipment.equipped.is_empty(), "เซฟ v14 ไม่มี equipment ยังคงเล่นและรับ starter ใน bag")
    migrated.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("ASSERTIONS: ", assertions)
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)

func tamer_max_from(profile: Dictionary) -> int:
    var bonus: int = 0
    for item_id: Variant in profile.equipment.equipped.values():
        bonus += (load(EquipmentInventory.CATALOG_PATH) as EquipmentCatalog).find_item(StringName(str(item_id))).hp_bonus
    return 200 + (int(profile.tamer_progress.level) - 1) * 50 + bonus
