class_name ItemData
extends Resource
## ต้นแบบไอเทมเท่านั้น จำนวนจริงอยู่ใน InventoryManager

enum ItemType { CONSUMABLE, QUEST_ITEM, EGG, MATERIAL, DATA_CHIP }
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

@export_group("ร้านค้า")
@export var shop_sold: bool = false
@export_range(0, 999999) var buy_price: int = 0
@export_range(0, 999999) var sell_price: int = 0

@export_group("Data Chip")
@export var chip_family: StringName = &""

@export_group("Core Egg / Incubator")
@export var egg_partner_id: StringName = &""
@export var required_chip_id: String = ""
@export_range(1, 5) var inject_goal: int = 5
@export_range(0.0, 1.0, 0.01) var inject_success_chance: float = 0.72
@export_range(0.0, 1.0, 0.01) var egg_break_chance: float = 0.12

func type_label() -> String:
    match item_type:
        ItemType.CONSUMABLE:
            return ["ฟื้น HP คู่หู","อาหาร Warden","ฟื้น MP คู่หู"][clampi(effect_type,0,2)]
        ItemType.QUEST_ITEM:
            return "ไอเทมเควสต์"
        ItemType.EGG:
            return "Core Egg"
        ItemType.MATERIAL:
            return "วัตถุดิบ"
        ItemType.DATA_CHIP:
            return "Data Chip"
    return "Item"
