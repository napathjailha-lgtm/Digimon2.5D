class_name ResonanceManager
extends Node
## Resonance ของ Cinderling + Frostcub เมื่อ Shared Companion Level ถึง 90
## ใช้ asset ต้นฉบับ Aegis Nova และคัตซีน Resonance ก่อน commit ร่าง

signal availability_changed(available: bool)
signal resonance_changed(active: bool)

const REQUIRED_LEVEL: int = 90
const REQUIRED_IDS: Array[StringName] = [&"cinderling", &"frostcub"]

var tamer: Tamer
var partner: PartnerMonster
var roster: PartnerRoster
var active: bool = false
var _fusion_form: MonsterData
var _last_available: bool = false
var _cutscene: ResonanceCutscene

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

func can_resonate() -> bool:
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

func request_resonance() -> bool:
    if active or is_instance_valid(_cutscene):
        return false
    if not can_resonate():
        if is_instance_valid(partner):
            partner.feedback.emit("Resonance ต้องมี Cinderling และ Frostcub ในทีม และ Shared Companion Level 90")
        return false

    _fusion_form = _build_fusion_form()
    if _fusion_form == null or not _fusion_form.validation_error().is_empty():
        partner.feedback.emit("สร้างข้อมูล Aegis Nova ไม่สำเร็จ")
        return false

    partner.auto_battle = false
    partner.cancel_battle()

    _cutscene = ResonanceCutscene.new()
    get_tree().root.add_child(_cutscene)
    _cutscene.finished.connect(_finish_resonance)

    if not _cutscene.play(partner, _fusion_form):
        _cutscene.queue_free()
        _cutscene = null
        return false

    partner.feedback.emit("Resonance Shift...")
    return true

func _finish_resonance(success: bool) -> void:
    _cutscene = null
    if not success or not is_instance_valid(partner):
        return

    partner._internal_load = true
    var ok: bool = partner.load_monster_data(_fusion_form, true)
    partner._internal_load = false
    if not ok:
        partner.feedback.emit("Resonance ล้มเหลว: โหลด Aegis Nova ไม่สำเร็จ")
        return

    active = true
    partner.feedback.emit("Resonance: Aegis Nova")
    resonance_changed.emit(true)
    _refresh_available()
    if is_instance_valid(tamer):
        tamer.save_party_progress()

func _build_fusion_form() -> MonsterData:
    var data := MonsterData.new()
    data.id = &"aegis_nova"
    data.monster_name = "Aegis Nova"
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

    var frames: SpriteFrames = _build_frames()
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
    data.skills = [_nova_blade(), _aether_cannon()]
    return data

func _build_frames() -> SpriteFrames:
    var texture := load("res://assets/original/fusion/aegis_nova.svg") as Texture2D
    if texture == null:
        push_error("ResonanceManager: ไม่พบ asset Aegis Nova")
        return null
    var frames := SpriteFrames.new()
    if frames.has_animation(&"default"):
        frames.remove_animation(&"default")
    _add_animation(frames, &"idle", texture, 2, 2.2, true)
    _add_animation(frames, &"walk", texture, 2, 4.0, true)
    _add_animation(frames, &"attack", texture, 4, 10.0, false)
    _add_animation(frames, &"cast", texture, 4, 10.0, false)
    return frames

func _add_animation(frames: SpriteFrames, animation: StringName, texture: Texture2D, count: int, fps: float, loop: bool) -> void:
    frames.add_animation(animation)
    frames.set_animation_speed(animation, fps)
    frames.set_animation_loop(animation, loop)
    for _index: int in range(count):
        frames.add_frame(animation, texture)

func _nova_blade() -> MonsterSkill:
    var skill := MonsterSkill.new()
    skill.id = &"aegis_nova_blade"
    skill.display_name = "Nova Blade"
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

func _aether_cannon() -> MonsterSkill:
    var skill := MonsterSkill.new()
    skill.id = &"aegis_aether_cannon"
    skill.display_name = "Aether Cannon"
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
    if active and (data == null or data.id != &"aegis_nova"):
        active = false
        resonance_changed.emit(false)
    _refresh_available()

func _refresh_available() -> void:
    var next_available := can_resonate() and not active
    if next_available != _last_available:
        _last_available = next_available
        availability_changed.emit(next_available)
