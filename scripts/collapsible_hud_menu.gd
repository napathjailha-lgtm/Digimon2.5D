class_name CollapsibleHudMenu
extends Control
## เมนู MMORPG มุมขวาบน: แถบเมนูหลัก + More popup แบบ Grid
## คง API เดิม (buttons / expanded / action_requested) เพื่อให้ MobileHUD เดิมใช้ต่อได้

signal action_requested(action: StringName)
signal expanded_changed(expanded: bool)

@export_range(0.05, 0.5) var duration: float = 0.18

var expanded: bool = false
var animations_enabled: bool = true
var buttons: Dictionary = {}
var _badges: Dictionary = {}
var _tween: Tween
var _revision: int = 0

var top_bar: HBoxContainer
var more_button: EquipmentButton
var drawer: PanelContainer
var grid: GridContainer

const TOP_ACTIONS: Array[StringName] = [
    &"digimon", &"skills", &"equipment", &"map", &"inventory"
]
const TOP_NAMES: Array[String] = [
    "Status", "Skills", "Equipment", "Map", "Bag"
]

const MORE_ACTIONS: Array[StringName] = [
    &"quest", &"settings", &"mail", &"rewards", &"community",
    &"wiki", &"help", &"updates", &"explorer", &"ranking",
    &"event", &"world_boss", &"pvp", &"cards", &"party",
    &"guild", &"friends", &"chat", &"character"
]
const MORE_NAMES: Array[String] = [
    "Quests", "Settings", "Mail", "Rewards", "Community",
    "Wiki", "Help", "Updates", "Explorer", "Ranking",
    "Events", "World Boss", "PVP", "Cards", "Party",
    "Guild", "Friends", "Chat", "Character"
]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_top_bar()
    _build_drawer()
    set_expanded(false, false)

func _build_top_bar() -> void:
    top_bar = HBoxContainer.new()
    top_bar.name = "TopBar"
    top_bar.anchor_left = 1.0
    top_bar.anchor_right = 1.0
    top_bar.offset_left = -430.0
    top_bar.offset_right = 0.0
    top_bar.offset_top = 0.0
    top_bar.offset_bottom = 74.0
    top_bar.add_theme_constant_override("separation", 4)
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top_bar)

    for index: int in range(TOP_ACTIONS.size()):
        var button := _make_tile(TOP_ACTIONS[index], TOP_NAMES[index], Vector2(68, 70))
        top_bar.add_child(button)

    more_button = _make_tile(&"more", "More", Vector2(68, 70))
    more_button.pressed.connect(toggle)
    top_bar.add_child(more_button)
    buttons[&"more"] = more_button

func _build_drawer() -> void:
    drawer = PanelContainer.new()
    drawer.name = "Drawer"
    drawer.anchor_left = 1.0
    drawer.anchor_right = 1.0
    drawer.offset_left = -462.0
    drawer.offset_right = -4.0
    drawer.offset_top = 78.0
    drawer.offset_bottom = 438.0
    drawer.mouse_filter = Control.MOUSE_FILTER_STOP
    drawer.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("516b82"), Color("101c2af2")))
    add_child(drawer)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    drawer.add_child(margin)

    grid = GridContainer.new()
    grid.name = "Grid"
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(grid)

    for index: int in range(MORE_ACTIONS.size()):
        var button := _make_tile(MORE_ACTIONS[index], MORE_NAMES[index], Vector2(82, 76))
        grid.add_child(button)

func _make_tile(action: StringName, label_text: String, minimum: Vector2) -> EquipmentButton:
    var button := EquipmentButton.new()
    button.name = String(action).to_pascal_case()
    button.custom_minimum_size = minimum
    button.caption = label_text
    button.accent = Color("48677f")
    button.pressed.connect(_request_action.bind(action))
    button.set_meta("action", action)
    buttons[action] = button

    # badge มุมขวาบน; เริ่มซ่อนจนระบบจริงส่งจำนวนมา
    var badge := Label.new()
    badge.name = "Badge"
    badge.anchor_left = 1.0
    badge.anchor_right = 1.0
    badge.offset_left = -25.0
    badge.offset_right = -3.0
    badge.offset_top = 2.0
    badge.offset_bottom = 23.0
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    badge.add_theme_font_size_override("font_size", 11)
    badge.add_theme_color_override("font_color", Color.WHITE)
    badge.add_theme_color_override("font_outline_color", Color("7b1e27"))
    badge.add_theme_constant_override("outline_size", 5)
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.hide()
    button.add_child(badge)
    _badges[action] = badge
    return button

func set_badge(action: StringName, value: int) -> void:
    if not _badges.has(action):
        return
    var badge: Label = _badges[action]
    badge.visible = value > 0
    badge.text = "99+" if value > 99 else str(value)

func toggle() -> void:
    set_expanded(not expanded)

func set_expanded(value: bool, animated: bool = true) -> void:
    _revision += 1
    var revision := _revision
    if _tween != null and _tween.is_valid():
        _tween.kill()

    expanded = value
    expanded_changed.emit(expanded)
    if is_instance_valid(more_button):
        more_button.selected = expanded
        more_button.set_caption("Close" if expanded else "More")

    for action: StringName in MORE_ACTIONS:
        if buttons.has(action):
            var button: EquipmentButton = buttons[action]
            button.release_input()
            button.locked = true

    if not animated or not animations_enabled:
        drawer.position.x = 0.0
        drawer.modulate.a = 1.0 if expanded else 0.0
        drawer.visible = expanded
        _finish(revision)
        return

    if expanded:
        drawer.show()
        drawer.modulate.a = 0.0
        drawer.position.x = 18.0

    _tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_property(drawer, "position:x", 0.0 if expanded else 18.0, duration)
    _tween.tween_property(drawer, "modulate:a", 1.0 if expanded else 0.0, duration)
    _tween.chain().tween_callback(_finish.bind(revision))

func _finish(revision: int) -> void:
    if revision != _revision:
        return
    drawer.visible = expanded
    for action: StringName in MORE_ACTIONS:
        if buttons.has(action):
            var button: EquipmentButton = buttons[action]
            button.locked = not expanded or bool(button.get_meta("unavailable", false))

func _request_action(action: StringName) -> void:
    if action == &"more":
        return
    # ปุ่มบนแถบหลักกดได้เสมอ ส่วนปุ่มใน drawer ต้องเปิด drawer ก่อน
    if action in MORE_ACTIONS and not expanded:
        return
    if action in MORE_ACTIONS:
        set_expanded(false, false)
    action_requested.emit(action)

func release_input() -> void:
    if is_instance_valid(more_button):
        more_button.release_input()
    for button: Variant in buttons.values():
        if button is EquipmentButton:
            (button as EquipmentButton).release_input()

func _unhandled_input(event: InputEvent) -> void:
    if not expanded:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        set_expanded(false)
        get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch and event.pressed:
        var local: Vector2 = drawer.get_global_transform_with_canvas().affine_inverse() * event.position
        var more_local: Vector2 = more_button.get_global_transform_with_canvas().affine_inverse() * event.position
        if not Rect2(Vector2.ZERO, drawer.size).has_point(local) and not Rect2(Vector2.ZERO, more_button.size).has_point(more_local):
            set_expanded(false)
