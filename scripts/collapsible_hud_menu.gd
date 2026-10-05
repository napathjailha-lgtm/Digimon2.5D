class_name CollapsibleHudMenu
extends Control
## เมนูยุบเหลือปุ่มเดียว กางเป็น Grid 2 คอลัมน์ โดยไม่เปลี่ยน layout ของ Container ระหว่าง Tween
signal action_requested(action: StringName)
signal expanded_changed(expanded: bool)
@export_range(0.05, 0.5) var duration: float = 0.18
var expanded: bool = false
var animations_enabled: bool = true
var buttons: Dictionary = {}
var _tween: Tween
var _revision: int = 0
@onready var toggle_button: TouchCommand = $Toggle
@onready var drawer: PanelContainer = $Drawer
@onready var grid: GridContainer = $Drawer/Margin/Grid

func _ready() -> void:
    # Touch targets 140×56; Container จัดช่อง ส่วน Drawer ว่างจาก Container จึง slide ได้
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    drawer.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("34779f"), Color("07182ef5")))
    toggle_button.pressed.connect(toggle)
    var actions: Array[StringName] = [&"inventory", &"digimon", &"quest", &"settings", &"equipment", &"map", &"chat", &"character"]
    var names: Array[String] = ["กระเป๋า", "คู่หู", "เควสต์", "ตั้งค่า", "อุปกรณ์", "แผนที่", "แชต", "ตัวละคร"]
    for index: int in range(actions.size()):
        var button := EquipmentButton.new()
        button.custom_minimum_size = Vector2(140, 56)
        button.caption = names[index]
        button.pressed.connect(_request_action.bind(actions[index]))
        grid.add_child(button)
        buttons[actions[index]] = button
    set_expanded(false, false)

func toggle() -> void:
    # กดเร็วกลาง Tween ได้: สั่งจากเป้าหมาย expanded ไม่รอ Tween เก่าจบ
    set_expanded(not expanded)

func set_expanded(value: bool, animated: bool = true) -> void:
    # หนึ่ง property มี Tween เดียว kill เก่าก่อนและใช้ revision กัน callback รุ่นเก่า
    _revision += 1
    var revision: int = _revision
    if _tween != null and _tween.is_valid():
        _tween.kill()
    expanded = value
    expanded_changed.emit(expanded)
    toggle_button.set_caption("ปิดเมนู" if expanded else "เมนู +")
    for button: EquipmentButton in buttons.values():
        button.release_input()
        button.locked = true
    if not animated or not animations_enabled:
        drawer.position = Vector2(-252, 76)
        drawer.modulate.a = 1.0 if value else 0.0
        drawer.visible = value
        _finish(revision)
        return
    if value and not drawer.visible:
        drawer.position = Vector2(-228, 58)
        drawer.modulate.a = 0.0
    drawer.show()
    _tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_property(drawer, "position", Vector2(-252, 76) if value else Vector2(-228, 58), duration)
    _tween.tween_property(drawer, "modulate:a", 1.0 if value else 0.0, duration)
    _tween.chain().tween_callback(_finish.bind(revision))

func _finish(revision: int) -> void:
    # ซ่อน Drawer จริงหลัง fade จบ เพื่อไม่รับ Touch ในช่องว่างขณะยุบ
    if revision != _revision:
        return
    drawer.visible = expanded
    for button: EquipmentButton in buttons.values():
        button.locked = not expanded or bool(button.get_meta("unavailable", false))

func _request_action(action: StringName) -> void:
    # ปิดแบบทันทีเมื่อจะเปิด modal ไม่ให้ Tween/นิ้วเดิมค้างอยู่ใต้ฉากหลังมืด
    if not expanded:
        return
    set_expanded(false, false)
    action_requested.emit(action)

func release_input() -> void:
    toggle_button.release_input()
    for button: EquipmentButton in buttons.values():
        button.release_input()

func _unhandled_input(event: InputEvent) -> void:
    # ดูด Touch เฉพาะ Drawer ที่เห็นจริง ปิดอยู่แล้วฉากด้านหลังยังแตะเลือกเป้าหมายได้
    if not drawer.visible or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
        return
    var local: Vector2 = drawer.get_global_transform_with_canvas().affine_inverse() * event.position
    if Rect2(Vector2.ZERO, drawer.size).has_point(local):
        get_viewport().set_input_as_handled()
