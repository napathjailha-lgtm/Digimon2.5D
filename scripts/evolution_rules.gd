class_name EvolutionRules
extends RefCounted
## แหล่งกติกากลาง: การโหลดเซฟ/ปุ่ม/การเปลี่ยนร่างใช้ตารางเดียวกัน
const MAX_LEVEL: int = 90
const FORM_LEVELS: Array[int] = [1, 15, 60, 90]
const DS_DRAIN_MULTIPLIER: float = 0.5
const EVOLUTION_PATHS: Dictionary = {
    "agumon": ["Agumon", "Greymon", "MetalGreymon", "WarGreymon"],
    "gabumon": ["Gabumon", "Garurumon", "WereGarurumon", "MetalGarurumon"]
}

static func max_form_index_for_level(level: int) -> int:
    for index: int in range(FORM_LEVELS.size() - 1, -1, -1):
        if clampi(level, 1, MAX_LEVEL) >= FORM_LEVELS[index]:
            return index
    return 0

static func minimum_level_for_form_index(index: int) -> int:
    return FORM_LEVELS[index] if index >= 0 and index < FORM_LEVELS.size() else 999

static func can_use_form(level: int, form_index: int) -> bool:
    return form_index >= 0 and form_index <= max_form_index_for_level(level)

static func ds_drain(original_rate: float) -> float:
    # ลดเฉพาะอัตราคงร่างต่อวินาที ไม่แก้ Resource ร่วม ไม่ลดซ้ำตอนเปลี่ยนร่าง
    # delta ใช้ใน PartnerMonster ทำให้ 30/60/120 FPS ใช้ DS เท่ากันตามเวลาจริง
    return maxf(0.0, original_rate) * DS_DRAIN_MULTIPLIER
