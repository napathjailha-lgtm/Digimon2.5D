class_name WorldServiceController
extends Node
## Controller กลางของ NPC Service แยก business logic ออกจาก Area2D บนแผนที่

var tamer: Tamer
var archive_ui: DigimonArchiveUI
var shop_ui: ShopUI
var incubator_ui: IncubatorUI
var shop_service := ShopService.new()
var incubator_service := IncubatorService.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("world_service_controller")
    tamer = get_tree().get_first_node_in_group("tamer") as Tamer
    if not is_instance_valid(tamer):
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

func open_service(service_id: StringName) -> void:
    # ปิดการเดิน/Auto ก่อนเปิด modal ป้องกันตัวละครเดินต่อใต้หน้าต่าง
    if not is_instance_valid(tamer) or get_tree().paused:
        return
    tamer.cancel_auto_navigation()
    tamer.velocity = Vector2.ZERO
    if is_instance_valid(tamer.partner):
        tamer.partner.velocity = Vector2.ZERO
    match service_id:
        &"archive":
            archive_ui.open_screen()
        &"shop":
            shop_ui.open_screen()
        &"incubator":
            incubator_ui.open_screen()
