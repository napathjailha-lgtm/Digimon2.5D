class_name HybridPartyPanel
extends VBoxContainer
## สล็อตแนวตั้ง 3 ช่อง; ตัวสำรองใช้ snapshot ของตนเอง ไม่อ่าน HP ของตัวที่ลงสนาม
signal switch_requested(index: int)
signal empty_pressed
var roster: PartnerRoster
var buttons: Array[HybridCommand] = []
var _bars: Array[HybridVitalsBar] = []
var _compact: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_constant_override("separation", 10)
    for index: int in range(PartnerRoster.CAPACITY):
        var button := HybridCommand.new()
        button.name = "Member%d" % index
        button.custom_minimum_size = Vector2(84, 88)
        button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        button.pressed.connect(_request.bind(index))
        add_child(button)
        buttons.append(button)
        button._label.add_theme_font_size_override("font_size", 11)
        var bar := HybridVitalsBar.new()
        bar.name = "HP"
        bar.fill_color = Color("9add89")
        bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        bar.offset_left = 10
        bar.offset_right = -10
        bar.offset_top = -2
        bar.offset_bottom = 2
        button.add_child(bar)
        _bars.append(bar)

func configure(owner_roster: PartnerRoster) -> void:
    roster = owner_roster
    roster.changed.connect(refresh)
    refresh()

func refresh() -> void:
    if roster == null:
        return
    for index: int in range(buttons.size()):
        var button: HybridCommand = buttons[index]
        var exists: bool = index < roster.members.size()
        button.empty_slot = not exists
        button.set_meta("active", exists and index == roster.active_index)
        _bars[index].visible = exists
        if not exists:
            button.icon = null
            if button.has_meta("frame"):
                button.remove_meta("frame")
            button.set_caption("เพิ่ม")
        else:
            var entry: Dictionary = roster.members[index]
            var family: StarterPartnerData = roster.family(StringName(entry.id))
            var form: MonsterData = family.forms[0]
            for possible: MonsterData in family.forms:
                if String(possible.id) == str(entry.get("form_id", "")):
                    form = possible
                    break
            var frame: Texture2D = form.sprite_frames.get_frame_texture(form.idle_animation, 0)
            # ตัดครึ่งบนจาก texture ที่ trim แล้ว ให้หน้าอ่านได้บนจอมือถือ
            var visible_frame: Texture2D = WalkTextureTools.visible_texture(frame)
            # ตัวสี่ขาที่หางชูสูงต้องมีกรอบรูปหน้าเฉพาะ เพื่อไม่ให้สล็อตโชว์แต่หาง
            if form.portrait_texture != null:
                button.icon = form.portrait_texture
                button.set_meta("frame", frame)
            elif not button.has_meta("frame") or button.get_meta("frame") != frame:
                var portrait := AtlasTexture.new()
                portrait.atlas = visible_frame
                portrait.region = Rect2(0, 0, visible_frame.get_width(), visible_frame.get_height() * 0.5)
                button.icon = portrait
                button.set_meta("frame", frame)
            button.set_caption("DIGITAMA" if bool(entry.get("egg", false)) else form.monster_name)
            _bars[index].set_vitals(int(entry.get("hp", 0)), int(entry.get("max_hp", 1)), "", true)
        button._label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        button._label.offset_bottom = -8
        button._label.clip_text = true
        button.queue_redraw()

func _request(index: int) -> void:
    if roster == null:
        return
    if index >= roster.members.size():
        empty_pressed.emit()
    else:
        switch_requested.emit(index)

func release_input() -> void:
    for button: HybridCommand in buttons:
        button.release_input()

func set_compact(value: bool) -> void:
    # จอเตี้ยใช้ hitbox 76px ซึ่งยังใหญ่พอนิ้ว; ไม่ให้ช่องที่สามทับวงสกิลด้านล่าง
    if _compact == value:
        return
    _compact = value
    add_theme_constant_override("separation", 7 if value else 10)
    for button: HybridCommand in buttons:
        button.custom_minimum_size = Vector2(76, 76) if value else Vector2(84, 88)
