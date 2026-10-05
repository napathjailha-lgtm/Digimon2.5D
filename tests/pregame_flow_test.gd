extends Node
## ทดสอบธุรกรรม/Isolation/Flow จริง ตั้ง path ในพื้นที่ทดสอบเท่านั้น
var assertions: int = 0
var failures: int = 0
const ROOT: String = "user://pregame_flow_test_v16"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run.call_deferred()

func check(value: bool, text: String) -> void:
    assertions += 1
    if value:
        print("PASS: ", text)
    else:
        failures += 1
        push_error("FAIL: " + text)

func clear_directory(path: String) -> void:
    # ลบเฉพาะโฟลเดอร์ ROOT ของชุดทดสอบ ไม่แตะ user://profiles จริง
    var directory: DirAccess = DirAccess.open(path)
    if directory == null:
        return
    for file: String in directory.get_files():
        directory.remove(file)
    for child: String in directory.get_directories():
        clear_directory(path.path_join(child))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func tap(control: Control) -> void:
    var position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
    for pressed: bool in [true, false]:
        var event := InputEventScreenTouch.new()
        event.position = position
        event.index = 0
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func open_scene(path: String) -> Node:
    get_tree().change_scene_to_file(path)
    for i: int in range(3):
        await get_tree().process_frame
    return get_tree().current_scene

func run() -> void:
    # Harness อยู่นอก current_scene เพื่อไม่ถูกเปลี่ยนทิ้งระหว่างทดสอบ SceneTree จริง
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    clear_directory(ROOT)
    GameManager.profile_root = ROOT.path_join("profiles")
    GameManager.legacy_save_path = ROOT.path_join("legacy_story.json")
    GameManager.logout()
    QuestManager.reset_progress(false)
    GameManager.catalog = null
    var loader: Control = load(GameManager.LOADING_SCENE).instantiate()
    loader.auto_transition = false
    loader.minimum_visible_seconds = 0
    loader.target_override = GameManager.LOGIN_SCENE
    get_tree().root.add_child(loader)
    var deadline: int = Time.get_ticks_msec() + 20000
    while loader.loaded_scene == null and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    check(loader.loaded_scene != null and loader.progress_bar.value == 100, "ResourceLoader โหลด Login+Catalog เบื้องหลังถึง 100%")
    check(loader.progress_bar is TextureProgressBar and GameManager.catalog != null, "TextureProgressBar และ Catalog พร้อมจริง")
    loader.queue_free()
    await get_tree().process_frame
    var broken: Control = load(GameManager.LOADING_SCENE).instantiate()
    broken.auto_transition = false
    broken.target_override = "res://scenes/no_such_scene.tscn"
    get_tree().root.add_child(broken)
    await get_tree().process_frame
    await get_tree().process_frame
    check(broken.retry_button.visible and broken.loaded_scene == null, "โหลด Scene ไม่พบให้ Retry ไม่เปลี่ยนฉากวน")
    broken.queue_free()
    await get_tree().process_frame
    if GameManager.catalog == null:
        get_tree().quit(1)
        return
    check(GameManager.catalog.tamers.size() == 8 and GameManager.catalog.starters.size() == 8, "มี 8 โมเดล Tamer และ 8 คู่หู")
    check(GameManager.catalog.tamer_by_id(&"sora").gender == "หญิง" and GameManager.catalog.tamer_by_id(&"mimi").gender == "หญิง", "ข้อมูลเพศของ Sora/Mimi ถูกต้อง")
    for starter: StarterPartnerData in GameManager.catalog.starters:
        var expected_forms: int = 4 if starter.id in [&"agumon", &"gabumon", &"patamon", &"gomamon"] else 3
        check(starter.forms.size() == expected_forms and starter.forms[0].id.begins_with(String(starter.id)), starter.display_name + " มีสายร่างเฉพาะ %d ร่าง" % expected_forms)
        for form: MonsterData in starter.forms:
            check(form.validation_error().is_empty(), form.monster_name + " มีสกิลและชุดเดิน/ตี/ร่าย 4 ทิศครบ")
    check(not GameManager.login_demo("a", "secret", "file_1"), "Login ปฏิเสธ username สั้น")
    check(not GameManager.login_demo("tester", "", "file_1"), "Login ปฏิเสธ password ว่าง")
    check(not GameManager.login_demo("tester", "secret", "unknown"), "Login ปฏิเสธ server ID ที่ไม่มี")
    var login: Control = await open_scene(GameManager.LOGIN_SCENE)
    check(login.password_input.secret and login.server_select.item_count == 2, "Login ซ่อน Password และมี 2 Servers")
    login.username_input.text = "Tester"
    login.password_input.text = "do-not-store-this-password"
    tap(login.login_button)
    for i: int in range(4):
        await get_tree().process_frame
    var character: Control = get_tree().current_scene
    check(character.get_script().resource_path.ends_with("character_selection.gd"), "แตะ Login จริงเปลี่ยนไปหน้า Character")
    check(GameManager.username == "Tester" and GameManager.get("password") == null, "Singleton เก็บ username แต่ไม่เก็บ password")
    check(character.slot_buttons.size() == 5 and character.model_buttons.size() == 8, "หน้า Character มี 5 slots และ 8 model cards")
    tap(character.model_buttons[2])
    check(character.model_selected == &"sora" and character.portrait.texture == GameManager.catalog.tamer_by_id(&"sora").portrait, "touch Sora เปลี่ยน portrait/ข้อมูลพรีวิว")
    character.name_input.text = "x"
    tap(character.action_button)
    check(GameManager.pending_character.is_empty() and GameManager.characters[0].is_empty(), "ชื่อไม่ผ่านไม่ใช้ช่องหรือสร้าง draft")
    character.name_input.text = "โซระทดสอบ"
    tap(character.action_button)
    for i: int in range(4):
        await get_tree().process_frame
    var starter_ui: Control = get_tree().current_scene
    check(starter_ui.get_script().resource_path.ends_with("starter_selection.gd") and GameManager.characters[0].is_empty(), "Create ไป Starter โดยยังไม่ commit ช่อง")
    tap(starter_ui.card_buttons[4])
    check(starter_ui.partner_selected == &"palmon" and starter_ui.path_label.text == "Palmon → Togemon → Lillymon", "touch Palmon แสดงสายพัฒนาตรงกับ Resource")
    starter_ui.back()
    for i: int in range(4):
        await get_tree().process_frame
    check(GameManager.pending_character.is_empty() and GameManager.characters[0].is_empty(), "Back ยกเลิก draft ไม่กิน slot")
    character = get_tree().current_scene
    check(character.name_input.text == "โซระทดสอบ" and character.model_selected == &"sora", "Back เก็บชื่อ/โมเดล draft สำหรับแก้ไขต่อ")
    character.select_model(&"sora")
    character.name_input.text = "โซระทดสอบ"
    character._continue()
    for i: int in range(4):
        await get_tree().process_frame
    starter_ui = get_tree().current_scene
    tap(starter_ui.card_buttons[1])
    check(starter_ui.partner_selected == &"gabumon" and starter_ui.stats_label.text.contains("HP 145"), "Gabumon พรีวิว HP/สายข้อมูล/น้ำแข็ง")
    tap(starter_ui.confirm_button)
    check(not GameManager.confirm_starter(&"agumon"), "กดยืนยันซ้ำไม่สร้างตัวละครซ้ำ")
    deadline = Time.get_ticks_msec() + 20000
    while (get_tree().current_scene == null or not get_tree().current_scene.has_node("Actors/Tamer")) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    var world: Node2D = get_tree().current_scene
    check(world != null and world.has_node("Actors/Tamer"), "Starter confirm ผ่าน Loading แล้วเข้า world.tscn")
    var tamer: Tamer = world.get_node("Actors/Tamer")
    var partner: PartnerMonster = world.get_node("Actors/Partner")
    var visible_height: float = WalkTextureTools.visible_texture(tamer.sprite.sprite_frames.get_frame_texture(&"idle_down", 0)).get_height() * tamer.sprite.scale.y
    check(visible_height >= 64.0 and visible_height <= 100.0, "โมเดลอนิเมะมีขนาดในสนามที่อ่านได้ ไม่ย่อจนเล็กหรือใหญ่เกิน")
    check(tamer.display_name == "โซระทดสอบ" and tamer.max_hp == 180 and tamer.max_ds == 130, "ชื่อและสเตตัส Tamer ส่งถึง gameplay")
    check(tamer.sprite.sprite_frames == GameManager.catalog.tamer_by_id(&"sora").sprite_frames and tamer.sprite.sprite_frames != GameManager.catalog.tamer_by_id(&"taichi").sprite_frames, "Tamer ในสนามใช้โมเดล Sora ที่เลือกจริง")
    check(partner.current_form.monster_name == "Gabumon" and partner.max_hp == 145 and partner.forms[1].monster_name == "Garurumon", "คู่หูจริงใช้สาย Gabumon ไม่ใช้สายเก่าร่วมกัน")
    check(partner.digivolve() and partner.current_form.monster_name == "Garurumon", "Starter เปลี่ยนร่าง Champion ตามสายที่เลือก")
    check(not partner.digivolve(), "Ultimate ของสายใหม่ยังล็อกตามเควสต์เดิม")
    partner.enter_fainted(false)
    check(partner.state == PartnerMonster.State.EGG and partner.hp == 0, "คู่หูสายใหม่แพ้แล้วคง Node เป็นไข่")
    check(partner.recover() and partner.current_form.monster_name == "Gabumon" and partner.hp == 145, "Recover ของสายใหม่กลับ Rookie ที่เลือก")
    check(not Input.is_emulating_mouse_from_touch() and Input.is_emulating_touch_from_mouse(), "เข้าสนามคืนการรับ touch หลายนิ้วเดิม")
    check(FileAccess.file_exists(QuestManager.save_path) and QuestManager.save_path.contains(GameManager.account_key), "Progress เซฟใน account/server/slot ของตัวละคร")
    tamer.equipment.put_on(&"field_cap")
    tamer.progress.add_exp(100)
    tamer.hp = 130
    partner.hp = 80
    tamer.save_party_progress()
    check(GameManager.current_level == 2 and GameManager.current_form == partner.current_form.id and GameManager.characters[0].level == 2, "Global level/form และ roster ตามสถานะจริง")
    var first_key: String = GameManager.account_key
    var first_path: String = QuestManager.save_path
    check(GameManager.catalog.starter_by_id(&"gabumon").forms[0].max_hp == 145, "level/gear ไม่แก้ต้นแบบ shared Resource")
    var roster_file: FileAccess = FileAccess.open(GameManager.profile_directory().path_join("roster.json"), FileAccess.READ)
    check(not roster_file.get_as_text().contains("do-not-store-this-password"), "JSON ไม่เก็บ password")
    roster_file.close()
    var hud: MobileHUD = world.get_node("MobileHUD")
    hud._return_to_characters()
    for i: int in range(4):
        await get_tree().process_frame
    character = get_tree().current_scene
    check(not GameManager.gameplay_active and character.action_button.text == "เข้าสู่โลกดิจิตอล", "กลับหน้า Character แล้วตัวเดิมใช้ปุ่มเข้าโลก")
    character._continue()
    deadline = Time.get_ticks_msec() + 20000
    while (get_tree().current_scene == null or not get_tree().current_scene.has_node("Actors/Tamer")) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    world = get_tree().current_scene
    tamer = world.get_node("Actors/Tamer")
    partner = world.get_node("Actors/Partner")
    check(tamer.progress.level == 2 and tamer.max_hp == 260 and tamer.equipment.item_at(&"head") != null, "ตัวเดิมข้าม Starter และคืน level/gear/ฐาน Sora")
    check(tamer.hp == 130 and partner.hp == 80, "เข้าโลกต่อไม่รีเซ็ต HP เป็นค่าเริ่มต้น")
    (world.get_node("MobileHUD") as MobileHUD)._return_to_characters()
    for i: int in range(4):
        await get_tree().process_frame
    check(not GameManager.begin_creation(&"taichi", "ชื่อใหม่"), "ไม่สร้างทับช่องที่มีตัวละคร")
    GameManager.select_character(1)
    check(not GameManager.begin_creation(&"taichi", "โซระทดสอบ"), "ปฏิเสธชื่อซ้ำในบัญชี/Server")
    check(GameManager.begin_creation(&"yamato", "ยามาโตะ") and GameManager.confirm_starter(&"palmon"), "สร้าง slot2 โดยใช้ model/partner คนละชุด")
    check(GameManager.prepare_adventure() and QuestManager.party_profile.is_empty() and not QuestManager.is_completed(&"q01_agumon"), "slot2 ไม่รับ HP/gear/quest ของ slot1")
    GameManager.gameplay_active = false
    check(GameManager.character_save_path(1) != first_path, "แต่ละ slot มีไฟล์ Progress คนละพาธ")
    GameManager.login_demo("Tester", "another", "file_2")
    check(GameManager.account_key != first_key and GameManager.characters[0].is_empty(), "Server 2 ไม่ใช้ตัวละครของ Server 1")
    GameManager.login_demo("AnotherUser", "another", "file_1")
    check(GameManager.characters[0].is_empty(), "คนละ username มี roster แยก")
    GameManager.login_demo("tester", "another", "file_1")
    check(GameManager.account_key == first_key and GameManager.characters[0].name == "โซระทดสอบ" and GameManager.characters[1].starter == "palmon", "Login ใหม่ case ต่างกันคืน roster จาก disk เดิม")
    for index: int in range(2, 5):
        GameManager.select_character(index)
        check(GameManager.begin_creation(&"koushiro", "Tamer%d" % index) and GameManager.confirm_starter(&"tentomon"), "สร้างช่อง %d" % (index+1))
    check(not GameManager.select_character(5) and GameManager.characters.size() == 5, "ไม่เกิน 5 ช่อง")
    GameManager.logout()
    check(GameManager.account_key.is_empty() and GameManager.pending_character.is_empty(), "Logout ล้าง session/draft")
    # นำเข้าเซฟ v15 ทดสอบด้วยไฟล์ต้นแบบ ไม่แตะเซฟจริงของผู้เล่น
    GameManager.login_demo("legacyuser", "demo", "file_1")
    var old_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(first_path))
    old_profile.party.erase("partner_roster") # v15 ยังไม่มี roster; อย่าทดสอบ fixture ด้วย schema ใหม่
    old_profile.party.form_id = "rookie"
    old_profile.party.hp = 80
    old_profile.party.ds = 95
    var source_data: String = JSON.stringify(old_profile)
    var legacy_file := FileAccess.open(GameManager.legacy_save_path, FileAccess.WRITE)
    legacy_file.store_string(source_data)
    legacy_file.close()
    check(GameManager.import_legacy_character() and GameManager.characters[0].starter == "legacy", "ปุ่ม migration นำเข้า progress/gear v15 ได้")
    check(FileAccess.get_file_as_string(GameManager.legacy_save_path) == source_data and FileAccess.get_file_as_string(GameManager.character_save_path(0)) == source_data, "migration เก็บต้นฉบับและคัดลอก byte ตรงกัน")
    check(GameManager.prepare_adventure(), "Legacy prepare ใช้ slot save ที่นำเข้า")
    var legacy_world: Node2D = load("res://scenes/world.tscn").instantiate()
    get_tree().root.add_child(legacy_world)
    var legacy_tamer: Tamer = legacy_world.get_node("Actors/Tamer")
    check(legacy_tamer.max_hp == 280 and legacy_tamer.max_ds == 100 and legacy_tamer.ds == 95, "Legacy ใช้ฐาน HP200/DS100 เดิม ไม่สวมฐาน Taichi ใหม่")
    check(legacy_tamer.partner.current_form.id == &"rookie" and legacy_tamer.partner.forms.size() == 4 and legacy_tamer.partner.hp == 80, "Legacy เก็บสายร่าง/ภาพ/HP คู่หู v15 เดิม")
    legacy_world.queue_free()
    await get_tree().process_frame
    GameManager.gameplay_active = false
    if get_tree().current_scene != null:
        get_tree().current_scene.queue_free()
    await get_tree().process_frame
    GameManager.logout()
    GameManager.set_menu_input(false)
    clear_directory(ROOT)
    print("ASSERTIONS: ", assertions)
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
