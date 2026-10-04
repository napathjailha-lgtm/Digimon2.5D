class_name ShopUI
extends CanvasLayer
## Digital Merchant แบบ responsive: แยก Buy/Sell ชัดเจน ใช้ card row และ ScrollContainer

signal closed

var service: ShopService
var is_open: bool = false
var root: Control
var safe: MarginContainer
var panel: PanelContainer
var list_box: VBoxContainer
var bits_label: Label
var mode_label: Label
var notice: Label
var buy_tab: DigimonTouchButton
var sell_tab: DigimonTouchButton
var visual_fx: ModalVisualFX
var sell_mode: bool = false
var _owns_pause: bool = false
var _previous_back_quit: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 96
    _build()
    root.hide()
    get_viewport().size_changed.connect(_layout)

func configure(owner_service: ShopService) -> void:
    service = owner_service
    if not service.changed.is_connected(_deferred_refresh):
        service.changed.connect(_deferred_refresh)
    if not service.feedback.is_connected(_show_notice):
        service.feedback.connect(_show_notice)
    if not GameManager.bits_changed.is_connected(_on_bits_changed):
        GameManager.bits_changed.connect(_on_bits_changed)
    if not InventoryManager.changed.is_connected(_deferred_refresh):
        InventoryManager.changed.connect(_deferred_refresh)

func open_screen() -> bool:
    if is_open or service == null or get_tree().paused:
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
    shade.color = Color(0.01, 0.018, 0.025, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)

    safe = MarginContainer.new()
    safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(safe)
    var center := CenterContainer.new()
    safe.add_child(center)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(ServiceUIStyle.GOLD, Color("151006f7")))
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
    title_stack.add_child(ServiceUIStyle.label("DIGITAL MERCHANT", 26, ServiceUIStyle.TEXT))
    title_stack.add_child(ServiceUIStyle.label("ซื้อของใช้และขายวัตถุดิบ • ไม่มีอุปกรณ์ Boss ขายที่นี่", 13, ServiceUIStyle.MUTED))

    var bits_frame := PanelContainer.new()
    bits_frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.GOLD, Color("2b210d")))
    header.add_child(bits_frame)
    bits_label = ServiceUIStyle.label("", 18, ServiceUIStyle.GOLD)
    bits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bits_label.custom_minimum_size = Vector2(150, 44)
    bits_frame.add_child(bits_label)

    header.add_child(_button("ปิด ×", Vector2(94, 46), close_screen, ServiceUIStyle.GOLD))

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 10)
    stack.add_child(tabs)
    buy_tab = _button("ซื้อสินค้า", Vector2(180, 48), func(): _set_mode(false), ServiceUIStyle.CYAN)
    buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.add_child(buy_tab)
    sell_tab = _button("ขายของ", Vector2(180, 48), func(): _set_mode(true), ServiceUIStyle.PURPLE)
    sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.add_child(sell_tab)

    var list_panel := PanelContainer.new()
    list_panel.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.GOLD, Color("0b1720e8")))
    list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(list_panel)
    var list_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        list_margin.add_theme_constant_override("margin_" + side, 12)
    list_panel.add_child(list_margin)
    var list_stack := VBoxContainer.new()
    list_stack.add_theme_constant_override("separation", 8)
    list_margin.add_child(list_stack)

    mode_label = ServiceUIStyle.label("", 18, ServiceUIStyle.GOLD)
    list_stack.add_child(mode_label)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 360
    scroll.clip_contents = true
    list_stack.add_child(scroll)
    list_box = VBoxContainer.new()
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_box.add_theme_constant_override("separation", 8)
    scroll.add_child(list_box)

    notice = ServiceUIStyle.label("", 14, ServiceUIStyle.MUTED)
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.custom_minimum_size.y = 30
    stack.add_child(notice)

    visual_fx = ModalVisualFX.attach(root, panel)

func _layout() -> void:
    ResponsiveUI.apply_safe_margins(safe, get_viewport(), 12.0)
    panel.custom_minimum_size = Vector2(900, 620)
    ResponsiveUI.fit_centered(panel, get_viewport(), 14.0)
    ResponsiveUI.fit_centered.call_deferred(panel, get_viewport(), 14.0)

func _set_mode(value: bool) -> void:
    sell_mode = value
    _refresh()

func _refresh() -> void:
    if not is_open:
        return
    bits_label.text = "◆  %d Bits" % GameManager.bits
    mode_label.text = "SELL / INVENTORY" if sell_mode else "BUY / CONSUMABLES"
    ServiceUIStyle.button(buy_tab, ServiceUIStyle.CYAN, not sell_mode)
    ServiceUIStyle.button(sell_tab, ServiceUIStyle.PURPLE, sell_mode)
    _clear_list()

    var rows: int = 0
    if sell_mode:
        for entry: Dictionary in InventoryManager.items():
            var item: ItemData = entry.item
            if item.sell_price <= 0 or item.item_type == ItemData.ItemType.EGG:
                continue
            list_box.add_child(_item_card(item, int(entry.quantity), true))
            rows += 1
        if rows == 0:
            list_box.add_child(_empty_state("ไม่มีของที่ร้านรับซื้อ", "วัตถุดิบและ Data Chip ที่มีราคาขายจะแสดงตรงนี้"))
        notice.text = "ขายทีละ 1 ชิ้น • Digitama และอุปกรณ์ Boss ไม่รับซื้อ"
    else:
        for item: ItemData in InventoryManager.catalog.items:
            if item.shop_sold and item.buy_price > 0:
                list_box.add_child(_item_card(item, InventoryManager.count(item.item_id), false))
                rows += 1
        if rows == 0:
            list_box.add_child(_empty_state("ร้านยังไม่มีสินค้า", "ตั้งค่า shop_sold และ buy_price ใน ItemData เพื่อเพิ่มสินค้า"))
        notice.text = "อุปกรณ์สวมใส่จะไม่มีขายในร้าน • หาได้จาก World Boss เท่านั้น"

func _item_card(item: ItemData, owned: int, selling: bool) -> PanelContainer:
    var accent: Color = ServiceUIStyle.PURPLE if selling else ServiceUIStyle.GOLD
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("0a1d2ae8")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    card.add_child(row)

    var icon_frame := PanelContainer.new()
    icon_frame.custom_minimum_size = Vector2(58, 58)
    icon_frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent.darkened(0.2), Color("08131d")))
    row.add_child(icon_frame)
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(54, 54)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture = item.item_texture
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon_frame.add_child(icon)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 1)
    row.add_child(info)
    info.add_child(ServiceUIStyle.label(item.item_name, 17, ServiceUIStyle.TEXT))
    var type_text: String = item.type_label()
    info.add_child(ServiceUIStyle.label("%s  •  มี %d ชิ้น" % [type_text, owned], 13, ServiceUIStyle.MUTED))
    var desc := ServiceUIStyle.label(item.description, 12, Color("7894a8"))
    desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    desc.custom_minimum_size.x = 350
    info.add_child(desc)

    var price_stack := VBoxContainer.new()
    price_stack.custom_minimum_size.x = 120
    row.add_child(price_stack)
    var price: int = item.sell_price if selling else item.buy_price
    var price_label := ServiceUIStyle.label(("%+d Bits" if selling else "%d Bits") % price, 16, accent)
    price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    price_stack.add_child(price_label)
    var after := ServiceUIStyle.label("หลังขาย" if selling else "ราคาต่อชิ้น", 11, ServiceUIStyle.MUTED)
    after.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    price_stack.add_child(after)

    var action := _button("ขาย 1" if selling else "ซื้อ 1", Vector2(110, 44), service.sell.bind(item.item_id, 1) if selling else service.buy.bind(item.item_id, 1), accent)
    if selling:
        action.disabled = owned <= 0
    else:
        action.disabled = not GameManager.can_afford_bits(item.buy_price)
    row.add_child(action)
    return card

func _empty_state(title: String, subtitle: String) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("40576a"), Color("07131d")))
    var stack := VBoxContainer.new()
    stack.custom_minimum_size.y = 92
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

func _show_notice(text: String) -> void:
    if is_open:
        notice.text = text
        notice.add_theme_color_override("font_color", ServiceUIStyle.GOLD)

func _on_bits_changed(_value: int) -> void:
    _deferred_refresh()

func _deferred_refresh(_a: Variant = null, _b: Variant = null) -> void:
    _refresh.call_deferred()

func _clear_list() -> void:
    for child: Node in list_box.get_children():
        list_box.remove_child(child)
        child.queue_free()

func _release_buttons() -> void:
    for node: Node in root.find_children("*", "", true, false):
        if node is DigimonTouchButton:
            (node as DigimonTouchButton).release_input()
