class_name VitalsCard
extends Panel
## กรอบเลือดแบบเกม MMO: รูปตัวละคร + ชื่อ/Lv + HP + Tamer MP + EXP
var portrait: TextureRect
var header: Label
var level_label: Label
var subtitle: Label
var hp_bar: ProgressBar
var ds_bar: ProgressBar
var exp_bar: ProgressBar
var _last_texture: Texture2D
var is_partner: bool = false

func _ready() -> void:
    # Node ชื่อ HP/EXP คงไว้เพื่อเชื่อมกับระบบเดิมและอ่านค่าได้ง่าย
    size = Vector2(324, 80)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", ClassicUIStyle.frame(ClassicUIStyle.GOLD if is_partner else ClassicUIStyle.BLUE))
    var portrait_bg := Panel.new()
    portrait_bg.position = Vector2(4, 4)
    portrait_bg.size = Vector2(68, 68)
    portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait_bg.add_theme_stylebox_override("panel", ClassicUIStyle.frame(ClassicUIStyle.GOLD, Color("123459")))
    add_child(portrait_bg)
    portrait = TextureRect.new()
    portrait.position = Vector2(3, 3)
    portrait.size = Vector2(62, 62)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait_bg.add_child(portrait)
    level_label = ClassicUIStyle.label("Lv 1", Vector2(3, 52), Vector2(64, 17), 11)
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.add_theme_stylebox_override("normal", ClassicUIStyle.frame(ClassicUIStyle.GOLD))
    portrait_bg.add_child(level_label)
    header = ClassicUIStyle.label("", Vector2(80, 2), Vector2(230, 21), 14)
    header.name = "Header"
    add_child(header)
    hp_bar = _make_bar("HP", 25, Color("da4249"), true)
    ds_bar = _make_bar("MP", 42, Color("20a3de"), true)
    exp_bar = _make_bar("EXP", 60, Color("d6b461"), false)
    subtitle = ClassicUIStyle.label("", Vector2(80, 66), Vector2(234, 13), 9)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(subtitle)

func _make_bar(key: String, y: float, color: Color, with_value: bool) -> ProgressBar:
    # ข้อความเป็นลูกของ Bar จึงเคลื่อนตำแหน่งตามกันเสมอ
    var bar := ProgressBar.new()
    bar.name = key
    bar.position = Vector2(80, y)
    bar.size = Vector2(234, 14 if with_value else 5)
    bar.show_percentage = false
    bar.add_theme_font_size_override("font_size", 1)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background: StyleBoxFlat = ClassicUIStyle.frame(Color("080e1c"), Color("030c18"))
    background.set_corner_radius_all(1)
    bar.add_theme_stylebox_override("background", background)
    var fill: StyleBoxFlat = ClassicUIStyle.frame(color.lightened(0.2), color)
    fill.set_corner_radius_all(1)
    bar.add_theme_stylebox_override("fill", fill)
    add_child(bar)
    # ตั้งขนาดหลัง Theme/Font พร้อม เพื่อไม่เก็บขนาดขั้นต่ำของธีมเดิม
    bar.size = Vector2(234, 14 if with_value else 5)
    if with_value:
        var text: Label = ClassicUIStyle.label("", Vector2.ZERO, bar.size, 10)
        text.name = "Value"
        text.add_theme_font_override("font", ThemeDB.fallback_font)
        text.size = bar.size
        text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        bar.add_child(text)
    return bar

func update_values(actor: Node, ds: float, max_ds: float, title: String, texture: Texture2D) -> void:
    # พารามิเตอร์ ds/max_ds คงชื่อเดิมเพื่อ compatibility แต่ค่าที่แสดงคือ Tamer MP
    header.text = title
    level_label.text = "Lv %d" % actor.progress.level
    hp_bar.max_value = maxi(1, actor.max_hp)
    hp_bar.value = actor.hp
    (hp_bar.get_node("Value") as Label).text = "HP  %d / %d" % [actor.hp, actor.max_hp]
    ds_bar.max_value = maxf(1.0, max_ds)
    ds_bar.value = ds
    (ds_bar.get_node("Value") as Label).text = "Tamer MP  %.0f / %.0f" % [ds, max_ds]
    exp_bar.max_value = actor.progress.max_exp
    exp_bar.value = actor.progress.current_exp
    var percent: float = 100.0 * actor.progress.current_exp / maxf(1, actor.progress.max_exp)
    subtitle.text = ("ใช้ Tamer MP ตอนเปลี่ยนร่าง  •  " if is_partner else "") + "EXP %.1f%%" % percent
    if texture != _last_texture:
        _last_texture = texture
        # ครอปส่วนบนของภาพต้นฉบับเป็น portrait โดยไม่แก้ไฟล์ภาพ
        var cropped := AtlasTexture.new()
        var visible: Texture2D = WalkTextureTools.visible_texture(texture)
        cropped.atlas = visible
        cropped.region = Rect2(0, 0, visible.get_width(), visible.get_height() * 0.48)
        portrait.texture = cropped
