extends Node
## Autoload ชื่อ GameManager: ไม่ประกาศ class_name ชื่อเดียวกับ Singleton
## Login/Server เป็นการจำลองในเครื่อง ไม่เก็บ Password และไม่ส่งข้อมูลออกเครือข่าย
signal roster_changed
signal feedback(message: String)
const LOADING_SCENE: String = "res://scenes/pregame/loading_screen.tscn"
const LOGIN_SCENE: String = "res://scenes/pregame/login_screen.tscn"
const CHARACTER_SCENE: String = "res://scenes/pregame/character_selection.tscn"
const STARTER_SCENE: String = "res://scenes/pregame/starter_selection.tscn"
const ZONE_SCENES: Dictionary = {"file_island":"res://scenes/world.tscn", "server_continent":"res://scenes/world.tscn", "odaiba":"res://scenes/world.tscn", "spiral_mountain":"res://scenes/world.tscn"}
const SERVERS: Array[Dictionary] = [{"id":"file_1","name":"File Island · Server 1"}, {"id":"file_2","name":"File Island · Server 2"}]
const CATALOG_PATH: String = "res://data/pregame/catalog.tres"
const SLOT_COUNT: int = 5
var catalog: PregameCatalog
var username: String = ""
var server_selected: String = "file_1"
var account_key: String = ""
var profile_root: String = "user://profiles"
var legacy_save_path: String = "user://story_progress.json"
var characters: Array[Dictionary] = []
var selected_slot: int = 0
var pending_character: Dictionary = {}
var creation_preview: Dictionary = {} # เก็บชื่อ/โมเดล draft กลับจาก Starter โดยยังไม่กิน slot
var tamer_selected: StringName = &""
var partner_selected: StringName = &""
var tamer_name: String = "Tamer"
var current_level: int = 1
var current_form: StringName = &""
const DEFAULT_BITS: int = 500
signal bits_changed(current: int)
var bits: int = DEFAULT_BITS
var incubator_state: Dictionary = {}
var gameplay_active: bool = false
var loading_target: String = LOGIN_SCENE
var _transition_pending: bool = false

func _ready() -> void:
    # Catalog จะถูก Loading Screen โหลดเบื้องหลังหลังแสดง UI แล้ว
    _empty_roster()

func ensure_catalog() -> void:
    # F6 เปิดเมนูโดยตรงได้; เส้นทาง F5 ปกติให้ Loading โหลดเบื้องหลังแล้ว
    if catalog == null:
        catalog = load(CATALOG_PATH) as PregameCatalog

func _empty_roster() -> void:
    characters.clear()
    for i: int in range(SLOT_COUNT):
        characters.append({})

func set_menu_input(enabled: bool) -> void:
    # หน้าเมนูใช้ Button/LineEdit/OptionButton มาตรฐานและเมาส์จาก touch
    # สนามใช้ finger index ของ MobileJoystick/TouchCommand เดิม จึงคืนค่าเดิมก่อนเข้าโลก
    Input.set_emulate_mouse_from_touch(enabled)
    Input.set_emulate_touch_from_mouse(not enabled)

func scene_entered() -> void:
    # เรียกเมื่อ Scene ใหม่พร้อม ปลด latch เพื่อรับคำสั่งครั้งถัดไป
    _transition_pending = false

func _fail(message: String) -> bool:
    feedback.emit(message)
    return false

func login_demo(user: String, password: String, server_id: String) -> bool:
    # จำลองสำเร็จเมื่อข้อมูลผ่าน validation ไม่มีการตรวจบัญชีบนเซิร์ฟเวอร์จริง
    ensure_catalog()
    var clean: String = user.strip_edges()
    if clean.length() < 3 or clean.length() > 24 or _has_control_chars(clean):
        return _fail("Username ต้องยาว 3–24 ตัวอักษร")
    if password.is_empty() or password.length() > 64:
        return _fail("กรอกรหัสผ่าน 1–64 ตัวอักษรสำหรับระบบจำลอง")
    if server_id not in ["file_1", "file_2"]:
        return _fail("กรุณาเลือกเซิร์ฟเวอร์ที่มีในรายการ")
    username = clean
    server_selected = server_id
    # Hash ชื่อบัญชี/Server ป้องกันชื่อไทยหรือ / ทำให้พาธไฟล์ผิด
    account_key = (server_id + "|" + clean.to_lower()).sha256_text()
    selected_slot = 0
    gameplay_active = false
    pending_character.clear()
    creation_preview.clear()
    tamer_selected = &""
    partner_selected = &""
    tamer_name = "Tamer"
    current_level = 1
    current_form = &""
    bits = DEFAULT_BITS
    incubator_state.clear()
    load_roster()
    return true

func _has_control_chars(value: String) -> bool:
    for i: int in range(value.length()):
        if value.unicode_at(i) < 32 or value.unicode_at(i) == 127:
            return true
    return false

func profile_directory() -> String:
    return profile_root.path_join(account_key)

func character_save_path(slot_index: int) -> String:
    return profile_directory().path_join("slot_%d_story.json" % (slot_index + 1))

func load_roster() -> void:
    # มี 5 ช่องเสมอ กรองข้อมูลต้นแบบ/ID ที่ไม่มี ป้องกัน slot index นอกขอบ
    _empty_roster()
    var path: String = profile_directory().path_join("roster.json")
    if FileAccess.file_exists(path):
        var file: FileAccess = FileAccess.open(path, FileAccess.READ)
        if file != null:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary and parsed.get("version", 0) == 1 and parsed.get("characters") is Array:
                var saved: Array = parsed["characters"]
                for i: int in range(mini(SLOT_COUNT, saved.size())):
                    if saved[i] is Dictionary and _valid_record(saved[i]):
                        characters[i] = saved[i].duplicate(true)
    roster_changed.emit()

func _valid_record(data: Dictionary) -> bool:
    if data.is_empty() or catalog.tamer_by_id(StringName(str(data.get("model", "")))) == null:
        return false
    var starter_id := StringName(str(data.get("starter", "")))
    return (starter_id == &"legacy" or catalog.starter_by_id(starter_id) != null) and str(data.get("name", "")).length() >= 2

func save_roster() -> bool:
    # หากเขียนไม่ได้ให้ caller rollback การสร้าง ห้ามแจ้งว่าสำเร็จทั้งที่ไม่มีเซฟ
    if account_key.is_empty():
        return _fail("ยังไม่ได้ Login")
    var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_directory()))
    if error != OK:
        return _fail("สร้างโฟลเดอร์เซฟไม่ได้: " + error_string(error))
    var file: FileAccess = FileAccess.open(profile_directory().path_join("roster.json"), FileAccess.WRITE)
    if file == null:
        return _fail("บันทึกตัวละครไม่ได้: " + error_string(FileAccess.get_open_error()))
    file.store_string(JSON.stringify({"version":1, "characters":characters}))
    file.close()
    return true

func select_character(slot_index: int) -> bool:
    # ช่องว่างเลือกได้เพื่อใช้สร้าง ช่องที่มีตัวละครจะคืนข้อมูลพร้อมเข้าโลก
    if account_key.is_empty() or slot_index < 0 or slot_index >= SLOT_COUNT:
        return false
    selected_slot = slot_index
    var record: Dictionary = characters[slot_index]
    if not record.is_empty():
        tamer_selected = StringName(record.model)
        partner_selected = StringName(record.starter)
        tamer_name = str(record.name)
        current_level = clampi(int(record.get("level", 1)), 1, 99)
    return true

func begin_creation(model_id: StringName, name_text: String) -> bool:
    # สร้าง draft เท่านั้น ยังไม่เขียน slot จนกว่าจะเลือกคู่หูยืนยันสำเร็จ
    if account_key.is_empty() or not characters[selected_slot].is_empty():
        return _fail("เลือกช่องตัวละครว่างก่อนสร้าง")
    var model: TamerModelData = catalog.tamer_by_id(model_id)
    var clean: String = name_text.strip_edges()
    if model == null:
        return _fail("โมเดล Tamer ไม่ถูกต้อง")
    if clean.length() < 2 or clean.length() > 16 or _has_control_chars(clean):
        return _fail("ชื่อ Tamer ต้องยาว 2–16 ตัวอักษร")
    for record: Dictionary in characters:
        if not record.is_empty() and str(record.name).to_lower() == clean.to_lower():
            return _fail("ชื่อนี้ถูกใช้แล้วในบัญชีและเซิร์ฟเวอร์นี้")
    pending_character = {"slot":selected_slot, "model":String(model_id), "name":clean}
    creation_preview = pending_character.duplicate()
    tamer_selected = model_id
    tamer_name = clean
    partner_selected = &""
    return true

func cancel_creation() -> void:
    # Back จากหน้า Starter ไม่กินช่องและไม่ให้ไอเทมหรือ Progress ล่วงหน้า
    pending_character.clear()

func random_starter_id() -> StringName:
    ensure_catalog()
    if catalog == null or catalog.starters.is_empty():
        return &""
    # ผูกผลสุ่มไว้กับ draft เดิม ป้องกัน Back/เข้าใหม่เพื่อ reroll คู่หู
    var cached: StringName = StringName(str(pending_character.get("random_starter", "")))
    if cached != &"" and catalog.starter_by_id(cached) != null:
        return cached
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var selected: StarterPartnerData = catalog.starters[rng.randi_range(0, catalog.starters.size() - 1)]
    pending_character["random_starter"] = String(selected.id)
    return selected.id

func confirm_starter(starter_id: StringName) -> bool:
    # ตรวจ draft อีกครั้งและ commit ครั้งเดียว กันกดยืนยันรัวสร้างหลายตัว
    if account_key.is_empty() or pending_character.is_empty() or catalog.starter_by_id(starter_id) == null:
        return _fail("ไม่มีตัวละครใหม่ที่รอเลือกคู่หู")
    var slot_index: int = int(pending_character.get("slot", -1))
    if slot_index < 0 or slot_index >= SLOT_COUNT or not characters[slot_index].is_empty():
        return _fail("ช่องนี้มีตัวละครแล้ว")
    var record: Dictionary = {"model":pending_character.model, "name":pending_character.name,
        "starter":String(starter_id), "level":1, "created_at":int(Time.get_unix_time_from_system())}
    characters[slot_index] = record
    if not save_roster():
        characters[slot_index] = {}
        return false
    selected_slot = slot_index
    select_character(slot_index)
    pending_character.clear()
    creation_preview.clear()
    current_form = catalog.starter_by_id(starter_id).forms[0].id
    roster_changed.emit()
    return true

func selected_tamer_data() -> TamerModelData:
    return catalog.tamer_by_id(tamer_selected)

func selected_partner_data() -> StarterPartnerData:
    return catalog.starter_by_id(partner_selected)

func prepare_adventure() -> bool:
    # คืนเซฟของ slot ก่อนโหลดแผนที่ จึงไม่ใช้ party ของตัวละครก่อนหน้า
    if account_key.is_empty() or characters[selected_slot].is_empty():
        return _fail("เลือกตัวละครที่สร้างแล้วก่อนเข้าโลก")
    select_character(selected_slot)
    QuestManager.reset_progress(false)
    QuestManager.save_path = character_save_path(selected_slot)
    if FileAccess.file_exists(QuestManager.save_path) and not QuestManager.load_progress():
        return _fail("ไฟล์ Progress ของตัวละครเสียหาย กรุณาสำรองและตรวจไฟล์เซฟ")
    gameplay_active = true
    current_level = int(QuestManager.party_profile.get("tamer_progress", {}).get("level", 1))
    var partner: StarterPartnerData = selected_partner_data()
    current_form = StringName(str(QuestManager.party_profile.get("form_id", partner.forms[0].id if partner != null else &"rookie")))
    bits = maxi(0, int(QuestManager.party_profile.get("bits", DEFAULT_BITS)))
    incubator_state = QuestManager.party_profile.get("incubator", {}).duplicate(true) if QuestManager.party_profile.get("incubator", {}) is Dictionary else {}
    bits_changed.emit(bits)
    return true

func sync_party(profile: Dictionary) -> void:
    # Tamer เป็น source of truth ของ HP/เลเวล/ร่าง GameManager เก็บ snapshot สำหรับข้ามหน้าจอ
    if not gameplay_active or account_key.is_empty():
        return
    current_level = int(profile.get("tamer_progress", {}).get("level", 1))
    current_form = StringName(str(profile.get("form_id", current_form)))
    if int(characters[selected_slot].get("level", 1)) != current_level:
        characters[selected_slot]["level"] = current_level
        save_roster()

func can_afford_bits(amount: int) -> bool:
    return amount >= 0 and bits >= amount

func spend_bits(amount: int) -> bool:
    # หัก Bits เฉพาะเมื่อยอดคงเหลือเพียงพอ
    if amount <= 0 or bits < amount:
        return false
    bits -= amount
    bits_changed.emit(bits)
    return true

func add_bits(amount: int) -> bool:
    if amount <= 0:
        return false
    bits = mini(2_000_000_000, bits + amount)
    bits_changed.emit(bits)
    return true

func import_legacy_character() -> bool:
    # คัดลอกเซฟ v15 ไปช่องใหม่ เก็บไฟล์ต้นฉบับและภาพ/ร่างคู่หูเดิมครบ
    if account_key.is_empty() or not characters[selected_slot].is_empty() or not FileAccess.file_exists(legacy_save_path):
        return _fail("เลือกช่องว่างและต้องมีเซฟ v15 ในเครื่อง")
    var file: FileAccess = FileAccess.open(legacy_save_path, FileAccess.READ)
    if file == null:
        return _fail("อ่านเซฟ v15 ไม่ได้")
    var source: String = file.get_as_text()
    var data: Variant = JSON.parse_string(source)
    if not data is Dictionary or data.get("version", 0) != 1 or not data.get("party", {}) is Dictionary:
        return _fail("รูปแบบเซฟ v15 ไม่ถูกต้อง")
    characters[selected_slot] = {"model":"taichi", "name":"Tamer v15", "starter":"legacy", "level":int(data.get("party", {}).get("tamer_progress", {}).get("level", 1))}
    if not save_roster():
        characters[selected_slot] = {}
        return false
    var destination: FileAccess = FileAccess.open(character_save_path(selected_slot), FileAccess.WRITE)
    if destination == null:
        characters[selected_slot] = {}
        save_roster()
        return _fail("คัดลอกเซฟ v15 ไม่ได้")
    destination.store_string(source)
    destination.close()
    select_character(selected_slot)
    roster_changed.emit()
    return true

func logout() -> void:
    # UI เรียกหลังกลับหน้าตัวละคร ไม่เก็บรหัสผ่านไว้ใน Singleton
    gameplay_active = false
    username = ""
    account_key = ""
    selected_slot = 0
    tamer_selected = &""
    partner_selected = &""
    tamer_name = "Tamer"
    current_level = 1
    current_form = &""
    bits = DEFAULT_BITS
    incubator_state.clear()
    pending_character.clear()
    creation_preview.clear()
    _empty_roster()

func go_to(path: String, through_loading: bool = false) -> bool:
    # ตรวจปลายทางจากรายการของเกม ห้ามพาธจาก input ผู้ใช้ และมี latch กันกดรัว
    var allowed: Array[String] = [LOGIN_SCENE, CHARACTER_SCENE, STARTER_SCENE]
    for zone_path: String in ZONE_SCENES.values():
        allowed.append(zone_path)
    if _transition_pending or path not in allowed:
        return false
    _transition_pending = true
    if through_loading:
        loading_target = path
        _change_scene.call_deferred(LOADING_SCENE)
    else:
        _change_scene.call_deferred(path)
    return true

func _change_scene(path: String) -> void:
    # ปิด soft keyboard ก่อนถอด LineEdit เดิมและเปลี่ยน Scene ใน safe deferred call
    if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
        DisplayServer.virtual_keyboard_hide()
    var error: Error = get_tree().change_scene_to_file(path)
    if error != OK:
        _transition_pending = false
        feedback.emit("เปิดหน้าจอไม่ได้: " + error_string(error))

func enter_world() -> bool:
    if not prepare_adventure():
        return false
    return go_to(ZONE_SCENES.get(String(QuestManager.current_zone), ZONE_SCENES.file_island), true)
