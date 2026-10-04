class_name JogressManager
extends Node
## รวม Agumon + Gabumon ที่ Lv90 รายตัว ใช้ actor เดียวและล็อกการสลับทีมขณะรวมร่าง
## การแยกร่างรักษา %HP/MP/CD ของตัวหลัก ไม่สร้างสมาชิกใหม่หรือแจกการฮีล
signal availability_changed(available: bool)
signal jogress_changed(active: bool)
const REQUIRED_LEVEL: int = 90
const REQUIRED_IDS: Array[StringName] = [&"agumon", &"gabumon"]
var tamer: Tamer
var partner: PartnerMonster
var roster: PartnerRoster
var active: bool = false
var _omegamon_form: MonsterData
var _last_available: bool = false
var _cutscene: JogressCutscene
var _source_id: StringName

func configure(owner_tamer: Tamer, owner_partner: PartnerMonster, owner_roster: PartnerRoster) -> void:
    tamer = owner_tamer
    partner = owner_partner
    roster = owner_roster
    roster.changed.connect(_refresh_available)
    partner.form_changed.connect(_on_form_changed)
    partner.state_changed.connect(_on_state_changed)
    partner.progress.progress_changed.connect(func(_level: int, _exp: int, _max_exp: int): _refresh_available())
    _refresh_available()

func _ingredients_ready() -> bool:
    if not is_instance_valid(tamer) or not is_instance_valid(partner) or not is_instance_valid(roster):
        return false
    if not partner.can_battle() or tamer.ds <= 0.0 or not roster.initialized or roster._switching:
        return false
    if roster.active_member_id() not in REQUIRED_IDS:
        return false
    for id: StringName in REQUIRED_IDS:
        if roster.member_level(id) != REQUIRED_LEVEL or not roster.member_alive(id):
            return false
    return true

func can_jogress() -> bool:
    if not is_instance_valid(partner):
        return false
    return not active and not is_instance_valid(_cutscene) and not partner.evolution_busy and not get_tree().paused and _ingredients_ready()

func request_jogress() -> bool:
    # J และปุ่ม HUD ใช้ entry point เดียวกัน; กดขณะรวมร่าง = แยกร่าง
    if active:
        return dissolve()
    if not can_jogress():
        partner.feedback.emit("Jogress: ต้องมี Agumon และ Gabumon Lv90 ทั้งคู่ที่ยังต่อสู้ได้")
        return false
    _omegamon_form = _build_omegamon_form()
    if _omegamon_form == null or not _omegamon_form.validation_error().is_empty():
        return false
    _source_id = roster.active_member_id()
    partner.auto_battle = false
    partner.cancel_battle()
    _cutscene = JogressCutscene.new()
    get_tree().root.add_child(_cutscene)
    _cutscene.finished.connect(_finish_jogress)
    if not _cutscene.play(partner, _omegamon_form):
        _cutscene.queue_free()
        _cutscene = null
        return false
    # จอง actor ตลอดคัตซีน ป้องกันสลับสมาชิก/เซฟสถานะกลางทาง
    partner.evolution_busy = true
    partner.evolution_changed.emit(true)
    return true

func _finish_jogress(success: bool) -> void:
    _cutscene = null
    if not is_instance_valid(partner):
        return
    partner.evolution_busy = false
    partner.evolution_changed.emit(false)
    # ตรวจอีกครั้งตอน commit แม้มีระบบอื่นแก้ roster/HP ระหว่างคัตซีน
    if success and roster.active_member_id() == _source_id and _ingredients_ready():
        _activate()
    tamer.save_party_progress()

func _activate() -> bool:
    if not _ingredients_ready():
        return false
    if _omegamon_form == null:
        _omegamon_form = _build_omegamon_form()
    if _omegamon_form == null or not _omegamon_form.validation_error().is_empty():
        return false
    partner._jogress_form = _omegamon_form
    partner._internal_load = true
    var ok: bool = partner.load_monster_data(_omegamon_form, true)
    partner._internal_load = false
    if not ok:
        partner._jogress_form = null
        return false
    active = true
    jogress_changed.emit(true)
    partner.feedback.emit("Jogress Evolution: Omegamon")
    _refresh_available()
    return true

func dissolve() -> bool:
    if not active or get_tree().paused or partner.evolution_busy:
        return false
    partner.cancel_battle()
    var form: MonsterData = partner.forms[3] if partner.can_battle() and tamer.ds > 0.0 else partner.forms[0]
    partner._internal_load = true
    var ok: bool = partner.load_monster_data(form, true)
    partner._internal_load = false
    if ok:
        tamer.save_party_progress()
    return ok

func get_save_data() -> Dictionary:
    if not active or not partner.is_alive():
        return {}
    return {"active": true, "active_id": String(roster.active_member_id()), "hp_ratio": float(partner.hp) / partner.max_hp}

func restore_data(raw: Variant) -> void:
    # story_world เรียกหลัง roster และ HP/DS ถูก restore แล้วเท่านั้น
    if not raw is Dictionary or not bool(raw.get("active", false)):
        return
    if str(raw.get("active_id", "")) != String(roster.active_member_id()) or not _ingredients_ready():
        return
    if _activate():
        var ratio: Variant = raw.get("hp_ratio", float(partner.hp) / partner.max_hp)
        if (ratio is float or ratio is int) and is_finite(float(ratio)) and float(ratio) > 0.0:
            partner.hp = clampi(roundi(partner.max_hp * float(ratio)), 1, partner.max_hp)
            partner.hp_changed.emit(partner.hp, partner.max_hp)

func _build_omegamon_form() -> MonsterData:
    var data := MonsterData.new()
    data.id = &"omegamon"
    data.monster_name = "Omegamon"
    data.evolution_stage = MonsterData.EvolutionStage.MEGA
    data.max_hp = 1200
    data.attack = 155
    data.move_speed = 300.0
    data.attack_range = 118.0
    data.attack_interval = 0.62
    data.critical_chance = 12.0
    data.critical_multiplier = 1.8
    data.hit_chance = 100.0
    data.defense = 35
    data.block_chance = 8.0
    data.evasion_chance = 5.0

    var frames: SpriteFrames = _build_omegamon_frames()
    if frames == null:
        return null

    data.sprite_frames = frames
    data.portrait_texture = frames.get_frame_texture(&"idle", 0)
    data.sprite_scale = Vector2(0.285714, 0.285714)
    data.attack_sprite_scale = Vector2(0.285714, 0.285714)
    data.cast_sprite_scale = Vector2(0.285714, 0.285714)
    data.animation_reference_speed = 300.0
    data.idle_animation = &"idle"
    data.walk_animation = &"walk"
    data.attack_animation = &"attack"
    data.cast_animation = &"cast"
    data.require_directional_animations = false
    data.require_action_animations = false
    data.attack_hit_frame = 2

    data.evolution_cost = 0.0
    data.ds_drain_per_second = 8.0

    var jogress_skills: Array[MonsterSkill] = [
        _grey_sword(),
        _garuru_cannon()
    ]
    data.skills = jogress_skills
    return data


func _build_omegamon_frames() -> SpriteFrames:
    # AtlasTexture ตัด 4 ท่าจากภาพเดียวและใช้ margin ปักเท้า ไม่มีการแก้ pixel ตอนเล่น
    # Idle/Walk/Attack/Cast มีภาพต่างกัน; เฟรม 2 ของ action ตรงกับจังหวะปล่อยสกิล
    return load("res://data/omegamon_frames.tres") as SpriteFrames

func _grey_sword() -> MonsterSkill:
    var skill := MonsterSkill.new()
    skill.id = &"omegamon_grey_sword"
    skill.display_name = "Grey Sword"
    skill.icon = load("res://assets/skills_painted/fire.png") as Texture2D
    skill.vfx_style = "claw"
    skill.animation_prefix = &"attack"
    skill.release_frame = 2
    skill.multiplier = 5.4
    skill.cast_range = 125.0
    skill.cooldown = 6.0
    skill.mp_cost = 16.0
    skill.impact_radius = 70.0
    skill.effect_color = Color(1.0, 0.85, 0.35)
    skill.effect_size = 44.0
    return skill

func _garuru_cannon() -> MonsterSkill:
    var skill := MonsterSkill.new()
    skill.id = &"omegamon_garuru_cannon"
    skill.display_name = "Garuru Cannon"
    skill.icon = load("res://assets/skills_painted/ice.png") as Texture2D
    skill.vfx_style = "ice"
    skill.animation_prefix = &"cast"
    skill.release_frame = 2
    skill.multiplier = 5.8
    skill.cast_range = 430.0
    skill.cooldown = 8.0
    skill.mp_cost = 20.0
    skill.impact_radius = 120.0
    skill.projectile_speed = 820.0
    skill.effect_color = Color(0.55, 0.9, 1.0)
    skill.effect_size = 46.0
    return skill

func _on_form_changed(data: MonsterData) -> void:
    if data == null or data.id != &"omegamon":
        partner._jogress_form = null
        if active:
            active = false
            jogress_changed.emit(false)
    _refresh_available()

func _on_state_changed(state: PartnerMonster.State) -> void:
    # ร่างไข่ยังใช้ HP0; ล้าง fusion เพื่อไม่ให้ recover คืนเป็น Omegamon โดยไม่ตรวจทีม
    if state in [PartnerMonster.State.FAINTED, PartnerMonster.State.EGG] and active:
        active = false
        partner._jogress_form = null
        jogress_changed.emit(false)
    _refresh_available()

func _refresh_available() -> void:
    var available: bool = can_jogress()
    if available != _last_available:
        _last_available = available
        availability_changed.emit(available)

func _exit_tree() -> void:
    if is_instance_valid(_cutscene):
        _cutscene.cancel()
