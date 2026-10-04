class_name JogressManager
extends Node
## Jogress ของ Agumon + Gabumon เมื่อทั้งคู่ Lv90
## หมายเหตุ: repo ปัจจุบันยังไม่มี Omegamon SpriteFrames จึงใช้ภาพ Mega ของตัวที่ active
## เป็น fallback ชั่วคราว แต่สเตตัส/สกิล/เงื่อนไข Jogress ทำงานจริงและเปลี่ยน asset ภายหลังได้จุดเดียว

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

func configure(owner_tamer: Tamer, owner_partner: PartnerMonster, owner_roster: PartnerRoster) -> void:
    tamer = owner_tamer
    partner = owner_partner
    roster = owner_roster
    if is_instance_valid(roster):
        roster.changed.connect(_refresh_available)
        roster.switched.connect(func(_index: int): _refresh_available())
    if is_instance_valid(partner):
        partner.form_changed.connect(_on_form_changed)
        partner.progress.progress_changed.connect(func(_level: int, _exp: int, _max_exp: int): _refresh_available())
    _refresh_available()

func can_jogress() -> bool:
    if not is_instance_valid(tamer) or not is_instance_valid(partner) or not is_instance_valid(roster):
        return false
    if not partner.is_alive() or partner.evolution_busy or not tamer.can_battle():
        return false
    var active_id: StringName = roster.active_member_id()
    if active_id not in REQUIRED_IDS:
        return false
    for id: StringName in REQUIRED_IDS:
        if roster.member_level(id) < REQUIRED_LEVEL:
            return false
    return true

func request_jogress() -> bool:
    if active:
        return false
    if not can_jogress():
        if is_instance_valid(partner):
            partner.feedback.emit("Jogress ต้องมี Agumon และ Gabumon Lv90 ทั้งคู่ และเลือกหนึ่งในสองตัวเป็นคู่หูหลัก")
        return false

    _omegamon_form = _build_omegamon_form(partner.current_form)
    partner.auto_battle = false
    partner.cancel_battle()
    partner._internal_load = true
    var ok: bool = partner.load_monster_data(_omegamon_form, true)
    partner._internal_load = false
    if not ok:
        return false
    active = true
    partner.feedback.emit("Jogress Evolution: Omegamon")
    jogress_changed.emit(true)
    _refresh_available()
    return true

func _build_omegamon_form(fallback: MonsterData) -> MonsterData:
    var data := MonsterData.new()
    data.id = &"omegamon"
    data.monster_name = "Omegamon"
    data.evolution_stage = MonsterData.EvolutionStage.MEGA
    data.max_hp = 1200
    data.attack = 155
    data.move_speed = 300.0
    data.attack_range = 110.0
    data.attack_interval = 0.62
    data.critical_chance = 12.0
    data.critical_multiplier = 1.8
    data.hit_chance = 100.0
    data.defense = 35
    data.block_chance = 8.0
    data.evasion_chance = 5.0
    # ใช้ภาพ Mega ปัจจุบันเป็น fallback จนกว่าจะเพิ่ม SpriteFrames Omegamon จริง
    data.sprite_frames = fallback.sprite_frames
    data.sprite_scale = fallback.sprite_scale
    data.attack_sprite_scale = fallback.attack_sprite_scale
    data.cast_sprite_scale = fallback.cast_sprite_scale
    data.idle_animation = fallback.idle_animation
    data.walk_animation = fallback.walk_animation
    data.attack_animation = fallback.attack_animation
    data.cast_animation = fallback.cast_animation
    data.attack_hit_frame = fallback.attack_hit_frame
    data.animation_reference_speed = 300.0
    data.require_directional_animations = fallback.require_directional_animations
    data.require_action_animations = fallback.require_action_animations
    data.evolution_cost = 0.0
    data.ds_drain_per_second = 8.0
    data.skills = [_grey_sword(), _garuru_cannon()]
    return data

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
    if active and (data == null or data.id != &"omegamon"):
        active = false
        jogress_changed.emit(false)
    _refresh_available()

func _refresh_available() -> void:
    var next_available := can_jogress() and not active
    if next_available != _last_available:
        _last_available = next_available
        availability_changed.emit(next_available)
