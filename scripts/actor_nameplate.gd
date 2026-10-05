extends Node2D
## ชื่อและหลอดเลือดเล็กบนหัว ยึดตามความสูงภาพแต่ละร่าง
var _actor: Node2D
var _name: Label
var _left: float = 0.0

func _ready() -> void:
    _actor = get_parent() as Node2D
    z_index = 10
    _name = Label.new()
    _name.position = Vector2(-90, -24)
    _name.size = Vector2(180, 22)
    _name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _name.add_theme_font_override("font", preload("res://assets/fonts/NotoSansThai.ttf"))
    _name.add_theme_font_size_override("font_size", 12)
    _name.add_theme_color_override("font_outline_color", Color("07182e"))
    _name.add_theme_constant_override("outline_size", 3)
    add_child(_name)

func _process(delta: float) -> void:
    # ลดการวาดซ้ำและอัปเดตตำแหน่งเมื่อเปลี่ยนร่าง/ไข่
    _left -= delta
    if _left > 0.0:
        return
    _left = 0.1
    var texture: Texture2D
    var scale_y: float
    if _actor is Tamer:
        var actor := _actor as Tamer
        _name.text = actor.display_name
        texture = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, actor.sprite.frame)
        scale_y = actor.sprite.scale.y
        _name.modulate = Color("9af8eb")
    elif _actor is PartnerMonster:
        var actor := _actor as PartnerMonster
        _name.text = actor.current_form.monster_name if actor.is_alive() else "Core Egg"
        texture = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, actor.sprite.frame) if actor.is_alive() else actor.egg_sprite.texture
        scale_y = actor.sprite.scale.y if actor.is_alive() else actor.egg_sprite.scale.y
        _name.modulate = Color("ffdc8e")
    elif _actor is WildMonster:
        var actor := _actor as WildMonster
        _name.text = String(actor.monster_id).capitalize()
        var image: Sprite2D = actor.get_node("Sprite2D")
        texture = image.texture
        scale_y = image.scale.y
        _name.modulate = Color("ffd4d4")
    if texture != null:
        position.y = -WalkTextureTools.visible_texture(texture).get_height() * scale_y - 12.0
    queue_redraw()

func _draw() -> void:
    if _actor == null:
        return
    var ratio: float = clampf(float(_actor.get("hp")) / maxf(1.0, float(_actor.get("max_hp"))), 0.0, 1.0)
    draw_rect(Rect2(-31, 0, 62, 7), Color("05101b"))
    draw_rect(Rect2(-30, 1, 60 * ratio, 5), Color("d54d52"))
