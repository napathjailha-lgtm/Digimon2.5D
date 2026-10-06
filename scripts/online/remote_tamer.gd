class_name RemoteTamer
extends Node2D

signal interaction_requested(peer_id: String, display_name: String, guild_name: String)

@export var interpolation_speed: float = 12.0
@export var partner_interpolation_speed: float = 11.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var guild_label: Label = $GuildLabel
@onready var partner_visual: Node2D = $PartnerVisual
@onready var partner_sprite: AnimatedSprite2D = $PartnerVisual/AnimatedSprite2D
@onready var partner_name: Label = $PartnerVisual/NameLabel
@onready var chat_bubble: WorldChatBubble = $ChatBubble

var peer_id: String = ""
var target_position: Vector2
var target_velocity: Vector2
var facing: String = "down"
var display_name: String = "Tamer"
var guild_name: String = ""
var initialized := false

var target_partner_position: Vector2
var partner_velocity: Vector2
var partner_form_id: StringName = &""
var partner_animation: StringName = &""
var partner_facing: String = "down"
var partner_initialized := false
var partner_visible := false
var _tamer_model_id: StringName = &""

func _ready() -> void:
    var hitbox := get_node_or_null("PlayerHitbox") as Area2D
    if hitbox != null:
        hitbox.input_event.connect(_on_player_hitbox_input)

func _on_player_hitbox_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    var activate := false
    if event is InputEventScreenTouch:
        activate = event.pressed and not event.canceled
    elif event is InputEventMouseButton:
        activate = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    if not activate:
        return
    interaction_requested.emit(peer_id, display_name, guild_name)
    get_viewport().set_input_as_handled()

func show_chat(message: String) -> void:
    if is_instance_valid(chat_bubble):
        chat_bubble.show_message(message)

func setup(id: String, payload: Dictionary) -> void:
    peer_id = id
    apply_state(payload, true)

func apply_state(payload: Dictionary, snap: bool = false) -> void:
    display_name = str(payload.get("name", display_name)).substr(0, 24)
    name_label.text = display_name
    guild_name = str(payload.get("guild_name", "")).strip_edges().substr(0, 20)
    guild_label.visible = not guild_name.is_empty()
    guild_label.text = "<%s>" % guild_name if not guild_name.is_empty() else ""

    var model_id := StringName(str(payload.get("tamer_model", "")))
    if model_id != &"" and model_id != _tamer_model_id:
        _apply_tamer_model(model_id)

    _apply_vec2_to_sprite(payload.get("tamer_scale", {}), sprite, true)
    _apply_vec2_to_sprite(payload.get("tamer_offset", {}), sprite, false)

    var position_data: Variant = payload.get("position", {})
    if position_data is Dictionary:
        target_position = _dict_to_vec2(position_data, global_position)
    var velocity_data: Variant = payload.get("velocity", {})
    if velocity_data is Dictionary:
        target_velocity = _dict_to_vec2(velocity_data, Vector2.ZERO)
    facing = str(payload.get("facing", facing))
    if snap or not initialized:
        global_position = target_position
        initialized = true

    var partner_data: Variant = payload.get("partner", {})
    if partner_data is Dictionary:
        _apply_partner_state(partner_data as Dictionary, snap)

func _process(delta: float) -> void:
    if not initialized:
        return

    global_position = global_position.lerp(target_position, clampf(delta * interpolation_speed, 0.0, 1.0))
    var moving := target_velocity.length_squared() > 16.0
    var animation := StringName(("walk_" if moving else "idle_") + facing)
    if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation):
        if sprite.animation != animation:
            sprite.play(animation)
        elif not sprite.is_playing():
            sprite.play(animation)

    partner_visual.visible = partner_visible
    if not partner_visible or not partner_initialized:
        return

    partner_visual.global_position = partner_visual.global_position.lerp(
        target_partner_position,
        clampf(delta * partner_interpolation_speed, 0.0, 1.0)
    )

    var next_animation := partner_animation
    if next_animation == &"":
        next_animation = _fallback_partner_animation()
    if partner_sprite.sprite_frames != null and partner_sprite.sprite_frames.has_animation(next_animation):
        if partner_sprite.animation != next_animation:
            partner_sprite.play(next_animation)
        elif not partner_sprite.is_playing():
            partner_sprite.play(next_animation)

func _apply_tamer_model(model_id: StringName) -> void:
    GameManager.ensure_catalog()
    if GameManager.catalog == null:
        return
    var model: TamerModelData = GameManager.catalog.tamer_by_id(model_id)
    if model == null or model.sprite_frames == null:
        return
    _tamer_model_id = model_id
    sprite.sprite_frames = model.sprite_frames
    sprite.scale = model.sprite_scale

func _apply_partner_state(data: Dictionary, snap: bool) -> void:
    partner_visible = bool(data.get("visible", false))
    var form_id := StringName(str(data.get("form_id", "")))
    if form_id != &"" and form_id != partner_form_id:
        var form := _find_form(form_id)
        if form != null:
            partner_form_id = form_id
            partner_sprite.sprite_frames = form.sprite_frames
            partner_sprite.scale = form.sprite_scale
            partner_name.text = form.monster_name

    var position_data: Variant = data.get("position", {})
    if position_data is Dictionary:
        target_partner_position = _dict_to_vec2(position_data, target_position)
    var velocity_data: Variant = data.get("velocity", {})
    if velocity_data is Dictionary:
        partner_velocity = _dict_to_vec2(velocity_data, Vector2.ZERO)

    partner_facing = str(data.get("facing", partner_facing))
    partner_animation = StringName(str(data.get("animation", partner_animation)))

    _apply_vec2_to_sprite(data.get("scale", {}), partner_sprite, true)
    _apply_vec2_to_sprite(data.get("offset", {}), partner_sprite, false)

    if snap or not partner_initialized:
        partner_visual.global_position = target_partner_position
        partner_initialized = true

func _find_form(form_id: StringName) -> MonsterData:
    GameManager.ensure_catalog()
    if GameManager.catalog == null:
        return null
    for family: StarterPartnerData in GameManager.catalog.starters:
        if family == null:
            continue
        for form: MonsterData in family.forms:
            if form != null and form.id == form_id:
                return form
    return null

func _fallback_partner_animation() -> StringName:
    if partner_sprite.sprite_frames == null:
        return &""
    var moving := partner_velocity.length_squared() > 16.0
    var directional := StringName(("walk_" if moving else "idle_") + partner_facing)
    if partner_sprite.sprite_frames.has_animation(directional):
        return directional
    var generic := StringName("walk" if moving else "idle")
    if partner_sprite.sprite_frames.has_animation(generic):
        return generic
    return partner_sprite.sprite_frames.get_animation_names()[0] if not partner_sprite.sprite_frames.get_animation_names().is_empty() else &""

func _dict_to_vec2(value: Dictionary, fallback: Vector2) -> Vector2:
    return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))

func _apply_vec2_to_sprite(value: Variant, target: AnimatedSprite2D, is_scale: bool) -> void:
    if not (value is Dictionary) or not is_instance_valid(target):
        return
    var current := target.scale if is_scale else target.offset
    var next := _dict_to_vec2(value as Dictionary, current)
    if is_scale:
        if next.x > 0.0 and next.y > 0.0:
            target.scale = next
    else:
        target.offset = next
