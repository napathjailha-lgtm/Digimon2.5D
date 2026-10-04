class_name HybridVitals
extends VBoxContainer
## ภาพ HUD กลางล่าง แยก Tamer MP (ใช้ Digivolve) และ Partner MP (ใช้สกิล)
var tamer_hp: HybridVitalsBar
var partner_hp: HybridVitalsBar
var ds_bar: HybridVitalsBar
var mp_bar: HybridVitalsBar
var hunger_bar: NeedsOrb
var stamina_bar: NeedsOrb
var condition: Label
var _tamer_name: Label
var _partner_name: Label
var _tamer_number: Label
var _partner_number: Label
var _ds_number: Label
var _mp_number: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_constant_override("separation", 3)
    var needs := HBoxContainer.new()
    needs.name = "Needs"
    needs.alignment = BoxContainer.ALIGNMENT_CENTER
    needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
    needs.add_theme_constant_override("separation", 8)
    add_child(needs)
    hunger_bar = NeedsOrb.new()
    hunger_bar.name = "Hunger"
    needs.add_child(hunger_bar)
    stamina_bar = NeedsOrb.new()
    stamina_bar.title = "แรง"
    stamina_bar.color = Color("bbdeb1")
    stamina_bar.name = "Stamina"
    needs.add_child(stamina_bar)
    condition = _label("", 12)
    condition.name = "Condition"
    condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    condition.visible = false
    add_child(condition)
    var tamer_row: HBoxContainer = _header("TamerHeader")
    _tamer_name = _label("TAMER", 12)
    _tamer_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tamer_name.clip_text = true
    tamer_row.add_child(_tamer_name)
    _tamer_number = _label("", 14)
    tamer_row.add_child(_tamer_number)
    tamer_hp = _bar(self, "TamerHP", Color("9cdb74"), 7)
    var partner_row: HBoxContainer = _header("PartnerHeader")
    _partner_name = _label("PARTNER", 12)
    _partner_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _partner_name.clip_text = true
    partner_row.add_child(_partner_name)
    _partner_number = _label("", 14)
    partner_row.add_child(_partner_number)
    partner_hp = _bar(self, "PartnerHP", Color("66d9bf"), 7)
    var energy := HBoxContainer.new()
    energy.name = "Energy"
    energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    energy.add_theme_constant_override("separation", 14)
    add_child(energy)
    _ds_number = _energy_column(energy, "TamerMP", Color("67baff"))
    _mp_number = _energy_column(energy, "PartnerMP", Color("c7a7ed"))

func _label(text: String, font_size: int) -> Label:
    var result := Label.new()
    result.text = text
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_constant_override("outline_size", 2)
    result.add_theme_color_override("font_outline_color", Color("102123"))
    return result

func _header(node_name: String) -> HBoxContainer:
    var result := HBoxContainer.new()
    result.name = node_name
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(result)
    return result

func _bar(parent: Node, node_name: String, color: Color, height: float) -> HybridVitalsBar:
    var result := HybridVitalsBar.new()
    result.name = node_name
    result.fill_color = color
    result.custom_minimum_size.y = height
    parent.add_child(result)
    return result

func _energy_column(parent: Node, node_name: String, color: Color) -> Label:
    var column := VBoxContainer.new()
    column.name = node_name
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 1)
    parent.add_child(column)
    var number: Label = _label("", 12)
    column.add_child(number)
    var bar: HybridVitalsBar = _bar(column, "Bar", color, 4)
    if node_name == "TamerMP":
        ds_bar = bar
    elif node_name == "PartnerMP":
        mp_bar = bar
    return number

func update_values(tamer: Tamer, partner: PartnerMonster, instant: bool = false) -> void:
    # ตัวเลขเป็นค่าจริงทันที ส่วนภาพหลอด Tween ตามหลัง; ไม่ใช้ value ตัดสินสิทธิ์ต่อสู้
    if partner.current_form == null:
        return
    _tamer_name.text = "%s · Lv%d" % [tamer.display_name, tamer.progress.level]
    _partner_name.text = "%s · Lv%d" % [partner.current_form.monster_name if partner.is_alive() else "DIGITAMA", partner.progress.level]
    _tamer_number.text = "%d / %d" % [tamer.hp, tamer.max_hp]
    _partner_number.text = "%d / %d" % [partner.hp, partner.max_hp]
    _ds_number.text = "T-MP  %.0f / %.0f" % [tamer.tamer_mp, tamer.max_tamer_mp]
    _mp_number.text = "P-MP  %.0f / %.0f" % [partner.digimon_mp, partner.digimon_max_mp]
    tamer_hp.set_vitals(tamer.hp, tamer.max_hp, "", instant)
    partner_hp.set_vitals(partner.hp, partner.max_hp, "", instant)
    ds_bar.set_vitals(tamer.tamer_mp, tamer.max_tamer_mp, "", instant)
    mp_bar.set_vitals(partner.digimon_mp, partner.digimon_max_mp, "", instant)
    hunger_bar.set_value(tamer.tamer_hunger)
    stamina_bar.set_value(tamer.tamer_stamina)
    condition.visible = not tamer.can_battle() or tamer.survival.is_resting()
    condition.text = "พักฟื้นในเมือง" if tamer.can_battle() else "ต่อสู้ไม่ได้ · กินอาหารหรือพัก"
    condition.modulate = Color("bcebbb") if tamer.can_battle() else Color("ffb3a0")
