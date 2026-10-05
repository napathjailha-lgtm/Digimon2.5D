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

static func minimum_level_for_form_index(index: int, form: MonsterData = null) -> int:
    # Base forms are always available, including Tailmon (Champion).
    # Later forms unlock by their actual stage, not their position in a short line.
    if index < 0:
        return 999
    if index == 0:
        return 1
    var stage: int = int(form.evolution_stage) if form != null else index
    match stage:
        0: return 1
        1: return 15
        2: return 60
        3: return 90
        _: return 999

static func can_use_form(level: int, form_index: int, form: MonsterData = null) -> bool:
    return form_index >= 0 and clampi(level, 1, MAX_LEVEL) >= minimum_level_for_form_index(form_index, form)
