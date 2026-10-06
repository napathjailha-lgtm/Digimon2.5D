class_name GuildUI
extends CanvasLayer
## Guild Phase 1: create/join/leave/member list/guild chat.
## Server is authoritative; this UI only sends commands and renders snapshots.

signal closed

var hud: MobileHUD
var is_open: bool = false
var root: Control
var panel: PanelContainer
var status_label: Label
var guild_info: Label
var create_section: VBoxContainer
var guild_section: VBoxContainer
var create_name: LineEdit
var join_code: LineEdit
var guild_chat_input: LineEdit
var members_view: RichTextLabel
var chat_view: RichTextLabel
var create_button: DigimonTouchButton
var join_button: DigimonTouchButton
var leave_button: DigimonTouchButton
var send_button: DigimonTouchButton

var invite_root: Control
var invite_panel: PanelContainer
var invite_title: Label
var invite_detail: Label
var invite_accept_button: DigimonTouchButton
var invite_decline_button: DigimonTouchButton
var _pending_invite: Dictionary = {}
var _invite_revision: int = 0
var _invite_owns_pause: bool = false
var _invite_previous_back_quit: bool = true

var _owns_pause: bool = false
var _previous_back_quit: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 89
    _build()
    _build_invite_popup()
    root.hide()
    invite_root.hide()
    OnlineManager.guild_changed.connect(_on_guild_changed)
    OnlineManager.guild_feedback.connect(_on_guild_feedback)
    OnlineManager.guild_chat.connect(_on_guild_chat)
    OnlineManager.guild_invite_received.connect(_on_guild_invite_received)
    OnlineManager.connection_changed.connect(_on_connection_changed)
    GameChat.messages_changed.connect(_refresh_chat)
    get_viewport().size_changed.connect(_layout)
    _refresh()

func configure(owner_hud: MobileHUD) -> void:
    hud = owner_hud

func open_screen() -> bool:
    if is_open or get_tree().paused or not is_instance_valid(hud):
        return false
    hud.release_for_equipment()
    is_open = true
    _owns_pause = true
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    get_tree().paused = true
    root.show()
    _layout()
    _refresh()
    OnlineManager.request_guild()
    return true

func close_screen() -> void:
    if not is_open:
        return
    for field: LineEdit in [create_name, join_code, guild_chat_input]:
        field.release_focus()
    for button: DigimonTouchButton in [create_button, join_button, leave_button, send_button]:
        button.release_input()
    root.hide()
    is_open = false
    _restore_pause()
    closed.emit()

func _restore_pause() -> void:
    if _owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _previous_back_quit
    _owns_pause = false

func _exit_tree() -> void:
    _restore_invite_pause()
    _restore_pause()

func _notification(what: int) -> void:
    if what != NOTIFICATION_WM_GO_BACK_REQUEST:
        return
    if is_instance_valid(invite_root) and invite_root.visible:
        _respond_invite(false)
    elif is_open:
        close_screen()

func _layout() -> void:
    if is_instance_valid(panel):
        panel.custom_minimum_size = Vector2(940, 590)
        ResponsiveUI.fit_centered(panel, get_viewport(), 12.0)
    if is_instance_valid(invite_panel):
        invite_panel.custom_minimum_size = Vector2(520, 260)
        ResponsiveUI.fit_centered(invite_panel, get_viewport(), 16.0)

func _build() -> void:
    root = Control.new()
    root.name = "Root"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.theme = ServiceUIStyle.make_theme()
    add_child(root)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.004, 0.014, 0.027, 0.78)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(center)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(Color("7b5cff")))
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

    var title := Label.new()
    title.text = "GUILD"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 28)
    header.add_child(title)

    var close := _button("ปิด ×", Vector2(94, 48))
    close.pressed.connect(close_screen)
    header.add_child(close)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 14)
    stack.add_child(status_label)

    create_section = VBoxContainer.new()
    create_section.add_theme_constant_override("separation", 12)
    stack.add_child(create_section)

    var create_card := PanelContainer.new()
    create_card.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("62d0ff"), Color("071927ee")))
    create_section.add_child(create_card)
    var create_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        create_margin.add_theme_constant_override("margin_" + side, 14)
    create_card.add_child(create_margin)
    var create_stack := VBoxContainer.new()
    create_stack.add_theme_constant_override("separation", 8)
    create_margin.add_child(create_stack)
    create_stack.add_child(ServiceUIStyle.label("สร้างกิลด์ใหม่", 19, Color("62d0ff")))

    var create_row := HBoxContainer.new()
    create_row.add_theme_constant_override("separation", 8)
    create_stack.add_child(create_row)
    create_name = _line_edit("ชื่อกิลด์ 3–20 ตัวอักษร", 20)
    create_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    create_row.add_child(create_name)
    create_button = _button("สร้างกิลด์", Vector2(150, 50))
    create_button.pressed.connect(_create_guild)
    create_row.add_child(create_button)

    var join_card := PanelContainer.new()
    join_card.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("c59cff"), Color("160d29ee")))
    create_section.add_child(join_card)
    var join_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        join_margin.add_theme_constant_override("margin_" + side, 14)
    join_card.add_child(join_margin)
    var join_stack := VBoxContainer.new()
    join_stack.add_theme_constant_override("separation", 8)
    join_margin.add_child(join_stack)
    join_stack.add_child(ServiceUIStyle.label("เข้ากิลด์ด้วยรหัส", 19, Color("c59cff")))

    var join_row := HBoxContainer.new()
    join_row.add_theme_constant_override("separation", 8)
    join_stack.add_child(join_row)
    join_code = _line_edit("เช่น AB12CD", 12)
    join_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    join_row.add_child(join_code)
    join_button = _button("เข้ากิลด์", Vector2(150, 50))
    join_button.pressed.connect(_join_guild)
    join_row.add_child(join_button)

    guild_section = VBoxContainer.new()
    guild_section.add_theme_constant_override("separation", 10)
    guild_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(guild_section)

    var guild_header := HBoxContainer.new()
    guild_header.add_theme_constant_override("separation", 10)
    guild_section.add_child(guild_header)
    guild_info = Label.new()
    guild_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    guild_info.add_theme_font_size_override("font_size", 18)
    guild_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    guild_header.add_child(guild_info)
    leave_button = _button("ออกจากกิลด์", Vector2(150, 50))
    leave_button.pressed.connect(_leave_guild)
    guild_header.add_child(leave_button)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 12)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    guild_section.add_child(columns)

    var members_card := PanelContainer.new()
    members_card.custom_minimum_size.x = 330
    members_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    members_card.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("72e6b1"), Color("071d19ee")))
    columns.add_child(members_card)
    var members_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        members_margin.add_theme_constant_override("margin_" + side, 12)
    members_card.add_child(members_margin)
    var members_stack := VBoxContainer.new()
    members_margin.add_child(members_stack)
    members_stack.add_child(ServiceUIStyle.label("สมาชิก", 18, Color("72e6b1")))
    members_view = RichTextLabel.new()
    members_view.bbcode_enabled = false
    members_view.fit_content = false
    members_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    members_view.custom_minimum_size.y = 285
    members_view.add_theme_font_size_override("normal_font_size", 14)
    members_stack.add_child(members_view)

    var chat_card := PanelContainer.new()
    chat_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_card.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("c59cff"), Color("160d29ee")))
    columns.add_child(chat_card)
    var chat_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        chat_margin.add_theme_constant_override("margin_" + side, 12)
    chat_card.add_child(chat_margin)
    var chat_stack := VBoxContainer.new()
    chat_stack.add_theme_constant_override("separation", 8)
    chat_margin.add_child(chat_stack)
    chat_stack.add_child(ServiceUIStyle.label("แชตกิลด์", 18, Color("c59cff")))
    chat_view = RichTextLabel.new()
    chat_view.bbcode_enabled = false
    chat_view.scroll_following = true
    chat_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    chat_view.custom_minimum_size.y = 235
    chat_view.add_theme_font_size_override("normal_font_size", 14)
    chat_stack.add_child(chat_view)
    var chat_row := HBoxContainer.new()
    chat_row.add_theme_constant_override("separation", 8)
    chat_stack.add_child(chat_row)
    guild_chat_input = _line_edit("พิมพ์ข้อความกิลด์…", 160)
    guild_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    guild_chat_input.text_submitted.connect(func(_text: String) -> void: _send_guild_chat())
    chat_row.add_child(guild_chat_input)
    send_button = _button("ส่ง", Vector2(90, 48))
    send_button.pressed.connect(_send_guild_chat)
    chat_row.add_child(send_button)

func _build_invite_popup() -> void:
    invite_root = Control.new()
    invite_root.name = "GuildInvitePopup"
    invite_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    invite_root.theme = ServiceUIStyle.make_theme()
    invite_root.z_index = 200
    add_child(invite_root)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.004, 0.01, 0.02, 0.72)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    invite_root.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    invite_root.add_child(center)

    invite_panel = PanelContainer.new()
    invite_panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(Color("c59cff")))
    center.add_child(invite_panel)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    invite_panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 14)
    margin.add_child(stack)

    invite_title = ServiceUIStyle.label("คำเชิญเข้ากิลด์", 24, Color("c59cff"))
    invite_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(invite_title)

    invite_detail = ServiceUIStyle.label("", 17, ServiceUIStyle.TEXT)
    invite_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    invite_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(invite_detail)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 12)
    stack.add_child(actions)

    invite_decline_button = _button("ปฏิเสธ", Vector2(150, 54))
    invite_decline_button.pressed.connect(_respond_invite.bind(false))
    actions.add_child(invite_decline_button)

    invite_accept_button = _button("ยอมรับ", Vector2(150, 54))
    invite_accept_button.pressed.connect(_respond_invite.bind(true))
    actions.add_child(invite_accept_button)


func _button(caption: String, minimum: Vector2) -> DigimonTouchButton:
    var button := DigimonTouchButton.new()
    button.text = caption
    button.custom_minimum_size = minimum
    button.add_theme_font_size_override("font_size", 15)
    return button

func _line_edit(placeholder: String, max_length: int) -> LineEdit:
    var field := LineEdit.new()
    field.custom_minimum_size.y = 48
    field.placeholder_text = placeholder
    field.max_length = max_length
    field.virtual_keyboard_enabled = true
    field.add_theme_font_size_override("font_size", 16)
    return field

func _create_guild() -> void:
    if OnlineManager.create_guild(create_name.text):
        status_label.text = "กำลังสร้างกิลด์…"
        create_name.release_focus()

func _join_guild() -> void:
    if OnlineManager.join_guild(join_code.text):
        status_label.text = "กำลังเข้ากิลด์…"
        join_code.release_focus()

func _leave_guild() -> void:
    if OnlineManager.leave_guild():
        status_label.text = "กำลังออกจากกิลด์…"

func _send_guild_chat() -> void:
    if OnlineManager.send_guild_chat(guild_chat_input.text):
        guild_chat_input.clear()
        guild_chat_input.release_focus()
    elif OnlineManager.guild.is_empty():
        status_label.text = "ต้องเข้ากิลด์ก่อนใช้แชตกิลด์"

func _on_guild_changed(_snapshot: Dictionary) -> void:
    _refresh()

func _on_guild_feedback(message: String, ok: bool) -> void:
    status_label.text = ("✓ " if ok else "⚠ ") + message
    _refresh()

func _on_guild_chat(_peer_id: String, sender: String, text: String) -> void:
    GameChat.add_guild(sender, text)

func _on_guild_invite_received(invite: Dictionary) -> void:
    var invite_id: String = str(invite.get("invite_id", ""))
    if invite_id.is_empty():
        return
    if not OnlineManager.guild.is_empty():
        OnlineManager.respond_guild_invite(invite_id, false)
        return

    _invite_revision += 1
    var revision: int = _invite_revision
    _pending_invite = invite.duplicate(true)

    var guild_name: String = str(invite.get("guild_name", "Guild"))
    var from_name: String = str(invite.get("from_name", "ผู้เล่น"))
    var seconds: int = clampi(int(invite.get("expires_in", 30)), 5, 60)
    invite_title.text = "คำเชิญเข้ากิลด์"
    invite_detail.text = "%s ชวนคุณเข้ากิลด์\n<%s>\n\nคำเชิญหมดอายุใน %d วินาที" % [
        from_name, guild_name, seconds
    ]

    _invite_owns_pause = not get_tree().paused
    if _invite_owns_pause:
        _invite_previous_back_quit = get_tree().quit_on_go_back
        get_tree().quit_on_go_back = false
        get_tree().paused = true

    invite_root.show()
    _layout()
    _expire_invite_after(seconds, revision)


func _expire_invite_after(seconds: int, revision: int) -> void:
    await get_tree().create_timer(float(seconds), true).timeout
    if revision != _invite_revision or _pending_invite.is_empty():
        return
    _hide_invite_popup()
    if is_instance_valid(hud):
        hud._show_message("คำเชิญกิลด์หมดอายุแล้ว")


func _respond_invite(accept: bool) -> void:
    if _pending_invite.is_empty():
        _hide_invite_popup()
        return
    var invite_id: String = str(_pending_invite.get("invite_id", ""))
    _pending_invite.clear()
    _invite_revision += 1
    _hide_invite_popup()
    OnlineManager.respond_guild_invite(invite_id, accept)


func _hide_invite_popup() -> void:
    if is_instance_valid(invite_accept_button):
        invite_accept_button.release_input()
    if is_instance_valid(invite_decline_button):
        invite_decline_button.release_input()
    if is_instance_valid(invite_root):
        invite_root.hide()
    _restore_invite_pause()


func _restore_invite_pause() -> void:
    if _invite_owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _invite_previous_back_quit
    _invite_owns_pause = false


func _on_connection_changed(connected: bool, _message: String) -> void:
    if not connected:
        status_label.text = "OFFLINE • ต้องเชื่อมต่อ Online Server ก่อนใช้ระบบกิลด์"
    _refresh()

func _refresh() -> void:
    if not is_instance_valid(root):
        return
    var has_guild: bool = not OnlineManager.guild.is_empty()
    create_section.visible = not has_guild
    guild_section.visible = has_guild

    create_button.disabled = not OnlineManager.connected
    join_button.disabled = not OnlineManager.connected

    if not OnlineManager.connected:
        status_label.text = "OFFLINE • ระบบกิลด์ต้องเชื่อมต่อ Online Server"
    elif status_label.text.begins_with("OFFLINE"):
        status_label.text = "ONLINE • สร้างกิลด์หรือกรอกรหัสเพื่อเข้ากิลด์"

    if has_guild:
        var guild: Dictionary = OnlineManager.guild
        var role_text: String = "หัวหน้ากิลด์" if str(guild.get("role", "")) == "owner" else "สมาชิก"
        guild_info.text = "%s  •  %s\nรหัสเข้ากิลด์: %s  •  ออนไลน์ %d/%d" % [
            str(guild.get("name", "Guild")),
            role_text,
            str(guild.get("code", "------")),
            int(guild.get("online_count", 0)),
            int(guild.get("member_count", 0))
        ]
        leave_button.disabled = not OnlineManager.connected
        _refresh_members()
    _refresh_chat()

func _refresh_members() -> void:
    if not is_instance_valid(members_view):
        return
    members_view.clear()
    var raw: Variant = OnlineManager.guild.get("members", [])
    if not (raw is Array):
        return
    for member_value: Variant in raw:
        if not (member_value is Dictionary):
            continue
        var member := member_value as Dictionary
        var online_text: String = "●" if bool(member.get("online", false)) else "○"
        var role_text: String = "หัวหน้า" if str(member.get("role", "")) == "owner" else "สมาชิก"
        members_view.add_text("%s %s  •  %s\n" % [
            online_text,
            str(member.get("name", "Tamer")),
            role_text
        ])

func _refresh_chat() -> void:
    if not is_instance_valid(chat_view):
        return
    chat_view.clear()
    for entry: Dictionary in GameChat.messages:
        if entry.channel != &"guild":
            continue
        chat_view.add_text("[%s] %s\n" % [entry.sender, entry.body])

func _point_in(control: Control, point: Vector2) -> bool:
    if not is_instance_valid(control) or not control.is_visible_in_tree():
        return false
    var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
    return Rect2(Vector2.ZERO, control.size).has_point(local)

func _input(event: InputEvent) -> void:
    if is_instance_valid(invite_root) and invite_root.visible:
        return
    if not is_open:
        return
    if event is InputEventScreenTouch and event.pressed and not event.canceled:
        for field: LineEdit in [create_name, join_code, guild_chat_input]:
            if _point_in(field, event.position):
                field.grab_focus()
                field.caret_column = field.text.length()
                get_viewport().set_input_as_handled()
                return

func _unhandled_input(event: InputEvent) -> void:
    if is_instance_valid(invite_root) and invite_root.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            _respond_invite(false)
        get_viewport().set_input_as_handled()
        return
    if not is_open:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
    get_viewport().set_input_as_handled()
