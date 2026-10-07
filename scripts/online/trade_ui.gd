class_name TradeUI
extends CanvasLayer
## Player-to-player trade UI.
## Server coordinates request/offer/ready/confirm while InventoryManager commits atomically.

signal closed

var hud: MobileHUD
var is_open: bool = false
var root: Control
var panel: PanelContainer
var partner_label: Label
var status_label: Label
var inventory_list: VBoxContainer
var your_offer_list: VBoxContainer
var their_offer_list: VBoxContainer
var bits_edit: LineEdit
var bits_owned_label: Label
var your_bits_label: Label
var their_bits_label: Label
var ready_button: DigimonTouchButton
var confirm_button: DigimonTouchButton
var cancel_button: DigimonTouchButton

var invite_root: Control
var invite_panel: PanelContainer
var invite_detail: Label
var invite_accept: DigimonTouchButton
var invite_decline: DigimonTouchButton

var _snapshot: Dictionary = {}
var _offer_items: Dictionary = {}
var _offer_bits: int = 0
var _pending_invite: Dictionary = {}
var _invite_revision: int = 0

var _owns_pause: bool = false
var _previous_back_quit: bool = true
var _invite_owns_pause: bool = false
var _invite_previous_back_quit: bool = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 92
    _build()
    _build_invite_popup()
    root.hide()
    invite_root.hide()

    OnlineManager.trade_invite_received.connect(_on_trade_invite_received)
    OnlineManager.trade_opened.connect(_on_trade_opened)
    OnlineManager.trade_changed.connect(_on_trade_changed)
    OnlineManager.trade_prepare.connect(_on_trade_prepare)
    OnlineManager.trade_commit.connect(_on_trade_commit)
    OnlineManager.trade_closed.connect(_on_trade_closed)
    OnlineManager.trade_feedback.connect(_on_trade_feedback)
    OnlineManager.connection_changed.connect(_on_connection_changed)
    InventoryManager.changed.connect(_refresh_lists)
    GameManager.bits_changed.connect(func(_value: int) -> void: _refresh_lists())
    get_viewport().size_changed.connect(_layout)

func configure(owner_hud: MobileHUD) -> void:
    hud = owner_hud

func _build() -> void:
    root = Control.new()
    root.name = "TradeRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.theme = ServiceUIStyle.make_theme()
    add_child(root)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.003, 0.012, 0.022, 0.82)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(center)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(Color("44c8e6")))
    center.add_child(panel)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    margin.add_child(stack)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    stack.add_child(header)

    var title := ServiceUIStyle.label("PLAYER TRADE", 26, Color("6fe8ff"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    partner_label = ServiceUIStyle.label("กับ —", 17, ServiceUIStyle.TEXT)
    partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    partner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(partner_label)

    cancel_button = _button("ยกเลิก ×", Vector2(120, 48))
    cancel_button.pressed.connect(_cancel_trade)
    header.add_child(cancel_button)

    status_label = ServiceUIStyle.label(
        "เลือกของที่จะเสนอ • ทั้งสองฝ่ายต้อง Ready และ Confirm",
        13,
        ServiceUIStyle.MUTED
    )
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(status_label)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 10)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(columns)

    var inventory_card := _section_card("กระเป๋าของคุณ", Color("57d6ff"))
    inventory_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(inventory_card)
    inventory_list = _scroll_list(inventory_card, 275.0)

    var your_card := _section_card("ข้อเสนอของคุณ", Color("6fe8b0"))
    your_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(your_card)
    var your_body := your_card.get_meta("body") as VBoxContainer
    your_offer_list = _plain_offer_list(your_body)
    _build_bits_editor(your_body)

    var their_card := _section_card("ข้อเสนออีกฝ่าย", Color("c79cff"))
    their_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(their_card)
    var their_body := their_card.get_meta("body") as VBoxContainer
    their_offer_list = _plain_offer_list(their_body)
    their_bits_label = ServiceUIStyle.label("Bits: 0", 15, ServiceUIStyle.GOLD)
    their_bits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    their_body.add_child(their_bits_label)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 12)
    stack.add_child(actions)

    ready_button = _button("READY", Vector2(180, 54))
    ready_button.pressed.connect(_toggle_ready)
    actions.add_child(ready_button)

    confirm_button = _button("CONFIRM", Vector2(180, 54))
    confirm_button.disabled = true
    confirm_button.pressed.connect(_confirm_trade)
    actions.add_child(confirm_button)

func _section_card(title_text: String, accent: Color) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(285, 340)
    card.add_theme_stylebox_override("panel", ServiceUIStyle.card(accent, Color("071624ee")))

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 10)
    card.add_child(margin)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 7)
    margin.add_child(body)
    body.add_child(ServiceUIStyle.label(title_text, 18, accent))
    card.set_meta("body", body)
    return card

func _scroll_list(card: PanelContainer, minimum_height: float) -> VBoxContainer:
    var body := card.get_meta("body") as VBoxContainer
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.scroll_deadzone = 8
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = minimum_height
    body.add_child(scroll)

    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    list.add_theme_constant_override("separation", 6)
    scroll.add_child(list)
    return list

func _plain_offer_list(body: VBoxContainer) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.scroll_deadzone = 8
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 220
    body.add_child(scroll)

    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    list.add_theme_constant_override("separation", 6)
    scroll.add_child(list)
    return list

func _build_bits_editor(body: VBoxContainer) -> void:
    var bits_frame := PanelContainer.new()
    bits_frame.add_theme_stylebox_override("panel", ServiceUIStyle.card(ServiceUIStyle.GOLD, Color("241d0a")))
    body.add_child(bits_frame)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    bits_frame.add_child(row)

    bits_edit = LineEdit.new()
    bits_edit.placeholder_text = "Bits"
    bits_edit.max_length = 10
    bits_edit.custom_minimum_size = Vector2(110, 44)
    bits_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bits_edit.virtual_keyboard_enabled = true
    row.add_child(bits_edit)

    var set_bits := _button("ตั้ง", Vector2(64, 44))
    set_bits.pressed.connect(_set_bits_offer)
    row.add_child(set_bits)

    bits_owned_label = ServiceUIStyle.label("", 12, ServiceUIStyle.MUTED)
    body.add_child(bits_owned_label)
    your_bits_label = ServiceUIStyle.label("เสนอ Bits: 0", 14, ServiceUIStyle.GOLD)
    body.add_child(your_bits_label)

func _build_invite_popup() -> void:
    invite_root = Control.new()
    invite_root.name = "TradeInvitePopup"
    invite_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    invite_root.theme = ServiceUIStyle.make_theme()
    invite_root.z_index = 300
    add_child(invite_root)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.002, 0.008, 0.016, 0.76)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    invite_root.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    invite_root.add_child(center)

    invite_panel = PanelContainer.new()
    invite_panel.add_theme_stylebox_override("panel", ServiceUIStyle.panel(Color("44c8e6")))
    center.add_child(invite_panel)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    invite_panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 14)
    margin.add_child(stack)

    var title := ServiceUIStyle.label("คำขอแลกเปลี่ยน", 24, Color("6fe8ff"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(title)

    invite_detail = ServiceUIStyle.label("", 17, ServiceUIStyle.TEXT)
    invite_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    invite_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(invite_detail)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 12)
    stack.add_child(actions)

    invite_decline = _button("ปฏิเสธ", Vector2(150, 54))
    invite_decline.pressed.connect(_respond_invite.bind(false))
    actions.add_child(invite_decline)

    invite_accept = _button("ยอมรับ", Vector2(150, 54))
    invite_accept.pressed.connect(_respond_invite.bind(true))
    actions.add_child(invite_accept)

func _button(caption: String, minimum: Vector2) -> DigimonTouchButton:
    var button := DigimonTouchButton.new()
    button.text = caption
    button.custom_minimum_size = minimum
    button.add_theme_font_size_override("font_size", 15)
    return button

func _layout() -> void:
    if is_instance_valid(panel):
        panel.custom_minimum_size = Vector2(980, 600)
        ResponsiveUI.fit_centered(panel, get_viewport(), 10.0)
    if is_instance_valid(invite_panel):
        invite_panel.custom_minimum_size = Vector2(500, 250)
        ResponsiveUI.fit_centered(invite_panel, get_viewport(), 16.0)

func _open_session(snapshot: Dictionary) -> void:
    _hide_invite_popup()
    _snapshot = snapshot.duplicate(true)
    _sync_offer_from_snapshot()

    if not is_open:
        if is_instance_valid(hud):
            hud.release_for_equipment()
        _owns_pause = not get_tree().paused
        if _owns_pause:
            _previous_back_quit = get_tree().quit_on_go_back
            get_tree().quit_on_go_back = false
            get_tree().paused = true
        is_open = true
        root.show()
    _layout()
    _refresh_lists()

func _close_session() -> void:
    if not is_open:
        return
    root.hide()
    is_open = false
    _snapshot.clear()
    _offer_items.clear()
    _offer_bits = 0
    bits_edit.clear()
    _restore_pause()
    closed.emit()

func _restore_pause() -> void:
    if _owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _previous_back_quit
    _owns_pause = false

func _on_trade_invite_received(invite: Dictionary) -> void:
    if is_open or not OnlineManager.trade.is_empty():
        OnlineManager.respond_trade_invite(str(invite.get("invite_id", "")), false)
        return

    _pending_invite = invite.duplicate(true)
    _invite_revision += 1
    var revision: int = _invite_revision
    var seconds: int = clampi(int(invite.get("expires_in", 30)), 5, 60)
    invite_detail.text = "%s ต้องการแลกเปลี่ยนกับคุณ\n\nคำขอหมดอายุใน %d วินาที" % [
        str(invite.get("from_name", "ผู้เล่น")),
        seconds
    ]

    _invite_owns_pause = not get_tree().paused
    if _invite_owns_pause:
        _invite_previous_back_quit = get_tree().quit_on_go_back
        get_tree().quit_on_go_back = false
        get_tree().paused = true
    invite_root.show()
    _layout()
    _expire_invite(seconds, revision)

func _expire_invite(seconds: int, revision: int) -> void:
    await get_tree().create_timer(float(seconds), true).timeout
    if revision != _invite_revision or _pending_invite.is_empty():
        return
    _pending_invite.clear()
    _hide_invite_popup()
    if is_instance_valid(hud):
        hud._show_message("คำขอแลกเปลี่ยนหมดอายุแล้ว")

func _respond_invite(accept: bool) -> void:
    if _pending_invite.is_empty():
        _hide_invite_popup()
        return
    var invite_id: String = str(_pending_invite.get("invite_id", ""))
    _pending_invite.clear()
    _invite_revision += 1
    _hide_invite_popup()
    OnlineManager.respond_trade_invite(invite_id, accept)

func _hide_invite_popup() -> void:
    if is_instance_valid(invite_accept):
        invite_accept.release_input()
    if is_instance_valid(invite_decline):
        invite_decline.release_input()
    if is_instance_valid(invite_root):
        invite_root.hide()
    if _invite_owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _invite_previous_back_quit
    _invite_owns_pause = false

func _on_trade_opened(snapshot: Dictionary) -> void:
    _open_session(snapshot)

func _on_trade_changed(snapshot: Dictionary) -> void:
    _snapshot = snapshot.duplicate(true)
    _sync_offer_from_snapshot()
    if not is_open:
        _open_session(snapshot)
    else:
        _refresh_lists()

func _sync_offer_from_snapshot() -> void:
    _offer_items.clear()
    var offer: Variant = _snapshot.get("your_offer", {})
    if offer is Dictionary:
        var items_value: Variant = (offer as Dictionary).get("items", [])
        if items_value is Array:
            for value: Variant in items_value:
                if value is Dictionary:
                    var entry := value as Dictionary
                    var item_id: String = str(entry.get("id", ""))
                    var quantity: int = int(entry.get("quantity", 0))
                    if not item_id.is_empty() and quantity > 0:
                        _offer_items[item_id] = quantity
        _offer_bits = maxi(0, int((offer as Dictionary).get("bits", 0)))

func _refresh_lists() -> void:
    if not is_instance_valid(root):
        return

    var partner: Variant = _snapshot.get("partner", {})
    partner_label.text = "กับ %s" % str((partner as Dictionary).get("name", "—")) if partner is Dictionary else "กับ —"

    _clear_children(inventory_list)
    _clear_children(your_offer_list)
    _clear_children(their_offer_list)

    var locked: bool = bool(_snapshot.get("your_ready", false))
    var entries: Array[Dictionary] = InventoryManager.items()
    var tradable_count: int = 0
    for entry: Dictionary in entries:
        var item: ItemData = entry.item
        if item == null or not InventoryManager.is_tradeable(item):
            continue
        tradable_count += 1
        inventory_list.add_child(_inventory_row(item, int(entry.quantity), locked))
    if tradable_count == 0:
        inventory_list.add_child(ServiceUIStyle.label("ไม่มีไอเทมที่แลกได้", 13, ServiceUIStyle.MUTED))

    for item_id: Variant in _offer_items.keys():
        var item: ItemData = InventoryManager.catalog.find_item(str(item_id))
        if item != null:
            your_offer_list.add_child(_your_offer_row(item, int(_offer_items[item_id]), locked))
    if _offer_items.is_empty():
        your_offer_list.add_child(ServiceUIStyle.label("ยังไม่ได้เสนอไอเทม", 13, ServiceUIStyle.MUTED))

    var their_offer: Variant = _snapshot.get("their_offer", {})
    var their_bits: int = 0
    var their_items: Variant = []
    if their_offer is Dictionary:
        their_bits = maxi(0, int((their_offer as Dictionary).get("bits", 0)))
        their_items = (their_offer as Dictionary).get("items", [])
    var other_count: int = 0
    if their_items is Array:
        for value: Variant in their_items:
            if not (value is Dictionary):
                continue
            var offer_entry := value as Dictionary
            var item: ItemData = InventoryManager.catalog.find_item(str(offer_entry.get("id", "")))
            if item == null:
                continue
            other_count += 1
            their_offer_list.add_child(_readonly_offer_row(item, int(offer_entry.get("quantity", 0))))
    if other_count == 0:
        their_offer_list.add_child(ServiceUIStyle.label("อีกฝ่ายยังไม่ได้เสนอไอเทม", 13, ServiceUIStyle.MUTED))

    bits_owned_label.text = "มี %d Bits" % GameManager.bits
    your_bits_label.text = "เสนอ Bits: %d" % _offer_bits
    their_bits_label.text = "Bits: %d" % their_bits
    bits_edit.editable = not locked

    var your_ready: bool = bool(_snapshot.get("your_ready", false))
    var their_ready: bool = bool(_snapshot.get("their_ready", false))
    var your_confirmed: bool = bool(_snapshot.get("your_confirmed", false))
    var their_confirmed: bool = bool(_snapshot.get("their_confirmed", false))

    ready_button.text = "ยกเลิก READY" if your_ready else "READY"
    confirm_button.disabled = not (your_ready and their_ready) or your_confirmed
    confirm_button.text = "ยืนยันแล้ว" if your_confirmed else "CONFIRM"

    if your_ready and their_ready:
        status_label.text = "ทั้งสองฝ่าย READY • %s" % ("รออีกฝ่าย CONFIRM" if your_confirmed and not their_confirmed else "ตรวจข้อเสนอแล้วกด CONFIRM")
    elif your_ready:
        status_label.text = "คุณ READY แล้ว • รออีกฝ่าย"
    elif their_ready:
        status_label.text = "อีกฝ่าย READY แล้ว • ตรวจข้อเสนอและกด READY"
    else:
        status_label.text = "แก้ข้อเสนอได้ • เมื่อพร้อมให้ทั้งสองฝ่ายกด READY"

func _inventory_row(item: ItemData, owned: int, locked: bool) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)

    var icon := TextureRect.new()
    icon.texture = item.item_texture
    icon.custom_minimum_size = Vector2(38, 38)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)

    var label := ServiceUIStyle.label("%s  x%d" % [item.item_name, owned], 13, ServiceUIStyle.TEXT)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var offered: int = int(_offer_items.get(item.item_id, 0))
    var add := _button("+1", Vector2(54, 40))
    add.disabled = locked or offered >= owned or _offer_items.size() >= 8 and offered <= 0
    add.pressed.connect(_change_offer.bind(item.item_id, 1))
    row.add_child(add)
    return row

func _your_offer_row(item: ItemData, quantity: int, locked: bool) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    var label := ServiceUIStyle.label("%s  x%d" % [item.item_name, quantity], 13, ServiceUIStyle.TEXT)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var minus := _button("−", Vector2(42, 38))
    minus.disabled = locked
    minus.pressed.connect(_change_offer.bind(item.item_id, -1))
    row.add_child(minus)

    var plus := _button("+", Vector2(42, 38))
    plus.disabled = locked or quantity >= InventoryManager.count(item.item_id)
    plus.pressed.connect(_change_offer.bind(item.item_id, 1))
    row.add_child(plus)
    return row

func _readonly_offer_row(item: ItemData, quantity: int) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    var icon := TextureRect.new()
    icon.texture = item.item_texture
    icon.custom_minimum_size = Vector2(36, 36)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)
    var label := ServiceUIStyle.label("%s  x%d" % [item.item_name, quantity], 13, ServiceUIStyle.TEXT)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    return row

func _clear_children(node: Node) -> void:
    if node == null:
        return
    for child: Node in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _change_offer(item_id: String, delta: int) -> void:
    if bool(_snapshot.get("your_ready", false)):
        return
    var owned: int = InventoryManager.count(item_id)
    var next: int = clampi(int(_offer_items.get(item_id, 0)) + delta, 0, owned)
    if next <= 0:
        _offer_items.erase(item_id)
    else:
        if not _offer_items.has(item_id) and _offer_items.size() >= 8:
            if is_instance_valid(hud):
                hud._show_message("เสนอไอเทมได้สูงสุด 8 ชนิด")
            return
        _offer_items[item_id] = next
    _send_offer()

func _set_bits_offer() -> void:
    if bool(_snapshot.get("your_ready", false)):
        return
    var value: int = 0
    if bits_edit.text.is_valid_int():
        value = int(bits_edit.text)
    _offer_bits = clampi(value, 0, GameManager.bits)
    bits_edit.text = str(_offer_bits)
    bits_edit.release_focus()
    _send_offer()

func _send_offer() -> void:
    var items: Array[Dictionary] = []
    for item_id: Variant in _offer_items.keys():
        var quantity: int = int(_offer_items[item_id])
        if quantity > 0:
            items.append({"id": str(item_id), "quantity": quantity})
    OnlineManager.update_trade_offer(items, _offer_bits)

func _toggle_ready() -> void:
    OnlineManager.set_trade_ready(not bool(_snapshot.get("your_ready", false)))

func _confirm_trade() -> void:
    if confirm_button.disabled:
        return
    OnlineManager.confirm_trade()

func _cancel_trade() -> void:
    OnlineManager.cancel_trade()

func _on_trade_prepare(payload: Dictionary) -> void:
    if not is_open:
        OnlineManager.send_trade_prepare_result(str(payload.get("trade_id", "")), false, "หน้าต่าง Trade ถูกปิด")
        return
    var outgoing: Dictionary = payload.get("outgoing", {}) as Dictionary
    var incoming: Dictionary = payload.get("incoming", {}) as Dictionary
    var error: String = InventoryManager.validate_trade(
        outgoing.get("items", []) as Array,
        incoming.get("items", []) as Array,
        int(outgoing.get("bits", 0)),
        int(incoming.get("bits", 0))
    )
    OnlineManager.send_trade_prepare_result(
        str(payload.get("trade_id", "")),
        error.is_empty(),
        error
    )
    status_label.text = "ตรวจสอบรายการผ่าน • รอ Server Commit" if error.is_empty() else error

func _on_trade_commit(payload: Dictionary) -> void:
    var outgoing: Dictionary = payload.get("outgoing", {}) as Dictionary
    var incoming: Dictionary = payload.get("incoming", {}) as Dictionary
    var ok: bool = InventoryManager.apply_trade(
        outgoing.get("items", []) as Array,
        incoming.get("items", []) as Array,
        int(outgoing.get("bits", 0)),
        int(incoming.get("bits", 0))
    )
    if not ok:
        push_error("TradeUI: trade commit failed after prepare validation")
        if is_instance_valid(hud):
            hud._show_message("เกิดข้อผิดพลาดขณะบันทึก Trade")

func _on_trade_closed(message: String, success: bool) -> void:
    if is_open:
        _close_session()
    if is_instance_valid(hud) and not message.is_empty():
        hud._show_message(("✓ " if success else "⚠ ") + message)

func _on_trade_feedback(message: String, _ok: bool) -> void:
    if is_open and not message.is_empty():
        status_label.text = message
    if is_instance_valid(hud) and not message.is_empty():
        hud._show_message(message)

func _on_connection_changed(connected: bool, _message: String) -> void:
    if not connected:
        _pending_invite.clear()
        _hide_invite_popup()
        if is_open:
            _close_session()

func _notification(what: int) -> void:
    if what != NOTIFICATION_WM_GO_BACK_REQUEST:
        return
    if is_instance_valid(invite_root) and invite_root.visible:
        _respond_invite(false)
    elif is_open:
        _cancel_trade()

func _unhandled_input(event: InputEvent) -> void:
    if not is_open and not (is_instance_valid(invite_root) and invite_root.visible):
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if invite_root.visible:
            _respond_invite(false)
        else:
            _cancel_trade()
    get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    _restore_pause()
    if _invite_owns_pause and is_inside_tree():
        get_tree().paused = false
        get_tree().quit_on_go_back = _invite_previous_back_quit
