class_name CompanionArchiveUI
extends CanvasLayer
## Companion Archive แบบ responsive: Party 3 ช่อง + Storage ไม่จำกัด
## ใช้ ScrollContainer และปุ่มขนาดสัมผัสแทนตำแหน่งตายตัว เพื่อให้ Web/Mobile แสดงผลเหมือนกัน

signal closed

var roster: PartnerRoster
var is_open: bool = false
var root: Control
var safe: MarginContainer
var panel: PanelContainer
var party_list: VBoxContainer
var storage_list: VBoxContainer
var party_count: Label
var storage_count: Label
var notice: Label
var visual_fx: ModalVisualFX
var _owns_pause: bool = false
var _previous_back_quit: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 96
    _build()
    root.hide()
    get_viewport().size_changed.connect(_layout)

func configure(owner_roster: PartnerRoster) -> void:
    roster = owner_roster
    if not roster.changed.is_connected(_deferred_refresh):
        roster.changed.connect(_deferred_refresh)
    if not roster.feedback.is_connected(_show_notice):
        roster.feedback.connect(_show_notice)

func open_screen() -> bool:
    if is_open or roster == null or get_tree().paused:
        return false
    _layout()
    is_open = true
    _owns_pause = true
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    get_tree().paused = true
    root.show()
    _refresh()
    visual_fx.animate_open()
    return true

func close_screen() -> void:
    if not is_open:
        return
    visual_fx.reset()
    _release_buttons()
    root.hide()
    is_open = false
    _restore_pause()
    if roster != null and is_instance_valid(roster.tamer):
        roster.tamer.save_party_progress()
    closed.emit()

func _restore_pause() -> void:
    if _owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _previous_back_quit
    _owns_pause = false

func _exit_tree() -> void:
    _restore_pause()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open:
        close_screen()

func _unhandled_input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
    get_viewport().set_input_as_handled()

func _build() -> void:
    root = Control.new()
    root.name = "Root"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.theme = ServiceUIStyle.make_theme()
    add_child(root)

    var shade := ColorRect.new()
    shade.name = "Shade"
    shade.color = Color(0.005, 0.018, 0.032, 0.70)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)

    safe = MarginContainer.new()
    safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(safe)

    var center := CenterContainer.new()
    safe.add_child(center)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(ServiceUIStyle.CYAN))
    center.add_child(panel)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    margin.add_child(stack)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    stack.add_child(header)

    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_stack.add_theme_constant_override("separation", 0)
    header.add_child(title_stack)
    title_stack.add_child(ServiceUIStyle.label("COMPANION ARCHIVE", 26, ServiceUIStyle.TEXT))
    title_stack.add_child(ServiceUIStyle.label("จัดทีมและฝาก Companion ได้เฉพาะที่ NPC นี้", 13, ServiceUIStyle.MUTED))

    var close := _button("ปิด ×", Vector2(94, 48), close_screen, ServiceUIStyle.GOLD)
    header.add_child(close)

    var summary := HBoxContainer.new()
    summary.add_theme_constant_override("separation", 10)
    stack.add_child(summary)
    var party_badge := PanelContainer.new()
    party_badge.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.GREEN, Color("0b241f")))
    party_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    summary.add_child(party_badge)
    party_count = ServiceUIStyle.label("", 16, ServiceUIStyle.GREEN)
    party_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    party_count.custom_minimum_size.y = 34
    party_badge.add_child(party_count)
    var storage_badge := PanelContainer.new()
    storage_badge.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.PURPLE, Color("1a1230")))
    storage_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    summary.add_child(storage_badge)
    storage_count = ServiceUIStyle.label("", 16, ServiceUIStyle.PURPLE)
    storage_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    storage_count.custom_minimum_size.y = 34
    storage_badge.add_child(storage_count)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 14)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(columns)

    var party_panel := _section_panel("CURRENT PARTY", "ตัวที่พกติดตัว • สูงสุด 3", ServiceUIStyle.GREEN)
    party_panel.custom_minimum_size.x = 420
    party_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(party_panel)
    party_list = party_panel.get_meta("list") as VBoxContainer

    var storage_panel := _section_panel("STORAGE BANK", "คลังถาวร • จำนวนไม่จำกัด", ServiceUIStyle.PURPLE)
    storage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(storage_panel)
    storage_list = storage_panel.get_meta("list") as VBoxContainer

    notice = ServiceUIStyle.label("แตะปุ่มด้านขวาของแต่ละการ์ดเพื่อย้าย Companion", 14, ServiceUIStyle.MUTED)
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.custom_minimum_size.y = 28
    stack.add_child(notice)

    visual_fx = ModalVisualFX.attach(root, panel)

func _section_panel(title: String, subtitle: String, accent: Color) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("081827f2")))
    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    frame.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 8)
    margin.add_child(stack)
    stack.add_child(ServiceUIStyle.label(title, 18, accent))
    stack.add_child(ServiceUIStyle.label(subtitle, 12, ServiceUIStyle.MUTED))
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 340
    scroll.clip_contents = true
    stack.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)
    frame.set_meta("list", list)
    return frame

func _layout() -> void:
    # Child card มี minimum width ของตัวเอง จึง fit ทั้ง Panel รอบจุดกึ่งกลางแทนการบังคับ width อย่างเดียว
    ResponsiveUI.apply_safe_margins(safe, get_viewport(), 12.0)
    panel.custom_minimum_size = Vector2(1080, 620)
    ResponsiveUI.fit_centered(panel, get_viewport(), 14.0)
    # เรียกซ้ำหลัง Container sort เพื่อให้ pivot ใช้ size จริง

func _refresh() -> void:
    if not is_open or roster == null:
        return
    _clear_list(party_list)
    _clear_list(storage_list)

    party_count.text = "PARTY  %d / %d" % [roster.members.size(), PartnerRoster.CAPACITY]
    storage_count.text = "STORAGE  %d" % roster.storage.size()

    for index: int in range(roster.members.size()):
        party_list.add_child(_member_card(roster.members[index], index, true))

    if roster.storage.is_empty():
        storage_list.add_child(_empty_state("คลังยังว่าง", "Companion ที่ฟักใหม่จะถูกส่งเข้าคลังนี้"))
    else:
        for index: int in range(roster.storage.size()):
            storage_list.add_child(_member_card(roster.storage[index], index, false))

func _member_card(entry: Dictionary, index: int, in_party: bool) -> PanelContainer:
    var data: StarterPartnerData = roster.family(StringName(str(entry.get("id", ""))))
    var active: bool = in_party and index == roster.active_index
    var accent: Color = ServiceUIStyle.GOLD if active else (ServiceUIStyle.GREEN if in_party else ServiceUIStyle.PURPLE)

    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("0a2031e8")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    card.add_child(row)

    var portrait_frame := PanelContainer.new()
    portrait_frame.custom_minimum_size = Vector2(58, 58)
    portrait_frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent.darkened(0.2), Color("07131f")))
    row.add_child(portrait_frame)
    var portrait := TextureRect.new()
    portrait.custom_minimum_size = Vector2(54, 54)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if data != null and not data.forms.is_empty() and data.forms[0] != null:
        var form: MonsterData = data.forms[0]
        portrait.texture = WalkTextureTools.visible_texture(form.sprite_frames.get_frame_texture(form.idle_animation, 0))
    portrait_frame.add_child(portrait)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 1)
    row.add_child(info)
    var display: String = data.display_name if data != null else str(entry.get("id", "Unknown"))
    var name := ServiceUIStyle.label(display, 17, ServiceUIStyle.TEXT)
    info.add_child(name)
    var level: int = int(roster.shared_progress.get("level", 1))
    var hp: int = int(entry.get("hp", 0))
    var max_hp: int = maxi(1, int(entry.get("max_hp", hp)))
    info.add_child(ServiceUIStyle.label("Lv.%d  •  HP %d/%d" % [level, hp, max_hp], 13, ServiceUIStyle.MUTED))
    if active:
        info.add_child(ServiceUIStyle.label("● ACTIVE PARTNER", 12, ServiceUIStyle.GOLD))
    elif in_party:
        info.add_child(ServiceUIStyle.label("พร้อมสลับลงสนาม", 12, ServiceUIStyle.GREEN))
    else:
        info.add_child(ServiceUIStyle.label("เก็บอยู่ใน Archive", 12, ServiceUIStyle.PURPLE))

    var action_text: String = "ฝากคลัง" if in_party else "เข้าปาร์ตี้"
    var action := _button(action_text, Vector2(106, 44), _move_party.bind(index) if in_party else _move_storage.bind(index), accent)
    if in_party:
        action.disabled = roster.members.size() <= 1
    else:
        action.disabled = roster.members.size() >= PartnerRoster.CAPACITY
    row.add_child(action)
    return card

func _empty_state(title: String, subtitle: String) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("38546b"), Color("07131f")))
    var stack := VBoxContainer.new()
    stack.custom_minimum_size.y = 90
    frame.add_child(stack)
    var a := ServiceUIStyle.label(title, 17, ServiceUIStyle.TEXT)
    a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(a)
    var b := ServiceUIStyle.label(subtitle, 13, ServiceUIStyle.MUTED)
    b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(b)
    return frame

func _button(text: String, minimum: Vector2, callback: Callable, accent: Color) -> DigimonTouchButton:
    var button := DigimonTouchButton.new()
    button.text = text
    button.custom_minimum_size = minimum
    ServiceUIStyle.button(button, accent)
    button.pressed.connect(callback)
    return button

func _move_party(index: int) -> void:
    roster.move_party_to_storage(index)
    _deferred_refresh()

func _move_storage(index: int) -> void:
    roster.move_storage_to_party(index)
    _deferred_refresh()

func _show_notice(text: String) -> void:
    if is_open:
        notice.text = text
        notice.add_theme_color_override("font_color", ServiceUIStyle.GOLD)

func _deferred_refresh(_a: Variant = null, _b: Variant = null) -> void:
    _refresh.call_deferred()

func _clear_list(list: VBoxContainer) -> void:
    for child: Node in list.get_children():
        list.remove_child(child)
        child.queue_free()

func _release_buttons() -> void:
    for node: Node in root.find_children("*", "", true, false):
        if node is DigimonTouchButton:
            (node as DigimonTouchButton).release_input()
