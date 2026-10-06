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
    # ระบบใหม่ยกเลิกการเลือกคู่หู: สุ่มหนึ่งสายให้ตัวละครใหม่และล็อกผลไว้กับ draft
    if GameManager.account_key.is_empty() or GameManager.pending_character.is_empty():
        GameManager.go_to(GameManager.LOGIN_SCENE if GameManager.account_key.is_empty() else GameManager.CHARACTER_SCENE)
        return

    cards_grid.hide()
    confirm_button.pressed.connect(confirm)
    $Margin/Column/Header/Back.pressed.connect(back)
    $Margin/Column/Header/Subtitle.text = "ระบบกำลังสุ่มคู่หูให้ " + GameManager.tamer_name

    partner_selected = GameManager.random_starter_id()
    if partner_selected == &"":
        description_label.text = "ไม่พบข้อมูลคู่หูใน Catalog"
        confirm_button.disabled = true
        return

    select_partner(partner_selected)
    confirm_button.text = "รับคู่หูที่สุ่มได้ และเริ่มการผจญภัย"
    path_label.text = "ร่างถัดไปทั้งหมดถูกล็อก • หา Evolution Core จากมอนสเตอร์เพื่อปลดล็อก"
func select_partner(partner_id: StringName) -> void:
    # อัปเดตภาพ/ชื่อ/สายพัฒนา/สเตตัสจาก Resource เดียวกับที่ Partner ใช้ในสนาม
    var data: StarterPartnerData = GameManager.catalog.starter_by_id(partner_id)
    if data == null or data.forms.is_empty():
        return
    partner_selected = partner_id
    portrait.texture = data.portrait
    var stages: Array[String] = ["Rookie", "Champion", "Ultimate", "Mega"]
    title_label.text = data.display_name + " · " + stages[data.forms[0].evolution_stage]
    var rookie: MonsterData = data.forms[0]
    stats_label.text = "%s / %s\n\nHP %d   ATK %d   SPD %.0f\n\nสกิล: %s" % [data.attribute_name, data.element_name, rookie.max_hp, rookie.attack, rookie.move_speed, rookie.skills[0].display_name]
    path_label.text = data.evolution_path()
    var unlocks: PackedStringArray = []
    for index: int in range(1, data.forms.size()):
        unlocks.append("%s Lv.%d" % [data.forms[index].monster_name, EvolutionRules.minimum_level_for_form_index(index, data.forms[index])])
    description_label.text = data.description + "\n\n" + " • ".join(unlocks) + "\nร่างถัดไปต้องมี Evolution Core เพื่อปลดล็อกถาวรก่อนใช้งาน"
    # ไม่มีการเลือกการ์ดแล้ว คู่หูถูกสุ่มจาก GameManager และล็อกผลไว้กับ draft

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
