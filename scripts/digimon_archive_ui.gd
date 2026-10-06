class_name DigimonArchiveUI
extends CanvasLayer
## Digimon Archive แบบ responsive: Party 3 ช่อง + Storage ไม่จำกัด • แต่ละ Digimon มี Level/EXP ของตัวเอง
## ใช้ ScrollContainer และปุ่มขนาดสัมผัสแทนตำแหน่งตายตัว เพื่อให้ Web/Mobile แสดงผลเหมือนกัน

signal closed

var roster: PartnerRoster
var is_open: bool = false
var root: Control
var safe: MarginContainer
var panel: PanelContainer
var party_list: VBoxContainer
var storage_list: VBoxContainer
var party_count: Label
var storage_count: Label
var notice: Label
var visual_fx: ModalVisualFX

var enhancement_panel: PanelContainer
var enhancement_title: Label
var enhancement_detail: Label
var enhancement_egg_source: PanelContainer
var enhancement_egg_icon: TextureRect
var enhancement_egg_count: Label
var enhancement_slots: Array[PanelContainer] = []
var enhancement_slot_icons: Array[TextureRect] = []
var enhancement_button: DigimonTouchButton
var enhancement_drag_ghost: TextureRect

var _enhance_uid: String = ""
var _enhance_staged: Array[bool] = [false, false, false, false, false]
var _drag_finger: int = -1
var _drag_mouse: bool = false
var _drag_started: bool = false
var _drag_start := Vector2.ZERO
const ENHANCE_DRAG_THRESHOLD := 6.0

var _owns_pause: bool = false
var _previous_back_quit: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 96
    _build()
    root.hide()
    get_viewport().size_changed.connect(_layout)

func configure(owner_roster: PartnerRoster) -> void:
    roster = owner_roster
    if not roster.changed.is_connected(_deferred_refresh):
        roster.changed.connect(_deferred_refresh)
    if not roster.feedback.is_connected(_show_notice):
        roster.feedback.connect(_show_notice)
    if not InventoryManager.changed.is_connected(_deferred_refresh):
        InventoryManager.changed.connect(_deferred_refresh)

func open_screen() -> bool:
    if is_open or roster == null or get_tree().paused:
        return false

    # First-open fix: dynamic rows/cards must exist before ResponsiveUI measures the panel.
    # Keep the panel transparent while Container nodes complete their first layout pass,
    # then measure twice across deferred turns and only after that start the modal FX.
    is_open = true
    _owns_pause = true
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    get_tree().paused = true

    visual_fx.reset()
    panel.modulate.a = 0.0
    root.show()
    _refresh()
    _prepare_open_layout.call_deferred()
    return true


func _prepare_open_layout() -> void:
    if not is_open or not is_instance_valid(panel):
        return
    _layout()
    _finish_open_layout.call_deferred()


func _finish_open_layout() -> void:
    if not is_open or not is_instance_valid(panel):
        return
    # รอบสองอ่าน size หลัง CenterContainer/ScrollContainer sort เสร็จ
    _layout()
    panel.modulate.a = 1.0
    visual_fx.animate_open()

func close_screen() -> void:
    if not is_open:
        return
    visual_fx.reset()
    _cancel_enhancement_drag()
    _release_buttons()
    root.hide()
    is_open = false
    _restore_pause()
    if roster != null and is_instance_valid(roster.tamer):
        roster.tamer.save_party_progress()
    closed.emit()

func _restore_pause() -> void:
    if _owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _previous_back_quit
    _owns_pause = false

func _exit_tree() -> void:
    _restore_pause()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open:
        close_screen()

func _unhandled_input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_screen()
    get_viewport().set_input_as_handled()

func _build() -> void:
    root = Control.new()
    root.name = "Root"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.theme = ServiceUIStyle.make_theme()
    add_child(root)

    var shade := ColorRect.new()
    shade.name = "Shade"
    shade.color = Color(0.005, 0.018, 0.032, 0.70)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)

    safe = MarginContainer.new()
    safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(safe)

    var center := CenterContainer.new()
    safe.add_child(center)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(ServiceUIStyle.CYAN))
    center.add_child(panel)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    margin.add_child(stack)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    stack.add_child(header)

    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_stack.add_theme_constant_override("separation", 0)
    header.add_child(title_stack)
    title_stack.add_child(ServiceUIStyle.label("DIGIMON ARCHIVE", 26, ServiceUIStyle.TEXT))
    title_stack.add_child(ServiceUIStyle.label("จัดทีม • ฝาก Digimon • Enhancement +1 ถึง +5", 13, ServiceUIStyle.MUTED))

    var close := _button("ปิด ×", Vector2(94, 48), close_screen, ServiceUIStyle.GOLD)
    header.add_child(close)

    var summary := HBoxContainer.new()
    summary.add_theme_constant_override("separation", 10)
    stack.add_child(summary)
    var party_badge := PanelContainer.new()
    party_badge.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.GREEN, Color("0b241f")))
    party_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    summary.add_child(party_badge)
    party_count = ServiceUIStyle.label("", 16, ServiceUIStyle.GREEN)
    party_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    party_count.custom_minimum_size.y = 34
    party_badge.add_child(party_count)
    var storage_badge := PanelContainer.new()
    storage_badge.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.PURPLE, Color("1a1230")))
    storage_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    summary.add_child(storage_badge)
    storage_count = ServiceUIStyle.label("", 16, ServiceUIStyle.PURPLE)
    storage_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    storage_count.custom_minimum_size.y = 34
    storage_badge.add_child(storage_count)

    enhancement_panel = PanelContainer.new()
    enhancement_panel.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.GOLD, Color("17140af2")))
    stack.add_child(enhancement_panel)

    var enhancement_margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        enhancement_margin.add_theme_constant_override("margin_" + side, 10)
    enhancement_panel.add_child(enhancement_margin)

    var enhancement_row := HBoxContainer.new()
    enhancement_row.add_theme_constant_override("separation", 10)
    enhancement_margin.add_child(enhancement_row)

    var enhancement_info := VBoxContainer.new()
    enhancement_info.custom_minimum_size.x = 255
    enhancement_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enhancement_row.add_child(enhancement_info)

    enhancement_title = ServiceUIStyle.label("ENHANCEMENT CHAMBER", 17, ServiceUIStyle.GOLD)
    enhancement_info.add_child(enhancement_title)
    enhancement_detail = ServiceUIStyle.label("เลือก Digimon จาก Party หรือ Storage เพื่อเริ่ม", 12, ServiceUIStyle.MUTED)
    enhancement_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    enhancement_info.add_child(enhancement_detail)

    enhancement_egg_source = PanelContainer.new()
    enhancement_egg_source.custom_minimum_size = Vector2(112, 76)
    enhancement_egg_source.mouse_filter = Control.MOUSE_FILTER_PASS
    enhancement_egg_source.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.CYAN, Color("081929")))
    enhancement_row.add_child(enhancement_egg_source)

    var egg_source_row := HBoxContainer.new()
    egg_source_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    egg_source_row.add_theme_constant_override("separation", 4)
    enhancement_egg_source.add_child(egg_source_row)

    enhancement_egg_icon = TextureRect.new()
    enhancement_egg_icon.custom_minimum_size = Vector2(48, 48)
    enhancement_egg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    enhancement_egg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    enhancement_egg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    egg_source_row.add_child(enhancement_egg_icon)

    enhancement_egg_count = ServiceUIStyle.label("x0", 14, ServiceUIStyle.CYAN)
    enhancement_egg_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    egg_source_row.add_child(enhancement_egg_count)

    var slots_row := HBoxContainer.new()
    slots_row.add_theme_constant_override("separation", 6)
    enhancement_row.add_child(slots_row)
    for slot_index: int in range(PartnerRoster.ENHANCEMENT_EGG_COST):
        var slot := PanelContainer.new()
        slot.custom_minimum_size = Vector2(62, 62)
        slot.mouse_filter = Control.MOUSE_FILTER_PASS
        slot.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("465362"), Color("07131f")))
        slots_row.add_child(slot)
        enhancement_slots.append(slot)

        var slot_icon := TextureRect.new()
        slot_icon.custom_minimum_size = Vector2(52, 52)
        slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot_icon.modulate = Color(1, 1, 1, 0.18)
        slot.add_child(slot_icon)
        enhancement_slot_icons.append(slot_icon)

    enhancement_button = _button("UPGRADE", Vector2(128, 58), _commit_enhancement, ServiceUIStyle.GOLD)
    enhancement_button.disabled = true
    enhancement_row.add_child(enhancement_button)

    enhancement_drag_ghost = TextureRect.new()
    enhancement_drag_ghost.custom_minimum_size = Vector2(54, 54)
    enhancement_drag_ghost.size = Vector2(54, 54)
    enhancement_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    enhancement_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    enhancement_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    enhancement_drag_ghost.z_index = 1000
    enhancement_drag_ghost.visible = false
    root.add_child(enhancement_drag_ghost)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 14)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(columns)

    var party_panel := _section_panel("CURRENT PARTY", "ตัวที่พกติดตัว • สูงสุด 3", ServiceUIStyle.GREEN)
    party_panel.custom_minimum_size.x = 420
    party_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(party_panel)
    party_list = party_panel.get_meta("list") as VBoxContainer

    var storage_panel := _section_panel("STORAGE BANK", "คลังถาวร • จำนวนไม่จำกัด", ServiceUIStyle.PURPLE)
    storage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(storage_panel)
    storage_list = storage_panel.get_meta("list") as VBoxContainer

    notice = ServiceUIStyle.label("Enhancement ใช้ Digitama สายเดียวกัน 5 ใบต่อครั้ง • ล้มเหลวไม่ลดระดับ", 14, ServiceUIStyle.MUTED)
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.custom_minimum_size.y = 28
    stack.add_child(notice)

    visual_fx = ModalVisualFX.attach(root, panel)

func _section_panel(title: String, subtitle: String, accent: Color) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("081827f2")))
    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    frame.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 8)
    margin.add_child(stack)
    stack.add_child(ServiceUIStyle.label(title, 18, accent))
    stack.add_child(ServiceUIStyle.label(subtitle, 12, ServiceUIStyle.MUTED))
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 260
    scroll.clip_contents = true
    stack.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)
    frame.set_meta("list", list)
    return frame

func _layout() -> void:
    # Child card มี minimum width ของตัวเอง จึง fit ทั้ง Panel รอบจุดกึ่งกลางแทนการบังคับ width อย่างเดียว
    ResponsiveUI.apply_safe_margins(safe, get_viewport(), 12.0)
    panel.custom_minimum_size = Vector2(1080, 700)
    ResponsiveUI.fit_centered(panel, get_viewport(), 14.0)
    # เรียกซ้ำหลัง Container sort เพื่อให้ pivot ใช้ size จริง

func _refresh() -> void:
    if not is_open or roster == null:
        return
    _clear_list(party_list)
    _clear_list(storage_list)

    party_count.text = "PARTY  %d / %d" % [roster.members.size(), PartnerRoster.CAPACITY]
    storage_count.text = "STORAGE  %d" % roster.storage.size()

    for index: int in range(roster.members.size()):
        party_list.add_child(_member_card(roster.members[index], index, true))

    if roster.storage.is_empty():
        storage_list.add_child(_empty_state("คลังยังว่าง", "Digimon ที่ฟักใหม่จะถูกส่งเข้าคลังนี้"))
    else:
        for index: int in range(roster.storage.size()):
            storage_list.add_child(_member_card(roster.storage[index], index, false))

    _refresh_enhancement_chamber()

func _member_card(entry: Dictionary, index: int, in_party: bool) -> PanelContainer:
    var data: StarterPartnerData = roster.family(StringName(str(entry.get("id", ""))))
    var active: bool = in_party and index == roster.active_index
    var accent: Color = ServiceUIStyle.GOLD if active else (ServiceUIStyle.GREEN if in_party else ServiceUIStyle.PURPLE)

    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("0a2031e8")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    card.add_child(row)

    var portrait_frame := PanelContainer.new()
    portrait_frame.custom_minimum_size = Vector2(58, 58)
    portrait_frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent.darkened(0.2), Color("07131f")))
    row.add_child(portrait_frame)
    var portrait := TextureRect.new()
    portrait.custom_minimum_size = Vector2(54, 54)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if data != null and not data.forms.is_empty() and data.forms[0] != null:
        var form: MonsterData = data.forms[0]
        portrait.texture = WalkTextureTools.visible_texture(form.sprite_frames.get_frame_texture(form.idle_animation, 0))
    portrait_frame.add_child(portrait)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 1)
    row.add_child(info)
    var display: String = data.display_name if data != null else str(entry.get("id", "Unknown"))
    var enhance_level: int = roster.enhancement_level(entry)
    var name := ServiceUIStyle.label("%s  +%d" % [display, enhance_level], 17, ServiceUIStyle.TEXT)
    info.add_child(name)
    var progress_data: Dictionary = entry.get("progress", {"level":1, "exp":0}) as Dictionary
    var level: int = clampi(int(progress_data.get("level", 1)), 1, EvolutionRules.MAX_LEVEL)
    var exp: int = maxi(0, int(progress_data.get("exp", 0)))
    var hp: int = int(entry.get("hp", 0))
    var max_hp: int = maxi(1, int(entry.get("max_hp", hp)))
    info.add_child(ServiceUIStyle.label("Lv.%d  •  EXP %d  •  HP %d/%d" % [level, exp, hp, max_hp], 13, ServiceUIStyle.MUTED))
    info.add_child(ServiceUIStyle.label(roster.enhancement_bonus_text(enhance_level), 12, Color("8fd37d")))

    var family_id := StringName(str(entry.get("id", "")))
    var egg_id: String = roster.enhancement_egg_item_id(family_id)
    var egg_owned: int = InventoryManager.count(egg_id) if not egg_id.is_empty() else 0
    if enhance_level < PartnerRoster.MAX_ENHANCEMENT and not egg_id.is_empty():
        var chance: float = roster.enhancement_success_chance(enhance_level) * 100.0
        info.add_child(ServiceUIStyle.label(
            "Digitama %d/%d  •  โอกาส +%d = %.0f%%" % [
                egg_owned, PartnerRoster.ENHANCEMENT_EGG_COST, enhance_level + 1, chance
            ],
            12,
            ServiceUIStyle.GOLD if egg_owned >= PartnerRoster.ENHANCEMENT_EGG_COST else ServiceUIStyle.MUTED
        ))
    elif enhance_level >= PartnerRoster.MAX_ENHANCEMENT:
        info.add_child(ServiceUIStyle.label("MAX ENHANCEMENT +5", 12, ServiceUIStyle.GOLD))

    if active:
        info.add_child(ServiceUIStyle.label("● ACTIVE PARTNER", 12, ServiceUIStyle.GOLD))
    elif in_party:
        info.add_child(ServiceUIStyle.label("พร้อมสลับลงสนาม", 12, ServiceUIStyle.GREEN))
    else:
        info.add_child(ServiceUIStyle.label("เก็บอยู่ใน Archive", 12, ServiceUIStyle.PURPLE))

    var actions := VBoxContainer.new()
    actions.add_theme_constant_override("separation", 6)
    row.add_child(actions)

    var enhance_text: String = "MAX +5" if enhance_level >= PartnerRoster.MAX_ENHANCEMENT else ("กำลังเลือก" if str(entry.get("uid", "")) == _enhance_uid else "เลือกอัปเกรด")
    var enhance := _button(enhance_text, Vector2(118, 42), _select_enhancement_target.bind(str(entry.get("uid", ""))), ServiceUIStyle.GOLD)
    enhance.disabled = enhance_level >= PartnerRoster.MAX_ENHANCEMENT or egg_id.is_empty()
    actions.add_child(enhance)

    var action_text: String = "ฝากคลัง" if in_party else "เข้าปาร์ตี้"
    var action := _button(action_text, Vector2(118, 42), _move_party.bind(index) if in_party else _move_storage.bind(index), accent)
    if in_party:
        action.disabled = roster.members.size() <= 1
    else:
        action.disabled = roster.members.size() >= PartnerRoster.CAPACITY
    actions.add_child(action)
    return card

func _empty_state(title: String, subtitle: String) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(Color("38546b"), Color("07131f")))
    var stack := VBoxContainer.new()
    stack.custom_minimum_size.y = 90
    frame.add_child(stack)
    var a := ServiceUIStyle.label(title, 17, ServiceUIStyle.TEXT)
    a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(a)
    var b := ServiceUIStyle.label(subtitle, 13, ServiceUIStyle.MUTED)
    b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(b)
    return frame

func _button(text: String, minimum: Vector2, callback: Callable, accent: Color) -> DigimonTouchButton:
    var button := DigimonTouchButton.new()
    button.text = text
    button.custom_minimum_size = minimum
    ServiceUIStyle.button(button, accent)
    button.pressed.connect(callback)
    return button

func _select_enhancement_target(uid: String) -> void:
    if uid.is_empty():
        return
    if _enhance_uid != uid:
        _enhance_uid = uid
        _clear_enhancement_staging()
    _refresh()


func _selected_enhancement_target() -> Dictionary:
    if roster == null or _enhance_uid.is_empty():
        return {}
    for index: int in range(roster.members.size()):
        if str(roster.members[index].get("uid", "")) == _enhance_uid:
            return {"entry": roster.members[index], "index": index, "in_party": true}
    for index: int in range(roster.storage.size()):
        if str(roster.storage[index].get("uid", "")) == _enhance_uid:
            return {"entry": roster.storage[index], "index": index, "in_party": false}
    return {}


func _clear_enhancement_staging() -> void:
    for index: int in range(_enhance_staged.size()):
        _enhance_staged[index] = false
    _cancel_enhancement_drag()


func _staged_egg_count() -> int:
    var result: int = 0
    for filled: bool in _enhance_staged:
        if filled:
            result += 1
    return result


func _refresh_enhancement_chamber() -> void:
    if not is_instance_valid(enhancement_panel):
        return

    var target: Dictionary = _selected_enhancement_target()
    if target.is_empty():
        enhancement_title.text = "ENHANCEMENT CHAMBER"
        enhancement_detail.text = "เลือก Digimon จาก Party หรือ Storage เพื่อเริ่ม"
        enhancement_egg_icon.texture = null
        enhancement_egg_count.text = "x0"
        enhancement_egg_source.modulate = Color(1, 1, 1, 0.45)
        for index: int in range(enhancement_slots.size()):
            enhancement_slot_icons[index].texture = null
            enhancement_slot_icons[index].modulate = Color(1, 1, 1, 0.18)
        enhancement_button.text = "UPGRADE"
        enhancement_button.disabled = true
        return

    var entry: Dictionary = target.entry
    var family_id := StringName(str(entry.get("id", "")))
    var family: StarterPartnerData = roster.family(family_id)
    var level: int = roster.enhancement_level(entry)
    var egg_id: String = roster.enhancement_egg_item_id(family_id)
    var egg: ItemData = InventoryManager.catalog.find_item(egg_id)
    var owned: int = InventoryManager.count(egg_id) if not egg_id.is_empty() else 0
    var staged: int = _staged_egg_count()
    var usable: int = mini(owned, PartnerRoster.ENHANCEMENT_EGG_COST)

    # ถ้าของในกระเป๋าลดลงจากระบบอื่น ให้เอาไข่ที่วางเกินจำนวนจริงออกจากช่องท้าย ๆ
    if staged > usable:
        for index: int in range(_enhance_staged.size() - 1, -1, -1):
            if staged <= usable:
                break
            if _enhance_staged[index]:
                _enhance_staged[index] = false
                staged -= 1

    var display: String = family.display_name if family != null else String(family_id)
    enhancement_title.text = "%s  +%d → +%d" % [display, level, mini(PartnerRoster.MAX_ENHANCEMENT, level + 1)]

    if level >= PartnerRoster.MAX_ENHANCEMENT:
        enhancement_detail.text = "MAX ENHANCEMENT +5 • " + roster.enhancement_bonus_text(level)
    else:
        enhancement_detail.text = "ลาก Digitama ลง 5 ช่อง • วาง %d/5 • สำเร็จ %.0f%%\n%s" % [
            staged,
            roster.enhancement_success_chance(level) * 100.0,
            roster.enhancement_bonus_text(level)
        ]

    enhancement_egg_icon.texture = egg.item_texture if egg != null else null
    enhancement_egg_count.text = "x%d" % owned
    enhancement_egg_source.modulate = Color.WHITE if owned > staged and level < PartnerRoster.MAX_ENHANCEMENT else Color(1, 1, 1, 0.42)

    for index: int in range(enhancement_slots.size()):
        var filled: bool = _enhance_staged[index]
        enhancement_slot_icons[index].texture = egg.item_texture if filled and egg != null else null
        enhancement_slot_icons[index].modulate = Color.WHITE if filled else Color(1, 1, 1, 0.18)
        enhancement_slots[index].add_theme_stylebox_override(
            "panel",
            ServiceUIStyle.card(ServiceUIStyle.GOLD if filled else Color("465362"), Color("17140a") if filled else Color("07131f"))
        )

    enhancement_button.text = "UPGRADE +%d" % (level + 1) if level < PartnerRoster.MAX_ENHANCEMENT else "MAX +5"
    enhancement_button.disabled = level >= PartnerRoster.MAX_ENHANCEMENT or staged < PartnerRoster.ENHANCEMENT_EGG_COST or owned < PartnerRoster.ENHANCEMENT_EGG_COST


func _commit_enhancement() -> void:
    var target: Dictionary = _selected_enhancement_target()
    if target.is_empty() or _staged_egg_count() < PartnerRoster.ENHANCEMENT_EGG_COST:
        _show_notice("ลาก Digitama ให้ครบ 5 ช่องก่อนกด UPGRADE")
        return
    _clear_enhancement_staging()
    roster.enhance_member(int(target.index), bool(target.in_party))
    _refresh.call_deferred()


func _point_in_control(control: Control, point: Vector2) -> bool:
    if not is_instance_valid(control) or not control.is_visible_in_tree():
        return false
    var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
    return Rect2(Vector2.ZERO, control.size).has_point(local)


func _egg_source_can_drag() -> bool:
    var target: Dictionary = _selected_enhancement_target()
    if target.is_empty():
        return false
    var entry: Dictionary = target.entry
    var level: int = roster.enhancement_level(entry)
    if level >= PartnerRoster.MAX_ENHANCEMENT:
        return false
    var egg_id: String = roster.enhancement_egg_item_id(StringName(str(entry.get("id", ""))))
    return not egg_id.is_empty() and InventoryManager.count(egg_id) > _staged_egg_count()


func _begin_enhancement_drag(point: Vector2) -> void:
    _drag_start = point
    _drag_started = false


func _update_enhancement_drag(point: Vector2) -> void:
    if not _drag_started and point.distance_to(_drag_start) >= ENHANCE_DRAG_THRESHOLD:
        _drag_started = true
        enhancement_drag_ghost.texture = enhancement_egg_icon.texture
        enhancement_drag_ghost.visible = enhancement_drag_ghost.texture != null
        _release_buttons()
    if _drag_started:
        enhancement_drag_ghost.position = point - enhancement_drag_ghost.size * 0.5


func _finish_enhancement_drag(point: Vector2) -> void:
    if _drag_started:
        for index: int in range(enhancement_slots.size()):
            if not _enhance_staged[index] and _point_in_control(enhancement_slots[index], point):
                _enhance_staged[index] = true
                AudioManager.play_sfx(&"ui_click", -6.0)
                break
    _cancel_enhancement_drag()
    _refresh_enhancement_chamber()


func _cancel_enhancement_drag() -> void:
    _drag_finger = -1
    _drag_mouse = false
    _drag_started = false
    if is_instance_valid(enhancement_drag_ghost):
        enhancement_drag_ghost.visible = false


func _input(event: InputEvent) -> void:
    if not is_open or not is_instance_valid(enhancement_egg_source):
        return

    if event is InputEventScreenTouch:
        if event.pressed and not event.canceled and _drag_finger == -1:
            if _point_in_control(enhancement_egg_source, event.position) and _egg_source_can_drag():
                _drag_finger = event.index
                _begin_enhancement_drag(event.position)
        elif event.index == _drag_finger and (not event.pressed or event.canceled):
            if not event.canceled:
                _finish_enhancement_drag(event.position)
            else:
                _cancel_enhancement_drag()
            if _drag_started:
                get_viewport().set_input_as_handled()

    elif event is InputEventScreenDrag and event.index == _drag_finger:
        _update_enhancement_drag(event.position)
        if _drag_started:
            get_viewport().set_input_as_handled()

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _point_in_control(enhancement_egg_source, event.position) and _egg_source_can_drag():
                _drag_mouse = true
                _begin_enhancement_drag(event.position)
        elif _drag_mouse:
            _finish_enhancement_drag(event.position)
            get_viewport().set_input_as_handled()

    elif event is InputEventMouseMotion and _drag_mouse:
        _update_enhancement_drag(event.position)
        if _drag_started:
            get_viewport().set_input_as_handled()


func _move_party(index: int) -> void:
    roster.move_party_to_storage(index)
    _deferred_refresh()

func _move_storage(index: int) -> void:
    roster.move_storage_to_party(index)
    _deferred_refresh()

func _show_notice(text: String) -> void:
    if is_open:
        notice.text = text
        notice.add_theme_color_override("font_color", ServiceUIStyle.GOLD)

func _deferred_refresh(_a: Variant = null, _b: Variant = null) -> void:
    _refresh.call_deferred()

func _clear_list(list: VBoxContainer) -> void:
    for child: Node in list.get_children():
        list.remove_child(child)
        child.queue_free()

func _release_buttons() -> void:
    for node: Node in root.find_children("*", "", true, false):
        if node is DigimonTouchButton:
            (node as DigimonTouchButton).release_input()
