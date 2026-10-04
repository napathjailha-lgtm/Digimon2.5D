class_name Tamer
extends CharacterBody2D
## Tamer เดินและสั่งการเท่านั้น ไม่มีฟังก์ชันสร้างความเสียหาย

signal hp_changed(current: int, maximum: int)
signal survival_changed(hunger: float, stamina: float)
signal battle_permission_changed(allowed: bool)
signal digivolve_requested(partner_node: PartnerMonster)
signal ds_changed(current: float, maximum: float)
signal target_changed(enemy: WildMonster)
signal auto_navigation_arrived(target_node: Node2D)
signal auto_navigation_failed(message: String)

@export var move_speed: float = 190.0
@export_range(100.0, 6000.0) var acceleration: float = 1600.0
@export_range(100.0, 6000.0) var braking: float = 2800.0
@export var max_ds: float = 100.0
@export var ds_regen_per_second: float = 3.0
@export var joystick: MobileJoystick
@export var partner: PartnerMonster
@export_flags_2d_physics var enemy_layer: int = 4
## ภาพนิ่ง 4 ทิศ: หน้า / ขวา / หลัง / ซ้าย
## เปลี่ยนภาพตามทิศทางการเดินโดยไม่แตะระบบ Collision หรือ Navigation
@export var directional_textures: Array[Texture2D] = []

@export_range(1.0, 1000.0) var animation_reference_speed: float = 190.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animator: DirectionalAnimator = $DirectionalAnimator
@onready var progress: CharacterProgress = $Progress
var display_name: String = "Tamer"
# เจ้าของสเตตัสเป็น Tamer เท่านั้น ชื่อ hp/max_hp/ds เดิมเป็น alias ไม่ใช่ข้อมูลอีกชุด
var tamer_max_hp: int = 200
var tamer_hp: int = 200:
    set(value):
        tamer_hp = clampi(value,0,maxi(1,tamer_max_hp))
        if is_node_ready():
            check_battle_permission()
var tamer_hunger: float = 100.0
var tamer_stamina: float = 100.0
var _cannot_battle: bool = false
@onready var survival: TamerSurvival = $Survival
var max_hp: int:
    get: return tamer_max_hp
    set(value): tamer_max_hp = maxi(1,value)
var hp: int:
    get: return tamer_hp
    set(value): tamer_hp = value
var attack_power: int = 0
var defense: int = 0
var equipment := EquipmentInventory.new()
var party_roster: PartnerRoster # สร้างโดย MobileHUD และ initialize หลัง World คืนเซฟ
var _base_max_ds: float = 100.0
const LEVEL_EFFECT = preload("res://scripts/level_up_effect.gd")

var tamer_ds: float = 100.0:
    set(value):
        if is_finite(value):
            tamer_ds = clampf(value,0,max_ds)
var ds: float:
    get: return tamer_ds
    set(value): tamer_ds = clampf(value,0,max_ds)
var target: WildMonster
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var _auto_target: Node2D
var _navigation_repath_left: float = 0.0
var _stuck_left: float = 0.0
var _last_navigation_position: Vector2

func _ready() -> void:
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    var initial_hp: int = 200
    if GameManager.gameplay_active:
        var model: TamerModelData = GameManager.selected_tamer_data()
        display_name = GameManager.tamer_name
        if model != null and GameManager.partner_selected != &"legacy":
            initial_hp = model.base_hp
            max_ds = model.base_ds
            move_speed = model.move_speed
            display_name = GameManager.tamer_name
            if model.sprite_frames != null:
                sprite.sprite_frames = model.sprite_frames
                sprite.scale = model.sprite_scale
                animator.configure_scales(model.sprite_scale, model.sprite_scale, model.sprite_scale)
    # ให้ระบบภาพนิ่ง/เครื่องมือเก่าอ้างอิงเฟรมของโมเดลที่กำลังใช้จริง
    directional_textures.clear()
    for direction: String in ["down", "right", "up", "left"]:
        var animation := StringName("idle_" + direction)
        directional_textures.append(sprite.sprite_frames.get_frame_texture(animation, 0))
    progress.set_base_stats(initial_hp, 0, move_speed)
    max_hp = initial_hp
    hp = initial_hp
    progress.leveled_up.connect(_on_level_up)
    _base_max_ds = max_ds
    equipment.initialize(self)
    equipment.changed.connect(_on_equipment_changed)
    ds = max_ds
    navigation_agent.path_desired_distance = 10.0
    navigation_agent.target_desired_distance = 40.0
    navigation_agent.avoidance_enabled = false
    animator.update_motion(Vector2.ZERO, animation_reference_speed)
    ds_changed.emit(ds, max_ds)
    check_battle_permission()

func _physics_process(delta: float) -> void:
    get_target() # ล้างเป้าหมายตาย/ถูกลบ ก่อนรับคำสั่งหรืออัปเดต UI
    # ใช้ความยาวเวกเตอร์จาก Joystick เพื่อเดินช้า/เร็วตามระยะลาก
    var direction: Vector2 = joystick.move_vector if is_instance_valid(joystick) else Vector2.ZERO
    # แตะ Joystick เพื่อยกเลิก Auto-Navigation แล้วกลับมาควบคุมเอง
    if direction.length_squared() > 0.0025:
        cancel_auto_navigation()
    var desired_velocity: Vector2 = direction.limit_length(1.0) * move_speed
    if is_instance_valid(_auto_target):
        desired_velocity = _auto_navigation_velocity(delta)
    velocity = SmoothMotion.step(velocity, desired_velocity, acceleration, braking, delta)
    move_and_slide()
    animator.update_motion(get_real_velocity(), animation_reference_speed)
    # ฟื้น DS เมื่ออยู่ร่างพื้นฐานเท่านั้น
    if is_instance_valid(partner) and partner.form_index == 0:
        restore_ds(ds_regen_per_second * delta)

func _unhandled_input(event: InputEvent) -> void:
    # UI รับและ consume touch ของตนเองก่อน จึงไม่กดเลือกศัตรูทะลุปุ่ม
    if event is InputEventScreenTouch and event.pressed and not event.canceled:
        select_at_screen(event.position)

func select_at_screen(screen_position: Vector2) -> void:
    cancel_auto_navigation()
    # แปลงพิกัด Viewport เป็นพิกัดโลก รองรับ Camera2D และ Stretch
    var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
    var query := PhysicsPointQueryParameters2D.new()
    query.position = world_position
    query.collision_mask = enemy_layer | 16
    query.collide_with_bodies = true
    query.collide_with_areas = true
    var nearest: WildMonster = null
    var best_distance: float = INF
    for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(query, 16):
        var npc := hit["collider"] as StoryNPC
        if npc != null:
            npc.try_talk(self)
            get_viewport().set_input_as_handled()
            return
        var enemy := hit["collider"] as WildMonster
        # ภาพใหม่สูงกว่าจุดเท้า: Area2D ครอบภาพช่วยให้แตะส่วนหัว/ลำตัวได้
        if enemy == null and hit["collider"] is Area2D:
            enemy = hit["collider"].get_parent() as WildMonster
        if is_instance_valid(enemy) and enemy.is_alive():
            var distance: float = world_position.distance_squared_to(enemy.global_position)
            if distance < best_distance:
                best_distance = distance
                nearest = enemy
    if nearest != null and can_battle():
        set_target(nearest)
        # แตะศัตรูแล้วเริ่มสั่งคู่หูไปต่อสู้ทันที
        if is_instance_valid(partner):
            partner.command_attack(target)
    else:
        set_target(null)
        if is_instance_valid(partner):
            partner.cancel_battle()
    get_viewport().set_input_as_handled()

func get_target() -> WildMonster:
    # จุดส่งต่อคำสั่งต้องคืนเฉพาะ Node ที่ยังใช้งานได้ ไม่ส่ง freed reference
    if not is_instance_valid(target):
        # freed Object อาจเปรียบเทียบเท่ากับ null แต่ยังส่งเข้าฟังก์ชัน typed ไม่ได้
        # ต้องเขียน null จริงทับ reference เก่า ไม่ใช้เพียง target == null
        target = null
        return null
    if target.is_queued_for_deletion() or not target.is_inside_tree() or not target.is_alive():
        set_target(null)
        return null
    return target

func set_target(enemy: Variant) -> void:
    # รับ Variant เพื่อตรวจ reference ก่อนแปลงชนิด เหมือนขอบเขตรับข้อมูลของ HUD
    var next_target: WildMonster = null
    if not can_battle():
        enemy = null
    if is_instance_valid(enemy) and enemy is WildMonster:
        var candidate := enemy as WildMonster
        if not candidate.is_queued_for_deletion() and candidate.is_inside_tree() and candidate.is_alive():
            next_target = candidate
    if target == next_target:
        if next_target == null:
            target = null # แทน freed reference ด้วย null จริงก่อนคืนค่า
        return # ไม่ส่ง signal ซ้ำเมื่อ cancel_battle ล้างเป้าเดิมอีกครั้ง
    if is_instance_valid(target):
        var old_callback: Callable = _on_target_exiting.bind(target.get_instance_id())
        if target.tree_exiting.is_connected(old_callback):
            target.tree_exiting.disconnect(old_callback)
        if not target.is_queued_for_deletion():
            target.set_selected(false)
    target = next_target
    if is_instance_valid(target):
        target.set_selected(true)
        # ผูก ID แทน Object เพื่อไม่เก็บ reference ศัตรูไว้ใน callback
        target.tree_exiting.connect(_on_target_exiting.bind(target.get_instance_id()))
    target_changed.emit(target)

func _on_target_exiting(expected_id: int) -> void:
    # Node ยัง valid ตอน tree_exiting ล้างเป้าได้ก่อนถูก free จริง
    # หากเลือกศัตรูใหม่แล้ว ศัตรูตัวเก่าออกจากฉากต้องไม่ล้างเป้าใหม่
    if not is_instance_valid(target) or target.get_instance_id() != expected_id:
        return
    set_target(null)
    if is_instance_valid(partner) and is_instance_valid(partner.target):
        if partner.target.get_instance_id() == expected_id:
            partner.cancel_battle()

func command_attack() -> void:
    if not can_battle() or not is_instance_valid(partner):
        return
    if get_target() == null:
        set_target(partner.find_nearest_enemy())
    partner.command_attack(get_target())

func command_skill(slot: int) -> void:
    if can_battle() and is_instance_valid(partner):
        partner.command_skill(slot, get_target())

func command_form_skill(source: MonsterData, slot: int) -> void:
    # ชุดสกิลต่างร่างใช้คำสั่งแยก ไม่เรียกเปลี่ยนข้อมูลตัวละคร
    cancel_auto_navigation()
    if can_battle() and is_instance_valid(partner):
        partner.command_form_skill(source, slot, get_target())

func command_digivolve() -> void:
    if can_battle() and is_instance_valid(partner):
        digivolve_requested.emit(partner)

func set_auto_battle(enabled: bool) -> void:
    if is_instance_valid(partner):
        partner.auto_battle = enabled and can_battle() and not survival.is_resting()

func consume_ds(amount: float) -> bool:
    # ตรวจและหักในจุดเดียว ป้องกันเปลี่ยนร่างโดยไม่มีพลังงาน
    if not is_finite(amount) or amount < 0.0 or ds < amount:
        return false
    ds = maxf(0.0, ds - amount)
    ds_changed.emit(ds, max_ds)
    return true

func restore_ds(amount: float) -> void:
    if not is_finite(amount) or amount <= 0:
        return
    var next_ds: float = clampf(ds + amount, 0.0, max_ds)
    if not is_equal_approx(next_ds, ds):
        ds = next_ds
        ds_changed.emit(ds, max_ds)

func start_auto_navigation(target_node: Node2D) -> void:
    if not is_instance_valid(target_node) or not target_node.is_inside_tree():
        return
    _auto_target = target_node
    _navigation_repath_left = 0.0
    _stuck_left = 1.0
    _last_navigation_position = global_position
    # หยุดการไล่ตีเก่าเพื่อให้คู่หูกลับมาเดินตามขณะนำทาง
    if is_instance_valid(partner):
        partner.auto_battle = false
        partner.cancel_battle()

func cancel_auto_navigation() -> void:
    _auto_target = null

func is_auto_navigating() -> bool:
    return is_instance_valid(_auto_target)

func _auto_navigation_velocity(delta: float) -> Vector2:
    if not is_instance_valid(_auto_target) or not _auto_target.is_inside_tree():
        cancel_auto_navigation()
        return Vector2.ZERO
    var destination: Vector2 = _auto_target.global_position
    if global_position.distance_to(destination) <= 55.0:
        var arrived_target: Node2D = _auto_target
        cancel_auto_navigation()
        if arrived_target is QuestTarget:
            arrived_target.interact_on_arrival(self)
        auto_navigation_arrived.emit(arrived_target)
        return Vector2.ZERO

    var map: RID = navigation_agent.get_navigation_map()
    if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
        return Vector2.ZERO
    _navigation_repath_left -= delta
    if _navigation_repath_left <= 0.0:
        navigation_agent.target_position = destination
        _navigation_repath_left = 0.2
    var next_point: Vector2 = navigation_agent.get_next_path_position()
    if navigation_agent.is_navigation_finished():
        cancel_auto_navigation()
        auto_navigation_failed.emit("ไม่พบเส้นทางถึงเป้าหมายเควสต์")
        return Vector2.ZERO

    # ถ้าชนกำแพงแล้วไม่ขยับ ให้หยุดแทนเดินค้างตลอดไป
    _stuck_left -= delta
    if _stuck_left <= 0.0:
        if global_position.distance_to(_last_navigation_position) < 2.0:
            cancel_auto_navigation()
            auto_navigation_failed.emit("เส้นทางถูกขวาง กรุณาขยับ Joystick")
            return Vector2.ZERO
        _last_navigation_position = global_position
        _stuck_left = 1.0
    return global_position.direction_to(next_point) * move_speed

func is_alive() -> bool:
    # Tamer มีสเตตัส HP แต่ศัตรูในตัวอย่างยังเลือกโจมตีคู่หูเท่านั้น
    return hp > 0

func take_damage(amount: int, _attacker: Node2D = null) -> void:
    # จุดเชื่อมสำหรับระบบอันตราย/ต่อสู้ของ Tamer ในอนาคต
    if amount > 0:
        hp = maxi(0, hp - maxi(1, amount - defense))
        hp_changed.emit(hp, max_hp)

func grant_party_exp(amount: int) -> void:
    # เครดิตการฆ่าหนึ่งตัวให้ทั้ง Tamer และคู่หู ไม่แบ่งครึ่ง
    progress.add_exp(amount)
    if is_instance_valid(partner):
        partner.progress.add_exp(amount)
    save_party_progress()

func _on_level_up(_new_level: int) -> void:
    # เพิ่ม HP เท่าค่าที่ Max HP เพิ่ม ไม่ทำให้ Tamer HP 0 ฟื้นเอง
    var previous_max: int = max_hp
    apply_progress_stats()
    if hp > 0:
        hp = mini(max_hp, hp + max_hp - previous_max)
    check_battle_permission()
    hp_changed.emit(hp, max_hp)
    var effect: Node2D = Node2D.new()
    effect.set_script(LEVEL_EFFECT)
    add_child(effect)

func apply_progress_stats() -> void:
    # ใช้ตอนโหลด Save และ Level Up ไม่เปลี่ยนฐานทุกครั้งจนโบนัสสะสมซ้ำ
    var stats: Dictionary = progress.get_effective_stats()
    var bonus: Dictionary = equipment.total_bonuses()
    max_hp = int(stats.max_hp) + int(bonus.hp)
    attack_power = int(stats.attack)
    defense = int(bonus.defense)
    move_speed = float(stats.speed) + float(bonus.speed)
    max_ds = _base_max_ds + int(bonus.ds)

func _on_equipment_changed() -> void:
    # ใส่/ถอดไม่แจก HP หรือ DS ฟรี และไม่ชุบผู้เล่น/คู่หูที่ HP 0
    apply_progress_stats()
    hp = mini(hp, max_hp)
    ds = minf(ds, max_ds)
    if is_instance_valid(partner) and partner.is_node_ready():
        partner.refresh_equipment_stats()
    check_battle_permission()
    hp_changed.emit(hp, max_hp)
    ds_changed.emit(ds, max_ds)
    save_party_progress()

func capture_party_state() -> Dictionary:
    # เก็บแต่ข้อมูลธรรมดา ไม่บันทึก Node หรือ Resource ลง JSON
    var result: Dictionary = {"ds": ds, "tamer_hp": hp, "tamer_progress": progress.get_save_data(), "equipment": equipment.get_save_data(), "survival":survival.get_save_data()}
    # Singleton เก็บกระเป๋าของ Tamer ที่ bind อยู่เท่านั้น ไม่ปนข้อมูล Scene/slot เก่า
    if InventoryManager.player_node() == self:
        result["inventory"] = InventoryManager.get_save_data()
    if is_instance_valid(partner) and partner.current_form != null:
        result.merge({
            "form_id": String(partner.current_form.id), "hp": partner.hp, "digimon_mp":partner.digimon_mp,
            "egg": partner.state in [PartnerMonster.State.FAINTED, PartnerMonster.State.EGG],
            "partner_progress": partner.progress.get_save_data()
        })
    if is_instance_valid(party_roster) and party_roster.initialized:
        result["partner_roster"] = party_roster.get_save_data()
    return result

func save_party_progress() -> void:
    # ไม่บันทึก DS ที่กำลังจองคัตซีนลง Save จนกว่าจะ Commit/Cancel เสร็จ
    if is_instance_valid(partner) and not partner.evolution_busy and (not is_instance_valid(party_roster) or not party_roster._switching):
        QuestManager.party_profile = capture_party_state()
        GameManager.sync_party(QuestManager.party_profile)
        QuestManager.save_progress()

func can_battle() -> bool:
    # แม้ระบบภายนอกเขียน HP ตรง ๆ ก็ไม่ข้ามประตูนี้; ใช้จำนวนเต็ม *5 ป้องกัน float ที่ 20%
    return hp > 0 and hp * 5 >= max_hp and not _cannot_battle

func check_battle_permission() -> void:
    # เข้า debuff เมื่อ <20%; ออกจาก debuff เมื่อ >20%; ที่เท่ากันคง latch เดิม
    var blocked: bool = _cannot_battle
    if hp * 5 < max_hp or hp == 0:
        blocked = true
    elif hp * 5 > max_hp:
        blocked = false
    if blocked == _cannot_battle:
        return
    _cannot_battle = blocked # เขียนก่อน Signal เพื่อให้ callback ตรวจ can_battle() ได้ทันที
    battle_permission_changed.emit(not blocked)
    if blocked:
        set_target(null)

func restore_battle_latch(saved_blocked: bool) -> void:
    # จำสถานะที่ HP เท่ากับ 20% ข้ามเซฟ แต่ไม่เชื่อ latch ที่ขัดกับ HP จริง
    _cannot_battle = saved_blocked if hp * 5 == max_hp else hp * 5 < max_hp
    battle_permission_changed.emit(can_battle())

func set_survival_values(hunger: float, stamina: float) -> void:
    # รวม Signal ครั้งเดียวต่อ step; UI อ่านค่าล่าสุด ไม่แยก Timer ต่อหลอด
    if not is_finite(hunger) or not is_finite(stamina):
        return
    var next_hunger: float = clampf(hunger,0,100)
    var next_stamina: float = clampf(stamina,0,100)
    if is_equal_approx(tamer_hunger,next_hunger) and is_equal_approx(tamer_stamina,next_stamina):
        return
    tamer_hunger = next_hunger
    tamer_stamina = next_stamina
    survival_changed.emit(tamer_hunger,tamer_stamina)

func take_survival_damage(amount: int) -> void:
    # ความอดอยาก/เหนื่อยเป็นดาเมจตรง ไม่ให้เกราะลด 5 หน่วยจนผู้เล่นไม่ต้องกินอาหาร
    if amount <= 0 or hp <= 0:
        return
    hp = maxi(0,hp-amount)
    hp_changed.emit(hp,max_hp)

func restore_hp(amount: int) -> int:
    # อาหาร/พักในเมืองฟื้น Tamer ได้แม้ HP 0; ไม่ชุบคู่หูและไม่เปิด Auto เอง
    if amount <= 0:
        return 0
    var healed: int = mini(amount,max_hp-hp)
    if healed <= 0:
        return 0
    hp += healed
    hp_changed.emit(hp,max_hp)
    return healed

func can_eat_food(hunger_value: float, heal_value: int, stamina_value: float) -> bool:
    # ไม่กินทิ้งเมื่อทุกค่าที่อาหารนี้ฟื้นได้เต็มแล้ว; กินได้แม้คู่หูยังเป็นไข่
    return (hunger_value > 0 and tamer_hunger < 100) or (heal_value > 0 and hp < max_hp) or (stamina_value > 0 and tamer_stamina < 100)

func eat_food(hunger_value: float, heal_value: int, stamina_value: float) -> bool:
    # Inventory ตัดจำนวนหลังฟื้นสำเร็จ แล้ว save HP+สเตตัส+จำนวนพร้อมกัน
    if not is_finite(hunger_value) or not is_finite(stamina_value) or not can_eat_food(hunger_value,heal_value,stamina_value):
        return false
    set_survival_values(tamer_hunger+maxf(0,hunger_value),tamer_stamina+maxf(0,stamina_value))
    restore_hp(maxi(0,heal_value))
    check_battle_permission()
    return true
