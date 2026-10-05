class_name LootTable
extends Resource
## ไอเทมทั่วไปสุ่มอิสระเหมือนเดิม
## Core Egg ทุกชนิดใช้ช่องสุ่มร่วมกัน จึงดรอปไข่ได้สูงสุด 1 ใบต่อมอนสเตอร์หนึ่งตัว

@export var entries: Array[LootDropEntry] = []

func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var egg_entries: Array[LootDropEntry] = []

    for entry: LootDropEntry in entries:
        if entry == null or entry.item == null or entry.item.item_id.is_empty():
            continue

        # แยก Core Egg ออกจาก loot ปกติ เพื่อไม่ให้มอนตัวเดียวแตกไข่หลายสายพันธุ์พร้อมกัน
        if entry.item.item_type == ItemData.ItemType.EGG:
            egg_entries.append(entry)
            continue

        var probability: float = clampf(entry.chance, 0.0, 1.0)
        if probability <= 0.0 or rng.randf() >= probability:
            continue

        var minimum: int = clampi(entry.min_quantity, 1, 999)
        var maximum: int = clampi(entry.max_quantity, minimum, 999)
        result.append({
            "item": entry.item,
            "quantity": rng.randi_range(minimum, maximum)
        })

    _roll_one_core_egg(rng, egg_entries, result)
    return result

func _roll_one_core_egg(rng: RandomNumberGenerator, egg_entries: Array[LootDropEntry], result: Array[Dictionary]) -> void:
    # chance ของ Core Egg แต่ละใบคือโอกาสจริง เช่น 0.02 = 2%
    # รวมกันเป็น pool เดียว เช่น 5 ใบ x 2% = มีโอกาสได้ไข่รวม 10% แต่ได้สูงสุดหนึ่งชนิด
    if egg_entries.is_empty():
        return

    var total_chance: float = 0.0
    for entry: LootDropEntry in egg_entries:
        total_chance += clampf(entry.chance, 0.0, 1.0)
    total_chance = clampf(total_chance, 0.0, 1.0)

    var roll_value: float = rng.randf()
    if roll_value >= total_chance:
        return

    var cumulative: float = 0.0
    for entry: LootDropEntry in egg_entries:
        cumulative += clampf(entry.chance, 0.0, 1.0)
        if roll_value < cumulative:
            var minimum: int = clampi(entry.min_quantity, 1, 999)
            var maximum: int = clampi(entry.max_quantity, minimum, 999)
            result.append({
                "item": entry.item,
                "quantity": rng.randi_range(minimum, maximum)
            })
            return
