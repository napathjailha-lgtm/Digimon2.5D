extends Node
## ทดสอบเวลาจริง, threshold, DS/MP, สกิลค้าง, อาหาร, Safe Zone, save และ UI ผ่าน Actor จริง
var failures: int = 0
var permission_events: int = 0
var world: Node2D
var tamer: Tamer
var partner: PartnerMonster
var hud: MobileHUD
var clock: TamerSurvival
var enemy: WildMonster
func _ready() -> void:
    run.call_deferred()
func check(ok: bool, message: String) -> void:
    if ok: print("PASS: ",message)
    else:
        failures += 1
        push_error("FAIL: "+message)
func reset_stats(hunger: float = 100, stamina: float = 100) -> void:
    # Reset ค่าที่กำหนดเพื่อทดสอบแต่ละเงื่อนไข ไม่เปลี่ยน scene/resources ต้นแบบ
    partner.abort_digivolve()
    partner.cancel_battle()
    partner.auto_battle = false
    if not partner.is_alive(): partner.recover()
    tamer.hp = tamer.max_hp
    partner.load_monster_data(partner.forms[0],false)
    partner.digimon_mp = partner.digimon_max_mp
    partner.skill_cooldowns.clear()
    partner._basic_cooldown = 0
    tamer.ds = tamer.max_ds
    clock.restore_data({"hunger":hunger,"stamina":stamina})
func tap(control: Control) -> void:
    for down: bool in [true,false]:
        var event := InputEventScreenTouch.new()
        event.index = 8
        event.position = control.get_global_transform_with_canvas() * (control.size * .5)
        event.pressed = down
        Input.parse_input_event(event)
        Input.flush_buffered_events()
func run() -> void:
    get_tree().root.size = Vector2i(1280,720)
    GameManager.gameplay_active = false
    QuestManager.save_path = "user://survival_status_test.json"
    QuestManager.reset_progress(false)
    world = preload("res://tests/fixtures/arena_v13.tscn").instantiate()
    get_tree().root.add_child(world)
    await get_tree().physics_frame
    await get_tree().physics_frame
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    hud = world.get_node("MobileHUD")
    clock = tamer.survival
    clock.autosave_enabled = false
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    clock.set_process(false)
    for node: Node in get_tree().get_nodes_in_group("wild_monsters"): node.set_physics_process(false)
    enemy = world.get_node("Spawners/SpawnerA").current_monster
    enemy.loot_enabled = false
    tamer.battle_permission_changed.connect(func(_allow: bool):permission_events+=1)
    InventoryManager.bind_player(tamer,{})
    check(tamer.tamer_hp == tamer.hp and partner.digimon_hp == partner.hp,"ชื่อสเตตัสใหม่และ alias เดิมอ่านค่าชุดเดียว")
    check(tamer.tamer_hunger == 100 and tamer.tamer_stamina == 100 and partner.digimon_mp == 100,"เริ่มหิว/แรง/MP เต็ม แยก instance")
    reset_stats()
    clock.advance(4.75)
    check(tamer.tamer_hunger == 100,"4.75s ยังไม่ครบรอบหิว")
    clock.advance(.25)
    check(tamer.tamer_hunger == 99,"5s หิวลด 1 แม้เรียกด้วย delta หลายขนาด")
    clock.advance(10)
    check(tamer.tamer_hunger == 97,"10s เพิ่มคิดครบสองรอบ ไม่หายเมื่อ frame ใหญ่")
    var one_call: Dictionary = clock.get_save_data()
    reset_stats()
    for _i: int in range(150): clock.advance(.1)
    check(tamer.tamer_hunger == one_call.hunger,"150 เฟรมเล็กเท่ากับ 15s รวม ผลไม่ขึ้นกับ FPS")
    reset_stats(1,100)
    clock.advance(5)
    check(tamer.tamer_hunger == 0 and tamer.hp == 200,"หิวเพิ่งถึงศูนย์ไม่ทำดาเมจย้อนหลัง 5s")
    clock.advance(2.75)
    check(tamer.hp == 200,"อดอาหาร 2.75s ยังไม่โดนดาเมจ")
    var partner_hp: int = partner.hp
    var partner_mp: float = partner.digimon_mp
    tamer.defense = 999
    clock.advance(.25)
    check(tamer.hp == 195,"ครบ 3s อดอาหาร HP -5 แม้ใส่เกราะสูง")
    check(partner.hp == partner_hp and partner.digimon_mp == partner_mp,"อดอาหารไม่หัก HP/MP ของคู่หู")
    tamer.defense = 0
    reset_stats(100,1)
    partner.command_attack(enemy)
    clock.advance(1)
    check(tamer.tamer_stamina == 0 and tamer.hp == 200,"Battle ทำให้แรงลดตามวินาที")
    clock.advance(3)
    check(tamer.hp == 195,"แรงศูนย์ 3s ทำดาเมจ 5")
    partner.cancel_battle()
    clock.advance(1)
    check(tamer.tamer_stamina > 0,"ออก Battle และยังอิ่ม ฟื้นแรงได้")
    reset_stats(0,0)
    partner.command_attack(enemy)
    clock.advance(3)
    check(tamer.hp == 190,"หิว/เหนื่อยศูนย์พร้อมกันดาเมจ 5+5 ไม่หักซ้ำเกินรอบ")
    reset_stats()
    check(partner.digivolve(),"เตรียม Champion สำหรับทดสอบ debuff")
    partner.hp = int(partner.max_hp*.5)
    partner.digimon_mp = 63
    partner.global_position = tamer.global_position+Vector2(170,0)
    partner.auto_battle = true
    partner.command_attack(enemy)
    var prior_events: int = permission_events
    tamer.hp = 40
    check(tamer.can_battle() and partner.form_index == 1,"HP เท่ากับ 20% ยังไม่เข้า debuff ถ้าเดิมพร้อมสู้")
    tamer.hp = 39
    check(not tamer.can_battle() and partner.form_index == 0,"HP 19.5% บังคับ Rookie ทันที")
    check(partner.target == null and tamer.target == null and not partner.auto_battle,"Debuff ล้างเป้าทั้งสองตัวและ Auto")
    check(partner.state == PartnerMonster.State.FOLLOW,"คู่หูไกลแล้วเปลี่ยน Follow กลับหา Tamer")
    check(partner.hp == int(partner.max_hp*.5) and partner.digimon_mp == 63,"Devolve คงสัดส่วน HP/MP ไม่แจกฟื้นฟรี")
    check(permission_events == prior_events+1,"เข้า debuff ส่ง Signal ครั้งเดียว")
    tamer.command_attack()
    partner.command_attack(enemy)
    partner.auto_battle = true
    partner._physics_process(1.0/60)
    check(partner.target == null and not partner.auto_battle,"เรียก command/Auto ตรง ๆ ไม่ข้าม Cannot Battle")
    partner.target = enemy
    check(not partner._try_skill(0) and not partner._start_basic_attack(),"ทั้งสกิลและตีธรรมดามี guard ที่ Actor")
    check(partner.prepare_digivolve() == null,"Cannot Battle ไม่จอง DS/คัตซีน")
    hud._process(0)
    hud.skill_panel._refresh_buttons()
    check(hud.attack_button.locked and hud.auto_button.locked and hud.evolve_button.locked and hud.skill_panel.buttons[0].locked,"HUD ปิดปุ่มโจมตี/Auto/พัฒนา/สกิล")
    tamer.hp = 40
    check(not tamer.can_battle(),"ฟื้นแค่ 20% ยังไม่ปลด debuff")
    tamer.hp = 41
    check(tamer.can_battle() and not partner.auto_battle,"ฟื้นเกิน 20% พร้อมสู้แต่ไม่เปิด Auto เอง")
    reset_stats()
    tamer.global_position = Vector2(450,350)
    partner.global_position = Vector2(500,350)
    enemy.global_position = Vector2(540,350)
    partner.command_attack(enemy)
    tamer.ds = 0
    check(partner._try_skill(0),"DS ศูนย์ แต่ MP พอ ยังใช้สกิลได้")
    check(partner.digimon_mp == 95 and tamer.ds == 0,"ใช้สกิลหัก MP 5 ไม่หัก DS")
    var spent: float = partner.digimon_mp
    check(not partner._try_skill(0) and partner.digimon_mp == spent,"กดซ้ำคูลดาวน์/ท่าร่ายไม่หัก MP ซ้ำ")
    partner._cancel_combat_action()
    partner.skill_cooldowns.clear()
    partner.digimon_mp = 4
    tamer.ds = 100
    check(not partner._try_skill(0) and partner.digimon_mp == 4 and tamer.ds == 100,"MP ไม่พอไม่ใช้ DS แทน ไม่ตั้งคูลดาวน์")
    partner.digimon_mp = 0
    var ds_before: float = tamer.ds
    check(partner.digivolve() and tamer.ds == ds_before-25 and partner.digimon_mp == 0,"MP ศูนย์ยัง Digivolve ได้ถ้า DS พอ; เปลี่ยนร่างไม่เติม MP")
    partner._apply_form(0,true)
    partner.digimon_mp = 100
    tamer.ds = 24
    check(partner.prepare_digivolve() == null and partner.digimon_mp == 100 and tamer.ds == 24,"DS ไม่พอเปลี่ยนร่าง ไม่หัก MP แทน")
    check(not partner.consume_mp(-1) and not partner.consume_mp(NAN) and not tamer.consume_ds(INF),"ปฏิเสธค่า energy ติดลบ/NaN/Infinity")
    reset_stats()
    partner.command_attack(enemy)
    partner._try_skill(0)
    partner.sprite.frame = 2
    var shots: Array[Node] = get_tree().get_nodes_in_group("skill_projectiles")
    check(shots.size() == 1,"ปล่อยลูกไฟจริงก่อน debuff")
    var shot: SkillProjectile = shots[0]
    var enemy_hp: int = enemy.hp
    tamer.hp = 39
    shot._impact(enemy)
    check(enemy.hp == enemy_hp and shot.is_queued_for_deletion(),"ลูกไฟที่ยิงแล้วถูกยกเลิกเมื่อ Tamer อ่อนแรง ไม่ลง hit ล่าช้า")
    await get_tree().process_frame
    reset_stats(0,0)
    tamer.hp = 39
    partner.enter_fainted(false)
    var fruit: ItemData = InventoryManager.catalog.find_item("digital_fruit")
    check(InventoryManager.add_item(fruit,2),"เพิ่มอาหาร Tamer เข้ากระเป๋า")
    check(InventoryManager.use_item(InventoryManager.index_of("digital_fruit")),"กินอาหารได้แม้คู่หูเป็นไข่")
    check(tamer.hp == 64 and tamer.tamer_hunger == 30 and tamer.tamer_stamina == 10 and tamer.can_battle(),"อาหารฟื้น HP/หิว/แรง และปลด debuff")
    check(partner.hp == 0 and partner.state == PartnerMonster.State.EGG,"อาหาร Tamer ไม่ชุบคู่หู")
    check(InventoryManager.count("digital_fruit") == 1 and int(QuestManager.party_profile.survival.hunger) == 30,"ตัดอาหารและ save Survival ในธุรกรรมเดียว")
    reset_stats()
    check(not InventoryManager.use_item(InventoryManager.index_of("digital_fruit")) and InventoryManager.count("digital_fruit") == 1,"อิ่ม/HP/แรงเต็มไม่กินของฟรี")
    var drink: ItemData = InventoryManager.catalog.find_item("mp_drink")
    InventoryManager.add_item(drink,2)
    partner.digimon_mp = 80
    var ds_same: float = tamer.ds
    check(InventoryManager.use_item(InventoryManager.index_of("mp_drink")) and partner.digimon_mp == 100 and tamer.ds == ds_same,"น้ำ MP เติมเท่าที่ขาด ไม่เติม/หัก DS")
    check(not InventoryManager.use_item(InventoryManager.index_of("mp_drink")) and InventoryManager.count("mp_drink") == 1,"MP เต็มไม่กินน้ำเพิ่ม")
    reset_stats(0,0)
    tamer.hp = 39
    partner.digimon_mp = 20
    var zone_a := Node.new()
    var zone_b := Node.new()
    world.add_child(zone_a)
    world.add_child(zone_b)
    clock.set_safe_zone(zone_a,true)
    clock.set_safe_zone(zone_b,true)
    clock.advance(3)
    check(tamer.hp == 49 and tamer.tamer_stamina == 30 and partner.digimon_mp == 35,"พัก 3s ฟื้น HP/แรง/MP ไม่มี Survival damage")
    check(tamer.tamer_hunger == 0 and tamer.can_battle(),"พักไม่เติมความอิ่มฟรี แต่ HP เกิน 20% ปลด debuff")
    clock.set_safe_zone(zone_a,false)
    check(clock.is_resting(),"ออก Safe Zone A ยังพักอยู่เพราะอยู่ใน B")
    zone_b.queue_free()
    await get_tree().process_frame
    check(not clock.is_resting(),"ลบ Safe Zone B ไม่ทิ้งสถานะพักค้าง")
    var hunger_before: float = tamer.tamer_hunger
    var hp_before: int = tamer.hp
    clock.set_process(true)
    hud._toggle_stats()
    await get_tree().create_timer(6,true).timeout
    check(tamer.tamer_hunger == hunger_before and tamer.hp == hp_before,"เปิด Status pause แล้ว Survival ไม่เดินต่อ")
    hud.smart_panel.close_screen()
    clock.set_process(false)
    reset_stats(0,50)
    tamer.hp = 40
    tamer.restore_battle_latch(true)
    partner.digimon_mp = 17
    clock.advance(2.75)
    var saved: Dictionary = tamer.capture_party_state()
    check(saved.survival.cannot_battle and saved.digimon_mp == 17,"Save เก็บ latch ที่ HP 20% และ MP คู่หู")
    reset_stats()
    tamer.hp = 40
    clock.restore_data(saved.survival)
    check(not tamer.can_battle() and tamer.tamer_hunger == 0,"Load ที่ HP 20% คง debuff เดิม")
    clock.advance(.25)
    check(tamer.hp == 35,"Load เก็บเศษเวลา starvation ไม่เริ่ม 3s ใหม่")
    tamer.hp = 200
    clock.restore_data({"hunger":"bad","stamina":INF})
    check(tamer.tamer_hunger == 100 and tamer.tamer_stamina == 100,"ฟิลด์ Survival ผิดชนิด/NaN ใช้ค่าเริ่มต้นปลอดภัย")
    clock.restore_data({})
    check(tamer.tamer_hunger == 100 and tamer.tamer_stamina == 100,"เซฟ v18 ไม่มี Survival ใช้ค่าเต็ม")
    tamer.hp_changed.emit(tamer.hp,tamer.max_hp)
    partner.mp_changed.emit(partner.digimon_mp,partner.digimon_max_mp)
    tamer.set_survival_values(75,65)
    # v20 ภาพหลอด Tween 0.45s แต่ค่าสเตตัสจริงเปลี่ยนทันที
    await get_tree().create_timer(0.50, true).timeout
    check(hud.party_status.hunger_bar.value == 75 and hud.party_status.stamina_bar.value == 65 and hud.party_status.mp_bar.value == partner.digimon_mp,"Signals อัปเดตหลอด Hunger/Stamina/MP จริง")
    var food_count: int = InventoryManager.count("digital_fruit")
    hud.inventory_screen.open_screen()
    hud.inventory_screen._choose_slot(InventoryManager.index_of("digital_fruit"))
    await get_tree().process_frame
    await get_tree().process_frame
    tap(hud.inventory_screen.use_button)
    check(InventoryManager.count("digital_fruit") == food_count-1 and tamer.tamer_hunger == 100,"แตะปุ่มกินจริงใน InventoryUI ฟื้น Tamer และหักของครั้งเดียว")
    hud.inventory_screen.close_screen()
    reset_stats()
    tamer.command_digivolve()
    check(get_tree().paused and partner.evolution_busy and tamer.ds == 75,"จอง DS ระหว่างคัตซีนก่อนรับอันตรายภายนอก")
    tamer.hp = 39
    check(not get_tree().paused and not partner.evolution_busy and tamer.ds == 100 and partner.form_index == 0,"HP ต่ำระหว่างคัตซีนยกเลิกและคืน DS ครั้งเดียว/Resume")
    await get_tree().process_frame
    reset_stats(12,54)
    partner.digimon_mp = 17
    var cross_scene: Dictionary = tamer.capture_party_state()
    cross_scene.tamer_hp = 39
    cross_scene.form_id = String(partner.forms[1].id)
    cross_scene.hp = int(partner.forms[1].max_hp*.5)
    # v23 สถานะคู่หูจริงอยู่ใน roster; top-level form_id/hp เป็น mirror สำหรับเซฟเก่า
    for member: Dictionary in cross_scene.partner_roster.members:
        if str(member.id) == str(cross_scene.partner_roster.active_id):
            member.form_id = cross_scene.form_id
            member.hp = cross_scene.hp
            member.max_hp = partner.forms[1].max_hp
    world.queue_free()
    await get_tree().process_frame
    QuestManager.party_profile = cross_scene
    QuestManager.party_snapshot.clear()
    world = preload("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(world)
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    clock = tamer.survival
    clock.set_process(false)
    clock.autosave_enabled = false
    tamer.set_physics_process(false)
    partner.set_physics_process(false)
    check(tamer.tamer_hunger == 12 and tamer.tamer_stamina == 54 and partner.digimon_mp == 17,"World loader คืน Hunger/Stamina/MP ข้าม Scene")
    check(not tamer.can_battle() and partner.form_index == 0 and partner.hp == int(partner.max_hp*.5),"คืนเซฟ HP ต่ำพร้อมร่างสูง แล้วลด Rookie โดยคงสัดส่วน HP")
    # ไม่แค่ทดสอบการ serialize: นาฬิกาจริงต้องสร้าง checkpoint หลัง 10s active
    tamer.hp = 200
    clock.restore_data({"hunger":100,"stamina":100})
    clock.autosave_enabled = true
    tamer.save_party_progress()
    clock.advance(9.75)
    check(int(QuestManager.party_profile.survival.hunger) == 100 and tamer.tamer_hunger == 99,"ก่อน 10s ไม่เขียน checkpoint ทุกเฟรม")
    clock.advance(.25)
    check(int(QuestManager.party_profile.survival.hunger) == 98,"ครบ 10s checkpoint เก็บ Survival ล่าสุด")
    partner.consume_mp(5)
    clock._notification(NOTIFICATION_APPLICATION_PAUSED)
    check(QuestManager.party_profile.digimon_mp == 12,"พักแอปหลังเสีย MP เซฟได้ทันทีแม้ยังไม่ถึงรอบความหิว")
    var paused_hunger: float = tamer.tamer_hunger
    clock._process(10)
    check(tamer.tamer_hunger == paused_hunger,"แอปอยู่พื้นหลังไม่คิด delta มาหักความหิว")
    clock._notification(NOTIFICATION_APPLICATION_RESUMED)
    clock._process(30)
    check(tamer.tamer_hunger == paused_hunger,"เฟรมแรกหลัง Resume ทิ้ง delta ที่อาจรวมเวลา OS พักไว้")
    clock._process(5)
    check(tamer.tamer_hunger == paused_hunger-1,"เฟรมถัดไปหลัง Resume กลับมานับเวลา active ตามเดิม")
    world.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(QuestManager.save_path))
    print("RESULT: ",failures," failure(s)")
    get_tree().quit(1 if failures else 0)
