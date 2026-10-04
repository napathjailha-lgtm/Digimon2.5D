class_name EquipmentItemData
extends EquipmentData
## Compatibility layer ของระบบอุปกรณ์เดิม เพิ่มค่าที่ใช้กับ Digivice/Partner โดยไม่ทำลาย .tres เก่า

@export_group("โบนัสเสริม Tamer")
@export_range(0, 9999) var ds_bonus: int = 0
@export_range(0.0, 200.0) var speed_bonus: float = 0.0

@export_group("โบนัสคู่หูจาก Digivice / Chip")
@export_range(0, 9999) var partner_hp_bonus: int = 0
@export_range(0, 999) var partner_attack_bonus: int = 0
@export_range(0.0, 200.0) var partner_speed_bonus: float = 0.0

func bonuses() -> Dictionary:
    # รวมค่าจากอุปกรณ์ทุกชิ้นใหม่ทุกครั้ง ป้องกันโบนัสสะสมซ้ำจากการ Refresh UI
    return {
        "attack": attack_bonus,
        "hp": hp_bonus,
        "ds": ds_bonus,
        "defense": defense_bonus,
        "critical": critical_chance_bonus,
        "speed": speed_bonus,
        "partner_hp": partner_hp_bonus,
        "partner_attack": partner_attack_bonus,
        "partner_speed": partner_speed_bonus
    }
