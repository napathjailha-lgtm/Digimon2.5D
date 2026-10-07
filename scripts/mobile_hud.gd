class_name MobileHUD
extends CanvasLayer
## HUD รับคำสั่ง/แสดงค่าจริง ไม่เก็บสำเนาสเตตัสหรือเปลี่ยน MonsterData ตอนสลับหน้า
@export var tamer: Tamer
@export var partner: PartnerMonster
@onready var joystick: MobileJoystick = $Root/Joystick
@onready var combat: Control = $Root/Safe/Layout/Combat
@onready var attack_button: TouchCommand = $Root/Safe/Layout/Combat/Attack
@onready var evolve_button: TouchCommand = $Root/Safe/Layout/Combat/Evolve
@onready var auto_button: TouchCommand = $Root/Safe/Layout/Combat/Auto
@onready var recover_button: TouchCommand = $Root/Safe/Layout/Combat/Recover
@onready var cycle_button: TouchCommand = $Root/Safe/Layout/Combat/Cycle
@onready var skill_panel: FormSkillPanel = $Root/Safe/Layout/Combat/SkillPanel
@onready var page_label: Label = $Root/Safe/Layout/Combat/PageLabel
@onready var party_status: HybridVitals = $Root/Safe/Layout/Vitals
@onready var quest_button: TouchCommand = $Root/Safe/Layout/TopLeft/QuestShortcut
@onready var party_panel: HybridPartyPanel = $Root/Safe/Layout/PartyPanel
@onready var inventory_shortcut: TouchCommand = $Root/Safe/Layout/TopLeft/MapRow/Shortcuts/Inventory
@onready var settings_shortcut: TouchCommand = $Root/Safe/Layout/TopLeft/MapRow/Shortcuts/Settings
@onready var menu: CollapsibleHudMenu = $Root/Safe/Layout/Menu
@onready var message: Label = $Root/Message
const CUTSCENE_SCENE: PackedScene = preload("res://scenes/digivolve_cutscene.tscn")
var active_cutscene: DigivolveCutscene
var preferences := HudPreferences.new()
var equipment_button: EquipmentButton
var inventory_button: EquipmentButton
var stats_button: TouchCommand
var stats_panel: Label
var equipment_screen: EquipmentScreen
var inventory_screen: InventoryUI
var smart_panel: HudSmartPanel
var digimon_screen: DigimonStatusScreen
var guild_screen: GuildUI
var trade_screen: TradeUI
var _selected_remote_peer_id: String = ""
var _selected_remote_name: String = ""
var _selected_remote_guild: String = ""
var exp_strip: ProgressBar
var chat_panel: MobileChatPanel
var minimap: MobileMinimap
var target_card: Panel
var online_badge: PanelContainer
var online_count_label: Label
var _online_compact: bool = false
var _target_bar: SmoothTextureBar
var _target_instance_id: int = 0
var critical_fx: CriticalScreenFX
var _target_name: Label
var _tracker: QuestTracker
var _target_refresh_left: float = 0.0
var _message_left: float = 0.0
var chat_editing: bool = false
var party_roster: PartnerRoster
var fusion_manager: FusionManager
var _rotate_overlay: ColorRect
var quick_bar: HBoxContainer
var quick_buttons: Array[HybridCommand] = []
var safe_inset_override := Vector4(-1, -1, -1, -1) # ใช้ทดสอบรอยบาก; ค่า -1 ให้อ่าน OS จริง

func _ready() -> void:
    layer = 10 # อยู่เหนือ CriticalScreenFX ชั้น 5 และใต้ modal ชั้น 80+
    HybridPlatform.configure_web_touch_surface()
    preferences.load_data()
    tamer.joystick = joystick
    party_roster = PartnerRoster.new()
    party_roster.name = "PartnerRoster"
    tamer.add_child(party_roster)
    tamer.party_roster = party_roster
    party_roster.configure(tamer)
    fusion_manager = FusionManager.new()
    fusion_manager.name = "FusionManager"
    tamer.add_child(fusion_manager)
    fusion_manager.configure(tamer, partner, party_roster)
    fusion_manager.availability_changed.connect(func(_available: bool): _refresh_combat_controls())
    fusion_manager.fusion_changed.connect(func(_active: bool): _refresh_combat_controls())
    party_panel.configure(party_roster)
    party_panel.switch_requested.connect(_switch_party)
    party_panel.empty_pressed.connect(func(): _show_message("ฟักไข่ในกระเป๋าเพื่อเพิ่มคู่หูในทีม"))
    party_roster.feedback.connect(_show_message)
    party_roster.switched.connect(_on_party_switched)
    tamer.digivolve_requested.connect(_request_digivolve)
    partner.form_changed.connect(_on_form_changed)
    tamer.target_changed.connect(_refresh_target)
    tamer.battle_permission_changed.connect(_on_battle_permission)
    for source_signal: Signal in [tamer.hp_changed, tamer.mp_changed, tamer.survival_changed, partner.mp_changed, partner.hp_changed, partner.state_changed, tamer.progress.progress_changed, partner.progress.progress_changed]:
        source_signal.connect(_refresh_bars)
    tamer.progress.leveled_up.connect(_on_tamer_level)
    partner.progress.leveled_up.connect(_on_partner_level)
    tamer.auto_navigation_failed.connect(_show_message)
    partner.feedback.connect(_show_message)
    skill_panel.page_changed.connect(_on_page_changed)
    skill_panel.configure(partner, tamer)
    skill_panel.skill_requested.connect(tamer.command_skill)
    # form_skill_requested เก็บ signal ไว้เพื่อ compatibility แต่ UI ใหม่ไม่ emit สกิลต่างร่าง
    skill_panel.form_skill_requested.connect(tamer.command_form_skill)
    cycle_button.set_caption("Fusion [J]")
    cycle_button.pressed.connect(fusion_manager.request_fusion)
    attack_button.pressed.connect(tamer.command_attack)
    evolve_button.pressed.connect(tamer.command_digivolve)
    auto_button.pressed.connect(_toggle_auto)
    recover_button.pressed.connect(partner.recover)
    menu.action_requested.connect(_menu_action)
    inventory_shortcut.pressed.connect(func(): _menu_action(&"inventory"))
    settings_shortcut.pressed.connect(_open_settings)
    menu.expanded_changed.connect(func(_expanded: bool): _sync_skill_input())
    menu.buttons[&"character"].set_meta("unavailable", not GameManager.gameplay_active)
    equipment_button = menu.buttons[&"equipment"]
    inventory_button = menu.buttons[&"inventory"]
    stats_button = menu.buttons[&"digimon"]
    equipment_screen = EquipmentScreen.new()
    add_child(equipment_screen)
    equipment_screen.configure(tamer, self)
    # แจ้งของสวมใส่ที่ดรอปแม้ไม่ได้เปิดหน้า Equipment
    tamer.equipment.feedback.connect(_show_message)
    inventory_screen = preload("res://scenes/inventory_ui.tscn").instantiate() as InventoryUI
    add_child(inventory_screen)
    inventory_screen.configure(tamer, self)
    smart_panel = preload("res://scenes/hud_smart_panel.tscn").instantiate() as HudSmartPanel
    smart_panel.hud = self
    add_child(smart_panel)
    smart_panel.root.theme = $Root.theme
    smart_panel.action_requested.connect(_modal_action)
    smart_panel.closed.connect(_sync_skill_input)
    stats_panel = smart_panel.details
    digimon_screen = DigimonStatusScreen.new()
    add_child(digimon_screen)
    digimon_screen.configure(self)
    guild_screen = GuildUI.new()
    guild_screen.name = "GuildUI"
    add_child(guild_screen)
    guild_screen.configure(self)
    trade_screen = TradeUI.new()
    trade_screen.name = "TradeUI"
    add_child(trade_screen)
    trade_screen.configure(self)
    trade_screen.closed.connect(_sync_skill_input)
    OnlineManager.remote_interaction_requested.connect(_on_remote_player_interaction)
    OnlineManager.guild_feedback.connect(_on_guild_feedback_toast)
    InventoryManager.feedback.connect(_show_message)
    InventoryManager.item_picked_up.connect(_on_item_picked_up)
    InventoryManager.changed.connect(_refresh_quick_items)
    _build_extras()
    _build_quick_item_bar()
    _build_mobile_web_overlay()
    critical_fx = CriticalScreenFX.new()
    critical_fx.name = "CriticalScreenFX"
    add_child(critical_fx)
    QuestManager.quest_updated.connect(_refresh_quest)
    _refresh_quest(&"")
    get_viewport().size_changed.connect(_layout)
    _layout()
    _refresh_bars()

func _build_extras() -> void:
    # EXP เป็นเส้น 4px ของ Tamer; EXP คู่หูดูได้ใน Status ไม่เพิ่มหลอดเต็มบนสนาม
    exp_strip = ProgressBar.new()
    exp_strip.name = "EXPStrip"
    exp_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    exp_strip.show_percentage = false
    exp_strip.add_theme_stylebox_override("background", ClassicUIStyle.frame(Color("132132"), Color("132132")))
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("ecc24c")
    exp_strip.add_theme_stylebox_override("fill", fill)
    $Root.add_child(exp_strip)
    chat_panel = MobileChatPanel.new()
    chat_panel.name = "ChatPanel"
    chat_panel.z_index = 50
    chat_panel.anchor_top = 1.0
    chat_panel.anchor_bottom = 1.0
    $Root.add_child(chat_panel)
    chat_panel.editing_changed.connect(_on_chat_editing)
    chat_panel.folded_changed.connect(_on_chat_folded)
    chat_panel.set_collapsed(preferences.chat_collapsed)
    minimap = $Root/Safe/Layout/TopLeft/MapRow/Minimap as RoundMinimap
    var world: Node = tamer.get_parent().get_parent()
    minimap.configure(tamer, partner, world.get("background_texture"))
    if world.get("world_extent") is Vector2:
        minimap.world_extent = world.get("world_extent")
    if bool(world.get("open_world_enabled")):
        minimap.world_layout = (world.get_node("OpenWorldEnvironment") as OpenWorldEnvironment).layout
    _build_target_card()
    _build_online_badge()
    _tracker = preload("res://scenes/quest_tracker.tscn").instantiate() as QuestTracker
    _tracker.tamer = tamer
    _tracker.navigation_requested.connect(tamer.start_auto_navigation)
    _tracker.feedback.connect(_show_message)
    $Root.add_child(_tracker)
    _tracker.hide()
    quest_button.set_caption("เควสต์หลัก · แตะดูรายละเอียด/นำทาง")
    quest_button.pressed.connect(_open_quest_details)

func _build_online_badge() -> void:
    online_badge = PanelContainer.new()
    online_badge.name = "OnlineCountBadge"
    online_badge.custom_minimum_size = Vector2(96, 64)
    online_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    online_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    online_badge.z_index = 40

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.08, 0.11, 0.90)
    style.border_color = Color(0.20, 0.75, 0.52, 0.88)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    online_badge.add_theme_stylebox_override("panel", style)

    # วางต่อจากกลุ่ม Inventory/Settings ใน MapRow จึงชิดด้านข้างกระเป๋า
    # และไม่ลอยทับมุมขวาบนของหน้าจออีก
    $Root/Safe/Layout/TopLeft/MapRow.add_child(online_badge)

    online_count_label = Label.new()
    online_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    online_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    online_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    online_count_label.add_theme_font_size_override("font_size", 12)
    online_count_label.add_theme_color_override("font_color", Color("a9f0c8"))
    online_badge.add_child(online_count_label)

    if not OnlineManager.online_count_changed.is_connected(_on_online_count_changed):
        OnlineManager.online_count_changed.connect(_on_online_count_changed)
    if not OnlineManager.connection_changed.is_connected(_on_online_connection_badge):
        OnlineManager.connection_changed.connect(_on_online_connection_badge)
    _refresh_online_badge()


func _on_online_count_changed(_total: int, _zone_count: int) -> void:
    _refresh_online_badge()


func _on_online_connection_badge(_connected: bool, _message: String) -> void:
    _refresh_online_badge()


func _refresh_online_badge() -> void:
    if not is_instance_valid(online_count_label):
        return
    if not OnlineManager.connected:
        online_count_label.text = "○ OFFLINE"
        online_count_label.add_theme_color_override("font_color", Color("9ca8b3"))
        online_badge.tooltip_text = "ไม่ได้เชื่อมต่อ Online Server"
        return

    online_count_label.add_theme_color_override("font_color", Color("a9f0c8"))
    online_count_label.text = "● ONLINE\n%d" % OnlineManager.total_online
    online_badge.tooltip_text = "ผู้เล่นออนไลน์ทั้งหมด %d • อยู่ในแมพเดียวกัน %d" % [OnlineManager.total_online, OnlineManager.zone_online]


func _open_quest_details() -> void:
    if not is_instance_valid(_tracker):
        return
    _tracker.show_details()
    _tracker.request_navigation()


func _build_quick_item_bar() -> void:
    quick_bar = HBoxContainer.new()
    quick_bar.name = "QuickItemBar"
    quick_bar.anchor_left = 0.5
    quick_bar.anchor_right = 0.5
    quick_bar.anchor_top = 1.0
    quick_bar.anchor_bottom = 1.0
    quick_bar.add_theme_constant_override("separation", 6)
    quick_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $Root.add_child(quick_bar)
    for slot: int in range(4):
        var button := HybridCommand.new()
        button.custom_minimum_size = Vector2(58, 58)
        button.size = Vector2(58, 58)
        button.illustrated = true
        button.pressed.connect(_use_quick_slot.bind(slot))
        quick_bar.add_child(button)
        quick_buttons.append(button)
    _refresh_quick_items()

func _quick_item_candidates() -> Array[String]:
    var result: Array[String] = []
    for item: ItemData in InventoryManager.catalog.items:
        if item.item_type == ItemData.ItemType.CONSUMABLE:
            result.append(item.item_id)
    return result

func _quick_item(slot: int) -> ItemData:
    if slot < 0 or slot >= preferences.quick_item_slots.size():
        return null
    return InventoryManager.catalog.find_item(preferences.quick_item_slots[slot])

func _refresh_quick_items(_a: Variant = null, _b: Variant = null) -> void:
    if quick_buttons.size() != 4 or InventoryManager.catalog == null:
        return
    for slot: int in range(4):
        var button: HybridCommand = quick_buttons[slot]
        var item: ItemData = _quick_item(slot)
        var key_number: int = slot + 5
        if item == null:
            button.icon = null
            button.empty_slot = true
            button.locked = true
            button.set_caption("%d · ว่าง" % key_number)
        else:
            var count: int = InventoryManager.count(item.item_id)
            button.icon = item.item_texture
            button.empty_slot = false
            button.locked = count <= 0 or not InventoryManager.can_use_item(item)
            button.set_caption("%d · %d" % [key_number, count])
        button.queue_redraw()

func _use_quick_slot(slot: int) -> void:
    if chat_editing or menu.expanded or get_tree().paused or partner.evolution_busy:
        return
    var item: ItemData = _quick_item(slot)
    if item == null:
        _show_message("ช่องลัด %d ยังไม่ได้ตั้งไอเทม" % (slot + 5))
        return
    if InventoryManager.count(item.item_id) <= 0:
        _show_message("%s หมดแล้ว" % item.item_name)
        return
    InventoryManager.use_item_by_id(item.item_id)
    _refresh_quick_items()

func _cycle_quick_slot(slot: int) -> void:
    var candidates: Array[String] = _quick_item_candidates()
    if candidates.is_empty() or slot < 0 or slot >= 4:
        return
    var current: String = preferences.quick_item_slots[slot]
    var index: int = candidates.find(current)
    preferences.quick_item_slots[slot] = candidates[(index + 1) % candidates.size()]
    _save_preferences()
    _refresh_quick_items()

func _quick_slot_label(slot: int) -> String:
    var item: ItemData = _quick_item(slot)
    return "ช่องลัด %d: %s" % [slot + 5, "ว่าง" if item == null else item.item_name]


func _layout() -> void:
    # Web-mobile ใช้ viewport จริงของ browser และปรับ HUD ให้พื้นที่นิ้วโป้งไม่ชนกัน
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var inset: Vector4 = safe_inset_override if safe_inset_override.x >= 0 else HudSafeArea.for_viewport(get_viewport())
    var margin: MarginContainer = $Root/Safe
    for index: int in range(4):
        margin.add_theme_constant_override(["margin_left","margin_top","margin_right","margin_bottom"][index], int(inset[index]))

    var safe_width: float = maxf(1.0, viewport_size.x - inset.x - inset.z)
    var safe_height: float = maxf(1.0, viewport_size.y - inset.y - inset.w)
    var touch_mode: bool = HybridPlatform.use_mobile_layout(get_viewport())
    var compact_touch: bool = touch_mode and (safe_width < 1050.0 or safe_height < 620.0)

    if is_instance_valid(online_badge):
        _online_compact = true
        online_badge.custom_minimum_size = Vector2(82, 58) if compact_touch else Vector2(96, 64)
        online_count_label.add_theme_font_size_override("font_size", 11 if compact_touch else 12)
        _refresh_online_badge()

    # วงสกิลเดิมมีฐาน 374x330; จอมือถือเว็บขนาดเล็กย่อทั้งกลุ่มโดยไม่เปลี่ยน hitbox ภายใน
    var combat_scale: float = preferences.combat_scale
    if compact_touch:
        combat_scale *= 0.86
    if touch_mode and safe_width < 820.0:
        combat_scale *= 0.82
    combat_scale = clampf(combat_scale, 0.68, 1.25)
    combat.scale = Vector2.ONE * combat_scale

    # Joystick ปรับตามด้านสั้นของ viewport แทนการตรึง 200px ทุกเครื่อง
    var joystick_side: float = 200.0
    if touch_mode:
        joystick_side = clampf(minf(safe_width * 0.23, safe_height * 0.34), 150.0, 200.0)
    joystick.radius = joystick_side * 0.375
    joystick.offset_left = inset.x + 8.0
    joystick.offset_right = joystick.offset_left + joystick_side
    joystick.offset_bottom = -inset.w
    joystick.offset_top = joystick.offset_bottom - joystick_side

    # กันพื้นที่ Joystick และวงสกิลก่อนกำหนดความกว้างหลอดกลางล่าง
    var combat_width: float = 374.0 * combat_scale
    var min_vitals: float = 240.0 if compact_touch else 300.0
    var vital_width: float = clampf(safe_width - joystick_side - combat_width - 44.0, min_vitals, 460.0)
    party_status.offset_left = -vital_width * 0.5
    party_status.offset_right = vital_width * 0.5
    party_panel.set_compact(compact_touch or safe_height < 660.0)

    var web_mobile_low_power: bool = HybridPlatform.is_web_mobile(get_viewport())
    menu.animations_enabled = preferences.animations_enabled and not web_mobile_low_power
    GameVisualSettings.motion_enabled = preferences.animations_enabled and not web_mobile_low_power
    GameVisualSettings.blur_enabled = preferences.blur_enabled and not web_mobile_low_power
    GameVisualSettings.low_effects = preferences.low_effects or web_mobile_low_power
    if not GameVisualSettings.motion_enabled:
        for fx: Node in get_tree().get_nodes_in_group("button_visual_fx"):
            fx.reset()
        for bar: Node in get_tree().get_nodes_in_group("smooth_texture_bars"):
            bar.snap_to_target()

    # บนมือถือจอแคบมาก ซ่อน minimap ก่อน แต่ยังเปิดกลับเมื่อหมุน Landscape/จอกว้างขึ้น
    minimap.visible = preferences.minimap_visible and (not touch_mode or safe_width >= 760.0)

    var chat_width: float = 264.0
    if touch_mode:
        chat_width = clampf(safe_width * 0.28, 190.0, 264.0)
    chat_panel.offset_left = inset.x
    chat_panel.offset_right = inset.x + chat_width
    chat_panel.bottom_inset = inset.w + joystick_side + 14.0
    chat_panel.layout_panel()
    quest_button.visible = chat_panel.collapsed

    if is_instance_valid(quick_bar):
        quick_bar.position = Vector2((viewport_size.x - quick_bar.size.x) * 0.5, viewport_size.y - inset.w - 238.0)
    target_card.offset_top = inset.y
    target_card.offset_bottom = inset.y + 59
    message.offset_top = inset.y + 78
    message.offset_bottom = inset.y + 116
    exp_strip.position = Vector2(inset.x, viewport_size.y - maxf(4.0, inset.w - 12.0))
    exp_strip.size = Vector2(maxf(1.0, viewport_size.x - inset.x - inset.z), 4)

    _refresh_mobile_web_overlay()


func _build_mobile_web_overlay() -> void:
    # World เป็นเกม Landscape; Portrait ยังคงรับ resize แต่บังคำสั่งสนามเพื่อไม่ให้ผู้เล่นกดผิดตำแหน่ง
    if not OS.has_feature("web") or not HybridPlatform.use_mobile_layout(get_viewport()) or is_instance_valid(_rotate_overlay):
        return

    _rotate_overlay = ColorRect.new()
    _rotate_overlay.name = "WebMobileRotateHint"
    _rotate_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _rotate_overlay.color = Color(0.012, 0.028, 0.050, 0.96)
    _rotate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _rotate_overlay.z_index = 4090
    $Root.add_child(_rotate_overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rotate_overlay.add_child(center)

    var stack := VBoxContainer.new()
    stack.custom_minimum_size = Vector2(300, 180)
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 10)
    center.add_child(stack)

    var icon := Label.new()
    icon.text = "↻"
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", 52)
    icon.add_theme_color_override("font_color", Color("70d8f4"))
    stack.add_child(icon)

    var title := Label.new()
    title.text = "หมุนมือถือเป็นแนวนอน"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color.WHITE)
    stack.add_child(title)

    var detail := Label.new()
    detail.text = "Joystick + Skill Touch พร้อมใช้งานเมื่ออยู่ใน Landscape"
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.add_theme_font_size_override("font_size", 15)
    detail.add_theme_color_override("font_color", Color("a4bbcf"))
    stack.add_child(detail)


func _refresh_mobile_web_overlay() -> void:
    if is_instance_valid(_rotate_overlay):
        _rotate_overlay.visible = HybridPlatform.is_portrait(get_viewport())

func _process(delta: float) -> void:
    # ไม่คำนวณสเตตัสใหม่ทุกเฟรม อัปเดตเฉพาะ lock/cooldown/เป้าหมาย
    _refresh_combat_controls()
    _target_refresh_left -= delta
    if _target_refresh_left <= 0:
        _target_refresh_left = 0.15
        _refresh_target(tamer.get_target())
    _message_left = maxf(0, _message_left - delta)
    message.visible = _message_left > 0

func _refresh_bars(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
    if not is_instance_valid(exp_strip):
        return
    party_status.update_values(tamer, partner)
    _refresh_quick_items()
    if is_instance_valid(critical_fx):
        critical_fx.set_critical(not tamer.can_battle())
    _refresh_combat_controls()
    exp_strip.max_value = maxi(1, tamer.progress.max_exp)
    exp_strip.value = tamer.progress.current_exp
    recover_button.visible = not partner.is_alive()
    attack_button.visible = not recover_button.visible
    if is_instance_valid(digimon_screen) and digimon_screen.is_open:
        digimon_screen.refresh()

func _status_text() -> String:
    # รายละเอียดแยกเจ้าของชัดเจน: Tamer MP ใช้เปลี่ยน/คงร่าง, Partner MP ใช้สกิล
    return "TAMER Lv%d  EXP %d/%d\nHP %d/%d  MP %.0f/%.0f\nอิ่ม %.0f/100 • แรง %.0f/100 • %s\n\nPARTNER Lv%d  EXP %d/%d\nHP %d/%d  MP %.0f/%.0f\nATK %d • SPD %.0f • %s" % [tamer.progress.level,tamer.progress.current_exp,tamer.progress.max_exp,tamer.hp,tamer.max_hp,tamer.tamer_mp,tamer.max_tamer_mp,tamer.tamer_hunger,tamer.tamer_stamina,"พร้อมสู้" if tamer.can_battle() else "ต่อสู้ไม่ได้",partner.progress.level,partner.progress.current_exp,partner.progress.max_exp,partner.hp,partner.max_hp,partner.digimon_mp,partner.digimon_max_mp,partner.attack_power,partner.move_speed,PartnerMonster.State.keys()[partner.state]]

func _refresh_quest(_id: StringName) -> void:
    var quest: StoryQuest = QuestManager.get_current_quest()
    quest_button.set_caption("เควสต์ครบแล้ว" if quest == null else "เควสต์ • " + quest.title)
    if is_instance_valid(menu):
        menu.set_badge(&"quest", 0 if quest == null else 1)
    if not skill_panel.pages.is_empty():
        page_label.text = skill_panel._page_title()

func _on_page_changed(title: String, _index: int, _count: int) -> void:
    page_label.text = title

func _on_remote_player_interaction(peer_id: String, display_name: String, guild_name: String) -> void:
    if peer_id.is_empty() or not OnlineManager.connected:
        return
    if get_tree().paused or menu.expanded or smart_panel.is_open or digimon_screen.is_open or guild_screen.is_open:
        return

    _selected_remote_peer_id = peer_id
    _selected_remote_name = display_name if not display_name.is_empty() else "ผู้เล่น"
    _selected_remote_guild = guild_name

    var detail: String = "Tamer: %s" % _selected_remote_name
    detail += "\nกิลด์: %s" % ("<%s>" % guild_name if not guild_name.is_empty() else "ยังไม่มีกิลด์")
    var options: Array[Dictionary] = [
        {"id": &"trade_player", "label": "Trade (ปิดปรับปรุง)"}
    ]

    if OnlineManager.guild.is_empty():
        detail += "\n\nกิลด์: คุณยังไม่มีกิลด์ จึงชวนเข้ากิลด์ไม่ได้"
    elif not guild_name.is_empty():
        if guild_name == str(OnlineManager.guild.get("name", "")):
            detail += "\n\nกิลด์: ผู้เล่นนี้อยู่กิลด์เดียวกับคุณแล้ว"
        else:
            detail += "\n\nกิลด์: ผู้เล่นนี้มีกิลด์อยู่แล้ว"
    else:
        options.append({"id": &"guild_invite_player", "label": "ชวนเข้ากิลด์"})

    smart_panel.open_kind(&"player", "ผู้เล่นออนไลน์", detail, options)


func _on_guild_feedback_toast(message: String, _ok: bool) -> void:
    if not message.is_empty():
        _show_message(message)


func _menu_action(action: StringName) -> void:
    # คำสั่ง modal ใช้ Pause ownership ของแต่ละหน้าต่าง ห้ามเปิดซ้อน
    match action:
        &"inventory": inventory_screen.open_screen()
        &"equipment": equipment_screen.open_screen()
        &"digimon": _toggle_stats()
        &"skills":
            _toggle_stats()
            _show_message("ดูสกิลของร่างปัจจุบันได้ในหน้า Digimon")
        &"quest":
            var quest: StoryQuest = QuestManager.get_current_quest()
            var detail: String = "ผ่านเควสต์หลักครบแล้ว"
            if quest != null:
                detail = "%s\n%s\nความคืบหน้า %d / %d\nโซน: %s" % [quest.title,quest.description,QuestManager.get_progress(quest.id),quest.required_count,quest.zone_id]
            var options: Array[Dictionary] = []
            if quest != null:
                options.append({"id": &"navigate", "label": "นำทางไปเป้าหมาย"})
            smart_panel.open_kind(&"quest", "เควสต์หลัก", detail, options)
        &"settings": _open_settings()
        &"map":
            preferences.minimap_visible = not preferences.minimap_visible
            _save_preferences()
        &"chat": chat_panel.toggle_collapsed()
        &"guild": guild_screen.open_screen()
        &"character": _return_to_characters()
        &"mail", &"rewards", &"community", &"wiki", &"help", &"updates", &"explorer", &"ranking", &"event", &"world_boss", &"pvp", &"cards", &"party", &"friends":
            _show_message("เมนู %s กำลังเตรียมระบบ" % String(action).replace("_", " ").capitalize())

func _toggle_stats() -> void:
    # เก็บชื่อเมธอดเดิมไว้สำหรับผู้เรียกเก่า แต่ใช้หน้าดิจิมอนใหม่ทั้งหมด
    if digimon_screen.is_open:
        digimon_screen.close_screen()
    else:
        digimon_screen.open_screen()

func _settings_options() -> Array[Dictionary]:
    # ตัวเลือกภาพอ่านเป็นภาษาผู้เล่น ไม่ต้องรู้คำว่า shader หรือ renderer
    return [
        {"id": &"motion", "label": "ภาพ: " + ("เคลื่อนไหว" if preferences.animations_enabled else "ลดการเคลื่อนไหว")},
        {"id": &"blur", "label": "ฉากหลังหน้าต่าง: " + ("เบลอ" if preferences.blur_enabled else "หรี่แสง")},
        {"id": &"effects", "label": "เอฟเฟกต์: " + ("น้อย" if preferences.low_effects else "เต็ม")},
        {"id": &"size", "label": "ปุ่มต่อสู้: %d%%" % roundi(preferences.combat_scale*100)},
        {"id": &"map", "label": "แผนที่: " + ("แสดง" if preferences.minimap_visible else "ซ่อน")},
        {"id": &"chat", "label": "แชต: " + ("ย่อ" if chat_panel.collapsed else "ขยาย")},
        {"id": &"quick_0", "label": _quick_slot_label(0)},
        {"id": &"quick_1", "label": _quick_slot_label(1)},
        {"id": &"quick_2", "label": _quick_slot_label(2)},
        {"id": &"quick_3", "label": _quick_slot_label(3)},
        {"id": &"light", "label": "สลับแสงกลางวัน / เย็น"}
    ]

func _open_settings() -> void:
    smart_panel.open_kind(&"settings", "ตั้งค่า HUD", "ปรับขนาดปุ่มและลดการเคลื่อนไหวได้ทันที\nบันทึกอัตโนมัติบนเครื่องนี้", _settings_options())

func _modal_action(action: StringName) -> void:
    if action == &"trade_player":
        var peer_id: String = _selected_remote_peer_id
        smart_panel.close_screen()
        if not OnlineManager.request_trade(peer_id):
            _show_message(OnlineManager.TRADE_UNAVAILABLE_MESSAGE)
        return
    if action == &"guild_invite_player":
        var peer_id: String = _selected_remote_peer_id
        smart_panel.close_screen()
        if not OnlineManager.invite_to_guild(peer_id):
            _show_message("ส่งคำเชิญกิลด์ไม่สำเร็จ")
        return
    if action == &"navigate":
        smart_panel.close_screen()
        _tracker.request_navigation()
        return
    match action:
        &"motion": preferences.animations_enabled = not preferences.animations_enabled
        &"blur": preferences.blur_enabled = not preferences.blur_enabled
        &"effects": preferences.low_effects = not preferences.low_effects
        &"size": preferences.combat_scale = 1.15 if preferences.combat_scale < 1.1 else 1.0
        &"map": preferences.minimap_visible = not preferences.minimap_visible
        &"chat": chat_panel.toggle_collapsed()
        &"quick_0": _cycle_quick_slot(0)
        &"quick_1": _cycle_quick_slot(1)
        &"quick_2": _cycle_quick_slot(2)
        &"quick_3": _cycle_quick_slot(3)
        &"light":
            var environment: Node = tamer.get_parent().get_parent().get_node_or_null("OpenWorldEnvironment")
            if environment != null:
                environment.lighting.toggle_time_of_day()
    _save_preferences()
    # เปลี่ยน caption เดิม ไม่สร้างปุ่มใหม่ระหว่างที่นิ้วยังค้าง
    for option: Dictionary in _settings_options():
        if smart_panel.buttons.has(option.id):
            smart_panel.buttons[option.id].set_caption(option.label)

func _save_preferences() -> void:
    var error: Error = preferences.save_data()
    if error != OK:
        _show_message("บันทึกการตั้งค่าไม่สำเร็จ: %s" % error_string(error))
    _layout()

func _on_chat_folded(collapsed: bool) -> void:
    preferences.chat_collapsed = collapsed
    _save_preferences()

func _on_chat_editing(editing: bool) -> void:
    chat_editing = editing
    joystick.release_input()
    joystick.visible = not editing
    skill_panel.release_input()
    if editing:
        tamer.cancel_auto_navigation()
    _sync_skill_input()

func _sync_skill_input() -> void:
    var blocked: bool = chat_editing or menu.expanded or (is_instance_valid(smart_panel) and smart_panel.is_open) or (is_instance_valid(digimon_screen) and digimon_screen.is_open) or (is_instance_valid(guild_screen) and guild_screen.is_open) or (is_instance_valid(trade_screen) and trade_screen.is_open)
    skill_panel.process_mode = Node.PROCESS_MODE_DISABLED if blocked else Node.PROCESS_MODE_INHERIT
    party_panel.process_mode = skill_panel.process_mode

func release_for_equipment() -> void:
    # คืนทุกนิ้วและคำสั่งเดิน ก่อน pause/cutscene เพื่อไม่เดินต่อเองเมื่อปิดหน้าต่าง
    chat_panel.release_input()
    joystick.release_input()
    skill_panel.release_input()
    party_panel.release_input()
    inventory_shortcut.release_input()
    settings_shortcut.release_input()
    menu.release_input()
    menu.set_expanded(false, false)
    tamer.cancel_auto_navigation()
    chat_editing = false
    for button: TouchCommand in [attack_button,evolve_button,auto_button,recover_button,cycle_button]:
        button.release_input()
    for quick_button: HybridCommand in quick_buttons:
        quick_button.release_input()

func _request_digivolve(partner_node: PartnerMonster) -> void:
    if is_instance_valid(active_cutscene) or get_tree().paused:
        return
    release_for_equipment()
    var cutscene: DigivolveCutscene = CUTSCENE_SCENE.instantiate() as DigivolveCutscene
    get_tree().root.add_child(cutscene)
    cutscene.finished.connect(_on_cutscene_finished)
    if not cutscene.play_for(partner_node):
        cutscene.queue_free()
        return
    active_cutscene = cutscene

func _unhandled_input(event: InputEvent) -> void:
    # Web/PC shortcuts: Space = โจมตี, 1-4 = สกิล, 5-8 = Quick Item, J = Fusion
    # ใช้ unhandled_input เพื่อไม่แย่งปุ่มจาก LineEdit/เมนูที่กำลังรับคีย์บอร์ด
    if chat_editing or menu.expanded or (is_instance_valid(smart_panel) and smart_panel.is_open) or (is_instance_valid(digimon_screen) and digimon_screen.is_open) or (is_instance_valid(guild_screen) and guild_screen.is_open) or (is_instance_valid(trade_screen) and trade_screen.is_open):
        return
    if event.is_action_pressed(&"basic_attack"):
        tamer.command_attack()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"skill_1"):
        tamer.command_skill(0)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"skill_2"):
        tamer.command_skill(1)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"skill_3"):
        tamer.command_skill(2)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"skill_4"):
        tamer.command_skill(3)
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_5 and event.keycode <= KEY_8:
        _use_quick_slot(int(event.keycode - KEY_5))
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"fusion") and is_instance_valid(fusion_manager):
        fusion_manager.request_fusion()
        get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
    # บัง touch เฉพาะ card ที่แสดง ปล่อยพื้นที่สนามที่เหลือให้เลือกศัตรู
    if event is InputEventScreenTouch:
        for control: Control in [party_status,target_card]:
            if is_instance_valid(control) and control.is_visible_in_tree():
                var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * event.position
                if Rect2(Vector2.ZERO,control.size).has_point(local):
                    get_viewport().set_input_as_handled()
                    return

func _toggle_auto() -> void:
    tamer.set_auto_battle(not partner.auto_battle)


func _show_message(value: String) -> void:
    GameChat.add_system(value)
    message.text = value
    _message_left = 3.0


func _on_cutscene_finished(_success: bool) -> void:
    # Signal หลังเวลาเกมถูกคืนแล้ว จึงรับคำสั่งครั้งใหม่ได้
    active_cutscene = null


func _build_target_card() -> void:
    # แสดงเฉพาะศัตรูที่เลือก HP อ่านสดได้แม้ศัตรูไม่มี hp_changed
    target_card = Panel.new()
    target_card.name = "TargetStatus"
    target_card.anchor_left = 0.5
    target_card.anchor_right = 0.5
    target_card.offset_left = -155
    target_card.offset_right = 155
    target_card.offset_top = 16
    target_card.offset_bottom = 75
    target_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    target_card.add_theme_stylebox_override("panel", ClassicUIStyle.frame(ClassicUIStyle.GOLD))
    $Root.add_child(target_card)
    _target_name = ClassicUIStyle.label("", Vector2(12, 4), Vector2(286, 22), 13)
    _target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    target_card.add_child(_target_name)
    _target_bar = SmoothTextureBar.new()
    _target_bar.position = Vector2(12, 33)
    _target_bar.size = Vector2(286, 14)
    _target_bar.add_theme_font_size_override("font_size", 1)
    _target_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    target_card.add_child(_target_bar)
    _target_bar.size = Vector2(286, 14)
    target_card.hide()


func _refresh_target(enemy: Variant) -> void:
    # Variant รับ reference ที่ถูก free แล้วได้ จึงตรวจได้ก่อนแปลงเป็น WildMonster
    # ถ้าบังคับชนิดในพารามิเตอร์ Godot จะ error ก่อนเข้าถึง guard ภายในฟังก์ชัน
    if not is_instance_valid(target_card):
        return
    if not is_instance_valid(enemy) or not (enemy is WildMonster):
        target_card.hide()
        return
    var live_enemy := enemy as WildMonster
    if live_enemy.is_queued_for_deletion() or not live_enemy.is_alive():
        target_card.hide()
        return
    target_card.show()
    _target_name.text = "%s  •  %d / %d" % [String(live_enemy.monster_id).capitalize(), live_enemy.hp, live_enemy.max_hp]
    # เปลี่ยนเป้าหมายแล้ว snap ครั้งแรก ป้องกันแสดง HP ของตัวเก่าค่อย ๆ ไหลมาเป็นตัวใหม่
    var new_id: int = live_enemy.get_instance_id()
    _target_bar.set_vitals(live_enemy.hp, live_enemy.max_hp, "", new_id != _target_instance_id)
    _target_instance_id = new_id


func _on_form_changed(_data: MonsterData) -> void:
    # Portrait และ roster เปลี่ยนตามร่างพร้อมกับปุ่มสกิล
    _refresh_bars()

func _switch_party(index: int) -> void:
    # ปล่อยนิ้วเดิน/สกิลก่อน commit สมาชิกใหม่ แต่ไม่หยุดเกมหรือโหลดฉากใหม่
    if partner.evolution_busy or get_tree().paused:
        return
    release_for_equipment()
    party_roster.select_member(index)

func _on_party_switched(_index: int) -> void:
    # ตัวละครคนละตัวต้องแสดง HP ใหม่ทันที; Tween ใช้กับดาเมจของตัวเดียวกันเท่านั้น
    party_status.update_values(tamer, partner, true)
    _refresh_combat_controls()


func _on_tamer_level(new_level: int) -> void:
    GameChat.add_system("Tamer เลเวลเพิ่มเป็น %d" % new_level)


func _on_partner_level(new_level: int) -> void:
    GameChat.add_system("คู่หูเลเวลเพิ่มเป็น %d" % new_level)


func _on_item_picked_up(item: ItemData, quantity: int) -> void:
    # แจ้งใน HUD/แชตหลัง commit กระเป๋าแล้ว ไม่แจกซ้ำจากเอฟเฟกต์ Tween
    _show_message("เก็บ %s x%d" % [item.item_name, quantity])


func _return_to_characters() -> void:
    # ไม่ออกระหว่างจอง DS คัตซีน หรือหน้าต่างอุปกรณ์ถือ pause
    if partner.evolution_busy or get_tree().paused:
        return
    release_for_equipment()
    tamer.save_party_progress()
    AudioManager.stop_bgm(0.30)
    GameManager.gameplay_active = false
    GameManager.go_to(GameManager.CHARACTER_SCENE)



func _refresh_combat_controls() -> void:
    # Cannot Battle ปิด Attack/Auto/Digivolve/สกิล แต่ Recover/อาหารยังใช้งานได้
    var blocked: bool = chat_editing or menu.expanded or (is_instance_valid(smart_panel) and smart_panel.is_open) or (is_instance_valid(digimon_screen) and digimon_screen.is_open) or (is_instance_valid(guild_screen) and guild_screen.is_open) or (is_instance_valid(trade_screen) and trade_screen.is_open)
    attack_button.locked = blocked or not partner.can_battle() or partner.evolution_busy
    recover_button.locked = blocked or partner.evolution_busy
    auto_button.locked = attack_button.locked
    auto_button.set_caption("Auto ON" if partner.auto_battle else "Auto OFF")
    var next_index: int = partner.form_index + 1
    evolve_button.locked = blocked or partner.evolution_busy or not partner.is_alive() or not tamer.can_battle() or next_index < 0 or next_index >= partner.forms.size()
    if next_index >= 0 and next_index < partner.forms.size():
        var next_form: MonsterData = partner.forms[next_index]
        var required_level: int = EvolutionRules.minimum_level_for_form_index(next_index, next_form)
        var level_locked: bool = not EvolutionRules.can_use_form(partner.progress.level, next_index, next_form)
        var story_locked: bool = not QuestManager.has_flag(next_form.required_story_flag)
        if not evolve_button.locked:
            evolve_button.locked = level_locked or story_locked
        if level_locked:
            evolve_button.set_caption("Evolve Lv%d" % required_level)
        elif story_locked:
            evolve_button.set_caption("Evolve 🔒")
        else:
            evolve_button.set_caption("Evolve")
    else:
        evolve_button.set_caption("MAX")
    # ปุ่ม Cycle ใช้เป็น Fusion; แสดงได้ตลอดแต่ล็อกจน Emberclaw/Frostfang Lv90 ทั้งคู่
    cycle_button.set_caption("Prismforge" if is_instance_valid(fusion_manager) and fusion_manager.active else "Fusion [J]")
    cycle_button.locked = blocked or not is_instance_valid(fusion_manager) or not fusion_manager.can_fusion() or fusion_manager.active


func _on_battle_permission(allowed: bool) -> void:
    # Signal ยังคงทำงานตอน pause: อันตรายจากระบบอื่นสามารถยกเลิกคัตซีน/คืน DS ได้ทันที
    if not allowed:
        skill_panel.release_input()
        for button: TouchCommand in [attack_button,evolve_button,auto_button]:
            button.release_input()
        if is_instance_valid(active_cutscene):
            active_cutscene.cancel()
    skill_panel._refresh_buttons()
    _refresh_bars()
