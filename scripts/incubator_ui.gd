class_name IncubatorUI
extends CanvasLayer
## Digital Incubator แบบ responsive: เลือกไข่ทางซ้ายและดูขั้น Inject 0/5 ทางขวา
## ใช้ ScrollContainer และ Progress UI ที่ชัดเจนแทนข้อความยาวแบบ prototype

signal closed

var service: IncubatorService
var tamer: Tamer
var is_open: bool = false
var root: Control
var safe: MarginContainer
var panel: PanelContainer
var egg_list: VBoxContainer
var selected_icon: TextureRect
var selected_name: Label
var selected_target: Label
var chip_count: Label
var progress_text: Label
var progress_bar: ProgressBar
var inject_button: DigimonTouchButton
var notice: Label
var visual_fx: ModalVisualFX
var hatch_flash: ColorRect
var _owns_pause: bool = false
var _previous_back_quit: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 96
    _build()
    root.hide()
    get_viewport().size_changed.connect(_layout)

func configure(owner_service: IncubatorService, player: Tamer) -> void:
    service = owner_service
    tamer = player
    if not service.changed.is_connected(_on_changed):
        service.changed.connect(_on_changed)
    if not service.feedback.is_connected(_show_notice):
        service.feedback.connect(_show_notice)
    if not service.hatch_completed.is_connected(_on_hatch_completed):
        service.hatch_completed.connect(_on_hatch_completed)
    if not InventoryManager.changed.is_connected(_deferred_refresh):
        InventoryManager.changed.connect(_deferred_refresh)

func open_screen() -> bool:
    if is_open or service == null or not is_instance_valid(tamer) or get_tree().paused:
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
    if is_instance_valid(tamer):
        tamer.save_party_progress()
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
    shade.color = Color(0.008, 0.012, 0.032, 0.74)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)

    safe = MarginContainer.new()
    safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(safe)
    var center := CenterContainer.new()
    safe.add_child(center)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(ServiceUIStyle.PURPLE, Color("120a22f8")))
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
    header.add_child(title_stack)
    title_stack.add_child(ServiceUIStyle.label("DIGITAL INCUBATOR", 26, ServiceUIStyle.TEXT))
    title_stack.add_child(ServiceUIStyle.label("Digitama ระบุสายพันธุ์แน่นอน • Inject Data ให้ครบ 5/5", 13, ServiceUIStyle.MUTED))
    header.add_child(_button("ปิด ×", Vector2(94, 46), close_screen, ServiceUIStyle.PURPLE))

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 14)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(columns)

    var left := PanelContainer.new()
    left.custom_minimum_size.x = 410
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.CYAN, Color("081929ee")))
    columns.add_child(left)
    var left_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        left_margin.add_theme_constant_override("margin_" + side, 12)
    left.add_child(left_margin)
    var left_stack := VBoxContainer.new()
    left_stack.add_theme_constant_override("separation", 8)
    left_margin.add_child(left_stack)
    left_stack.add_child(ServiceUIStyle.label("DIGITAMA INVENTORY", 18, ServiceUIStyle.CYAN))
    left_stack.add_child(ServiceUIStyle.label("เลือกไข่ที่จะวางลงเครื่อง", 12, ServiceUIStyle.MUTED))
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 360
    scroll.clip_contents = true
    left_stack.add_child(scroll)
    egg_list = VBoxContainer.new()
    egg_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    egg_list.add_theme_constant_override("separation", 8)
    scroll.add_child(egg_list)

    var right := PanelContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.PURPLE, Color("130d24ee")))
    columns.add_child(right)
    var right_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        right_margin.add_theme_constant_override("margin_" + side, 16)
    right.add_child(right_margin)
    var right_stack := VBoxContainer.new()
    right_stack.add_theme_constant_override("separation", 12)
    right_margin.add_child(right_stack)

    right_stack.add_child(ServiceUIStyle.label("INCUBATION CHAMBER", 18, ServiceUIStyle.PURPLE))

    var selected_card := PanelContainer.new()
    selected_card.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("7f62b3"), Color("0b1522")))
    right_stack.add_child(selected_card)
    var selected_row := HBoxContainer.new()
    selected_row.add_theme_constant_override("separation", 12)
    selected_card.add_child(selected_row)

    var icon_frame := PanelContainer.new()
    icon_frame.custom_minimum_size = Vector2(92, 92)
    icon_frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.PURPLE.darkened(0.15), Color("080d18")))
    selected_row.add_child(icon_frame)
    selected_icon = TextureRect.new()
    selected_icon.custom_minimum_size = Vector2(88, 88)
    selected_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    selected_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    selected_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon_frame.add_child(selected_icon)

    var selected_info := VBoxContainer.new()
    selected_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selected_info.add_theme_constant_override("separation", 2)
    selected_row.add_child(selected_info)
    selected_name = ServiceUIStyle.label("ยังไม่ได้เลือก Digitama", 18, ServiceUIStyle.TEXT)
    selected_info.add_child(selected_name)
    selected_target = ServiceUIStyle.label("เลือกจากรายการด้านซ้าย", 14, ServiceUIStyle.MUTED)
    selected_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selected_info.add_child(selected_target)
    chip_count = ServiceUIStyle.label("", 14, ServiceUIStyle.CYAN)
    selected_info.add_child(chip_count)

    var inject_title := HBoxContainer.new()
    right_stack.add_child(inject_title)
    var gauge_title := ServiceUIStyle.label("DATA INJECTION", 15, ServiceUIStyle.MUTED)
    gauge_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inject_title.add_child(gauge_title)
    progress_text = ServiceUIStyle.label("0 / 5", 18, ServiceUIStyle.PURPLE)
    inject_title.add_child(progress_text)

    progress_bar = ServiceUIStyle.progress_bar(ServiceUIStyle.PURPLE, 14)
    progress_bar.max_value = 5
    right_stack.add_child(progress_bar)

    var risk := PanelContainer.new()
    risk.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("705074"), Color("171020")))
    right_stack.add_child(risk)
    var risk_label := ServiceUIStyle.label("ทุกครั้งที่ Inject จะใช้ Data Chip 1 ชิ้น
ผลลัพธ์: สำเร็จ / ล้มเหลว / Digitama แตก", 13, Color("d6bddf"))
    risk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    risk.add_child(risk_label)

    inject_button = _button("INJECT DATA", Vector2(0, 62), _inject, ServiceUIStyle.PURPLE)
    inject_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inject_button.add_theme_font_size_override("font_size", 19)
    right_stack.add_child(inject_button)

    notice = ServiceUIStyle.label("เลือก Digitama เพื่อเริ่มต้น", 14, ServiceUIStyle.MUTED)
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.custom_minimum_size.y = 34
    stack.add_child(notice)

    visual_fx = ModalVisualFX.attach(root, panel)

    # Flash สีขาวอยู่ชั้นบนสุดและไม่รับ input ใช้เฉพาะจังหวะฟักสำเร็จ
    hatch_flash = ColorRect.new()
    hatch_flash.name = "HatchFlash"
    hatch_flash.color = Color.WHITE
    hatch_flash.modulate.a = 0.0
    hatch_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hatch_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(hatch_flash)

func _layout() -> void:
    ResponsiveUI.apply_safe_margins(safe, get_viewport(), 12.0)
    panel.custom_minimum_size = Vector2(1020, 620)
    ResponsiveUI.fit_centered(panel, get_viewport(), 14.0)

func _refresh() -> void:
    if not is_open or service == null or not is_instance_valid(tamer):
        return
    _clear_egg_list()

    var selected_id: String = service.selected_egg_id()
    var selected: ItemData = InventoryManager.catalog.find_item(selected_id)
    var egg_rows: int = 0
    for entry: Dictionary in InventoryManager.items():
        var item: ItemData = entry.item
        if item.item_type != ItemData.ItemType.EGG:
            continue
        egg_list.add_child(_egg_card(item, int(entry.quantity), item.item_id == selected_id))
        egg_rows += 1

    if egg_rows == 0:
        egg_list.add_child(_empty_state())

    var chips: int = InventoryManager.count(selected.required_chip_id) if selected != null else InventoryManager.count("data_chip")
    chip_count.text = "Data Chip ในกระเป๋า: %d" % chips

    if selected == null:
        selected_icon.texture = preload("res://assets/items/digitama.svg")
        selected_icon.modulate = Color(0.45, 0.5, 0.6)
        selected_name.text = "ยังไม่ได้เลือก Digitama"
        selected_target.text = "เลือกไข่จากรายการด้านซ้ายเพื่อดูสายพันธุ์และเริ่ม Inject"
        progress_bar.value = 0
        progress_text.text = "0 / 5"
        inject_button.disabled = true
        return

    selected_icon.modulate = Color.WHITE
    selected_icon.texture = selected.item_texture
    selected_name.text = selected.item_name
    var target: StarterPartnerData = tamer.party_roster.family(selected.egg_partner_id)
    var target_name: String = target.display_name if target != null else String(selected.egg_partner_id)
    selected_target.text = "ผลฟัก: %s 100%%
ใช้ %s • เป้าหมาย %d/5" % [target_name, selected.required_chip_id, selected.inject_goal]
    var level: int = service.inject_level()
    progress_bar.max_value = selected.inject_goal
    progress_bar.value = level
    progress_text.text = "%d / %d" % [level, selected.inject_goal]
    inject_button.disabled = chips <= 0 or InventoryManager.count(selected.item_id) <= 0

func _egg_card(item: ItemData, quantity: int, selected: bool) -> PanelContainer:
    var accent: Color = ServiceUIStyle.GOLD if selected else ServiceUIStyle.CYAN
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("091d2ce8")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    card.add_child(row)

    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(54, 54)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture = item.item_texture
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    info.add_child(ServiceUIStyle.label(item.item_name, 16, ServiceUIStyle.TEXT))
    var target: StarterPartnerData = tamer.party_roster.family(item.egg_partner_id)
    var target_name: String = target.display_name if target != null else String(item.egg_partner_id)
    info.add_child(ServiceUIStyle.label("x%d  •  → %s 100%%" % [quantity, target_name], 13, ServiceUIStyle.MUTED))

    var button := _button("เลือกแล้ว" if selected else "เลือก", Vector2(96, 42), service.select_egg.bind(item.item_id), accent)
    button.disabled = selected
    row.add_child(button)
    return card

func _empty_state() -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("40576a"), Color("07131d")))
    var stack := VBoxContainer.new()
    stack.custom_minimum_size.y = 104
    frame.add_child(stack)
    var a := ServiceUIStyle.label("ไม่มี Digitama ในกระเป๋า", 17, ServiceUIStyle.TEXT)
    a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(a)
    var b := ServiceUIStyle.label("หา Digitama ก่อน แล้วกลับมาที่เครื่องฟัก", 13, ServiceUIStyle.MUTED)
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

func _inject() -> void:
    if service.inject_data() and is_instance_valid(tamer):
        tamer.save_party_progress()
    _deferred_refresh()

func _on_changed() -> void:
    if is_instance_valid(tamer):
        tamer.save_party_progress()
    _deferred_refresh()

func _on_hatch_completed(_partner_id: StringName) -> void:
    # Signal ถูกยิงหลังเพิ่ม Digimon เข้า Storage สำเร็จ จึงไม่มีเสียง success หลอกเมื่อ transaction ล้มเหลว
    AudioManager.play_sfx(&"hatch_success", -3.0)
    if not is_open or not is_instance_valid(hatch_flash):
        return
    hatch_flash.modulate.a = 0.0
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(hatch_flash, "modulate:a", 0.92, 0.10)
    tween.tween_property(hatch_flash, "modulate:a", 0.0, 0.34)


func _show_notice(text: String) -> void:
    if not is_open:
        return
    notice.text = text
    var color: Color = ServiceUIStyle.RED if text.contains("แตก") else (ServiceUIStyle.GREEN if text.contains("สำเร็จ") else ServiceUIStyle.GOLD)
    notice.add_theme_color_override("font_color", color)

func _deferred_refresh(_a: Variant = null, _b: Variant = null) -> void:
    _refresh.call_deferred()

func _clear_egg_list() -> void:
    for child: Node in egg_list.get_children():
        egg_list.remove_child(child)
        child.queue_free()

func _release_buttons() -> void:
    for node: Node in root.find_children("*", "", true, false):
        if node is DigimonTouchButton:
            (node as DigimonTouchButton).release_input()
