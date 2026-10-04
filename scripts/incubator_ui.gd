class_name IncubatorUI
extends CanvasLayer
## UI แท่นฟัก: เลือก Digitama -> Inject Data 0/5 -> Hatch เข้า Storage

signal closed
var service: IncubatorService
var tamer: Tamer
var root: Control
var panel: Panel
var status: Label
var items_box: VBoxContainer
var notice: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    _build()
    root.hide()

func configure(owner_service: IncubatorService, player: Tamer) -> void:
    service = owner_service
    tamer = player
    service.changed.connect(_on_changed)
    service.feedback.connect(_show_notice)
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
    if is_instance_valid(tamer):
        tamer.save_party_progress()
    closed.emit()

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    panel = Panel.new()
    panel.position = Vector2(250, 85)
    panel.size = Vector2(780, 550)
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("b98cff"), Color("120b20")))
    root.add_child(panel)
    panel.add_child(_label("DIGITAL INCUBATOR", Vector2(25, 18), Vector2(500, 36), 24))
    panel.add_child(_button("ปิด", Vector2(670, 14), Vector2(85, 42), close_screen))
    status = _label("", Vector2(30, 75), Vector2(720, 80), 18)
    panel.add_child(status)
    items_box = VBoxContainer.new()
    items_box.position = Vector2(30, 165)
    items_box.size = Vector2(720, 220)
    panel.add_child(items_box)
    panel.add_child(_button("INJECT DATA", Vector2(250, 400), Vector2(280, 62), _inject))
    notice = _label("", Vector2(30, 478), Vector2(720, 52), 15)
    panel.add_child(notice)

func _refresh() -> void:
    if not root.visible:
        return
    for child: Node in items_box.get_children():
        if child is TouchCommand:
            child.release_input()
        child.queue_free()
    var selected: String = service.selected_egg_id()
    var egg: ItemData = InventoryManager.catalog.find_item(selected)
    if egg != null:
        status.text = "%s
Inject %d/%d • ต้องใช้ %s x1 ต่อครั้ง" % [egg.item_name, service.inject_level(), egg.inject_goal, egg.required_chip_id]
    else:
        status.text = "เลือก Digitama จากกระเป๋า
สายพันธุ์ปลายทางกำหนดโดยไอเทมไข่ ไม่สุ่ม"
    for entry: Dictionary in InventoryManager.items():
        var item: ItemData = entry.item
        if item.item_type != ItemData.ItemType.EGG:
            continue
        var target: StarterPartnerData = tamer.party_roster.family(item.egg_partner_id)
        var text: String = "%s x%d  →  %s 100%%" % [item.item_name, int(entry.quantity), target.display_name if target != null else String(item.egg_partner_id)]
        var button := _button(text, Vector2.ZERO, Vector2(700, 46), func(): service.select_egg(item.item_id))
        items_box.add_child(button)
    notice.text = "Data Chip: %d • สำเร็จ/ล้มเหลว/ไข่แตกตามโอกาสของ Digitama" % InventoryManager.count("data_chip")

func _inject() -> void:
    service.inject_data()
    if is_instance_valid(tamer):
        tamer.save_party_progress()
    _deferred_refresh()

func _on_changed() -> void:
    if is_instance_valid(tamer):
        tamer.save_party_progress()
    _deferred_refresh()

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
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
