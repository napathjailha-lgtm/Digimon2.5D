class_name EquipmentScreen
extends CanvasLayer
## หน้าจออุปกรณ์แนวนอน: ถือครอง pause เฉพาะช่วงเปิดและคืนเมื่อปิด/ออก Scene
signal closed
var tamer: Tamer
var hud: CanvasLayer # Interface ของ HUD โดยไม่อ้างชนิด MobileHUD กลับเป็นวงจร
var is_open: bool = false
var active_tab: int = 0
var selected_item: StringName = &""
var selected_slot: StringName = &""
var _preferred_slot: StringName = &""
var _owns_pause: bool = false
var _previous_back_quit: bool = true
var _root: Control
var _content: Control
var _slots: Dictionary = {}
var _bag_buttons: Dictionary = {}
var _tabs: Array[EquipmentButton] = []
var _stage: EquipmentStage
var _portrait: TextureRect
var _level: Label
var _stats: Label
var _applied: Label
var _bonus: Label
var _details: Label
var _notice: Label
var _bag_count: Label
var _skill_list: Label
var _equip: EquipmentButton
var _unequip: EquipmentButton
var _close: EquipmentButton
var _rotate: EquipmentButton
var _facing: int = 0
var _notice_left: float = 0.0
var visual_fx: ModalVisualFX

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 80
    _build()
    _root.hide()
    visual_fx = ModalVisualFX.attach(_root, _content)
    get_viewport().size_changed.connect(_layout)

func configure(player: Tamer, mobile_hud: CanvasLayer) -> void:
    # ผูกเพียงครั้งเดียว หลัง Node พร้อม และเริ่มต้นอ่านจากสถานะที่โหลดเซฟแล้ว
    tamer = player
    hud = mobile_hud
    tamer.equipment.changed.connect(refresh)
    tamer.equipment.feedback.connect(_show_notice)
    tamer.progress.progress_changed.connect(_on_values_changed)
    tamer.hp_changed.connect(_on_values_changed)
    tamer.ds_changed.connect(_on_values_changed)
    tamer.partner.hp_changed.connect(_on_values_changed)
    tamer.partner.form_changed.connect(_on_values_changed)
    _build_bag()

func open_screen() -> bool:
    # ไม่แย่ง pause ของคัตซีน/หน้าต่างอื่น ปุ่มเปิดถูกกดซ้ำก็ไม่เปิดซ้อน
    if is_open or not is_instance_valid(tamer) or get_tree().paused or tamer.partner.evolution_busy:
        return false
    hud.release_for_equipment()
    tamer.cancel_auto_navigation()
    tamer.velocity = Vector2.ZERO
    tamer.partner.velocity = Vector2.ZERO
    is_open = true
    _owns_pause = true
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    get_tree().paused = true
    _root.show()
    _layout()
    refresh()
    visual_fx.animate_open()
    return true

func close_screen() -> void:
    # ล้างนิ้วก่อนเล่นเกมต่อ ป้องกันการปล่อยนิ้วแล้วกดปุ่ม/เลือกศัตรูทะลุหน้าต่าง
    if not is_open:
        return
    visual_fx.reset()
    _root.hide()
    for button: EquipmentButton in _all_buttons():
        button.release_input()
    is_open = false
    _restore_pause()
    tamer.save_party_progress()
    closed.emit()

func _restore_pause() -> void:
    if _owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _previous_back_quit
    _owns_pause = false

func _exit_tree() -> void:
    # ถ้าเปลี่ยน Scene ระหว่างเปิดอุปกรณ์ เกมใหม่จะไม่ค้าง pause
    _restore_pause()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open:
        close_screen()

func _unhandled_input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
    # Buttons ใช้ _input รับ touch ก่อน ส่วนพื้นที่ว่าง consume ที่นี่
    get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if not is_open:
        return
    _notice_left = maxf(0, _notice_left - delta)
    if _notice_left == 0:
        _notice.text = "เลือกช่องอุปกรณ์หรือไอเทม → ใส่ / ถอด"

func _all_buttons() -> Array[EquipmentButton]:
    var result: Array[EquipmentButton] = [_close, _rotate, _equip, _unequip]
    result.append_array(_tabs)
    for value: EquipmentButton in _slots.values():
        result.append(value)
    for value: EquipmentButton in _bag_buttons.values():
        result.append(value)
    return result

func _panel(parent: Control, at: Vector2, extent: Vector2, color: Color = Color("286c92")) -> Panel:
    var panel := Panel.new()
    panel.position = at
    panel.size = extent
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(color, Color("061a2bf5")))
    parent.add_child(panel)
    return panel

func _label(parent: Control, text: String, at: Vector2, extent: Vector2, font_size: int = 16) -> Label:
    var node: Label = ClassicUIStyle.label(text, at, extent, font_size)
    parent.add_child(node)
    return node

func _button(parent: Control, text: String, at: Vector2, extent: Vector2, action: Callable) -> EquipmentButton:
    var button := EquipmentButton.new()
    button.caption = text
    button.position = at
    button.size = extent
    parent.add_child(button)
    button.pressed.connect(action)
    return button

func _build() -> void:
    # ปรับสเกลทั้งหน้าต่างตาม viewport ขณะที่ hitbox ใช้ transform ของ Control
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var theme := Theme.new()
    theme.default_font = preload("res://assets/fonts/NotoSansThai.ttf")
    _root.theme = theme
    add_child(_root)
    var dim := ColorRect.new()
    dim.name = "Shade"
    dim.color = Color(0.0, 0.025, 0.055, 0.42)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(dim)
    _content = Control.new()
    _content.size = Vector2(1184, 660)
    _root.add_child(_content)
    _panel(_content, Vector2.ZERO, _content.size, Color("45b7dd"))
    _label(_content, "◈  TAMER INFORMATION", Vector2(22, 11), Vector2(550, 38), 25)
    _label(_content, "อุปกรณ์ / กระเป๋า", Vector2(790, 15), Vector2(290, 30), 17)
    _close = _button(_content, "×", Vector2(1111, 5), Vector2(64, 56), close_screen)
    _close.accent = Color("deb969")
    for i: int in range(3):
        var tab: EquipmentButton = _button(_content, ["Tamer", "Digivice", "Skill"][i], Vector2(18 + i * 140, 60), Vector2(134, 48), _select_tab.bind(i))
        _tabs.append(tab)
    _level = _label(_content, "", Vector2(22, 108), Vector2(725, 30), 18)
    _stage = EquipmentStage.new()
    _stage.position = Vector2(213, 135)
    _stage.size = Vector2(340, 352)
    _stage.clip_contents = true
    _stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _content.add_child(_stage)
    _portrait = TextureRect.new()
    _portrait.position = Vector2(263, 149)
    _portrait.size = Vector2(240, 312)
    _portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _content.add_child(_portrait)
    _rotate = _button(_content, "↻  หมุน", Vector2(340, 482), Vector2(86, 30), _rotate_preview)
    _rotate._label.add_theme_font_size_override("font_size", 13)
    var ordinary: Array[StringName] = [&"head", &"face", &"chest", &"legs", &"gloves", &"boots", &"back", &"neck", &"ring", &"bracelet", &"belt", &"charm"]
    for i: int in range(ordinary.size()):
        var right: bool = i >= 6
        var at := Vector2(691 if right else 24, 147 + (i % 6) * 60)
        _create_slot(ordinary[i], at, right)
    _create_slot(&"device", Vector2(76, 207), false)
    _create_slot(&"chip_a", Vector2(76, 317), false)
    _create_slot(&"chip_b", Vector2(639, 317), true)
    _skill_list = _label(_content, "", Vector2(32, 158), Vector2(714, 320), 19)
    _skill_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _panel(_content, Vector2(18, 528), Vector2(737, 110))
    _label(_content, "TAMER STATUS", Vector2(31, 534), Vector2(225, 26), 15).modulate = Color("6bd7f2")
    _label(_content, "EQUIPMENT BONUS", Vector2(280, 534), Vector2(234, 26), 15).modulate = Color("debb77")
    _label(_content, "APPLIED / PARTNER", Vector2(530, 534), Vector2(220, 26), 15).modulate = Color("6bd7f2")
    _stats = _label(_content, "", Vector2(31, 562), Vector2(235, 77), 14)
    _bonus = _label(_content, "", Vector2(280, 562), Vector2(243, 77), 14)
    _applied = _label(_content, "", Vector2(530, 562), Vector2(219, 77), 14)
    _panel(_content, Vector2(777, 60), Vector2(388, 578))
    _bag_count = _label(_content, "", Vector2(793, 74), Vector2(363, 28), 16)
    _details = _label(_content, "", Vector2(795, 322), Vector2(348, 210), 15)
    _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _equip = _button(_content, "สวมใส่", Vector2(793, 545), Vector2(174, 48), _equip_selected)
    _unequip = _button(_content, "ถอดอุปกรณ์", Vector2(975, 545), Vector2(174, 48), _unequip_selected)
    _notice = _label(_content, "", Vector2(795, 604), Vector2(351, 28), 12)
    _notice.clip_text = true
    _notice.modulate = Color("ebca7c")

func _create_slot(slot_id: StringName, at: Vector2, right: bool) -> void:
    var button: EquipmentButton = _button(_content, "", at, Vector2(54, 54), select_slot.bind(slot_id))
    var name_label: Label = _label(button, EquipmentInventory.LABELS[String(slot_id)], Vector2(-123 if right else 64, 14), Vector2(116, 27), 14)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
    button.set_meta("slot_name", name_label)
    _slots[String(slot_id)] = button

func _build_bag() -> void:
    # ช่องคงตำแหน่งเดิมแม้จำนวนเป็น 0 ลดการกระโดดของ layout ขณะแตะ
    for i: int in range(tamer.equipment.catalog.items.size()):
        var item: EquipmentItemData = tamer.equipment.catalog.items[i]
        var button: EquipmentButton = _button(_content, "", Vector2(795 + (i % 6) * 59, 112 + (i / 6) * 62), Vector2(54, 56), select_bag_item.bind(item.id))
        button.icon = item.icon
        button.accent = item.rarity_color()
        _bag_buttons[String(item.id)] = button

func _layout() -> void:
    var available: Vector2 = get_viewport().get_visible_rect().size
    var factor: float = minf(1.0, minf(available.x / 1220.0, available.y / 700.0))
    _content.scale = Vector2.ONE * factor
    _content.position = (available - _content.size * factor) * 0.5

func _select_tab(index: int) -> void:
    active_tab = index
    selected_item = &""
    selected_slot = &""
    _preferred_slot = &""
    refresh()

func select_bag_item(item_id: StringName) -> void:
    selected_item = item_id
    selected_slot = &""
    var item: EquipmentItemData = tamer.equipment.catalog.find_item(item_id)
    if item == null or not item.fits_slot(_preferred_slot):
        _preferred_slot = &""
    refresh()

func select_slot(slot_id: StringName) -> void:
    selected_slot = slot_id
    _preferred_slot = slot_id
    var item: EquipmentItemData = tamer.equipment.item_at(slot_id)
    selected_item = item.id if item != null else &""
    refresh()

func _rotate_preview() -> void:
    _facing = (_facing + 1) % 4
    refresh()

func _equip_selected() -> void:
    # เลือกช่อง Chip ที่ต้องการได้; เมื่อเลือกจาก bag จะเลือกช่องว่างก่อน
    tamer.equipment.put_on(selected_item, _preferred_slot)

func _unequip_selected() -> void:
    tamer.equipment.take_off(selected_slot)

func _on_values_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
    if is_open:
        refresh()

func _show_notice(text: String) -> void:
    if is_open:
        _notice.text = text
        _notice_left = 3.0

func refresh() -> void:
    if not is_open or not is_instance_valid(tamer):
        return
    var inventory: EquipmentInventory = tamer.equipment
    for i: int in range(_tabs.size()):
        _tabs[i].selected = i == active_tab
        _tabs[i].queue_redraw()
    for key: String in _slots:
        var button: EquipmentButton = _slots[key]
        var device_slot: bool = key in ["device", "chip_a", "chip_b"]
        button.visible = (active_tab == 0 and not device_slot) or (active_tab == 1 and device_slot)
        var item: EquipmentItemData = inventory.item_at(StringName(key))
        var icon_name: String = "chip" if key.begins_with("chip_") else key
        button.icon = item.icon if item != null else load("res://assets/equipment/" + icon_name + ".svg")
        button.modulate = Color.WHITE if item != null else Color(0.6, 0.72, 0.8)
        button.selected = selected_slot == StringName(key)
        button.accent = item.rarity_color() if item != null else Color("34779f")
        button.queue_redraw()
    var count_owned: int = 0
    for item: EquipmentItemData in inventory.catalog.items:
        var button: EquipmentButton = _bag_buttons[String(item.id)]
        button.quantity = inventory.count(item.id)
        count_owned += button.quantity
        button.locked = button.quantity == 0
        button.selected = selected_item == item.id and selected_slot == &""
        button.queue_redraw()
    _bag_count.text = "กระเป๋าไอเทม  •  %d ชิ้น" % count_owned
    _level.text = "Lv.%d   ADVENTURE TAMER                           <No Guild>" % tamer.progress.level
    _stage.visible = active_tab != 2
    _portrait.visible = active_tab != 2
    _rotate.visible = active_tab != 2
    var animation := StringName("idle_" + ["down", "right", "up", "left"][_facing])
    _portrait.texture = WalkTextureTools.visible_texture(tamer.sprite.sprite_frames.get_frame_texture(animation, 0))
    _skill_list.visible = active_tab == 2
    _skill_list.text = "PARTNER / %s\n\n" % tamer.partner.current_form.monster_name
    for skill: MonsterSkill in tamer.partner.active_skills:
        _skill_list.text += "%s   •   %.0f%% ATK   /   CD %.1fs\n" % [skill.display_name, skill.multiplier * 100, skill.cooldown]
    _skill_list.text += "\nชุดสกิลเปลี่ยนตามร่างคู่หู\nอุปกรณ์เพิ่ม ATK ก่อนคำนวณดาเมจสกิล"
    var b: Dictionary = inventory.total_bonuses()
    _stats.text = "HP  %d / %d     DF  %d\nDS  %.0f / %.0f\nSPD  %.0f   •   Tamer สั่งการ" % [tamer.hp, tamer.max_hp, tamer.defense, tamer.ds, tamer.max_ds, tamer.move_speed]
    _bonus.text = "HP +%d   DS +%d   DF +%d\nSPD +%.0f\nคู่หู HP +%d  ATK +%d" % [b.hp, b.ds, b.defense, b.speed, b.partner_hp, b.partner_attack]
    _applied.text = "%s Lv.%d\nHP  %d / %d\nATK  %d    SPD  %.0f" % [tamer.partner.current_form.monster_name, tamer.partner.progress.level, tamer.partner.hp, tamer.partner.max_hp, tamer.partner.attack_power, tamer.partner.move_speed]
    _refresh_details()

func _refresh_details() -> void:
    var inventory: EquipmentInventory = tamer.equipment
    var item: EquipmentItemData = inventory.catalog.find_item(selected_item)
    _equip.locked = item == null or inventory.count(selected_item) <= 0 or tamer.progress.level < item.required_level
    _unequip.locked = selected_slot == &"" or inventory.item_at(selected_slot) == null
    if item == null:
        _details.text = "เลือกไอเทมเพื่อดูรายละเอียด\n\nใส่/ถอดของแล้วค่าสเตตัสเปลี่ยนทันที\nHP / DS ปัจจุบันไม่เติมฟรีเมื่อใส่ของ\n\nDigivice และ Chip เพิ่มพลังคู่หู\nช่อง Chip ใช้ได้ทั้ง A และ B"
        if selected_slot != &"":
            _details.text = EquipmentInventory.LABELS[String(selected_slot)] + " / ช่องว่าง\n\nเลือกไอเทมจากกระเป๋าเพื่อสวมใส่"
        return
    var bonus: Dictionary = item.bonuses()
    var lines: String = ""
    var labels: Dictionary = {"hp":"Tamer HP", "ds":"Tamer DS", "defense":"Tamer DF", "speed":"Tamer SPD", "partner_hp":"Partner HP", "partner_attack":"Partner ATK", "partner_speed":"Partner SPD"}
    for key: String in bonus:
        if float(bonus[key]) != 0:
            lines += "%s  +%.0f   " % [labels[key], bonus[key]]
    var destination: StringName = _preferred_slot if _preferred_slot != &"" else item.slot
    if destination == &"chip":
        destination = &"chip_a" if inventory.item_at(&"chip_a") == null else &"chip_b"
    var previous: EquipmentItemData = inventory.item_at(destination)
    var difference: String = ""
    if selected_slot == &"":
        var old: Dictionary = previous.bonuses() if previous != null else {"hp":0,"ds":0,"defense":0,"speed":0,"partner_hp":0,"partner_attack":0,"partner_speed":0}
        for key: String in bonus:
            var delta: float = float(bonus[key]) - float(old[key])
            if delta != 0:
                difference += "%s %+.0f   " % [labels[key], delta]
    _details.text = "%s\n%s  /  ต้องการ Lv.%d%s\n\n%s\n\n%s\n%s" % [item.item_name, EquipmentInventory.LABELS.get(String(destination), "Chip"), item.required_level, "  •  สวมอยู่" if selected_slot != &"" else "", lines, ("เปลี่ยนจาก " + previous.item_name + "\n") if previous != null and selected_slot == &"" else "", difference if not difference.is_empty() else item.description]
