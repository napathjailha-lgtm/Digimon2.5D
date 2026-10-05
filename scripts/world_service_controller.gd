class_name WorldServiceController
extends Node
## Controller กลางของ NPC Service
## รับ E เพียงจุดเดียวแล้วเลือก ServicePoint ที่ใกล้ที่สุด ป้องกัน Archive/Shop เปิดผิดตัวเมื่อรัศมีซ้อนกัน

var tamer: Tamer
var hud: MobileHUD
var archive_ui: DigimonArchiveUI
var shop_ui: ShopUI
var incubator_ui: IncubatorUI
var shop_service := ShopService.new()
var incubator_service := IncubatorService.new()

# ปุ่ม E เสมือนสำหรับมือถือ แสดงเฉพาะเมื่อมี ServicePoint อยู่ในระยะ
var mobile_interact_button: TouchCommand
var _mobile_interact_point: WorldServicePoint
var _services_initialized: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("world_service_controller")
    HybridInput.ensure_actions()
    _try_initialize_services()


func _try_initialize_services() -> void:
    if _services_initialized:
        return

    tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    hud = get_parent().get_node_or_null("MobileHUD") as MobileHUD

    # Sibling _ready order ต่างกันได้ระหว่าง editor/Web/Android
    # ห้าม return ถาวร: _process จะลองใหม่จน MobileHUD สร้าง PartnerRoster เสร็จ
    if not is_instance_valid(tamer) or not is_instance_valid(tamer.party_roster) or not is_instance_valid(hud):
        return

    _build_mobile_interact_button()

    archive_ui = DigimonArchiveUI.new()
    add_child(archive_ui)
    archive_ui.configure(tamer.party_roster)

    shop_ui = ShopUI.new()
    add_child(shop_ui)
    shop_ui.configure(shop_service)

    incubator_service.configure(tamer.party_roster)
    incubator_ui = IncubatorUI.new()
    add_child(incubator_ui)
    incubator_ui.configure(incubator_service, tamer)

    _services_initialized = true

func _process(_delta: float) -> void:
    if not _services_initialized:
        _try_initialize_services()
    if not _services_initialized:
        return

    # Desktop ไม่ต้องมีปุ่มนี้ เพราะใช้ E/Mouse ได้ตามเดิม
    if not is_instance_valid(mobile_interact_button):
        return

    if get_tree().paused or not is_instance_valid(tamer):
        _set_mobile_interact_point(null)
        return

    # Web Mobile Portrait มี overlay บังคับหมุนจออยู่แล้ว จึงไม่แสดงปุ่มทะลุ overlay
    if OS.has_feature("web") and HybridPlatform.use_mobile_layout(get_viewport()) and HybridPlatform.is_portrait(get_viewport()):
        _set_mobile_interact_point(null)
        return

    var nearest: WorldServicePoint = _nearest_service_point()
    _set_mobile_interact_point(nearest)
    if nearest != null:
        _layout_mobile_interact_button()


func _build_mobile_interact_button() -> void:
    # ใช้ TouchCommand เพื่อรองรับ multi-touch จริง ไม่ต้องอาศัย mouse emulation
    # Android/iOS native ต้องได้ปุ่มแม้ viewport ใหญ่หรือ feature mobile ไม่ถูกใส่มาใน export
    if not HybridPlatform.is_touch_device() or not is_instance_valid(hud):
        return

    var hud_root := hud.get_node_or_null("Root") as Control
    if hud_root == null:
        return

    mobile_interact_button = TouchCommand.new()
    mobile_interact_button.name = "MobileServiceInteract"
    mobile_interact_button.caption = "ใช้งาน"
    mobile_interact_button.tint = Color("2c8fac")
    mobile_interact_button.z_index = 300
    mobile_interact_button.visible = false
    hud_root.add_child(mobile_interact_button)
    mobile_interact_button.pressed.connect(_on_mobile_interact_pressed)
    _layout_mobile_interact_button()


func _layout_mobile_interact_button() -> void:
    if not is_instance_valid(mobile_interact_button):
        return

    var view: Vector2 = get_viewport().get_visible_rect().size
    var inset: Vector4 = HudSafeArea.for_viewport(get_viewport())
    var button_size := Vector2(184.0, 82.0)

    # วางเหนือกลุ่ม Skill ด้านขวา เพื่อให้นิ้วโป้งกดได้และไม่ทับ Attack/Skill
    var combat_scale: float = absf(hud.combat.scale.y) if is_instance_valid(hud) else 1.0
    var combat_top: float = view.y - maxf(12.0, inset.w) - 330.0 * maxf(0.55, combat_scale)
    var center_y: float = combat_top - button_size.y * 0.60
    center_y = clampf(
        center_y,
        maxf(12.0, inset.y) + button_size.y * 0.5,
        view.y - maxf(12.0, inset.w) - button_size.y * 0.5
    )

    mobile_interact_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    mobile_interact_button.position = Vector2(
        view.x - maxf(14.0, inset.z) - button_size.x,
        center_y - button_size.y * 0.5
    )
    mobile_interact_button.size = button_size


func _set_mobile_interact_point(point: WorldServicePoint) -> void:
    if not is_instance_valid(mobile_interact_button):
        return

    if point == null:
        _mobile_interact_point = null
        mobile_interact_button.release_input()
        mobile_interact_button.hide()
        return

    _mobile_interact_point = point
    mobile_interact_button.tint = point.accent_color
    mobile_interact_button.set_caption(_mobile_caption(point))
    mobile_interact_button.show()


func _mobile_caption(point: WorldServicePoint) -> String:
    match StringName(point.service_id):
        &"archive":
            return "ใช้งาน\nคลัง Digimon"
        &"shop":
            return "ใช้งาน\nร้านค้า"
        &"incubator":
            return "ใช้งาน\nฟักไข่"
    return "ใช้งาน"


func _on_mobile_interact_pressed() -> void:
    # เช็ก nearest ใหม่ตอนกดจริง ป้องกันผู้เล่นเดินพ้นระยะในเฟรมเดียวกับที่แตะ
    var nearest: WorldServicePoint = _nearest_service_point()
    if nearest == null:
        _set_mobile_interact_point(null)
        return

    mobile_interact_button.release_input()
    nearest.request_interaction()


func _unhandled_input(event: InputEvent) -> void:
    # Keyboard interaction ทำที่ Controller ตัวเดียว เพื่อเลือก NPC ที่ใกล้ที่สุดอย่าง deterministic
    if get_tree().paused or not event.is_action_pressed(&"interact"):
        return
    var nearest: WorldServicePoint = _nearest_service_point()
    if nearest != null:
        nearest.request_interaction()
        get_viewport().set_input_as_handled()

func _nearest_service_point() -> WorldServicePoint:
    var nearest: WorldServicePoint = null
    var best: float = INF
    for node: Node in get_tree().get_nodes_in_group("world_service_points"):
        var point := node as WorldServicePoint
        if point == null or not point.can_interact():
            continue
        var distance: float = point.distance_to_tamer()
        if distance < best:
            best = distance
            nearest = point
    return nearest

func open_service(service_id: StringName) -> void:
    # หยุดการควบคุมสนามและคืน finger state ก่อน pause modal
    if not _services_initialized:
        _try_initialize_services()
    if not _services_initialized or not is_instance_valid(tamer) or get_tree().paused:
        return

    if is_instance_valid(mobile_interact_button):
        mobile_interact_button.release_input()
        mobile_interact_button.hide()

    if is_instance_valid(hud):
        hud.release_for_equipment()
    tamer.cancel_auto_navigation()
    tamer.velocity = Vector2.ZERO
    tamer.set_target(null)
    if is_instance_valid(tamer.partner):
        tamer.partner.velocity = Vector2.ZERO
        tamer.partner.cancel_battle()

    match service_id:
        &"archive":
            archive_ui.open_screen()
        &"shop":
            shop_ui.open_screen()
        &"incubator":
            incubator_ui.open_screen()
