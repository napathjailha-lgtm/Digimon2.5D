class_name EvolutionRules
extends RefCounted
## กฎวิวัฒนาการตามเลเวลของคู่หู โดยไม่ผูกกับเควสต์
const MAX_LEVEL: int = 90

static func max_form_index_for_level(level: int) -> int:
    var safe_level := clampi(level, 1, MAX_LEVEL)
    if safe_level >= 90:
        return 3 # Mega
    if safe_level >= 60:
        return 2 # Ultimate
    if safe_level >= 15:
        return 1 # Champion
    return 0 # Rookie

static func minimum_level_for_form_index(index: int) -> int:
    match index:
        0: return 1
        1: return 15
        2: return 60
        3: return 90
        _: return 999

static func can_use_form(level: int, form_index: int) -> bool:
    return form_index >= 0 and form_index <= max_form_index_for_level(level)
