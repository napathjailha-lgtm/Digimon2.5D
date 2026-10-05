class_name EquipmentData
extends Resource
## ข้อมูลต้นแบบอุปกรณ์ร่วมของ Tamer/Digimon
## Resource เก็บเฉพาะค่าคงที่ จำนวนและสถานะสวมใส่อยู่ใน EquipmentInventory

@export var id: StringName = &""
@export var item_name: String = "Equipment"
@export_multiline var description: String = ""
@export var slot: StringName = &"head"
@export_range(1, 99) var required_level: int = 1
@export_enum("Common", "Rare", "Epic", "Legendary") var rarity: int = 0
@export var icon: Texture2D

@export_group("ค่าสเตตัสหลัก")
@export_range(0, 9999) var attack_bonus: int = 0
@export_range(0, 9999) var hp_bonus: int = 0
@export_range(0, 999) var defense_bonus: int = 0
@export_range(0.0, 100.0, 0.1) var critical_chance_bonus: float = 0.0

func fits_slot(slot_id: StringName) -> bool:
    # Chip ใช้ได้สองช่อง ส่วนอุปกรณ์ชนิดอื่นต้องตรง slot ที่ระบุ
    return slot == slot_id or (slot == &"chip" and slot_id in [&"chip_a", &"chip_b"])

func rarity_color() -> Color:
    return [Color("93b9cc"), Color("49cbe9"), Color("c799ff"), Color("ffbf55")][clampi(rarity, 0, 3)]

func rarity_name() -> String:
    return ["Common", "Rare", "Epic", "Legendary"][clampi(rarity, 0, 3)]
