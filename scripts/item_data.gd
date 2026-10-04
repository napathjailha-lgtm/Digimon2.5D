class_name ItemData
extends Resource
## ข้อมูลต้นแบบเท่านั้น: จำนวนที่ถืออยู่ต้องเก็บใน InventoryManager ไม่แก้ Resource ร่วมกัน
enum ItemType { CONSUMABLE, QUEST_ITEM, EGG }
enum EffectType { PARTNER_HP, TAMER_FOOD, PARTNER_MP }
@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var item_texture: Texture2D
@export_multiline var description: String = ""
@export var effect_value: int = 0
@export var effect_type: EffectType = EffectType.PARTNER_HP
@export_range(0, 9999) var tamer_hp_restore: int = 0
@export_range(0.0, 100.0) var tamer_stamina_restore: float = 0.0

func type_label() -> String:
    # ไอเทมเก่า default เป็นเนื้อคู่หู; อาหาร Tamer/น้ำ MP ใช้ EffectType แยกจาก ItemType
    if item_type == ItemType.CONSUMABLE:
        return ["ฟื้น HP คู่หู","อาหาร Tamer","ฟื้น MP คู่หู"][clampi(effect_type,0,2)]
    return "ไอเทมเควสต์" if item_type == ItemType.QUEST_ITEM else "ไข่ดิจิมอน"
