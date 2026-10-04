class_name DynamicScaling
extends RefCounted
## โตตามเลเวลแบบค่อยเป็นค่อยไป แทนการคูณเลเวลเต็มซึ่งแรงเกินคู่หู
## Lv1 คงฐานเดิม: HP เพิ่ม 20% ของฐาน/เลเวล, ATK เพิ่ม 15% ของฐาน/เลเวล
const HP_GROWTH_PER_LEVEL: float = 0.20
const ATTACK_GROWTH_PER_LEVEL: float = 0.15
const BOSS_MULTIPLIER: float = 2.5

static func stats(base_hp: int, base_attack: int, level: int, boss: bool = false) -> Dictionary:
    var bonus_levels: int = clampi(level, 1, EvolutionRules.MAX_LEVEL) - 1
    var hp_factor: float = 1.0 + bonus_levels * HP_GROWTH_PER_LEVEL
    var attack_factor: float = 1.0 + bonus_levels * ATTACK_GROWTH_PER_LEVEL
    var boss_factor: float = BOSS_MULTIPLIER if boss else 1.0
    # คำนวณจากฐานทุกครั้ง ไม่ทบต้น และคูณบอสเพียงครั้งเดียวก่อนปัดเศษ
    return {
        "max_hp": maxi(1, roundi(base_hp * hp_factor * boss_factor)),
        "attack": maxi(1, roundi(base_attack * attack_factor * boss_factor))
    }
