class_name JogressManager
extends Node
## Jogress ของ Agumon + Gabumon เมื่อ Shared Partner Level ถึง 90
## ใช้ภาพ Omegamon ที่ generate ใหม่จริง + JogressCutscene ก่อน commit ร่าง

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
    if active or is_instance_valid(_cutscene):
        return false
    if not can_jogress():
        if is_instance_valid(partner):
            partner.feedback.emit("Jogress ต้องมี Agumon และ Gabumon ในทีม และ Shared Partner Level 90")
        return false

    _omegamon_form = _build_omegamon_form()
    if _omegamon_form == null or not _omegamon_form.validation_error().is_empty():
        partner.feedback.emit("สร้างข้อมูล Omegamon ไม่สำเร็จ")
        return false

    partner.auto_battle = false
    partner.cancel_battle()

    _cutscene = JogressCutscene.new()
    get_tree().root.add_child(_cutscene)
    _cutscene.finished.connect(_finish_jogress)

    if not _cutscene.play(partner, _omegamon_form):
        _cutscene.queue_free()
        _cutscene = null
        return false

    partner.feedback.emit("Jogress Evolution...")
    return true


func _finish_jogress(success: bool) -> void:
    _cutscene = null
    if not success or not is_instance_valid(partner):
        return

    partner._internal_load = true
    var ok: bool = partner.load_monster_data(_omegamon_form, true)
    partner._internal_load = false

    if not ok:
        partner.feedback.emit("Jogress ล้มเหลว: โหลดร่าง Omegamon ไม่สำเร็จ")
        return

    active = true
    partner.feedback.emit("Jogress Evolution: Omegamon")
    jogress_changed.emit(true)
    _refresh_available()

    if is_instance_valid(tamer):
        tamer.save_party_progress()

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
    data.sprite_scale = Vector2(0.82, 0.82)
    data.attack_sprite_scale = Vector2(0.90, 0.90)
    data.cast_sprite_scale = Vector2(0.90, 0.90)
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
    # ใช้ภาพ Omegamon ที่ generate ใหม่และตัดพื้นหลังแล้ว
    # ไม่ใช้ SVG placeholder เดิมอีกต่อไป
    var generated := load("res://assets/jogress/omegamon_generated.png") as Texture2D
    if generated == null:
        push_error("JogressManager: ไม่พบภาพ Omegamon ที่ generate ใหม่")
        return null

    var frames := SpriteFrames.new()
    if frames.has_animation(&"default"):
        frames.remove_animation(&"default")

    # ภาพหลักเป็น key art เดียวกัน แต่แบ่ง state animation ให้ CombatAction
    # ใช้ VFX/scale/impact frame ทำให้ Grey Sword และ Garuru Cannon มีจังหวะร่ายจริง
    _add_generated_animation(frames, &"idle", generated, 2, 2.2, true)
    _add_generated_animation(frames, &"walk", generated, 2, 4.0, true)
    _add_generated_animation(frames, &"attack", generated, 4, 10.0, false)
    _add_generated_animation(frames, &"cast", generated, 4, 10.0, false)

    return frames


func _add_generated_animation(
        frames: SpriteFrames,
        animation: StringName,
        texture: Texture2D,
        frame_count: int,
        fps: float,
        loop: bool
) -> void:
    frames.add_animation(animation)
    frames.set_animation_speed(animation, fps)
    frames.set_animation_loop(animation, loop)
    for _index: int in range(frame_count):
        frames.add_frame(animation, texture)


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
