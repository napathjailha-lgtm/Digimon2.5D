extends AdventureMenuScreen
@onready var cards_grid: GridContainer = $Margin/Column/Body/Selection/Inner/Stack/Cards
@onready var portrait: TextureRect = $Margin/Column/Body/Preview/Inner/Stack/Portrait
@onready var title_label: Label = $Margin/Column/Body/Preview/Inner/Stack/Name
@onready var stats_label: Label = $Margin/Column/Body/Preview/Inner/Stack/Details
@onready var path_label: Label = $Margin/Column/Body/Selection/Inner/Stack/EvolutionPath
@onready var description_label: Label = $Margin/Column/Body/Selection/Inner/Stack/Description
@onready var confirm_button: Button = $Margin/Column/Body/Selection/Inner/Stack/Confirm
var partner_selected: StringName = &"agumon"
var card_buttons: Array[Button] = []

func _ready() -> void:
    super._ready()
    # ตัวละครเก่าเข้า World จากหน้า Character โดยตรง ไม่ผ่านหน้านี้
    if GameManager.account_key.is_empty() or GameManager.pending_character.is_empty():
        GameManager.go_to(GameManager.LOGIN_SCENE if GameManager.account_key.is_empty() else GameManager.CHARACTER_SCENE)
        return
    for data: StarterPartnerData in GameManager.catalog.starters:
        var card: Button = make_card(cards_grid, data.display_name, data.element_name, data.portrait, select_partner.bind(data.id), Vector2(126, 198))
        card_buttons.append(card)
    confirm_button.pressed.connect(confirm)
    $Margin/Column/Header/Back.pressed.connect(back)
    $Margin/Column/Header/Subtitle.text = "คู่หูตัวแรกของ " + GameManager.tamer_name
    select_partner(partner_selected)

func select_partner(partner_id: StringName) -> void:
    # อัปเดตภาพ/ชื่อ/สายพัฒนา/สเตตัสจาก Resource เดียวกับที่ Partner ใช้ในสนาม
    var data: StarterPartnerData = GameManager.catalog.starter_by_id(partner_id)
    if data == null or data.forms.is_empty():
        return
    partner_selected = partner_id
    portrait.texture = data.portrait
    title_label.text = data.display_name + " · Rookie"
    var rookie: MonsterData = data.forms[0]
    stats_label.text = "%s / %s\n\nHP %d   ATK %d   SPD %.0f\n\nสกิล: %s" % [data.attribute_name, data.element_name, rookie.max_hp, rookie.attack, rookie.move_speed, rookie.skills[0].display_name]
    path_label.text = data.evolution_path()
    description_label.text = data.description + "\n\nChampion เปลี่ยนได้เมื่อ DS เพียงพอ\nUltimate ปลดล็อกตามเควสต์เนื้อเรื่องเดิม"
    for i: int in range(card_buttons.size()):
        card_buttons[i].set_pressed_no_signal(GameManager.catalog.starters[i].id == partner_id)

func confirm() -> void:
    AudioManager.unlock_audio()
    AudioManager.play_sfx(&"ui_click")
    # สร้างจริงเฉพาะกดยืนยัน ถ้ากด Back จะไม่เสีย slot
    if not GameManager.confirm_starter(partner_selected):
        return
    confirm_button.disabled = true
    if not GameManager.enter_world():
        # สร้างไปแล้ว ให้กลับหน้า Character เพื่อ retry โดยไม่สร้างซ้ำ
        GameManager.go_to(GameManager.CHARACTER_SCENE)

func back() -> void:
    GameManager.cancel_creation()
    GameManager.go_to(GameManager.CHARACTER_SCENE)
