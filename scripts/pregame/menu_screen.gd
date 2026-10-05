class_name AdventureMenuScreen
extends Control
## Base ของหน้าจอเมนู: Theme, touch, Web-mobile landscape hint และ Android Back ร่วมกัน

var _previous_back_quit: bool = true
var _rotate_overlay: ColorRect
@onready var message: Label = get_node_or_null("Margin/Column/Message") as Label

func _ready() -> void:
    # Web mobile ต้องปิด browser pan/zoom ก่อนรับ Touch ของ Godot
    HybridPlatform.configure_web_touch_surface()
    GameManager.scene_entered()
    GameManager.set_menu_input(true)
    if not get_script().resource_path.ends_with("loading_screen.gd"):
        GameManager.ensure_catalog()
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    GameManager.feedback.connect(show_message)

    _build_mobile_web_overlay()
    if not get_viewport().size_changed.is_connected(_refresh_mobile_web_overlay):
        get_viewport().size_changed.connect(_refresh_mobile_web_overlay)
    _refresh_mobile_web_overlay()

func show_message(text: String) -> void:
    # Label แสดงข้อความธรรมดา ไม่ตีความ markup จากชื่อผู้เล่น
    if is_instance_valid(message):
        message.text = text

func back() -> void:
    # แต่ละ Scene override ปลายทางเอง; หน้าล็อกอินไม่ออกเกมเพราะแตะ Back เผลอ
    pass

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        back()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        back()

func _exit_tree() -> void:
    # คืนค่าก่อนเมนูใหม่ _ready จับค่าเดิม หรือก่อนเข้าสนาม
    if is_inside_tree():
        get_tree().quit_on_go_back = _previous_back_quit

func _build_mobile_web_overlay() -> void:
    # เกมออกแบบสำหรับ Landscape; บนมือถือเว็บ Portrait จะบีบหน้าสร้างตัวละคร 3 คอลัมน์จนใช้งานไม่ได้
    # จึงแสดงคำแนะนำแทนการปล่อย UI ซ้อนกัน และซ่อนอัตโนมัติทันทีเมื่อหมุนจอ
    if not OS.has_feature("web") or not HybridPlatform.use_mobile_layout(get_viewport()) or is_instance_valid(_rotate_overlay):
        return

    _rotate_overlay = ColorRect.new()
    _rotate_overlay.name = "WebMobileRotateHint"
    _rotate_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _rotate_overlay.color = Color(0.015, 0.035, 0.060, 0.97)
    _rotate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _rotate_overlay.z_index = 4090
    add_child(_rotate_overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rotate_overlay.add_child(center)

    var stack := VBoxContainer.new()
    stack.custom_minimum_size = Vector2(300, 180)
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 12)
    center.add_child(stack)

    var icon := Label.new()
    icon.text = "↻"
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", 52)
    icon.add_theme_color_override("font_color", Color("70d8f4"))
    stack.add_child(icon)

    var title := Label.new()
    title.text = "หมุนมือถือเป็นแนวนอน"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color("f3f8ff"))
    stack.add_child(title)

    var detail := Label.new()
    detail.text = "Web Mobile ใช้งาน Touch ได้เต็มรูปแบบใน Landscape"
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.add_theme_font_size_override("font_size", 15)
    detail.add_theme_color_override("font_color", Color("9fb6c9"))
    stack.add_child(detail)

func _refresh_mobile_web_overlay() -> void:
    if is_instance_valid(_rotate_overlay):
        _rotate_overlay.visible = HybridPlatform.is_portrait(get_viewport())

func make_card(parent: Container, name_text: String, description: String, image: Texture2D, callback: Callable, extent: Vector2 = Vector2(130, 180)) -> Button:
    # Button มาตรฐานรับ Touch ผ่าน emulate_mouse_from_touch=true บน Web mobile
    var card: Button = preload("res://scenes/pregame/selection_card.tscn").instantiate()
    card.custom_minimum_size = extent
    parent.add_child(card)
    (card.get_node("Margin/Column/Portrait") as TextureRect).texture = image
    (card.get_node("Margin/Column/Name") as Label).text = name_text
    (card.get_node("Margin/Column/Detail") as Label).text = description
    card.pressed.connect(callback)
    return card
