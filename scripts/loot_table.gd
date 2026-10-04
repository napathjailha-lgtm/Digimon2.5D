class_name LootTable
extends Resource
## สุ่มอิสระแต่ละแถว: ศัตรูหนึ่งตัวอาจดรอปหลายชนิดหรือไม่ดรอปเลย
@export var entries: Array[LootDropEntry] = []

func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
    # รับ RNG ภายนอกเพื่อกำหนด seed ทดสอบได้ และไม่แก้ไขค่าใน Resource
    var result: Array[Dictionary] = []
    for entry: LootDropEntry in entries:
        if entry == null or entry.item == null or entry.item.item_id.is_empty():
            continue
        var probability: float = clampf(entry.chance, 0.0, 1.0)
        if probability <= 0.0 or rng.randf() >= probability:
            continue
        var minimum: int = clampi(entry.min_quantity, 1, 999)
        var maximum: int = clampi(entry.max_quantity, minimum, 999)
        result.append({"item":entry.item, "quantity":rng.randi_range(minimum, maximum)})
    return result
