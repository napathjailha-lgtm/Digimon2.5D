class_name DigimonArchiveUI
extends CanvasLayer
## UI คลัง Digimon: Party สูงสุด 3 / Storage ไม่จำกัด ใช้ปุ่มแทน Drag&Drop เพื่อให้ Touch และ Web ทำงานเหมือนกัน

signal closed
var roster: PartnerRoster
var root: Control
var panel: Panel
var party_box: VBoxContainer
var storage_box: VBoxContainer
var info: Label
var storage_page: int = 0
const PAGE_SIZE: int = 7

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    _build()
    root.hide()

func configure(owner_roster: PartnerRoster) -> void:
    roster = owner_roster
    if not roster.changed.is_connected(_deferred_refresh):
        roster.changed.connect(_deferred_refresh)

func open_screen() -> bool:
    if roster == null or root.visible:
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
    panel.position = Vector2(150, 70)
    panel.size = Vector2(980, 580)
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("69c8ff"), Color("081727")))
    root.add_child(panel)
    var title := _label("DIGIMON ARCHIVE", Vector2(24, 16), Vector2(700, 36), 24)
    panel.add_child(title)
    var close := _button("ปิด", Vector2(850, 14), Vector2(100, 44), close_screen)
    panel.add_child(close)
    var left := _label("CURRENT PARTY  •  สูงสุด 3", Vector2(35, 75), Vector2(410, 30), 18)
    panel.add_child(left)
    var right := _label("STORAGE BANK  •  ไม่จำกัด", Vector2(520, 75), Vector2(410, 30), 18)
    panel.add_child(right)
    party_box = VBoxContainer.new()
    party_box.position = Vector2(35, 115)
    party_box.size = Vector2(410, 360)
    party_box.add_theme_constant_override("separation", 8)
    panel.add_child(party_box)
    storage_box = VBoxContainer.new()
    storage_box.position = Vector2(520, 115)
    storage_box.size = Vector2(410, 360)
    storage_box.add_theme_constant_override("separation", 8)
    panel.add_child(storage_box)
    info = _label("", Vector2(35, 500), Vector2(895, 48), 15)
    panel.add_child(info)
    panel.add_child(_button("◀", Vector2(520, 470), Vector2(70, 38), _prev_page))
    panel.add_child(_button("▶", Vector2(860, 470), Vector2(70, 38), _next_page))

func _refresh() -> void:
    if roster == null or not root.visible:
        return
    _clear_box(party_box)
    _clear_box(storage_box)
    for index: int in range(roster.members.size()):
        var entry: Dictionary = roster.members[index]
        var data: StarterPartnerData = roster.family(StringName(str(entry.get("id", ""))))
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(400, 48)
        var name := Label.new()
        name.text = "%d. %s%s" % [index + 1, data.display_name if data != null else str(entry.id), "  [ACTIVE]" if index == roster.active_index else ""]
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name)
        var move := _button("ฝาก", Vector2.ZERO, Vector2(84, 42), func(): _move_party(index))
        row.add_child(move)
        party_box.add_child(row)

    var max_page: int = maxi(0, ceili(float(roster.storage.size()) / PAGE_SIZE) - 1)
    storage_page = clampi(storage_page, 0, max_page)
    var start: int = storage_page * PAGE_SIZE
    for index: int in range(start, mini(start + PAGE_SIZE, roster.storage.size())):
        var entry: Dictionary = roster.storage[index]
        var data: StarterPartnerData = roster.family(StringName(str(entry.get("id", ""))))
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(400, 42)
        var name := Label.new()
        name.text = "%d. %s" % [index + 1, data.display_name if data != null else str(entry.id)]
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name)
        var move := _button("เข้าทีม", Vector2.ZERO, Vector2(92, 38), func(): _move_storage(index))
        move.locked = roster.members.size() >= PartnerRoster.CAPACITY
        row.add_child(move)
        storage_box.add_child(row)
    info.text = "Party %d/3   •   Storage %d   •   หน้า %d/%d" % [roster.members.size(), roster.storage.size(), storage_page + 1, max_page + 1]

func _move_party(index: int) -> void:
    roster.move_party_to_storage(index)
    _deferred_refresh()

func _move_storage(index: int) -> void:
    roster.move_storage_to_party(index)
    _deferred_refresh()

func _prev_page() -> void:
    storage_page = maxi(0, storage_page - 1)
    _refresh()

func _next_page() -> void:
    storage_page += 1
    _refresh()

func _deferred_refresh(_a: Variant = null) -> void:
    _refresh.call_deferred()

func _clear_box(box: Container) -> void:
    for child: Node in box.get_children():
        if child is TouchCommand:
            child.release_input()
        child.queue_free()

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
