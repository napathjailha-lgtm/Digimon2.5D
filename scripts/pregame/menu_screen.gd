class_name AdventureMenuScreen
extends Control
## Base ของสี่หน้าจอเมนู: Theme, touch, ข้อความ feedback และ Android Back ร่วมกัน
var _previous_back_quit: bool = true
@onready var message: Label = get_node_or_null("Margin/Column/Message") as Label

func _ready() -> void:
    GameManager.scene_entered()
    GameManager.set_menu_input(true)
    if not get_script().resource_path.ends_with("loading_screen.gd"):
        GameManager.ensure_catalog()
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    GameManager.feedback.connect(show_message)

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

func make_card(parent: Container, name_text: String, description: String, image: Texture2D, callback: Callable, extent: Vector2 = Vector2(130, 180)) -> Button:
    # Card เป็น Button มาตรฐาน ลูกเป็น mouse_filter IGNORE ให้ root รับ touch/click
    var card: Button = preload("res://scenes/pregame/selection_card.tscn").instantiate()
    card.custom_minimum_size = extent
    parent.add_child(card)
    (card.get_node("Margin/Column/Portrait") as TextureRect).texture = image
    (card.get_node("Margin/Column/Name") as Label).text = name_text
    (card.get_node("Margin/Column/Detail") as Label).text = description
    card.pressed.connect(callback)
    return card
