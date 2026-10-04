class_name EquipmentDropEntry
extends Resource
## หนึ่งแถวของ Boss Equipment Drop Table เท่านั้น

@export var item: EquipmentItemData
@export_range(0.0, 1.0, 0.01) var chance: float = 0.10

func roll(rng: RandomNumberGenerator) -> EquipmentItemData:
    # คืน Resource เดิมเมื่อสุ่มผ่าน ไม่มีการสร้างสำเนาและไม่มีจำนวนเก็บใน Resource
    if item == null or chance <= 0.0:
        return null
    return item if rng.randf() < clampf(chance, 0.0, 1.0) else null
