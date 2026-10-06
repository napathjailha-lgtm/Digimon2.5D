class_name RemoteTamer
extends Node2D

@export var interpolation_speed: float = 12.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel

var peer_id: String = ""
var target_position: Vector2
var target_velocity: Vector2
var facing: String = "down"
var display_name: String = "Tamer"
var initialized := false

func setup(id: String, payload: Dictionary) -> void:
    peer_id = id
    apply_state(payload, true)

func apply_state(payload: Dictionary, snap: bool = false) -> void:
    display_name = str(payload.get("name", display_name)).substr(0, 24)
    name_label.text = display_name
    var position_data: Variant = payload.get("position", {})
    if position_data is Dictionary:
        target_position = Vector2(float(position_data.get("x", global_position.x)), float(position_data.get("y", global_position.y)))
    var velocity_data: Variant = payload.get("velocity", {})
    if velocity_data is Dictionary:
        target_velocity = Vector2(float(velocity_data.get("x", 0.0)), float(velocity_data.get("y", 0.0)))
    facing = str(payload.get("facing", facing))
    if snap or not initialized:
        global_position = target_position
        initialized = true

func _process(delta: float) -> void:
    if not initialized:
        return
    global_position = global_position.lerp(target_position, clampf(delta * interpolation_speed, 0.0, 1.0))
    var moving := target_velocity.length_squared() > 16.0
    var animation := StringName(("walk_" if moving else "idle_") + facing)
    if sprite.sprite_frames.has_animation(animation):
        if sprite.animation != animation:
            sprite.play(animation)
        elif not sprite.is_playing():
            sprite.play(animation)
