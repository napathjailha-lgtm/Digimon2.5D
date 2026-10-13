class_name DigimonStatusScreen
extends CanvasLayer
## หน้าดิจิมอนแทน Status เดิม: พรีวิว / ค่าต่อสู้ / สกิลของตัวลงสนามจริง
## Container จัดหน้า และ ScrollContainer รองรับ Landscape ที่มีพื้นที่แนวตั้งน้อย
var hud: MobileHUD
var is_open: bool = false
var root: Control
var panel: PanelContainer
var safe: MarginContainer
var scroll: ScrollContainer
var preview: DigimonStatusPreview
var title_name: Label
var level_label: Label
var stage_label: Label
var exp_label: Label
var attribute_label: Label
var detail_label: Label
var exp_bar: ProgressBar
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var values: Dictionary = {}
var skill_buttons: Array[DigimonTouchButton] = []
var stat_buttons: Dictionary = {}
var growth_label: Label
var upgrade_skill_button: DigimonTouchButton
var _selected_skill_index: int = -1
var close_button: DigimonTouchButton
var visual_fx: ModalVisualFX
var _form: MonsterData
var _owns_pause: bool = false
var _previous_back_quit: bool = true
var _refresh_left: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 87
    _build()
    root.hide()
    get_viewport().size_changed.connect(_layout)

func configure(owner_hud: MobileHUD) -> void:
    hud = owner_hud
    root.theme = hud.get_node("Root").theme

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size.y = height
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = Color("08121d")
    bar.add_theme_stylebox_override("background", background)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)
    return bar

func _build() -> void:
    root = Control.new()
    root.name = "Root"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    var dim := ColorRect.new()
    dim.name = "Shade"
    dim.color = Color(0.01, 0.025, 0.045, 0.7)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    safe = MarginContainer.new()
    safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(safe)
    var center := CenterContainer.new()
    safe.add_child(center)
    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("3c7898"), Color("091827fa")))
    center.add_child(panel)
    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    panel.add_child(margin)
    scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    margin.add_child(scroll)
    var stack := VBoxContainer.new()
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation", 10)
    scroll.add_child(stack)
    var header := HBoxContainer.new()
    stack.add_child(header)
    var heading: Label = _label(header, "DIGIMON  /  STATUS", 23, Color("b5eb79"))
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var close := DigimonTouchButton.new()
    close_button = close
    close.text = "ปิด ×"
    close.custom_minimum_size = Vector2(80, 48)
    close.pressed.connect(close_screen)
    header.add_child(close)
    var summary := HBoxContainer.new()
    summary.add_theme_constant_override("separation", 18)
    stack.add_child(summary)
    level_label = _label(summary, "Lv.1", 22, Color("73dced"))
    title_name = _label(summary, "", 24, Color("f0f6fe"))
    title_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage_label = _label(summary, "", 16, Color("c1a5f2"))
    exp_bar = _bar(stack, Color("e5cb52"), 6)
    exp_label = _label(stack, "", 14, Color("a1b5ca"))
    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 24)
    stack.add_child(columns)
    var portrait := VBoxContainer.new()
    portrait.custom_minimum_size.x = 260
    portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(portrait)
    preview = DigimonStatusPreview.new()
    preview.custom_minimum_size = Vector2(240, 230)
    portrait.add_child(preview)
    attribute_label = _label(portrait, "", 16, Color("77cfe0"))
    attribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_bar = _bar(portrait, Color("87ca76"), 8)
    mp_bar = _bar(portrait, Color("55a8e0"), 6)
    var stats := GridContainer.new()
    stats.columns = 2
    stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats.add_theme_constant_override("h_separation", 24)
    stats.add_theme_constant_override("v_separation", 3)
    columns.add_child(stats)
    var names: Array[String] = ["HP  เลือด", "MP  พลังสกิล", "AT  โจมตี", "AS  จังหวะโจมตี", "CT  คริติคอล", "HT  แม่นยำ", "DE  ป้องกัน", "BL  บล็อก", "EV  หลบหลีก", "MS  ความเร็ว"]
    var ids: Array[String] = ["HP", "MP", "AT", "AS", "CT", "HT", "DE", "BL", "EV", "MS"]
    for i: int in range(ids.size()):
        _label(stats, names[i], 15, Color("6cbdd5"))
        var value: Label = _label(stats, "—", 17, Color("b4e585"))
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        values[ids[i]] = value
    var skill_frame := PanelContainer.new()
    skill_frame.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("66538d"), Color("171c35")))
    stack.add_child(skill_frame)
    var skill_stack := VBoxContainer.new()
    skill_stack.add_theme_constant_override("separation", 8)
    skill_frame.add_child(skill_stack)
    var skill_header := HBoxContainer.new()
    skill_stack.add_child(skill_header)
    var active_title: Label = _label(skill_header, "SKILL", 16, Color("c3a5f1"))
    active_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    active_title.size_flags_stretch_ratio = 4.0
    var memory_title: Label = _label(skill_header, "MEMORY SKILL", 16, Color("96c7af"))
    memory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    memory_title.size_flags_stretch_ratio = 2.0
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    skill_stack.add_child(row)
    for i: int in range(6):
        var button := DigimonTouchButton.new()
        button.custom_minimum_size = Vector2(64, 64)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.expand_icon = true
        button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.add_theme_constant_override("icon_max_width", 56)
        button.pressed.connect(_show_skill.bind(i))
        row.add_child(button)
        skill_buttons.append(button)
    var growth_frame := PanelContainer.new()
    growth_frame.add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("3b8d83"), Color("10251f")))
    stack.add_child(growth_frame)
    var growth_stack := VBoxContainer.new()
    growth_stack.add_theme_constant_override("separation", 7)
    growth_frame.add_child(growth_stack)
    growth_label = _label(growth_stack, "", 15, Color("b8ead5"))
    growth_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var stat_row := HBoxContainer.new()
    stat_row.add_theme_constant_override("separation", 7)
    growth_stack.add_child(stat_row)
    var stat_ids: Array[StringName] = [&"hp", &"attack", &"defense", &"speed"]
    var stat_titles: Array[String] = ["HP +25", "ATK +3", "DEF +2", "SPD +2"]
    for i: int in range(stat_ids.size()):
        var button := DigimonTouchButton.new()
        button.text = stat_titles[i]
        button.custom_minimum_size = Vector2(78, 44)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_spend_stat_point.bind(stat_ids[i]))
        stat_row.add_child(button)
        stat_buttons[String(stat_ids[i])] = button

    upgrade_skill_button = DigimonTouchButton.new()
    upgrade_skill_button.text = "อัปสกิลที่เลือก • 1 แต้ม"
    upgrade_skill_button.custom_minimum_size = Vector2(0, 44)
    upgrade_skill_button.pressed.connect(_upgrade_selected_skill)
    growth_stack.add_child(upgrade_skill_button)

    detail_label = _label(stack, "", 14, Color("b7c8da"))
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.custom_minimum_size.y = 42
    visual_fx = ModalVisualFX.attach(root, panel)

func _layout() -> void:
    if hud == null:
        return

    # ใช้ Safe Area เดียวกับ HUD แล้ว scale Panel ทั้งก้อนเมื่อ child minimum size ใหญ่กว่าพื้นที่จริง
    ResponsiveUI.apply_safe_margins(safe, get_viewport(), 12.0)
    var view: Vector2 = get_viewport().get_visible_rect().size
    var width: float = maxf(1.0, view.x - safe.get_theme_constant("margin_left") - safe.get_theme_constant("margin_right"))
    var height: float = maxf(1.0, view.y - safe.get_theme_constant("margin_top") - safe.get_theme_constant("margin_bottom"))

    panel.custom_minimum_size = Vector2(780, 660)
    scroll.custom_minimum_size = Vector2(0, minf(620.0, maxf(300.0, height - 40.0)))
    ResponsiveUI.fit_centered(panel, get_viewport(), 14.0)


func open_screen() -> bool:
    if is_open or hud == null or get_tree().paused or hud.partner.evolution_busy:
        return false
    hud.release_for_equipment()
    _layout()
    _form = null
    refresh()
    is_open = true
    _owns_pause = true
    _previous_back_quit = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    get_tree().paused = true
    root.show()
    hud._sync_skill_input()
    visual_fx.animate_open()
    return true

func refresh() -> void:
    if hud == null or not is_instance_valid(hud.partner):
        return
    var partner: PartnerMonster = hud.partner
    var form: MonsterData = partner.current_form
    if form == null:
        return
    level_label.text = "Lv.%d" % partner.progress.level
    title_name.text = form.monster_name
    var enhancement: int = 0
    if is_instance_valid(hud.party_roster):
        enhancement = hud.party_roster.current_enhancement_level()
    stage_label.text = "%s  •  ENH +%d" % [MonsterData.EvolutionStage.keys()[form.evolution_stage], enhancement]
    exp_bar.max_value = partner.progress.max_exp
    exp_bar.value = partner.progress.current_exp
    exp_label.text = "EXP  %d / %d    •    %s" % [partner.progress.current_exp, partner.progress.max_exp, "พร้อมต่อสู้" if partner.can_battle() else "พักฟื้น / ต่อสู้ไม่ได้"]
    hp_bar.max_value = partner.max_hp
    hp_bar.value = partner.hp
    mp_bar.max_value = partner.digimon_max_mp
    mp_bar.value = partner.digimon_mp
    values.HP.text = "%d / %d" % [partner.hp, partner.max_hp]
    values.MP.text = "%.0f / %.0f" % [partner.digimon_mp, partner.digimon_max_mp]
    values.AT.text = str(partner.attack_power)
    values.AS.text = "%.2f s" % form.attack_interval
    values.CT.text = "%.1f%%" % form.critical_chance
    values.HT.text = "%.1f%%" % form.hit_chance
    values.DE.text = str(form.defense + int(partner.allocated_stats.get("defense", 0)) * PartnerMonster.STAT_POINT_DEFENSE)
    values.BL.text = "%.1f%%" % form.block_chance
    values.EV.text = "%.1f%%" % form.evasion_chance
    values.MS.text = "%.0f" % partner.move_speed
    attribute_label.text = "DIGITAL PARTNER"
    if is_instance_valid(hud.party_roster):
        attribute_label.text += "  •  " + hud.party_roster.enhancement_bonus_text(enhancement)
    var roster: PartnerRoster = hud.party_roster
    if roster.initialized and not roster.members.is_empty():
        var family: StarterPartnerData = roster.family(StringName(roster.members[roster.active_index].id))
        if family != null:
            attribute_label.text = family.attribute_name + "  /  " + family.element_name
    preview.configure(partner)
    if _form != form:
        _form = form
        for i: int in range(skill_buttons.size()):
            var skill: MonsterSkill = partner.active_skills[i] if i < partner.active_skills.size() and i < 4 else null
            skill_buttons[i].icon = skill.icon if skill != null else null
            skill_buttons[i].text = "" if skill != null else ("M" if i >= 4 else "—")
            skill_buttons[i].disabled = skill == null
            skill_buttons[i].tooltip_text = skill.display_name if skill != null else "ยังไม่มี Memory Skill" if i >= 4 else "ไม่มีสกิลในช่องนี้"
        _show_skill(0)

    growth_label.text = "แต้มสเตตัส: %d  •  แต้มสกิล: %d\nสะสมแล้ว  HP +%d  •  ATK +%d  •  DEF +%d  •  SPD +%d" % [
        partner.unspent_stat_points, partner.unspent_skill_points,
        int(partner.allocated_stats.get("hp", 0)) * PartnerMonster.STAT_POINT_HP,
        int(partner.allocated_stats.get("attack", 0)) * PartnerMonster.STAT_POINT_ATTACK,
        int(partner.allocated_stats.get("defense", 0)) * PartnerMonster.STAT_POINT_DEFENSE,
        int(partner.allocated_stats.get("speed", 0)) * int(PartnerMonster.STAT_POINT_SPEED)
    ]
    var stat_ids: Array[StringName] = [&"hp", &"attack", &"defense", &"speed"]
    var stat_titles: Array[String] = ["HP +25", "ATK +3", "DEF +2", "SPD +2"]
    for i: int in range(stat_ids.size()):
        var button: DigimonTouchButton = stat_buttons.get(String(stat_ids[i])) as DigimonTouchButton
        if is_instance_valid(button):
            button.text = "%s (%d)" % [stat_titles[i], int(partner.allocated_stats.get(String(stat_ids[i]), 0))]
            button.disabled = partner.unspent_stat_points <= 0
    for i: int in range(mini(4, partner.active_skills.size())):
        var learned_skill: MonsterSkill = partner.active_skills[i]
        if learned_skill != null:
            skill_buttons[i].tooltip_text = "%s • Rank %d/5" % [learned_skill.display_name, partner.skill_rank(learned_skill.id)]
    if _selected_skill_index >= 0:
        _show_skill(_selected_skill_index)


func _show_skill(index: int) -> void:
    _selected_skill_index = index
    if hud == null or not is_instance_valid(hud.partner):
        upgrade_skill_button.disabled = true
        return
    var partner: PartnerMonster = hud.partner
    if index < 0 or index >= 4 or index >= partner.active_skills.size() or partner.active_skills[index] == null:
        detail_label.text = "เลือกสกิลใน 4 ช่องแรกเพื่อดูรายละเอียดและใช้แต้มอัปเกรด"
        upgrade_skill_button.text = "เลือกสกิลที่อัปได้"
        upgrade_skill_button.disabled = true
        return
    var skill: MonsterSkill = partner.active_skills[index]
    var rank: int = partner.skill_rank(skill.id)
    detail_label.text = "%s  •  Rank %d/5  •  ดาเมจสกิล +%d%%\nAT %.0f%%  •  MP %.0f  •  CD %.1fs\nระยะ %.0f  •  รัศมี %.0f" % [
        skill.display_name, rank, (rank - 1) * 15, skill.multiplier * 100,
        skill.mp_cost, skill.cooldown, skill.cast_range, skill.impact_radius
    ]
    upgrade_skill_button.text = "อัปสกิล • Rank %d/5 • เหลือ %d แต้ม" % [rank, partner.unspent_skill_points]
    upgrade_skill_button.disabled = partner.unspent_skill_points <= 0 or rank >= PartnerMonster.SKILL_RANK_MAX


func _spend_stat_point(stat: StringName) -> void:
    if hud == null or not is_instance_valid(hud.partner):
        return
    if hud.partner.spend_stat_point(stat):
        refresh()


func _upgrade_selected_skill() -> void:
    if hud == null or not is_instance_valid(hud.partner):
        return
    var partner: PartnerMonster = hud.partner
    if _selected_skill_index < 0 or _selected_skill_index >= partner.active_skills.size():
        return
    var skill: MonsterSkill = partner.active_skills[_selected_skill_index]
    if skill != null and partner.upgrade_skill(skill.id):
        refresh()
        _show_skill(_selected_skill_index)

func _process(delta: float) -> void:
    if not is_open:
        return
    _refresh_left -= delta
    if _refresh_left <= 0:
        _refresh_left = 0.2
        refresh()

func close_screen() -> void:
    if not is_open:
        return
    visual_fx.reset()
    close_button.release_input()
    for button: DigimonTouchButton in skill_buttons:
        button.release_input()
    root.hide()
    is_open = false
    _restore_pause()
    hud._sync_skill_input()

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
