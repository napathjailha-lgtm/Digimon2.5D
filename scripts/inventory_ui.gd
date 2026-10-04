class_name InventoryUI
extends CanvasLayer
## หน้าจอ Mobile ใช้ GridContainer จัดช่อง และ TouchCommand แยกนิ้วแบบเดียวกับเกม
## Pause เฉพาะช่วงเปิด จึงหยุดการต่อสู้ขณะเลือกของ แต่ UI ทำงาน PROCESS_MODE_ALWAYS
var player: Node
var hud: CanvasLayer
var is_open: bool = false
var selected_id: String = ""
var _owns_pause: bool = false
var _previous_back_quit: bool = true
var _refresh_pending: bool = false
var slots: Array[EquipmentButton] = []
var visual_fx: ModalVisualFX
var equipment_shortcut: EquipmentButton
@onready var root: Control = $Root
@onready var grid: GridContainer = $Root/Panel/Margin/Column/Body/Bag/Inner/Stack/Grid
@onready var count_label: Label = $Root/Panel/Margin/Column/Header/Count
@onready var close_button: EquipmentButton = $Root/Panel/Margin/Column/Header/Close
@onready var popup: PanelContainer = $Root/Panel/Margin/Column/Body/Popup
@onready var icon: TextureRect = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Icon
@onready var name_label: Label = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Name
@onready var type_label: Label = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Type
@onready var description_label: Label = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Description
@onready var partner_label: Label = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Partner
@onready var use_button: EquipmentButton = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Actions/Use
@onready var drop_button: EquipmentButton = $Root/Panel/Margin/Column/Body/Popup/Inner/Details/Actions/Drop
@onready var notice: Label = $Root/Panel/Margin/Column/Notice

func _ready() -> void:
    # สร้างช่องครั้งเดียว ไม่ queue_free ปุ่มที่ยังประมวลผล Touch อยู่ระหว่าง Use
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 85
    root.hide()
    ($Root/Panel as PanelContainer).add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("5ac4d7")))
    popup.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("9070af"), Color("101d31")))
    visual_fx = ModalVisualFX.attach(root, $Root/Panel)
    popup.hide()
    for index: int in range(24):
        var button := InventorySlot.new()
        button.name = "Slot%d" % (index + 1)
        button.custom_minimum_size = Vector2(92, 94)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_choose_slot.bind(index))
        grid.add_child(button)
        slots.append(button)
    close_button.pressed.connect(close_screen)
    # เข้าหน้าสวมใส่จาก Inventory โดยตรง ตาม flow มือถือ/เว็บเดียวกัน
    equipment_shortcut = EquipmentButton.new()
    equipment_shortcut.caption = "อุปกรณ์"
    equipment_shortcut.custom_minimum_size = Vector2(110, 42)
    equipment_shortcut.pressed.connect(_open_equipment)
    close_button.get_parent().add_child(equipment_shortcut)
    use_button.pressed.connect(_use_selected)
    drop_button.pressed.connect(_drop_selected)
    InventoryManager.changed.connect(_request_refresh)
    InventoryManager.feedback.connect(_show_notice)
    get_viewport().size_changed.connect(_layout)

func configure(tamer: Node, mobile_hud: CanvasLayer) -> void:
    # ผูกหลัง instantiate เพื่อให้ UI ใช้ HP ปัจจุบัน รวมสัญญาณฟื้น/แพ้/เปลี่ยนร่าง
    player = tamer
    hud = mobile_hud
    player.hp_changed.connect(_request_refresh)
    player.survival_changed.connect(_request_refresh)
    player.partner.mp_changed.connect(_request_refresh)
    player.partner.hp_changed.connect(_request_refresh)
    player.partner.form_changed.connect(_request_refresh)
    _layout()

func _layout() -> void:
    # ปรับกรอบตาม Viewport logical size; เกมกำหนด Landscape 1280x720 + canvas_items
    var panel: Control = $Root/Panel
    var extent: Vector2 = get_viewport().get_visible_rect().size
    var factor: float = minf(1.0, minf((extent.x - 48) / 1184, (extent.y - 48) / 640))
    panel.scale = Vector2.ONE * factor
    panel.size = Vector2(1184, 640)
    panel.position = (extent - panel.size * factor) * 0.5

func open_screen() -> bool:
    # ไม่แย่ง pause จากอุปกรณ์/คัตซีน และคืนทุก finger ก่อนหยุดเวลา
    if is_open or not is_instance_valid(player) or get_tree().paused or player.partner.evolution_busy:
        return false
    hud.release_for_equipment()
    player.cancel_auto_navigation()
    player.velocity = Vector2.ZERO
    player.partner.velocity = Vector2.ZERO
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    is_open = true
    _owns_pause = true
    get_tree().paused = true
    root.show()
    notice.text = "แตะไอเทมเพื่อดูรายละเอียด • ใช้/ทิ้งครั้งละ 1 ชิ้น"
    refresh()
    visual_fx.animate_open()
    return true

func close_screen() -> void:
    # ปล่อย Touch ทั้งหมดก่อน Resume ป้องกันนิ้วเดิมสั่งโจมตีทะลุหน้าต่าง
    if not is_open:
        return
    visual_fx.reset()
    root.hide()
    for button: EquipmentButton in slots + [close_button, use_button, drop_button, equipment_shortcut]:
        button.release_input()
    is_open = false
    _restore_pause()
    if is_instance_valid(player):
        player.save_party_progress()

func _open_equipment() -> void:
    # ปิด Inventory ก่อนเพื่อคืน pause ownership แล้วเปิด EquipmentScreen ในเฟรมถัดไป
    if not is_instance_valid(hud) or hud.equipment_screen == null:
        return
    close_screen()
    hud.equipment_screen.open_screen.call_deferred()

func _restore_pause() -> void:
    # ถือ ownership เฉพาะ pause ที่หน้าต่างนี้เปิดเอง
    if _owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _previous_back_quit
    _owns_pause = false

func _exit_tree() -> void:
    # เปลี่ยน Scene หรือถูกลบขณะเปิดก็ไม่ทิ้งเกมไว้ในสถานะ pause
    _restore_pause()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open:
        close_screen()

func _unhandled_input(event: InputEvent) -> void:
    # TouchCommand รับก่อน; พื้นที่ว่างถูก consume เพื่อไม่เลือกศัตรูด้านหลัง
    if not is_open:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
    get_viewport().set_input_as_handled()

func _request_refresh(_a: Variant = null, _b: Variant = null) -> void:
    # coalesce หลาย signal เป็นการวาดหนึ่งครั้งหลัง transaction เสร็จ
    if _refresh_pending:
        return
    _refresh_pending = true
    _refresh_deferred.call_deferred()

func _refresh_deferred() -> void:
    _refresh_pending = false
    if is_open:
        refresh()

func refresh() -> void:
    # อ่านข้อมูลล่าสุด แสดงไอคอน/จำนวน และ border ของ ID ที่เลือกไว้
    var entries: Array[Dictionary] = InventoryManager.items()
    count_label.text = "%d / %d ช่อง" % [entries.size(), InventoryManager.max_slots]
    for index: int in range(slots.size()):
        var button: EquipmentButton = slots[index]
        var item: ItemData = entries[index].item if index < entries.size() else null
        button.icon = item.item_texture if item != null else null
        button.quantity = int(entries[index].quantity) if item != null else -1
        button.locked = item == null or index >= InventoryManager.max_slots
        button.selected = item != null and item.item_id == selected_id
        button.set_caption(item.item_name if item != null else "—")
        # label ของช่องถูกสร้างก่อนได้ icon จึงตั้ง alignment ของข้อความใต้ไอคอน
        button._label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        button._label.add_theme_font_size_override("font_size", 12)
        button._label.clip_text = true
        button.queue_redraw()
    _refresh_popup()

func _choose_slot(index: int) -> void:
    # เก็บ ID เพราะ index อาจเลื่อนเมื่อลบ stack แรกจาก Array
    var item: ItemData = InventoryManager.item_at(index)
    if item == null:
        return
    selected_id = item.item_id
    refresh()

func _refresh_popup() -> void:
    # ปิด Popup เมื่อใช้ชิ้นสุดท้าย ไม่เปิดให้ปุ่มเดิมไปใช้ item ถัดไปโดยบังเอิญ
    var item: ItemData = InventoryManager.item_at(InventoryManager.index_of(selected_id))
    popup.visible = item != null
    if item == null:
        selected_id = ""
        return
    icon.texture = item.item_texture
    name_label.text = "%s  x%d" % [item.item_name, InventoryManager.count(item.item_id)]
    type_label.text = item.type_label()
    description_label.text = item.description
    var partner: Node = player.partner
    partner_label.text = "Tamer HP %d/%d • อิ่ม %.0f • แรง %.0f\n%s HP %d/%d • MP %.0f/%.0f" % [player.hp,player.max_hp,player.tamer_hunger,player.tamer_stamina,partner.current_form.monster_name,partner.hp,partner.max_hp,partner.digimon_mp,partner.digimon_max_mp]
    use_button.locked = not InventoryManager.can_use_item(item)
    var caption: String = "ใช้ไม่ได้"
    if item.item_type == ItemData.ItemType.EGG:
        caption = "ไป Incubator"
    if item.item_type == ItemData.ItemType.CONSUMABLE:
        match item.effect_type:
            ItemData.EffectType.TAMER_FOOD: caption = "กิน • อิ่ม +%d" % item.effect_value
            ItemData.EffectType.PARTNER_HP: caption = "ใช้ • HP +%d" % item.effect_value
            ItemData.EffectType.PARTNER_MP: caption = "ใช้ • MP +%d" % item.effect_value
    use_button.set_caption(caption)
    drop_button.locked = false
    use_button.queue_redraw()

func _use_selected() -> void:
    # หา index ใหม่ ณ ตอนกดจริง แล้วให้ Manager ตัดสินใจและเปลี่ยนข้อมูล
    InventoryManager.use_item(InventoryManager.index_of(selected_id))

func _drop_selected() -> void:
    # วาง Loot ไว้ข้าง Tamer จะเก็บกลับได้หลังปิดหน้าต่างและเข้าใกล้
    InventoryManager.drop_item(InventoryManager.index_of(selected_id), 1)

func _show_notice(text: String) -> void:
    # ข้อความเดียวในหน้าต่าง ไม่สร้าง Popup ซ้อนทุกครั้งที่กระเป๋าเต็ม
    if is_open:
        notice.text = text
