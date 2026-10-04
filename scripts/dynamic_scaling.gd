class_name DynamicScaling
extends RefCounted
## แปรผันตรง: HP(L)=HP(1)*L และ ATK(L)=ATK(1)*L
## บอสใช้ฐาน Lv1 เดียวกับ wild แล้วคูณ 2.5 เพียงครั้งเดียว
const BOSS_MULTIPLIER: float = 2.5

static func stats(base_hp: int, base_attack: int, level: int, boss: bool = false) -> Dictionary:
    var factor: float = float(clampi(level, 1, EvolutionRules.MAX_LEVEL))
    if boss:
        factor *= BOSS_MULTIPLIER
    return {"max_hp": maxi(1, roundi(base_hp * factor)), "attack": maxi(1, roundi(base_attack * factor))}
