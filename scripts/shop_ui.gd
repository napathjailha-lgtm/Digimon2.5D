class_name ShopUI
extends CanvasLayer
## Merchant UI ซื้อ Consumable/Data Chip และขายวัสดุจาก Inventory

signal closed
var service: ShopService
var root: Control
var panel: Panel
var bits_label: Label
var list_box: VBoxContainer
var notice: Label
var sell_mode: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    _build()
    root.hide()

func configure(owner_service: ShopService) -> void:
    service = owner_service
    service.changed.connect(_deferred_refresh)
    service.feedback.connect(_show_notice)
    GameManager.bits_changed.connect(func(_value: int): _deferred_refresh())
    InventoryManager.changed.connect(_deferred_refresh)

func open_screen() -> bool:
    if service == null or root.visible:
        return false
    root.show()
    get_tree().paused = true
    _refresh()
    return true

func close_screen() -> void:
    if not root.visible:
        return
    root.hide()
    get_tree().paused = false
    closed.emit()

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    panel = Panel.new()
    panel.position = Vector2(260, 80)
    panel.size = Vector2(760, 560)
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("f0c86a"), Color("171207")))
    root.add_child(panel)
    panel.add_child(_label("DIGITAL MERCHANT", Vector2(25, 18), Vector2(430, 35), 24))
    bits_label = _label("", Vector2(470, 22), Vector2(170, 30), 18)
    bits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    panel.add_child(bits_label)
    panel.add_child(_button("ปิด", Vector2(650, 14), Vector2(85, 42), close_screen))
    panel.add_child(_button("ซื้อ", Vector2(30, 70), Vector2(120, 45), func(): _set_mode(false)))
    panel.add_child(_button("ขาย", Vector2(160, 70), Vector2(120, 45), func(): _set_mode(true)))
    list_box = VBoxContainer.new()
    list_box.position = Vector2(30, 130)
    list_box.size = Vector2(700, 330)
    list_box.add_theme_constant_override("separation", 7)
    panel.add_child(list_box)
    notice = _label("", Vector2(30, 480), Vector2(700, 52), 15)
    panel.add_child(notice)

func _set_mode(value: bool) -> void:
    sell_mode = value
    _refresh()

func _refresh() -> void:
    if not root.visible:
        return
    bits_label.text = "%d Bits" % GameManager.bits
    for child: Node in list_box.get_children():
        if child is TouchCommand:
            child.release_input()
        child.queue_free()
    if sell_mode:
        for entry: Dictionary in InventoryManager.items():
            var item: ItemData = entry.item
            if item.sell_price <= 0 or item.item_type == ItemData.ItemType.EGG:
                continue
            _add_row("%s x%d   •   +%d Bits" % [item.item_name, int(entry.quantity), item.sell_price], "ขาย 1", func(): service.sell(item.item_id, 1))
    else:
        for item: ItemData in InventoryManager.catalog.items:
            if item.shop_sold and item.buy_price > 0:
                _add_row("%s   •   %d Bits" % [item.item_name, item.buy_price], "ซื้อ 1", func(): service.buy(item.item_id, 1))
    notice.text = "ร้านค้าไม่ขายอุปกรณ์สวมใส่ • อุปกรณ์ได้จาก World Boss เท่านั้น"

func _add_row(text: String, action: String, callback: Callable) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(680, 48)
    var label := Label.new()
    label.text = text
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_button(action, Vector2.ZERO, Vector2(110, 42), callback))
    list_box.add_child(row)

func _show_notice(text: String) -> void:
    if root.visible:
        notice.text = text

func _deferred_refresh(_a: Variant = null) -> void:
    _refresh.call_deferred()

func _label(text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _button(text: String, pos: Vector2, size: Vector2, callback: Callable) -> EquipmentButton:
    var button := EquipmentButton.new()
    button.caption = text
    button.position = pos
    button.size = size
    button.pressed.connect(callback)
    return button

func _unhandled_input(event: InputEvent) -> void:
    if root.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
        get_viewport().set_input_as_handled()
