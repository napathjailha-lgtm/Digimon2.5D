class_name CreatureStatusPreview
extends Control
## ภาพพรีวิวแยกจากตัวสนาม ใช้ SpriteFrames เดียวกันแต่ไม่แก้ท่าของตัวจริง
var sprite: AnimatedSprite2D
var egg: Sprite2D

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    sprite = AnimatedSprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(sprite)
    egg = Sprite2D.new()
    add_child(egg)
    resized.connect(_fit)

func configure(partner: PartnerMonster) -> void:
    var animation: StringName = partner.current_form.idle_animation
    if sprite.sprite_frames != partner.current_form.sprite_frames or sprite.animation != animation:
        sprite.sprite_frames = partner.current_form.sprite_frames
        sprite.play(animation)
    sprite.visible = partner.is_alive()
    egg.visible = not sprite.visible
    egg.texture = partner.egg_sprite.texture
    _fit()

func _fit() -> void:
    if sprite == null:
        return
    sprite.position = size * Vector2(0.5, 0.46)
    if sprite.sprite_frames != null and sprite.sprite_frames.get_frame_count(sprite.animation) > 0:
        var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
        sprite.scale = Vector2.ONE * minf(size.x * 0.85 / texture.get_width(), size.y * 0.8 / texture.get_height())
    egg.position = size * Vector2(0.5, 0.55)
    if egg.texture != null:
        egg.scale = Vector2.ONE * minf(100.0 / egg.texture.get_width(), 130.0 / egg.texture.get_height())
    queue_redraw()

func _draw() -> void:
    # เส้นดิจิตอลเบา ๆ ไม่กลบรายละเอียดตัวละคร
    for x: int in range(0, int(size.x), 26):
        draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.8, 1.0, 0.045))
    for y: int in range(0, int(size.y), 26):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.8, 1.0, 0.045))
    draw_set_transform(size * Vector2(0.5, 0.83), 0.0, Vector2(1, 0.28))
    for radius: float in [66.0, 88.0, 108.0]:
        draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.2, 0.8, 1.0, 0.24), 2.0, true)
    draw_set_transform(Vector2.ZERO)
