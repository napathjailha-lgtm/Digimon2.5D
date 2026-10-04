extends AdventureMenuScreen
@onready var username_input: LineEdit = $Margin/Column/Body/LoginPanel/Inner/Stack/Username
@onready var password_input: LineEdit = $Margin/Column/Body/LoginPanel/Inner/Stack/Password
@onready var server_select: OptionButton = $Margin/Column/Body/LoginPanel/Inner/Stack/Server
@onready var login_button: Button = $Margin/Column/Body/LoginPanel/Inner/Stack/Login
var _logging_in: bool = false

func _ready() -> void:
    super._ready()
    for server: Dictionary in GameManager.SERVERS:
        server_select.add_item(server.name)
        server_select.set_item_metadata(server_select.item_count - 1, server.id)
    username_input.text = GameManager.username
    password_input.secret = true
    password_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
    login_button.pressed.connect(login)
    password_input.text_submitted.connect(func(_text: String) -> void: login())

func login() -> void:
    # ต้องปลดล็อก Web Audio จาก user gesture เดิม ห้าม defer/await ก่อนคำสั่งนี้
    AudioManager.unlock_audio()
    AudioManager.play_sfx(&"ui_click")
    # ไม่กด Login ซ้ำขณะกำลังเปลี่ยน Scene และไม่เก็บ password ใน GameManager
    if _logging_in:
        return
    var server_id: String = str(server_select.get_item_metadata(server_select.selected))
    if not GameManager.login_demo(username_input.text, password_input.text, server_id):
        return
    _logging_in = true
    login_button.disabled = true
    password_input.clear()
    username_input.release_focus()
    password_input.release_focus()
    if not GameManager.go_to(GameManager.CHARACTER_SCENE):
        _logging_in = false
        login_button.disabled = false

func back() -> void:
    username_input.release_focus()
    password_input.release_focus()
    show_message("ใช้ Username และ Password ใดก็ได้เพื่อทดสอบ เช่น demo / demo")
