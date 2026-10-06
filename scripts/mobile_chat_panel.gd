class_name MobileChatPanel
extends Panel
## แชตแบบพับได้ ปุ่ม touch แยก finger และ LineEdit เรียกคีย์บอร์ดมือถือ
signal editing_changed(editing: bool)
var log_view: RichTextLabel
var line_edit: LineEdit
var send_button: ClassicCommand
var fold_button: ClassicCommand
var tabs: Array[ClassicCommand] = []
var active_filter: StringName = &"all"
var collapsed: bool = false
var _touch_finger: int = -1
var _keyboard_offset: float = 0.0

var bottom_inset: float = 24
var _rows: VBoxContainer
var title_label: Label
signal folded_changed(collapsed: bool)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.04, 0.09, 0.12, 0.52)
    background.set_corner_radius_all(8)
    add_theme_stylebox_override("panel", background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side: String in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side, 4)
    add_child(margin)
    _rows = VBoxContainer.new()
    _rows.add_theme_constant_override("separation", 4)
    margin.add_child(_rows)
    var header := HBoxContainer.new()
    _rows.add_child(header)
    title_label = Label.new()
    title_label.text = "พูดคุย • OFFLINE"
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.add_theme_font_size_override("font_size", 15)
    header.add_child(title_label)
    fold_button = _button(header, "+", Vector2(64,44))
    fold_button.pressed.connect(toggle_collapsed)
    var tab_row := HBoxContainer.new()
    tab_row.name = "Tabs"
    _rows.add_child(tab_row)
    for index: int in range(4):
        var tab: ClassicCommand = _button(tab_row,["ทั้งหมด","ทั่วไป","กิลด์","ระบบ"][index],Vector2(68,44))
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.pressed.connect(_set_filter.bind([&"all",&"general",&"guild",&"system"][index]))
        tabs.append(tab)
    log_view = RichTextLabel.new()
    log_view.custom_minimum_size = Vector2(0,100)
    log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_view.add_theme_font_size_override("normal_font_size", 15)
    log_view.scroll_following = true
    _rows.add_child(log_view)
    var edit_row := HBoxContainer.new()
    edit_row.name = "Edit"
    _rows.add_child(edit_row)
    line_edit = LineEdit.new()
    line_edit.custom_minimum_size = Vector2(0,48)
    line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    line_edit.max_length = 160
    line_edit.placeholder_text = "พิมพ์ข้อความ…"
    line_edit.virtual_keyboard_enabled = true
    line_edit.text_submitted.connect(_submit)
    line_edit.focus_entered.connect(func(): editing_changed.emit(true))
    line_edit.focus_exited.connect(func(): editing_changed.emit(false))
    edit_row.add_child(line_edit)
    send_button = _button(edit_row,"ส่ง",Vector2(64,48))
    send_button.pressed.connect(_send)
    GameChat.messages_changed.connect(_refresh)
    OnlineManager.connection_changed.connect(_on_connection_changed)
    _on_connection_changed(OnlineManager.connected, "Online" if OnlineManager.connected else "Offline")
    set_collapsed(true)
    _refresh()

func _button(parent: Node, text: String, extent: Vector2) -> ClassicCommand:
    var button := HybridChatCommand.new()
    button.custom_minimum_size = extent
    button.caption = text
    button.tint = Color("10385a")
    parent.add_child(button)
    button._label.add_theme_font_size_override("font_size", 15)
    return button

func layout_panel() -> void:
    # ยกเหนือคีย์บอร์ดเท่าที่จำเป็น ไม่บวกความสูง keyboard ซ้ำกับระยะหนี Joystick
    offset_bottom = -maxf(bottom_inset, _keyboard_offset + 12 if _keyboard_offset > 0 else bottom_inset)
    offset_top = offset_bottom - (52.0 if collapsed else 260.0)

func set_collapsed(value: bool) -> void:
    # Header 52px ยังแตะง่าย; เนื้อหา/แท็บซ่อนทั้ง Container จึงไม่เหลือช่องว่าง
    collapsed = value
    if line_edit == null:
        return
    line_edit.release_focus()
    _rows.get_node("Tabs").visible = not collapsed
    _rows.get_node("Edit").visible = not collapsed
    log_view.visible = not collapsed
    fold_button.set_caption("+" if collapsed else "−")
    layout_panel()

func _send() -> void:
    _submit(line_edit.text)

func _submit(text: String) -> void:
    # แตะ Send หรือ Enter ใช้ฟังก์ชันเดียวกัน ปิดคีย์บอร์ดเมื่อส่งสำเร็จ
    if GameChat.submit_local(text):
        line_edit.clear()
        line_edit.release_focus()

func _set_filter(filter: StringName) -> void:
    active_filter = filter
    _refresh()

func _refresh() -> void:
    # add_text แสดง [b] หรือ [img] ของผู้เล่นเป็นข้อความ ไม่ใช่ markup
    if log_view == null:
        return
    log_view.clear()
    for entry: Dictionary in GameChat.messages:
        if active_filter != &"all" and entry.channel != active_filter:
            continue
        var row_color := Color("8bdfed")
        if entry.channel == &"system":
            row_color = Color("e5c87b")
        elif entry.channel == &"guild":
            row_color = Color("c8a7ff")
        log_view.push_color(row_color)
        log_view.add_text("[%s] %s\n" % [entry.sender, entry.body])
        log_view.pop()
    for index: int in range(tabs.size()):
        tabs[index].tint = Color("226596") if active_filter == [&"all", &"general", &"guild", &"system"][index] else Color("10385a")
        tabs[index].queue_redraw()

func _on_connection_changed(is_connected: bool, _message: String) -> void:
    if title_label != null:
        title_label.text = "พูดคุย • ONLINE" if is_connected else "พูดคุย • OFFLINE"

func toggle_collapsed() -> void:
    set_collapsed(not collapsed)
    folded_changed.emit(collapsed)

func release_input() -> void:
    # เรียกก่อนคัตซีน ไม่ปล่อย keyboard focus ค้างบนหน้าจอ
    _touch_finger = -1
    line_edit.release_focus()
    for button: ClassicCommand in tabs + [send_button, fold_button]:
        button.release_input()

func _input(event: InputEvent) -> void:
    # กิน touch ในหน้าต่าง ป้องกันเลือกศัตรูทะลุแชต
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
        if event.pressed and not event.canceled and Rect2(Vector2.ZERO, size).has_point(local):
            _touch_finger = event.index
            if not collapsed and Rect2(Vector2.ZERO, line_edit.size).has_point(line_edit.get_global_transform_with_canvas().affine_inverse() * event.position):
                line_edit.grab_focus()
                line_edit.caret_column = line_edit.text.length()
            get_viewport().set_input_as_handled()
        elif event.pressed and line_edit.has_focus():
            line_edit.release_focus()
        elif event.index == _touch_finger:
            if not event.pressed or event.canceled:
                _touch_finger = -1
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == _touch_finger:
        # ลากข้อความเพื่อเลื่อนดูย้อนหลัง โดยไม่สั่งตัวละครเดิน
        if not collapsed:
            log_view.get_v_scroll_bar().value -= event.relative.y
        get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
    # ยกช่องพิมพ์เหนือคีย์บอร์ด Android/iOS เมื่อระบบรายงานความสูง
    var height: int = DisplayServer.virtual_keyboard_get_height() if line_edit.has_focus() else 0
    _apply_keyboard_height(height)

func _apply_keyboard_height(pixel_height: int) -> void:
    # OS ส่งหน่วย pixel จริง แต่ Control ใช้หน่วย viewport หลัง stretch
    var screen_height: float = maxf(1.0, get_tree().root.size.y)
    var viewport_height: float = get_viewport().get_visible_rect().size.y
    var desired: float = clampf(pixel_height * viewport_height / screen_height, 0.0, maxf(0.0, viewport_height - 230.0))
    if is_equal_approx(desired, _keyboard_offset):
        return
    _keyboard_offset = desired
    layout_panel()
