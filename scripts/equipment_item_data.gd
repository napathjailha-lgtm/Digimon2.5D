class_name EquipmentItemData
extends Resource
## ต้นแบบไอเทม .tres อ่านร่วมกันได้: ห้ามเก็บจำนวนหรือสถานะสวมใส่ใน Resource
@export var id: StringName
@export var item_name: String = "Equipment"
@export_multiline var description: String = ""
@export var slot: StringName = &"head"
@export_range(1, 99) var required_level: int = 1
@export_enum("Common", "Rare", "Epic") var rarity: int = 0
@export var icon: Texture2D
@export_group("โบนัสเทมเมอร์")
@export_range(0, 9999) var hp_bonus: int = 0
@export_range(0, 9999) var ds_bonus: int = 0
@export_range(0, 999) var defense_bonus: int = 0
@export_range(0.0, 200.0) var speed_bonus: float = 0.0
@export_group("โบนัสคู่หูจาก Digivice / Chip")
@export_range(0, 9999) var partner_hp_bonus: int = 0
@export_range(0, 999) var partner_attack_bonus: int = 0
@export_range(0.0, 200.0) var partner_speed_bonus: float = 0.0

func bonuses() -> Dictionary:
    # คืนสำเนาค่าตัวเลขเพื่อใช้คำนวณใหม่ ไม่แก้ต้นแบบด้วยโบนัสสะสม
    return {"hp": hp_bonus, "ds": ds_bonus, "defense": defense_bonus,
        "speed": speed_bonus, "partner_hp": partner_hp_bonus,
        "partner_attack": partner_attack_bonus, "partner_speed": partner_speed_bonus}

func fits_slot(slot_id: StringName) -> bool:
    # ชิปชนิดเดียวกันใช้ได้ทั้งสองช่อง ส่วนอุปกรณ์อื่นต้องตรงช่อง
    return slot == slot_id or (slot == &"chip" and slot_id in [&"chip_a", &"chip_b"])

func rarity_color() -> Color:
    return [Color("93b9cc"), Color("49cbe9"), Color("c799ff")][clampi(rarity, 0, 2)]
