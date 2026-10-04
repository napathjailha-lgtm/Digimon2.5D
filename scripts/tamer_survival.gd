class_name TamerSurvival
extends Node
## ตัวจับเวลาตัวเดียวสำหรับ Survival: สเตตัสจริงอยู่ใน Tamer ไม่เก็บสำเนา HP/หิว/เหนื่อย
## อัปเดตแบบ fixed step 0.25s (4 ครั้ง/วินาที) ลดภาระ Signal/UI และผลไม่ขึ้นกับ FPS
@export_range(0.25, 60.0) var hunger_interval: float = 5.0
@export_range(0.0, 10.0) var hunger_loss: float = 1.0
@export_range(0.25, 30.0) var damage_interval: float = 3.0
@export_range(1, 100) var starvation_damage: int = 5
@export_range(1, 100) var fatigue_damage: int = 5
@export_range(0.0, 20.0) var battle_stamina_loss: float = 1.0
@export_range(0.0, 20.0) var idle_stamina_regen: float = 3.0
@export_range(0.0, 50.0) var rest_stamina_regen: float = 10.0
@export_range(0.25, 30.0) var rest_heal_interval: float = 3.0
@export_range(1, 100) var rest_heal_amount: int = 10
@export_range(0.0, 50.0) var rest_mp_regen: float = 5.0
@export var autosave_enabled: bool = true
@export_range(5.0, 60.0) var autosave_interval: float = 10.0
const STEP: float = 0.25
var tamer: Tamer
var _accumulator: float = 0.0
var _hunger_elapsed: float = 0.0
var _starvation_elapsed: float = 0.0
var _fatigue_elapsed: float = 0.0
var _rest_elapsed: float = 0.0
var _safe_zones: Dictionary = {} # instance ID -> WeakRef; ซ้อนหลายเขตได้ไม่หยุดพักก่อนเวลา
var _app_paused: bool = false
var _skip_resume_delta: bool = false
var _save_elapsed: float = 0.0
var _dirty: bool = false

func _ready() -> void:
    # Inherit จาก Tamer: หยุดพร้อมสนามเมื่อ Inventory/Status/Cutscene pause
    tamer = get_parent() as Tamer
    # จับผลที่เปลี่ยนจากนอก loop ด้วย เช่น ร่ายสกิลแล้วพักแอปก่อนครบ tick ความหิว
    for source_signal: Signal in [tamer.hp_changed, tamer.ds_changed, tamer.survival_changed]:
        source_signal.connect(_mark_dirty)
    if is_instance_valid(tamer.partner):
        for source_signal: Signal in [tamer.partner.hp_changed, tamer.partner.mp_changed]:
            source_signal.connect(_mark_dirty)

func _mark_dirty(_a: Variant = null, _b: Variant = null) -> void:
    # Signal ไม่เขียนเซฟทันที แค่ติดธงไว้ให้ checkpoint/app pause ทำครั้งเดียว
    _dirty = true

func _process(delta: float) -> void:
    # เก็บเศษเวลาไว้ ไม่ใช้จำนวนเฟรมหรือ await หลายตัวที่อาจนับซ้อน
    if _app_paused or not is_instance_valid(tamer) or not is_finite(delta) or delta <= 0:
        return
    if _skip_resume_delta:
        # เฟรมแรกหลังกลับแอปอาจรวมเวลาที่ OS หยุดไว้ ไม่เอา delta นั้นมาทำดาเมจย้อนหลัง
        _skip_resume_delta = false
        return
    _accumulator += delta
    # ถ้าเฟรมกระตุกหนัก จำกัดงานเฟรมนี้ไว้ 32 step แต่ไม่ทิ้งเวลาค้าง
    _drain_steps(32)

func advance(seconds: float) -> void:
    # API สำหรับทดสอบ/จำลองเวลา active play; ไม่อ่านเวลานาฬิกาเพื่อหักความหิวขณะปิดเกม
    if not is_instance_valid(tamer) or not is_finite(seconds) or seconds <= 0:
        return
    _accumulator += seconds
    _drain_steps(-1)

func _drain_steps(limit: int) -> void:
    var steps: int = 0
    while _accumulator + 0.000001 >= STEP and (limit < 0 or steps < limit):
        _accumulator = maxf(0, _accumulator - STEP)
        _tick(STEP)
        steps += 1

func _tick(seconds: float) -> void:
    # ตรวจช่วงต้น step เพื่อไม่คิดดาเมจย้อนหลังทั้งเฟรมเมื่อหิวเพิ่งลดถึงศูนย์ตอนท้าย
    var previous_hp: int = tamer.hp
    var previous_hunger: float = tamer.tamer_hunger
    var previous_stamina: float = tamer.tamer_stamina
    var previous_mp: float = tamer.partner.digimon_mp if is_instance_valid(tamer.partner) else 0
    var resting: bool = is_resting()
    var battling: bool = not resting and is_instance_valid(tamer.partner) and tamer.partner.state == PartnerMonster.State.BATTLE
    var hunger: float = tamer.tamer_hunger
    var stamina: float = tamer.tamer_stamina
    if resting:
        # พักในเมืองหยุดความหิว/ดาเมจ Survival; ไม่เติมอาหารฟรี ค่าหิวเดิมยังคงอยู่
        _starvation_elapsed = 0
        _fatigue_elapsed = 0
        _rest_elapsed += seconds
        if _rest_elapsed + 0.000001 >= rest_heal_interval:
            _rest_elapsed = maxf(0, _rest_elapsed - rest_heal_interval)
            tamer.restore_hp(rest_heal_amount)
        stamina = minf(100, stamina + rest_stamina_regen * seconds)
        if is_instance_valid(tamer.partner):
            tamer.partner.restore_mp(rest_mp_regen * seconds)
    else:
        _rest_elapsed = 0
        if hunger <= 0:
            _starvation_elapsed += seconds
            if _starvation_elapsed + 0.000001 >= damage_interval:
                _starvation_elapsed = maxf(0, _starvation_elapsed - damage_interval)
                tamer.take_survival_damage(starvation_damage)
        else:
            _starvation_elapsed = 0
        if stamina <= 0:
            _fatigue_elapsed += seconds
            if _fatigue_elapsed + 0.000001 >= damage_interval:
                _fatigue_elapsed = maxf(0, _fatigue_elapsed - damage_interval)
                tamer.take_survival_damage(fatigue_damage)
        else:
            _fatigue_elapsed = 0
        _hunger_elapsed += seconds
        if _hunger_elapsed + 0.000001 >= hunger_interval:
            _hunger_elapsed = maxf(0, _hunger_elapsed - hunger_interval)
            hunger = maxf(0, hunger - hunger_loss)
        if battling:
            stamina = maxf(0, stamina - battle_stamina_loss * seconds)
        elif hunger > 0:
            stamina = minf(100, stamina + idle_stamina_regen * seconds)
    # หิวและเหนื่อยศูนย์พร้อมกัน: มีดาเมจ 5+5 ต่อรอบ แยกตัวจับเวลา ไม่หัก HP คู่หู
    tamer.set_survival_values(hunger, stamina)
    tamer.check_battle_permission()
    var values_changed: bool = (
        previous_hp != tamer.hp
        or not is_equal_approx(previous_hunger, tamer.tamer_hunger)
        or not is_equal_approx(previous_stamina, tamer.tamer_stamina)
        or (is_instance_valid(tamer.partner)
            and not is_equal_approx(previous_mp, tamer.partner.digimon_mp))
    )
    _dirty = _dirty or values_changed
    _save_elapsed += seconds
    if _save_elapsed >= autosave_interval:
        _save_elapsed = 0
        _save_if_dirty()

func _save_if_dirty() -> void:
    # เซฟไม่เกินหนึ่งครั้งต่อ 10s เฉพาะค่าที่เปลี่ยน ห้ามเขียน DS ระหว่างจองคัตซีน
    if autosave_enabled and _dirty and is_instance_valid(tamer) and (not is_instance_valid(tamer.partner) or not tamer.partner.evolution_busy):
        tamer.save_party_progress()
        _dirty = false

func set_safe_zone(zone: Node, entered: bool) -> void:
    # ID + WeakRef ไม่ยื้อ Safe Zone เก่าที่ถูกลบ และออกเขต A ขณะยังอยู่ B ยังคงพัก
    if not is_instance_valid(zone):
        return
    if entered:
        _safe_zones[zone.get_instance_id()] = weakref(zone)
    else:
        _safe_zones.erase(zone.get_instance_id())
    if is_resting() and is_instance_valid(tamer.partner):
        tamer.partner.auto_battle = false
        tamer.partner.cancel_battle()
    tamer.survival_changed.emit(tamer.tamer_hunger,tamer.tamer_stamina)

func is_resting() -> bool:
    # เมื่อเขตถูก free โดยไม่ส่ง body_exited ให้เก็บกวาดและไม่พักค้างนอกเมือง
    for id: int in _safe_zones.keys():
        var zone: Node = (_safe_zones[id] as WeakRef).get_ref()
        if not is_instance_valid(zone) or not zone.is_inside_tree() or zone.is_queued_for_deletion():
            _safe_zones.erase(id)
    return not _safe_zones.is_empty()

func get_save_data() -> Dictionary:
    # เก็บเศษตัวจับเวลาเพื่อวาร์ปไม่เริ่มรอบความหิว/ดาเมจใหม่ทุกครั้ง ไม่เก็บ Node เมือง
    return {
        "version": 1,
        "hunger": tamer.tamer_hunger,
        "stamina": tamer.tamer_stamina,
        "cannot_battle": not tamer.can_battle(),
        "step_elapsed": _accumulator,
        "hunger_elapsed": _hunger_elapsed,
        "starvation_elapsed": _starvation_elapsed,
        "fatigue_elapsed": _fatigue_elapsed,
        "rest_elapsed": _rest_elapsed,
    }

func restore_data(data: Dictionary) -> void:
    # เซฟ v18 ไม่มีฟิลด์ Survival: เริ่มหิว/เหนื่อย 100 และไม่หักเวลาขณะปิดเกม
    _safe_zones.clear()
    _save_elapsed = 0
    _dirty = false
    tamer.set_survival_values(_number(data,"hunger",100,100),_number(data,"stamina",100,100))
    _accumulator = _number(data,"step_elapsed",0,60)
    _hunger_elapsed = _number(data,"hunger_elapsed",0,hunger_interval)
    _starvation_elapsed = _number(data,"starvation_elapsed",0,damage_interval)
    _fatigue_elapsed = _number(data,"fatigue_elapsed",0,damage_interval)
    _rest_elapsed = _number(data,"rest_elapsed",0,rest_heal_interval)
    tamer.restore_battle_latch(bool(data.get("cannot_battle",false)))

func _number(data: Dictionary, key: String, fallback: float, maximum: float) -> float:
    # ปฏิเสธชนิด/NaN/Infinity จาก JSON หรือสคริปต์ภายนอกก่อนนำเข้าสมการ
    var value: Variant = data.get(key,fallback)
    if not (value is int or value is float) or not is_finite(float(value)):
        return fallback
    return clampf(float(value),0,maximum)

func _notification(what: int) -> void:
    # ไม่ทำดาเมจย้อนหลังตอนสลับไปใช้แอปอื่น/จอดับบนมือถือ
    if what == NOTIFICATION_APPLICATION_PAUSED:
        _app_paused = true
        _save_if_dirty()
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        _app_paused = false
        _skip_resume_delta = true
