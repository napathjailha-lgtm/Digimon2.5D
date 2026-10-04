extends AdventureMenuScreen
@onready var slots_box: VBoxContainer = $Margin/Column/Body/Slots/Inner/Stack/SlotsList
@onready var models_grid: GridContainer = $Margin/Column/Body/Create/Inner/Stack/Models
@onready var portrait: TextureRect = $Margin/Column/Body/Preview/Inner/Stack/Portrait
@onready var preview_name: Label = $Margin/Column/Body/Preview/Inner/Stack/Name
@onready var preview_details: Label = $Margin/Column/Body/Preview/Inner/Stack/Details
@onready var name_input: LineEdit = $Margin/Column/Body/Create/Inner/Stack/TamerName
@onready var action_button: Button = $Margin/Column/Body/Create/Inner/Stack/Action
@onready var import_button: Button = $Margin/Column/Body/Slots/Inner/Stack/ImportLegacy
var model_selected: StringName = &"taichi"
var slot_buttons: Array[Button] = []
var model_buttons: Array[Button] = []

func _ready() -> void:
    super._ready()
    if GameManager.account_key.is_empty():
        GameManager.go_to(GameManager.LOGIN_SCENE)
        return
    for i: int in range(GameManager.SLOT_COUNT):
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 72)
        button.toggle_mode = true
        button.clip_text = true
        slots_box.add_child(button)
        button.pressed.connect(select_slot.bind(i))
        slot_buttons.append(button)
    for data: TamerModelData in GameManager.catalog.tamers:
        var card: Button = make_card(models_grid, data.display_name, data.gender, data.portrait, select_model.bind(data.id), Vector2(89, 148))
        model_buttons.append(card)
    name_input.text_submitted.connect(func(_value: String) -> void: _continue())
    action_button.pressed.connect(_continue)
    import_button.pressed.connect(_import_legacy)
    $Margin/Column/Header/Back.pressed.connect(back)
    GameManager.roster_changed.connect(refresh)
    select_slot(GameManager.selected_slot)

func select_slot(index: int) -> void:
    # บัญชีมีตัวละครได้ 5 ช่อง แยกจาก 5 archetypes ที่เลือกตอนสร้าง
    if not GameManager.select_character(index):
        return
    var record: Dictionary = GameManager.characters[index]
    if not record.is_empty():
        model_selected = StringName(record.model)
        name_input.text = str(record.name)
    else:
        var draft: Dictionary = GameManager.creation_preview
        if int(draft.get("slot", -1)) == index:
            name_input.text = str(draft.get("name", ""))
            model_selected = StringName(str(draft.get("model", "taichi")))
        else:
            name_input.text = ""
    refresh()

func select_model(model_id: StringName) -> void:
    # ไม่เปลี่ยนโมเดลตัวละครที่สร้างแล้วโดยกดพรีวิว
    if not GameManager.characters[GameManager.selected_slot].is_empty():
        return
    model_selected = model_id
    refresh()

func refresh() -> void:
    if slot_buttons.is_empty():
        return
    var existing: bool = not GameManager.characters[GameManager.selected_slot].is_empty()
    for i: int in range(slot_buttons.size()):
        var record: Dictionary = GameManager.characters[i]
        slot_buttons[i].text = "ช่อง %d  •  ว่าง\nสร้าง Tamer ใหม่" % (i + 1) if record.is_empty() else "ช่อง %d  •  %s\nLv.%d  /  %s" % [i + 1, record.name, record.get("level", 1), str(record.starter).capitalize()]
        slot_buttons[i].set_pressed_no_signal(i == GameManager.selected_slot)
    var data: TamerModelData = GameManager.catalog.tamer_by_id(model_selected)
    portrait.texture = data.portrait
    preview_name.text = (name_input.text + " / ") if existing else ""
    preview_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    preview_name.text += data.display_name + " · " + data.gender
    preview_details.text = "%s\nHP %d  •  DS %.0f  •  SPD %.0f\n\n%s" % [data.play_style, data.base_hp, data.base_ds, data.move_speed, data.description]
    if existing:
        var partner: StarterPartnerData = GameManager.selected_partner_data()
        if GameManager.partner_selected == &"legacy":
            preview_details.text = "Tamer เดิมจาก v15\nฐาน HP 200 • DS 100 • SPD 190\n\nเลเวล เควสต์ อุปกรณ์และชุดภาพเดิม"
        preview_details.text += "\n\nคู่หู: " + (partner.display_name if partner != null else "คู่หูเดิมจาก v15")
    for i: int in range(model_buttons.size()):
        model_buttons[i].disabled = existing
        model_buttons[i].set_pressed_no_signal(GameManager.catalog.tamers[i].id == model_selected)
    name_input.editable = not existing
    action_button.text = "เข้าสู่โลกดิจิตอล" if existing else "สร้างตัวละคร → เลือกคู่หู"
    import_button.visible = not existing and FileAccess.file_exists(GameManager.legacy_save_path)
    $Margin/Column/Header/Subtitle.text = "%s  /  %s  •  5 ช่องตัวละคร" % [GameManager.username, GameManager.server_selected]

func _continue() -> void:
    if not GameManager.characters[GameManager.selected_slot].is_empty():
        if GameManager.enter_world():
            action_button.disabled = true
        return
    if GameManager.begin_creation(model_selected, name_input.text):
        name_input.release_focus()
        GameManager.go_to(GameManager.STARTER_SCENE)

func _import_legacy() -> void:
    if GameManager.import_legacy_character():
        select_slot(GameManager.selected_slot)
        show_message("นำเข้าเซฟ v15 แล้ว ไฟล์ต้นฉบับยังอยู่ครบ")

func back() -> void:
    GameManager.cancel_creation()
    GameManager.logout()
    GameManager.go_to(GameManager.LOGIN_SCENE)
