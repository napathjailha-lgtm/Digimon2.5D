class_name FormSkillPanel
extends Control
## หน้า UI เป็นเพียงแหล่งสกิล ไม่ใช่ร่างจริงของคู่หู; Resource ไม่ถูกแก้ตอนสลับหน้า
signal skill_requested(slot: int)
signal form_skill_requested(source: MonsterData, slot: int) # compatibility; ระบบใหม่จะไม่ emit ข้ามร่าง
signal page_changed(title: String, index: int, count: int)
@export var partner: PartnerMonster
@export var tamer: Tamer
var buttons: Array[TouchCommand] = []
var pages: Array[Dictionary] = []
var page_index: int = 0
var _revision: int = 0
@export var attack_center := Vector2(222, 206)
@export_range(90.0, 200.0, 1.0) var arc_radius: float = 126.0
@export var arc_start_degrees: float = -210.0
@export var arc_end_degrees: float = -30.0
@export var button_size := Vector2(72, 72)
const SLOT_COUNT: int = 4
var _cooldown_refresh: float = 0.0

func configure(owner_partner: PartnerMonster, owner_tamer: Tamer) -> void:
    # ถอด signal เจ้าของเก่าก่อน รองรับการเปลี่ยนคู่หู
    if is_instance_valid(partner) and partner.skills_changed.is_connected(rebuild):
        partner.skills_changed.disconnect(rebuild)
    if is_instance_valid(partner) and partner.evolution_changed.is_connected(_refresh_buttons):
        partner.evolution_changed.disconnect(_refresh_buttons)
    partner = owner_partner
    tamer = owner_tamer
    partner.skills_changed.connect(rebuild)
    partner.evolution_changed.connect(_refresh_buttons) # จบ cutscene แล้วรับคำสั่งได้ทันที ไม่รอ tick CD
    rebuild(partner.active_skills)

func rebuild(_skills: Array[MonsterSkill]) -> void:
    # แสดงเฉพาะสกิลของร่างปัจจุบัน ร่างอื่น "มองไม่เห็น" ตามกฎใหม่
    pages.clear()
    page_index = 0
    if not is_instance_valid(partner) or partner.current_form == null:
        _draw_page()
        return
    var source: MonsterData = partner.current_form
    for offset: int in range(0, maxi(1, partner.active_skills.size()), SLOT_COUNT):
        pages.append({"form": source, "offset": offset})
    _draw_page()

func cycle_page() -> void:
    # ใช้เฉพาะกรณีร่างปัจจุบันมีสกิลเกิน 4 ช่อง ไม่ใช้เปลี่ยนไปดูสกิลต่างร่าง
    if pages.size() < 2:
        return
    partner.cancel_page_skill()
    page_index = (page_index + 1) % pages.size()
    _draw_page()

func _draw_page() -> void:
    _revision += 1
    for button: TouchCommand in buttons:
        button.release_input()
        remove_child(button)
        button.queue_free()
    buttons.clear()
    if pages.is_empty():
        return
    var source: MonsterData = pages[page_index].form
    var offset: int = pages[page_index].offset
    var skills: Array[MonsterSkill] = _form_skills(source)
    var positions: Array[Vector2] = SkillArcLayout.positions(attack_center, arc_radius,
        arc_start_degrees, arc_end_degrees, button_size, SLOT_COUNT)
    # มีสี่ตำแหน่งคงที่เพื่อสร้าง muscle memory; ช่องที่ไม่มีสกิลปิดใช้งานชัดเจน
    for local_slot: int in range(SLOT_COUNT):
        var slot: int = offset + local_slot
        var skill: MonsterSkill = skills[slot] if slot < skills.size() else null
        var button := HybridCommand.new()
        button.name = "Skill%d" % slot
        button.position = positions[local_slot]
        button.size = button_size
        button.icon = skill.icon if skill != null else null
        button.illustrated = skill != null
        button.art_accent = skill.effect_color.lightened(0.25) if skill != null else Color("eee3c8")
        button.caption = skill.display_name if skill != null else ""
        button.empty_slot = skill == null
        button.locked = skill == null
        button.set_meta("skill_slot", slot)
        button.set_meta("skill_id", skill.id if skill != null else &"")
        if skill != null:
            button.pressed.connect(_request_slot.bind(slot, skill.id, _revision))
        add_child(button)
        buttons.append(button)
    _refresh_buttons()
    page_changed.emit(_page_title(), page_index, pages.size())

func _page_title() -> String:
    var source: MonsterData = pages[page_index].form
    return "%s • %d/%d" % [source.monster_name, page_index + 1, pages.size()]

func _process(delta: float) -> void:
    # อ่าน CD 20 Hz ก็ลื่นพอสำหรับเลข/วงแหวน; ตอนกดตรวจค่าจริงซ้ำเสมอ
    _cooldown_refresh -= delta
    if _cooldown_refresh <= 0.0:
        _cooldown_refresh = 0.05
        _refresh_buttons()

func _refresh_buttons(_evolving: bool = false) -> void:
    if pages.is_empty():
        return
    var source: MonsterData = pages[page_index].form
    for button: TouchCommand in buttons:
        var slot: int = int(button.get_meta("skill_slot", -1))
        if not is_instance_valid(partner) or not is_instance_valid(tamer) or slot < 0 or slot >= _form_skills(source).size():
            button.locked = true
            continue
        var skill: MonsterSkill = _form_skills(source)[slot]
        if skill == null or skill.id != button.get_meta("skill_id"):
            button.locked = true
            continue
        var remaining: float = partner.cooldown_remaining(skill)
        button.locked = not partner.can_use_skill_from_form(source, slot) or partner.evolution_busy or not partner.can_battle() or remaining > 0.0 or partner.digimon_mp < skill.mp_cost
        button.set_caption(skill.display_name)
        (button as HybridCommand).set_cooldown(remaining, skill.cooldown)

func _request_slot(slot: int, expected_id: StringName, expected_revision: int) -> void:
    # ตรวจ revision/Resource/สิทธิ์ซ้ำตอนกด ป้องกัน callback จากปุ่มที่ queue_free ยังไม่จบเฟรม
    if expected_revision != _revision or pages.is_empty() or not is_instance_valid(partner):
        return
    var source: MonsterData = pages[page_index].form
    if not partner.can_use_skill_from_form(source, slot):
        return
    var skill: MonsterSkill = _form_skills(source)[slot]
    if skill.id != expected_id or partner.cooldown_remaining(skill) > 0 or partner.digimon_mp < skill.mp_cost or not partner.can_battle() or partner.evolution_busy:
        return
    # source ต้องเป็น current_form จาก guard ด้านบนเสมอ
    skill_requested.emit(slot)

func release_input() -> void:
    for button: TouchCommand in buttons:
        button.release_input()

func _form_skills(source: MonsterData) -> Array[MonsterSkill]:
    # ต่างร่างคืน Array ว่างเพื่อป้องกันทั้ง UI และ callback เก่าเข้าถึงสกิลข้ามร่าง
    if not is_instance_valid(partner) or source != partner.current_form:
        return []
    return partner.active_skills
