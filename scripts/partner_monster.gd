class_name PartnerMonster
extends CharacterBody2D
## ตัวตัดสินใจหลัก: Idle / Follow / Battle
## ใช้ Resource เป็นข้อมูลคงที่ ส่วน HP/คูลดาวน์เก็บใน instance นี้

enum State { IDLE, FOLLOW, BATTLE, FAINTED, EGG }
signal state_changed(next_state: State)
signal form_changed(form: MonsterData)
signal skills_changed(skills: Array[MonsterSkill])
signal hp_changed(current: int, maximum: int)
signal mp_changed(current: float, maximum: float)
signal died # ชื่อเดิมเก็บไว้สำหรับ migration แต่คู่หูจะไม่ emit สัญญาณตายแล้ว
signal feedback(message: String)
signal defeated
signal recovered
signal evolution_changed(busy: bool)

@export var tamer: Tamer
@export var forms: Array[MonsterData] = []
@export var follow_start_distance: float = 100.0
@export var follow_stop_distance: float = 58.0
@export var leash_distance: float = 600.0
@export var auto_search_radius: float = 380.0
@export var repath_interval: float = 0.2
@export_range(100.0, 6000.0) var acceleration: float = 2000.0
@export_range(100.0, 6000.0) var braking: float = 3000.0
@export_flags_2d_physics var world_layer: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animator: DirectionalAnimator = $DirectionalAnimator
@onready var combat_action: PartnerCombatAction = $CombatAction
const PROJECTILE_SCRIPT = preload("res://scripts/skill_projectile.gd")
@export_flags_2d_physics var enemy_layer: int = 4
var _damage_rng := RandomNumberGenerator.new()
@onready var progress: CharacterProgress = $Progress
@onready var egg_sprite: Sprite2D = $EggSprite
@onready var agent: NavigationAgent2D = $NavigationAgent2D

var evolution_busy: bool = false
var _reserved_form: MonsterData
var _reserved_previous: MonsterData
var _reserved_cost: float = 0.0
var _internal_load: bool = false
var _morph_tween: Tween
const LEVEL_EFFECT = preload("res://scripts/level_up_effect.gd")

var max_story_stage: int = MonsterData.EvolutionStage.CHAMPION
var state: State = State.IDLE
var form_index: int = 0
var current_form: MonsterData
# ค่าสถานะระหว่างเล่น แยกจาก Resource ต้นแบบ
var digimon_hp: int = 0
var digimon_max_hp: int = 0
@export_range(1.0, 99999.0) var digimon_max_mp: float = 100.0
var digimon_mp: float = 100.0:
    set(value):
        if is_finite(value):
            digimon_mp = clampf(value,0,digimon_max_mp)
# Alias เพื่อให้ Nameplate/เซฟ/EXP เดิมใช้งานได้ ข้อมูลจริงมีเพียงชุดเดียว
var hp: int:
    get: return digimon_hp
    set(value): digimon_hp = clampi(value,0,maxi(0,digimon_max_hp))
var max_hp: int:
    get: return digimon_max_hp
    set(value): digimon_max_hp = maxi(1,value)
var attack_power: int = 0
var move_speed: float = 0.0
var active_skills: Array[MonsterSkill] = []
var _attack_animation_locked: bool = false
var target: WildMonster
var auto_battle: bool = false
var skill_cooldowns: Dictionary = {}
var _basic_cooldown: float = 0.0
var _pending_skill: int = -1
var _pending_page_skill: MonsterSkill
var _pending_page_form: MonsterData
var _repath_left: float = 0.0
var _search_left: float = 0.0
var _desired_velocity: Vector2 = Vector2.ZERO
var _last_path_destination: Vector2 = Vector2(INF, INF)
var _action_target: WildMonster
var _action_skill: MonsterSkill
var _action_damage: int = 0
var _charge_effect: CombatActionEffect

func _ready() -> void:
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    # สวมสายคู่หูที่เลือกก่อน _apply_form และก่อน HUD ผูกสกิล
    if GameManager.gameplay_active:
        var starter: StarterPartnerData = GameManager.selected_partner_data()
        if starter != null and not starter.forms.is_empty():
            forms.assign(starter.forms)
    digimon_mp = digimon_max_mp
    if is_instance_valid(tamer):
        tamer.battle_permission_changed.connect(_on_tamer_battle_permission)
    _damage_rng.randomize()
    # ดิจิมอนมีเลเวลสูงสุด 90 ตามระบบวิวัฒนาการใหม่
    progress.level_cap = EvolutionRules.MAX_LEVEL
    progress.leveled_up.connect(_on_level_up)
    egg_sprite.hide()
    QuestManager.unlocks_changed.connect(_on_story_unlocks_changed)
    _on_story_unlocks_changed(QuestManager.max_unlocked_stage)
    if forms.is_empty() or forms[0] == null:
        push_error("PartnerMonster: ต้องกำหนด forms อย่างน้อยร่างพื้นฐาน")
        set_physics_process(false)
        return
    agent.path_desired_distance = 10.0
    agent.target_desired_distance = 8.0
    agent.avoidance_enabled = false
    combat_action.impact.connect(_on_action_impact)
    combat_action.finished.connect(_on_animation_finished)
    combat_action.canceled.connect(_clear_action_context)
    if not _apply_form(0, false):
        set_physics_process(false)
    mp_changed.emit(digimon_mp,digimon_max_mp)

func is_alive() -> bool:
    return hp > 0 and state not in [State.FAINTED, State.EGG]

func _physics_process(delta: float) -> void:
    _desired_velocity = Vector2.ZERO
    if not is_instance_valid(tamer):
        velocity = Vector2.ZERO
        return
    _repath_left -= delta
    if state == State.FAINTED:
        velocity = Vector2.ZERO
        return # รอ Tween หดตัวจบ ไม่มีการโจมตี
    if state == State.EGG:
        # HP == 0 ก็ยังเดินตามได้ แต่ไม่เข้า Battle และไม่ใช้ DS
        _update_cooldowns(delta)
        if global_position.distance_to(tamer.global_position) > follow_stop_distance:
            _navigate_to(tamer.global_position, follow_stop_distance)
        velocity = SmoothMotion.step(velocity, _desired_velocity, acceleration, braking, delta)
        move_and_slide()
        return
    if not is_alive() or evolution_busy:
        velocity = Vector2.ZERO
        return
    _update_cooldowns(delta)
    _search_left -= delta
    # ไม่ให้ Auto-Battle/คำสั่งค้างเปิดการต่อสู้อีกหลัง Tamer ติด debuff
    if not tamer.can_battle() and (state == State.BATTLE or auto_battle or form_index > 0):
        _on_tamer_battle_permission(false)
    if not can_battle() and is_instance_valid(target):
        cancel_battle()

    if current_form.ds_drain_per_second > 0.0:
        # ลดการใช้ DS ระหว่างคงร่างพัฒนาเหลือ 50% ของค่าที่กำหนดใน Resource
        var balanced_drain: float = current_form.ds_drain_per_second * 0.5
        if not tamer.consume_ds(balanced_drain * delta):
            # DS หมดกลับร่างพื้นฐาน ไม่เสีย HP และไม่รีเซ็ตคูลดาวน์
            tamer.consume_ds(tamer.ds)
            _apply_form(0, true)
            feedback.emit("DS หมด: กลับร่างพื้นฐาน")

    # ตาย/ถูกลบ/ห่าง Tamer เกินกำหนด ให้เลิกไล่และกลับไปเดินตาม
    if is_instance_valid(target):
        if not target.is_alive() or tamer.global_position.distance_to(target.global_position) > leash_distance:
            cancel_battle()
    elif state == State.BATTLE:
        cancel_battle()

    if auto_battle and can_battle() and not is_instance_valid(target) and _search_left <= 0.0:
        _search_left = 0.35
        var enemy: WildMonster = find_nearest_enemy()
        if enemy != null:
            command_attack(enemy)

    if is_instance_valid(target):
        _change_state(State.BATTLE)
    else:
        var distance: float = global_position.distance_to(tamer.global_position)
        # ใช้สองระยะป้องกันสลับ Idle/Follow ถี่เมื่ออยู่แถวขอบระยะ
        var tamer_moving: bool = tamer.get_real_velocity().length_squared() > 4.0
        if state == State.FOLLOW and distance <= follow_stop_distance and not tamer_moving:
            _change_state(State.IDLE)
        elif distance > follow_start_distance or (tamer_moving and distance > follow_stop_distance):
            _change_state(State.FOLLOW)

    if combat_action.busy:
        # ปักเท้าระหว่างเตรียม/โจมตี/คืนท่า ไม่สไลด์ไปพร้อมภาพตี
        velocity = Vector2.ZERO
        move_and_slide()
        return
    match state:
        State.IDLE:
            pass
        State.FOLLOW:
            _navigate_to(tamer.global_position, follow_stop_distance)
        State.BATTLE:
            _battle_tick()
    velocity = SmoothMotion.step(velocity, _desired_velocity, acceleration, braking, delta)
    move_and_slide()
    _update_movement_animation()

func command_attack(enemy: WildMonster) -> void:
    if evolution_busy or not can_battle() or not is_instance_valid(enemy) or not enemy.is_alive():
        return
    if not is_instance_valid(tamer):
        return
    if tamer.global_position.distance_to(enemy.global_position) > leash_distance:
        feedback.emit("เป้าหมายอยู่ไกล Tamer เกินไป")
        return
    if target != enemy:
        _cancel_combat_action()
        _pending_skill = -1
        _repath_left = 0.0
    target = enemy
    # ให้ Auto-Battle กับการกดเองใช้ Target Lock วงเดียวกัน
    if tamer.target != enemy:
        tamer.set_target(enemy)
    _change_state(State.BATTLE)

func cancel_battle() -> void:
    _cancel_combat_action()
    var old_target: WildMonster = target if is_instance_valid(target) else null
    target = null
    _pending_skill = -1
    _repath_left = 0.0
    if is_instance_valid(tamer) and (not is_instance_valid(tamer.target) or tamer.target == old_target):
        tamer.set_target(null)
    if state not in [State.FAINTED, State.EGG]:
        _change_state(State.IDLE)

func command_skill(slot: int, enemy: WildMonster) -> void:
    _pending_page_skill = null
    _pending_page_form = null
    if evolution_busy or not can_battle() or current_form == null:
        return
    if slot < 0 or slot >= active_skills.size():
        return
    var skill: MonsterSkill = active_skills[slot]
    if skill == null or cooldown_remaining(skill) > 0.0:
        return
    if not is_instance_valid(enemy):
        enemy = find_nearest_enemy()
    command_attack(enemy)
    if is_instance_valid(target) and target == enemy:
        # รับคำสั่งไว้ก่อน ถ้าอยู่นอกระยะจะเดินเข้าหาแล้วค่อยใช้
        _pending_skill = slot

func can_use_skill_from_form(source: MonsterData, slot: int) -> bool:
    # ระบบใหม่อนุญาตเฉพาะสกิลของร่างที่กำลังสวมอยู่เท่านั้น
    # ต่อให้ UI/สคริปต์เก่าส่ง Resource ร่างอื่นเข้ามาก็ถูกปฏิเสธที่ gameplay layer
    if source == null or source != current_form:
        return false
    return slot >= 0 and slot < active_skills.size() and active_skills[slot] != null

func command_form_skill(source: MonsterData, slot: int, enemy: WildMonster) -> void:
    # Compatibility API: ห้ามข้ามร่าง และส่งต่อเฉพาะร่างปัจจุบัน
    if source == current_form:
        command_skill(slot, enemy)

func cancel_page_skill() -> void:
    # เรียกเมื่อเลือกเป้าหมายใหม่/กลับ Idle/เปลี่ยนร่าง ไม่ทิ้งคำสั่งเดินไปร่ายเก่าไว้
    _pending_page_skill = null
    _pending_page_form = null
    _pending_skill = -1

func _battle_tick() -> void:
    if not can_battle() or combat_action.busy or not is_instance_valid(target) or not target.is_alive():
        return
    var distance: float = global_position.distance_to(target.global_position)
    var desired_range: float = current_form.attack_range
    if _pending_page_skill != null:
        var source_slot: int = _pending_page_form.skills.find(_pending_page_skill) if _pending_page_form != null else -1
        if not can_use_skill_from_form(_pending_page_form, source_slot) or digimon_mp < _pending_page_skill.mp_cost:
            cancel_page_skill()
            feedback.emit("ชุดสกิลถูกล็อกหรือ MP ไม่พอ")
        else:
            desired_range = _pending_page_skill.cast_range
    if _pending_skill >= 0:
        var skill: MonsterSkill = active_skills[_pending_skill]
        if skill == null or digimon_mp < skill.mp_cost:
            _pending_skill = -1
            feedback.emit("MP ไม่พอใช้สกิล")
        else:
            desired_range = skill.cast_range

    # ต้องถึงระยะและไม่มีผนังกั้น จึงสร้างความเสียหายได้
    if distance > desired_range or not _has_line_of_sight():
        _navigate_to(target.global_position, maxf(4.0, desired_range - 4.0))
        return

    if _pending_page_skill != null:
        _try_skill_resource(_pending_page_skill)
        cancel_page_skill()
        return
    if _pending_skill >= 0:
        _try_skill(_pending_skill)
        _pending_skill = -1
        return
    if auto_battle:
        for slot: int in range(active_skills.size()):
            if _try_skill(slot):
                return
    if _basic_cooldown <= 0.0:
        _start_basic_attack()

func _try_skill(slot: int) -> bool:
    # ป้องกันเรียกตรงจากระบบอื่นขณะสลบ/คัตซีน หรือ index ของร่างเก่า
    if combat_action.busy or not can_battle() or evolution_busy or slot < 0 or slot >= active_skills.size():
        return false
    var skill: MonsterSkill = active_skills[slot]
    return _try_skill_resource(skill)

func _try_skill_resource(skill: MonsterSkill) -> bool:
    # กลไกเดียวกับสกิลร่างปัจจุบัน: ท่าร่าย/Projectile/AoE ใช้ Resource ที่ร้องขอ
    # attack_power และ Sprite ยังคงเป็นร่างในสนาม คูลดาวน์เก็บตาม skill.id เดิม
    if combat_action.busy or not can_battle() or evolution_busy:
        return false
    if skill == null or cooldown_remaining(skill) > 0.0 or not is_instance_valid(target) or not target.is_alive():
        return false
    if global_position.distance_to(target.global_position) > skill.cast_range:
        return false
    var direction: Vector2 = global_position.direction_to(target.global_position)
    var fallback: StringName = current_form.cast_animation if skill.animation_prefix == &"cast" else current_form.attack_animation
    if not _has_line_of_sight() or not combat_action.can_begin(skill.animation_prefix, direction, fallback):
        return false
    if not consume_mp(skill.mp_cost):
        return false
    # หัก MP/CD ครั้งเดียวตอนเริ่มร่าย เก็บ ATK ตอนนี้แม้ Level Up ระหว่างท่า
    skill_cooldowns[skill.id] = skill.cooldown
    _action_target = target
    _action_skill = skill
    _action_damage = roll_outgoing_damage(skill.roll_damage(attack_power, _damage_rng))
    velocity = Vector2.ZERO
    _attack_animation_locked = true
    if not combat_action.begin(skill.animation_prefix, direction, fallback, skill.release_frame):
        restore_mp(skill.mp_cost)
        skill_cooldowns.erase(skill.id)
        _clear_action_context()
        return false
    if skill.animation_prefix == &"cast" and combat_action.busy:
        _charge_effect = _create_action_effect(self, _mouth_offset(), direction,
            CombatActionEffect.Kind.CHARGE, skill.effect_color, skill.effect_size,
            _time_to_frame(sprite.animation, skill.release_frame))
        _charge_effect.style = skill.vfx_style
    return true

func _apply_skill_hit(skill: MonsterSkill, hit_target: WildMonster = null, saved_damage: int = -1) -> void:
    if not can_battle():
        return
    # คำนวณครั้งเดียวตอนยิง ใช้ ATK ปัจจุบันโดยไม่บวกโบนัสเลเวลซ้ำ
    if hit_target == null:
        hit_target = target if is_instance_valid(target) else null
    if not is_instance_valid(hit_target) or not hit_target.is_alive():
        return
    var damage: int = saved_damage if saved_damage >= 0 else skill.roll_damage(attack_power, _damage_rng)
    if skill.projectile_speed > 0.0:
        var projectile: SkillProjectile = PROJECTILE_SCRIPT.new()
        projectile.setup(self, hit_target, skill, damage, world_layer, enemy_layer)
        projectile.launch_visual_offset = _mouth_offset()
        projectile.position = (get_parent() as Node2D).to_local(global_position)
        get_parent().add_child(projectile)
        # ยังไม่ลงดาเมจตอน cast ลูกไฟจะลงครั้งเดียวเมื่อชน
        return
    SkillHitResolver.apply_hit(get_parent() as Node2D, hit_target.global_position,
        hit_target, self, damage, skill.impact_radius, skill.effect_color,
        skill.effect_size, world_layer, skill.vfx_style)

func cooldown_remaining(skill: MonsterSkill) -> float:
    return float(skill_cooldowns.get(skill.id, 0.0))

func _update_cooldowns(delta: float) -> void:
    _basic_cooldown = maxf(0.0, _basic_cooldown - delta)
    for id: StringName in skill_cooldowns.keys():
        skill_cooldowns[id] = maxf(0.0, float(skill_cooldowns[id]) - delta)

func _navigate_to(destination: Vector2, stop_distance: float = 8.0) -> void:
    # NavigationAgent ไม่ได้เคลื่อนที่ให้ ต้องนำ waypoint มาคำนวณ velocity เอง
    # รอ NavigationServer sync แผนที่ก่อน ห้าม query ตั้งแต่ _ready()
    var map: RID = agent.get_navigation_map()
    if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
        return
    # เป้าหมายเคลื่อนเกิน 12px ให้ปรับ path ก่อนครบเวลา ลดการไล่จุดเก่า
    if _repath_left <= 0.0 or _last_path_destination.distance_squared_to(destination) > 144.0:
        agent.target_position = destination
        _last_path_destination = destination
        _repath_left = repath_interval
    # เรียกหนึ่งครั้งต่อ physics frame ที่กำลังเดินตามเส้นทาง
    var next_position: Vector2 = agent.get_next_path_position()
    var distance: float = global_position.distance_to(destination)
    var tamer_speed: float = tamer.get_real_velocity().length()
    var moving_follow: bool = state == State.FOLLOW and tamer_speed > 2.0
    if distance <= stop_distance and not moving_follow:
        return
    # ทางโล่งใช้จุดปัจจุบันของเป้าหมาย แต่เมื่อมีผนังยังเดินตาม waypoint
    var ray := PhysicsRayQueryParameters2D.create(global_position, destination, world_layer)
    var clear: bool = get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
    if clear:
        next_position = destination
    elif agent.is_navigation_finished():
        return
    var speed: float = SmoothMotion.arrival_speed(distance, stop_distance, move_speed, braking)
    if state == State.FOLLOW and clear:
        # ตามด้วยความเร็วใกล้ Tamer ในระยะปกติ แทนวิ่งเต็มแล้วหยุดเป็นช่วง ๆ
        if tamer_speed > 2.0:
            speed = clampf(tamer_speed + (distance - stop_distance) * 3.0, 0.0, move_speed)
    _desired_velocity = global_position.direction_to(next_position) * speed

func _has_line_of_sight() -> bool:
    if not is_instance_valid(target):
        return false
    var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, world_layer)
    return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func find_nearest_enemy() -> WildMonster:
    if not is_instance_valid(tamer):
        return null
    var nearest: WildMonster = null
    var best_distance: float = auto_search_radius * auto_search_radius
    # เดโมมีศัตรูน้อย: ใช้ group; แผนที่ใหญ่ควรใช้ Area2D หรือ spatial index
    for node: Node in get_tree().get_nodes_in_group("wild_monsters"):
        var enemy := node as WildMonster
        if not is_instance_valid(enemy) or not enemy.is_alive():
            continue
        if tamer.global_position.distance_to(enemy.global_position) > leash_distance:
            continue
        var distance: float = global_position.distance_squared_to(enemy.global_position)
        if distance < best_distance:
            best_distance = distance
            nearest = enemy
    return nearest

func get_next_form() -> MonsterData:
    # คืน Resource ร่างถัดไป โดยไม่เปลี่ยนสถานะหรือหัก DS
    var index: int = form_index + 1
    return forms[index] if form_index >= 0 and index < forms.size() else null

func prepare_digivolve() -> MonsterData:
    # ปลดล็อกร่างตามเลเวล: Champion 15 / Ultimate 60 / Mega 90
    if evolution_busy or not is_alive() or not is_instance_valid(tamer) or not tamer.can_battle():
        return null
    var next_data: MonsterData = get_next_form()
    var next_index: int = form_index + 1
    if next_data == null:
        feedback.emit("อยู่ร่างสูงสุดแล้ว")
        return null
    if not EvolutionRules.can_use_form(progress.level, next_index):
        feedback.emit("ต้องเลเวล %d เพื่อปลดล็อกร่าง %s" % [EvolutionRules.minimum_level_for_form_index(next_index), next_data.monster_name])
        return null
    if not QuestManager.has_flag(next_data.required_story_flag):
        feedback.emit("ร่างนี้ยังต้องปลดล็อกเงื่อนไขเนื้อเรื่อง")
        return null
    var error: String = next_data.validation_error()
    if not error.is_empty():
        feedback.emit(error)
        return null
    if not tamer.consume_ds(next_data.evolution_cost):
        feedback.emit("DS ไม่พอเปลี่ยนร่าง")
        return null
    _cancel_combat_action() # หยุด wind-up ก่อนคัตซีน
    _reserved_form = next_data
    _reserved_previous = current_form
    _reserved_cost = next_data.evolution_cost
    evolution_busy = true
    velocity = Vector2.ZERO
    evolution_changed.emit(true)
    return next_data

func finish_digivolve() -> bool:
    # Commit หลังคัตซีนจบ ตรวจสิทธิ์อีกครั้งก่อนเปลี่ยนตัวจริงในสนาม
    if not evolution_busy:
        return false
    if not is_alive() or not is_instance_valid(tamer) or not tamer.can_battle() or current_form != _reserved_previous or not _form_unlocked(_reserved_form):
        abort_digivolve()
        return false
    _internal_load = true
    var success: bool = load_monster_data(_reserved_form)
    _internal_load = false
    if not success:
        abort_digivolve()
        return false
    evolution_busy = false
    _reserved_cost = 0.0
    _reserved_form = null
    _reserved_previous = null
    evolution_changed.emit(false)
    feedback.emit("Digivolve: " + current_form.monster_name)
    tamer.save_party_progress()
    return true

func abort_digivolve() -> void:
    # ยกเลิก/ปิดคัตซีนก่อนจบ: คืน DS ครั้งเดียวและปลด busy
    if not evolution_busy:
        return
    if is_instance_valid(tamer):
        tamer.restore_ds(_reserved_cost)
    evolution_busy = false
    _reserved_cost = 0.0
    _reserved_form = null
    _reserved_previous = null
    evolution_changed.emit(false)

func digivolve() -> bool:
    # API เปลี่ยนทันทีสำหรับระบบภายใน/ทดสอบ ปุ่ม UI ใช้ DigivolveCutscene
    if prepare_digivolve() == null:
        return false
    return finish_digivolve()

func load_monster_data(data: MonsterData, preserve_hp: bool = true) -> bool:
    # ร่างไข่ต้องฟื้นผ่าน recover() เท่านั้น ห้าม loader ชุบหรือแสดงร่างต่อสู้
    if not _internal_load and is_instance_valid(tamer) and not tamer.can_battle() and not forms.is_empty() and data != forms[0]:
        return false
    if not _internal_load and (state in [State.FAINTED, State.EGG] or evolution_busy):
        return false
    # เรียกเมื่อ Partner อยู่ใน Scene แล้ว เพื่อให้ @onready มี Node ครบ
    if data == null or not is_instance_valid(sprite) or not is_instance_valid(agent):
        feedback.emit("โหลดข้อมูลไม่ได้: Resource หรือ Node ยังไม่พร้อม")
        return false
    var error: String = data.validation_error()
    if not error.is_empty():
        feedback.emit(error)
        return false

    if not _form_unlocked(data):
        feedback.emit("ร่างนี้ยังไม่ปลดล็อกตามเลเวลหรือเงื่อนไขเนื้อเรื่อง")
        return false

    # คำนวณ HP จากค่าระหว่างเล่นก่อนสวมข้อมูลร่างใหม่
    var ratio: float = 1.0
    var was_dead: bool = false
    if preserve_hp and current_form != null:
        ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
        was_dead = hp == 0

    _cancel_combat_action()
    current_form = data
    form_index = forms.find(data)
    progress.set_base_stats(data.max_hp, data.attack, data.move_speed)
    var stats: Dictionary = _effective_stats()
    max_hp = int(stats.max_hp)
    attack_power = int(stats.attack)
    move_speed = float(stats.speed)
    hp = 0 if was_dead else clampi(int(round(max_hp * ratio)), 1, max_hp)

    # คัดลอกเฉพาะ Array เพื่อไม่เพิ่ม/ลบช่องสกิลใน Resource ที่ใช้ร่วมกัน
    # Resource สกิลยังอ่านร่วมกันได้ คูลดาวน์เก็บใน skill_cooldowns ของแต่ละตัว
    active_skills.assign(data.skills)

    # เปลี่ยนภาพและหยุดแอนิเมชันจากร่างเดิมก่อน
    sprite.stop()
    sprite.sprite_frames = data.sprite_frames
    sprite.scale = data.sprite_scale
    animator.configure_scales(data.sprite_scale, data.attack_sprite_scale, data.cast_sprite_scale)
    # AtlasTexture ตัดแต่ละร่างให้พอดีตัว ตั้งเท้าให้ตรงจุด Origin ทุกครั้ง
    var idle_texture: Texture2D = data.sprite_frames.get_frame_texture(data.idle_animation, 0)
    sprite.offset.y = -idle_texture.get_height() * 0.5
    sprite.modulate = Color(0.4, 0.4, 0.4) if was_dead else Color.WHITE
    agent.max_speed = move_speed
    velocity = Vector2.ZERO
    _attack_animation_locked = false
    animator.reset_actions()
    _pending_skill = -1
    _repath_left = 0.0
    if hp > 0:
        sprite.play(data.idle_animation)
    else:
        sprite.animation = data.idle_animation

    # ไม่ล้างคูลดาวน์ และคง Target/State เดิมเพื่อเปลี่ยนร่างระหว่างต่อสู้ได้
    # ชุดสกิลใหม่พร้อมครบแล้ว จึงแจ้ง UI ล้างปุ่มเก่าและสร้างใหม่
    var skill_snapshot: Array[MonsterSkill] = []
    skill_snapshot.assign(active_skills)
    skills_changed.emit(skill_snapshot)
    form_changed.emit(data)
    hp_changed.emit(hp, max_hp)
    return true

func _apply_form(index: int, preserve_hp: bool) -> bool:
    # Wrapper สำหรับกลับร่างเมื่อ DS หมด และใช้ใน Scene เริ่มต้น
    if index < 0 or index >= forms.size():
        return false
    return load_monster_data(forms[index], preserve_hp)

func _update_movement_animation() -> void:
    # ใช้ความเร็วจริงหลัง move_and_slide ป้องกันวิ่งขาค้างตอนชนกำแพง
    if not is_alive() or current_form == null or _attack_animation_locked:
        return
    animator.update_motion(get_real_velocity(), current_form.animation_reference_speed,
        current_form.idle_animation, current_form.walk_animation)

func _on_animation_finished() -> void:
    _clear_action_context()
    _update_movement_animation()

func take_damage(amount: int, _attacker: Node2D = null) -> void:
    if not is_alive():
        return
    hp = maxi(0, hp - resolve_incoming_damage(amount))
    hp_changed.emit(hp, max_hp)
    if hp == 0:
        enter_fainted()

func restore_hp(amount: int) -> int:
    # เนื้อฟื้น HP เท่าที่ขาดจริง ไม่ชุบร่างไข่และไม่ให้ฟื้นระหว่างจองคัตซีน
    if amount <= 0 or not is_alive() or evolution_busy:
        return 0
    var restored: int = mini(amount, max_hp - hp)
    if restored <= 0:
        return 0
    hp += restored
    hp_changed.emit(hp, max_hp)
    # ไม่ save ที่นี่ InventoryManager จะ commit จำนวนและ HP ก่อน save พร้อมกัน
    return restored

func enter_fainted(animate: bool = true) -> void:
    # เก็บ Node เดิมไว้: ไม่ใช้ queue_free() กับคู่หู และไม่ล้าง EXP/Level
    if state in [State.FAINTED, State.EGG]:
        return
    abort_digivolve()
    hp = 0
    auto_battle = false
    cancel_battle()
    velocity = Vector2.ZERO
    sprite.stop()
    _attack_animation_locked = false
    animator.reset_actions()
    _change_state(State.FAINTED)
    hp_changed.emit(hp, max_hp)
    defeated.emit()
    feedback.emit("คู่หูกลับเป็นไข่ แตะ Recover หรือเข้า Safe Zone")
    if animate:
        _morph_tween = create_tween()
        _morph_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.28)
        _morph_tween.tween_callback(_enter_egg_form)
    else:
        _enter_egg_form()
    if is_instance_valid(tamer):
        tamer.save_party_progress()

func _enter_egg_form() -> void:
    # Tween อาจถูกยกเลิกด้วย Recover ระหว่างทาง ต้องตรวจ State ก่อน
    if state != State.FAINTED:
        return
    sprite.hide()
    egg_sprite.show()
    move_speed = 240.0
    agent.max_speed = move_speed
    _repath_left = 0.0
    _change_state(State.EGG)

func recover() -> bool:
    # ฟื้นเฉพาะคู่หูที่แพ้ ไม่ใช้ปุ่มนี้เติม HP ระหว่างต่อสู้
    if state not in [State.FAINTED, State.EGG] or forms.is_empty():
        return false
    if _morph_tween != null and _morph_tween.is_valid():
        _morph_tween.kill()
    _internal_load = true
    var success: bool = load_monster_data(forms[0], false)
    _internal_load = false
    if not success:
        return false
    egg_sprite.hide()
    sprite.show()
    sprite.modulate = Color.WHITE
    hp = max_hp
    restore_mp(digimon_max_mp)
    skill_cooldowns.clear()
    _basic_cooldown = 0.0
    _change_state(State.IDLE)
    sprite.play(current_form.idle_animation)
    hp_changed.emit(hp, max_hp)
    recovered.emit()
    feedback.emit("ฟื้นฟูสำเร็จ: Rookie HP เต็ม")
    if is_instance_valid(tamer):
        tamer.save_party_progress()
    return true

func _effective_stats() -> Dictionary:
    # คำนวณร่าง + เลเวล + โบนัส Digivice ใหม่เสมอ ไม่แก้ MonsterData
    var stats: Dictionary = progress.get_effective_stats()
    if is_instance_valid(tamer):
        var bonus: Dictionary = tamer.equipment.total_bonuses()
        stats.max_hp += int(bonus.partner_hp)
        stats.attack += int(bonus.partner_attack)
        stats.speed += float(bonus.partner_speed)
    return stats

func refresh_equipment_stats() -> void:
    # สวมของขณะเป็นไข่ยังไม่ชุบ HP / เปิดการโจมตี
    if current_form == null:
        return
    var stats: Dictionary = _effective_stats()
    max_hp = int(stats.max_hp)
    attack_power = int(stats.attack)
    hp = mini(hp, max_hp)
    if is_alive():
        move_speed = float(stats.speed)
        agent.max_speed = move_speed
    hp_changed.emit(hp, max_hp)

func _on_level_up(new_level: int) -> void:
    # โบนัสสเตตัสเป็นค่าคำนวณใหม่ ร่างไข่จะยัง HP 0 ไม่ชุบด้วย Level Up
    var unlocked_index: int = EvolutionRules.max_form_index_for_level(new_level)
    if unlocked_index > form_index and unlocked_index < forms.size():
        feedback.emit("ปลดล็อกร่าง: %s" % forms[unlocked_index].monster_name)
    var previous_max: int = max_hp
    var stats: Dictionary = _effective_stats()
    max_hp = int(stats.max_hp)
    attack_power = int(stats.attack)
    if is_alive():
        hp = mini(max_hp, hp + max_hp - previous_max)
        move_speed = float(stats.speed)
        agent.max_speed = move_speed
    hp_changed.emit(hp, max_hp)
    var effect: Node2D = Node2D.new()
    effect.set_script(LEVEL_EFFECT)
    add_child(effect)

func _change_state(next_state: State) -> void:
    if state != next_state:
        state = next_state
        state_changed.emit(state)

func _on_story_unlocks_changed(max_stage: int) -> void:
    # stage เดิมยังเก็บไว้เพื่อ compatibility แต่การปลดร่างหลักใช้เลเวลเป็นตัวกำหนด
    max_story_stage = max_stage
    if current_form != null and not QuestManager.has_flag(current_form.required_story_flag) and not forms.is_empty():
        abort_digivolve()
        load_monster_data(forms[0])

func _form_unlocked(data: MonsterData) -> bool:
    if data == null:
        return false
    # Jogress เป็นร่าง runtime พิเศษ ไม่ได้อยู่ใน forms จึงอนุญาตเมื่อ Manager ผ่านเงื่อนไขแล้ว
    if data.id == &"omegamon":
        return true
    var index: int = forms.find(data)
    return index >= 0 and EvolutionRules.can_use_form(progress.level, index) and QuestManager.has_flag(data.required_story_flag)

func _start_basic_attack() -> bool:
    if not can_battle():
        return false
    # เตรียม snapshot ก่อนเล่นท่า ยังไม่หัก HP จนถึง Impact frame
    if _basic_cooldown > 0.0 or combat_action.busy or not is_alive() or evolution_busy or not is_instance_valid(target) or not target.is_alive():
        return false
    if global_position.distance_to(target.global_position) > current_form.attack_range or not _has_line_of_sight():
        return false
    var direction: Vector2 = global_position.direction_to(target.global_position)
    if not combat_action.can_begin(&"attack", direction, current_form.attack_animation):
        return false
    _action_target = target
    _action_skill = null
    _action_damage = roll_outgoing_damage(attack_power)
    _basic_cooldown = current_form.attack_interval
    velocity = Vector2.ZERO
    _attack_animation_locked = true
    if not combat_action.begin(&"attack", direction, current_form.attack_animation, current_form.attack_hit_frame):
        _clear_action_context()
        _basic_cooldown = 0.0
        return false
    return true

func _on_action_impact() -> void:
    if not can_battle():
        _cancel_combat_action()
        return
    # ตรวจ reference และระยะที่เฟรมโดนจริง: เป้าหมายอาจตาย/หนี/ถูกลบระหว่างเตรียมท่า
    if not is_alive() or evolution_busy or not is_instance_valid(_action_target):
        return
    if _action_target.is_queued_for_deletion() or not _action_target.is_inside_tree() or not _action_target.is_alive():
        return
    var range_limit: float = current_form.attack_range if _action_skill == null else _action_skill.cast_range
    if global_position.distance_to(_action_target.global_position) > range_limit:
        return # พลาดแล้วไม่คืน DS/CD เพื่อกันใช้ท่าเตรียมฟรี
    var ray := PhysicsRayQueryParameters2D.create(global_position, _action_target.global_position, world_layer)
    if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
        return
    var direction: Vector2 = global_position.direction_to(_action_target.global_position)
    _remove_charge_effect()
    if _action_skill == null:
        _create_action_effect(_action_target, Vector2(0, -24), direction,
            CombatActionEffect.Kind.SLASH, Color(1.0, 0.9, 0.55), 22.0, 0.2)
        _action_target.take_damage(_action_damage, self)
    else:
        _create_action_effect(self, _mouth_offset(), direction,
            CombatActionEffect.Kind.RELEASE, _action_skill.effect_color, _action_skill.effect_size, 0.18)
        if _action_skill.animation_prefix == &"attack":
            _create_action_effect(_action_target, Vector2(0, -24), direction,
                CombatActionEffect.Kind.SLASH, _action_skill.effect_color, _action_skill.effect_size, 0.2)
        _apply_skill_hit(_action_skill, _action_target, _action_damage)

func _cancel_combat_action() -> void:
    cancel_page_skill()
    # ออกจากการต่อสู้ทุกทาง ไม่ใช้ await ที่ยังถือเป้าหมายเก่า
    if is_instance_valid(combat_action):
        combat_action.cancel()
    _clear_action_context()

func _clear_action_context() -> void:
    _action_target = null
    _action_skill = null
    _action_damage = 0
    _attack_animation_locked = false
    _remove_charge_effect()

func _remove_charge_effect() -> void:
    if is_instance_valid(_charge_effect) and not _charge_effect.is_queued_for_deletion():
        _charge_effect.queue_free()
    _charge_effect = null

func _mouth_offset() -> Vector2:
    # อ่านเฉพาะพื้นที่ภาพจริง ไม่รวม padding 512x512 ของ AtlasTexture
    var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
    var height: float = WalkTextureTools.visible_texture(texture).get_height() * sprite.scale.y
    var horizontal: float = height * 0.22 if animator.facing == &"right" else (-height * 0.22 if animator.facing == &"left" else 0.0)
    var vertical: float = 0.83 if animator.facing == &"up" else (0.6 if animator.facing == &"down" else 0.63)
    return Vector2(horizontal, -height * vertical)

func _time_to_frame(animation: StringName, frame_index: int) -> float:
    # ชาร์จจบตาม duration ของเฟรมที่ศิลปินปรับไว้จริง
    var duration: float = 0.0
    for index: int in range(mini(frame_index, sprite.sprite_frames.get_frame_count(animation))):
        duration += sprite.sprite_frames.get_frame_duration(animation, index)
    return maxf(0.05, duration / sprite.sprite_frames.get_animation_speed(animation))

func _create_action_effect(parent_node: Node2D, at: Vector2, direction: Vector2,
        kind: CombatActionEffect.Kind, color: Color, size: float, duration: float) -> CombatActionEffect:
    # ลบตัวเองและ pause พร้อมเจ้าของ
    var effect := CombatActionEffect.new()
    effect.position = at
    effect.direction = direction
    effect.kind = kind
    effect.color = color
    effect.radius = clampf(size, 10.0, 50.0)
    effect.lifetime = duration
    effect.z_index = 2
    parent_node.add_child(effect)
    return effect

func can_battle() -> bool:
    # เป็น guard จริงที่ตัวละคร ไม่พึ่งปุ่ม UI อย่างเดียว; ใน Safe Zone ให้พักแทนโจมตี
    return is_alive() and is_instance_valid(tamer) and tamer.can_battle() and not tamer.survival.is_resting()

func consume_mp(amount: float) -> bool:
    # เรียกเมื่อกำลังเริ่มสกิลเท่านั้น ท่าโจมตีธรรมดา/เดิน/ความหิวไม่แตะ MP
    if not is_finite(amount) or amount < 0 or digimon_mp < amount:
        return false
    if amount > 0:
        digimon_mp = maxf(0,digimon_mp-amount)
        mp_changed.emit(digimon_mp,digimon_max_mp)
    return true

func restore_mp(amount: float) -> float:
    # เมือง/ไอเทม/Recover เติม MP แต่เปลี่ยนร่างไม่เติมฟรีและไม่หัก MP
    if not is_finite(amount) or amount <= 0:
        return 0
    var restored: float = minf(amount,digimon_max_mp-digimon_mp)
    if restored <= 0:
        return 0
    digimon_mp += restored
    mp_changed.emit(digimon_mp,digimon_max_mp)
    return restored

func _on_tamer_battle_permission(allowed: bool) -> void:
    # หยุด Wind-up, Auto, คำสั่งรอ, Target และลูกไฟเก่าก่อนกลับร่างพื้นฐาน
    if allowed:
        return # ไม่เปิด Auto/ล็อกเป้าหมายเก่าซ้ำเองหลังฟื้น
    abort_digivolve() # คืน DS ที่จองถ้าคัตซีนยังไม่ Commit
    auto_battle = false
    cancel_battle()
    for projectile: Node in get_tree().get_nodes_in_group("skill_projectiles"):
        if is_instance_valid(projectile) and projectile.source == self:
            projectile._expire()
    if is_alive() and not forms.is_empty() and current_form != forms[0]:
        # HP เปลี่ยนตาม max ของ Rookie โดยคงสัดส่วนเดิม ไม่ทำดาเมจจาก Survival ใส่คู่หู
        _apply_form(0,true)
    velocity = Vector2.ZERO
    _desired_velocity = Vector2.ZERO
    if is_alive():
        _change_state(State.FOLLOW if global_position.distance_to(tamer.global_position) > follow_stop_distance else State.IDLE)
    feedback.emit("Tamer HP ต่ำกว่า 20%: กลับ Rookie และหยุดต่อสู้")

func roll_outgoing_damage(amount: int) -> int:
    # หนึ่งแอคชั่นสุ่มครั้งเดียว ก่อนส่งไป projectile/hit resolver
    if amount <= 0 or current_form == null:
        return 0
    if current_form.hit_chance < 100.0 and _damage_rng.randf_range(0, 100) >= current_form.hit_chance:
        return 0
    if current_form.critical_chance > 0.0 and _damage_rng.randf_range(0, 100) < current_form.critical_chance:
        return maxi(1, roundi(amount * current_form.critical_multiplier))
    return amount

func resolve_incoming_damage(amount: int) -> int:
    # หลบก่อน → หักเกราะ → ถ้าบล็อกได้ลดอีกครึ่ง ตัวเลข UI อ่านจากข้อมูลร่างเดียวกัน
    if amount <= 0 or current_form == null:
        return 0
    if current_form.evasion_chance > 0.0 and _damage_rng.randf_range(0, 100) < current_form.evasion_chance:
        return 0
    var damage: int = maxi(1, amount - current_form.defense)
    if current_form.block_chance > 0.0 and _damage_rng.randf_range(0, 100) < current_form.block_chance:
        damage = maxi(1, ceili(damage * 0.5))
    return damage
