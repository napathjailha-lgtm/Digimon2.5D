@tool
extends Node2D
## รากอยู่ที่เท้า: ต้นไม้/บ้านและตัวละครจึงเข้า Y Sort ร่วมกัน
var sprite: Sprite2D
var player: Node2D
var check_left: float = 0.0
var can_fade: bool = false

func _ready() -> void:
    # บ้าน/หิน/ดอกไม้ไม่ต้องได้รับ _process ทุกเฟรมเลย
    set_process(can_fade and not Engine.is_editor_hint())

func _process(delta: float) -> void:
    # จางยอดไม้เฉพาะเมื่อผู้เล่นอยู่หลังภาพ ลดปัญหาตัวละครหายใต้ต้นไม้
    if Engine.is_editor_hint() or not can_fade or not is_instance_valid(player) or not is_instance_valid(sprite):
        return
    check_left -= delta
    if check_left > 0.0:
        return
    check_left = 0.22 if HybridPlatform.is_web_mobile(get_viewport()) else 0.12
    # ต้นไม้ไกลกล้องไม่สามารถบังผู้เล่นได้ จึงข้าม transform/texture checks
    if global_position.distance_squared_to(player.global_position) > 900.0 * 900.0:
        sprite.modulate.a = 1.0
        return
    var local: Vector2 = to_local(player.global_position)
    var hidden_behind: bool = local.y < 0.0 and local.y > -sprite.texture.get_height() * sprite.scale.y and absf(local.x) < sprite.texture.get_width() * sprite.scale.x * 0.38
    sprite.modulate.a = 0.48 if hidden_behind else 1.0
