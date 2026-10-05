class_name CharacterProgress
extends Node
## Component เลเวลของแต่ละตัวละคร ไม่แก้ MonsterData Resource ที่แชร์กัน
signal progress_changed(level: int, current_exp: int, max_exp: int)
signal leveled_up(new_level: int)

enum ExpCurve { TAMER, DIGIMON }

@export_range(1, 999) var level_cap: int = 99
@export var exp_curve: ExpCurve = ExpCurve.TAMER
@export var hp_per_level: int = 50
@export var attack_per_level: int = 5
@export var speed_per_level: float = 1.0
var level: int = 1
var current_exp: int = 0
var max_exp: int = 100
var base_stats: Dictionary = {"max_hp": 120, "attack": 15, "speed": 240.0}


func _ready() -> void:
    max_exp = exp_required(level)


func set_base_stats(hp: int, attack: int, speed: float) -> void:
    # ร่างใหม่เปลี่ยนเฉพาะฐาน เลเวลและ EXP เดิมยังอยู่
    base_stats = {"max_hp": maxi(1, hp), "attack": maxi(0, attack), "speed": maxf(1.0, speed)}

func get_effective_stats() -> Dictionary:
    # คำนวณจากฐานเสมอ ป้องกันบวกโบนัสซ้ำทุกครั้งที่เปลี่ยนร่าง
    var bonus_levels: int = level - 1
    return {
        "max_hp": int(base_stats.max_hp) + bonus_levels * hp_per_level,
        "attack": int(base_stats.attack) + bonus_levels * attack_per_level,
        "speed": float(base_stats.speed) + bonus_levels * speed_per_level
    }

func exp_required(at_level: int) -> int:
    var safe_level: int = maxi(1, at_level)
    match exp_curve:
        ExpCurve.DIGIMON:
            return _digimon_exp_required(safe_level)
        _:
            return _tamer_exp_required(safe_level)


func _tamer_exp_required(at_level: int) -> int:
    # Tamer คง curve เดิมเพื่อไม่กระทบ progression/เซฟเดิม
    # Lv1 100, Lv15 800, Lv60 3050
    return 100 + (at_level - 1) * 50


func _digimon_exp_required(at_level: int) -> int:
    # Rookie 1-14 เรียนรู้เกมด้วย pace เดียวกับ Tamer
    # หลัง Champion (Lv15) curve จะชันขึ้นเรื่อย ๆ เพื่อให้ Ultimate/Mega มีคุณค่า
    # Lv15 800, Lv30 2225, Lv60 7775, Lv89 16562
    if at_level < 15:
        return _tamer_exp_required(at_level)
    var post_champion: int = at_level - 15
    return 800 + 65 * post_champion + 2 * post_champion * post_champion

func add_exp(amount: int) -> void:
    # ไม่รับ EXP ติดลบ และหยุดสะสมเมื่อถึงเพดาน
    if amount <= 0 or level >= level_cap:
        return
    current_exp += amount
    check_level_up()

func check_level_up() -> void:
    # ใช้ while เพื่อรองรับรางวัลครั้งเดียวขึ้นหลายเลเวล เก็บ EXP ส่วนเกินไว้
    max_exp = exp_required(level)
    while level < level_cap and current_exp >= max_exp:
        current_exp -= max_exp
        level += 1
        max_exp = exp_required(level)
        leveled_up.emit(level)
    if level >= level_cap:
        current_exp = 0
    progress_changed.emit(level, current_exp, max_exp)

func get_save_data() -> Dictionary:
    # บันทึกเฉพาะความก้าวหน้า ฐานสเตตัสมาจากร่างที่โหลด
    return {"level": level, "exp": current_exp}

func restore_data(data: Dictionary) -> void:
    # การโหลด Save ไม่ส่ง leveled_up จึงไม่แจก HP/เอฟเฟกต์ซ้ำ
    level = clampi(int(data.get("level", 1)), 1, level_cap)
    max_exp = exp_required(level)
    current_exp = clampi(int(data.get("exp", 0)), 0, max_exp - 1) if level < level_cap else 0
    progress_changed.emit(level, current_exp, max_exp)
