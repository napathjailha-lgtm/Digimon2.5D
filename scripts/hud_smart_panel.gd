class_name HudSmartPanel
extends CanvasLayer
## modal ร่วมของ Status/Quest/Settings: เบลอหลังหน้าต่างและเปิดด้วยจังหวะ pop
signal action_requested(action: StringName)
signal closed
var is_open: bool = false
var kind: StringName = &""
var _owns_pause: bool = false
var _previous_back_quit: bool = true
var hud: CanvasLayer
var buttons: Dictionary = {}
var visual_fx: ModalVisualFX
@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Center/Panel
@onready var title: Label = $Root/Center/Panel/Margin/Stack/Header/Title
@onready var close_button: EquipmentButton = $Root/Center/Panel/Margin/Stack/Header/Close
@onready var body: VBoxContainer = $Root/Center/Panel/Margin/Stack/Body
@onready var details: Label = $Root/Center/Panel/Margin/Stack/Body/Details
@onready var actions: GridContainer = $Root/Center/Panel/Margin/Stack/Body/Actions

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 86
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("34779f"), Color("07182ef5")))
    root.hide()
    visual_fx = ModalVisualFX.attach(root, panel)
    close_button.pressed.connect(close_screen)
    get_viewport().size_changed.connect(_layout)

func _layout() -> void:
    # Settings/Quest มีปุ่ม 300px สองคอลัมน์ จึง scale ทั้ง panel เมื่อ browser แคบ/เตี้ย
    panel.custom_minimum_size = Vector2(840, 480)
    ResponsiveUI.fit_centered(panel, get_viewport(), 14.0)

func open_kind(value: StringName, title_text: String, content: String, options: Array[Dictionary] = []) -> bool:
    # ไม่แย่ง pause ของ Inventory/Equipment/Cutscene
    if is_open or get_tree().paused or hud.partner.evolution_busy:
        return false
    hud.release_for_equipment()
    _layout()
    kind = value
    title.text = title_text
    details.text = content
    _build_actions(options)
    is_open = true
    hud._sync_skill_input()
    _owns_pause = true
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    get_tree().paused = true
    root.show()
    visual_fx.animate_open()
    return true

func _build_actions(options: Array[Dictionary]) -> void:
    # Native GridContainer จัดปุ่ม 2 คอลัมน์ touch ขนาด >=56px ไม่ย่อจนเล็กตามข้อความ
    for child: Node in actions.get_children():
        actions.remove_child(child)
        child.queue_free()
    buttons.clear()
    for option: Dictionary in options:
        var button := EquipmentButton.new()
        button.caption = str(option.label)
        button.custom_minimum_size = Vector2(300, 56)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_request.bind(StringName(option.id)))
        actions.add_child(button)
        buttons[StringName(option.id)] = button

func _request(action: StringName) -> void:
    # Status/Settings อยู่ใน modal ต่อได้; Quest นำทางและออกตัวละครให้ HUD ปิดก่อนทำงาน
    action_requested.emit(action)

func close_screen() -> void:
    if not is_open:
        return
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("34779f"), Color("07182ef5")))
    visual_fx.reset()
    root.hide()
    close_button.release_input()
    for button: EquipmentButton in buttons.values():
        button.release_input()
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
    # consume พื้นที่ว่างของ overlay ป้องกันเลือกศัตรูผ่านช่องระหว่างปุ่ม
    if not is_open:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
    get_viewport().set_input_as_handled()
