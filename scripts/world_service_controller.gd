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

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("world_service_controller")
    HybridInput.ensure_actions()
    tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    hud = get_parent().get_node_or_null("MobileHUD") as MobileHUD

    if not is_instance_valid(tamer) or not is_instance_valid(tamer.party_roster):
        push_warning("WorldServiceController: Tamer/PartnerRoster ยังไม่พร้อม")
        return

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
        if point == null or not point.can_keyboard_interact():
            continue
        var distance: float = point.distance_to_tamer()
        if distance < best:
            best = distance
            nearest = point
    return nearest

func open_service(service_id: StringName) -> void:
    # หยุดการควบคุมสนามและคืน finger state ก่อน pause modal
    if not is_instance_valid(tamer) or get_tree().paused:
        return
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
