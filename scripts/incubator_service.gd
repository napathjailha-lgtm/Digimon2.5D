class_name IncubatorService
extends RefCounted
## เครื่องฟักไข่แบบกำหนดสายพันธุ์แน่นอนเมื่อ 5/5
## ความสุ่มมีเฉพาะ Inject สำเร็จ/ล้มเหลว/ไข่แตก ไม่สุ่ม Creature ปลายทาง

signal changed
signal feedback(message: String)
signal hatch_completed(partner_id: StringName)

var roster: PartnerRoster
var rng := RandomNumberGenerator.new()

func configure(owner_roster: PartnerRoster) -> void:
    roster = owner_roster
    rng.randomize()

func selected_egg_id() -> String:
    return str(GameManager.incubator_state.get("egg_id", ""))

func inject_level() -> int:
    return clampi(int(GameManager.incubator_state.get("inject_level", 0)), 0, 5)

func select_egg(item_id: String) -> bool:
    var item: ItemData = InventoryManager.catalog.find_item(item_id)
    if item == null or item.item_type != ItemData.ItemType.EGG or item.egg_partner_id == &"":
        feedback.emit("ไข่นี้ไม่มีข้อมูลสายพันธุ์ที่แน่นอน")
        return false
    if InventoryManager.count(item_id) <= 0:
        feedback.emit("ไม่มี Core Egg ใบนี้ในกระเป๋า")
        return false
    GameManager.incubator_state = {"egg_id": item_id, "inject_level": 0}
    changed.emit()
    feedback.emit("วาง %s ลงเครื่องฟัก" % item.item_name)
    return true

func clear_selection() -> void:
    GameManager.incubator_state.clear()
    changed.emit()

func inject_data() -> bool:
    var egg: ItemData = InventoryManager.catalog.find_item(selected_egg_id())
    if egg == null or egg.item_type != ItemData.ItemType.EGG:
        feedback.emit("เลือก Core Egg ก่อน")
        return false
    if InventoryManager.count(egg.item_id) <= 0:
        clear_selection()
        feedback.emit("Core Egg ไม่อยู่ในกระเป๋าแล้ว")
        return false
    if egg.required_chip_id.is_empty() or InventoryManager.count(egg.required_chip_id) <= 0:
        feedback.emit("ต้องใช้ Data Chip ที่ตรงกับไข่")
        return false

    # Data Chip ถูกใช้ทุกครั้งที่กด Inject ไม่ว่าจะสำเร็จหรือล้มเหลว
    if not InventoryManager.remove_item(egg.required_chip_id, 1):
        return false

    var roll: float = rng.randf()
    var break_limit: float = clampf(egg.egg_break_chance, 0.0, 1.0)
    var success_limit: float = clampf(break_limit + egg.inject_success_chance, 0.0, 1.0)

    if roll < break_limit:
        InventoryManager.remove_item(egg.item_id, 1)
        GameManager.incubator_state.clear()
        changed.emit()
        feedback.emit("Inject ล้มเหลวรุนแรง • Core Egg แตก")
        return false
    if roll >= success_limit:
        changed.emit()
        feedback.emit("Inject ล้มเหลว • ไข่ยังปลอดภัย")
        return false

    var level: int = mini(egg.inject_goal, inject_level() + 1)
    GameManager.incubator_state["inject_level"] = level
    changed.emit()
    feedback.emit("Inject สำเร็จ %d/%d" % [level, egg.inject_goal])
    if level >= egg.inject_goal:
        return _complete_hatch(egg)
    return true

func _complete_hatch(egg: ItemData) -> bool:
    # ปลายทางมาจาก egg_partner_id โดยตรง ไม่มี pick_random()
    if not is_instance_valid(roster) or roster.family(egg.egg_partner_id) == null:
        feedback.emit("ไม่พบข้อมูล Creature ของไข่นี้")
        return false
    if not roster.add_hatched_to_storage(egg.egg_partner_id):
        feedback.emit("เพิ่ม Creature เข้าคลังไม่สำเร็จ")
        return false
    InventoryManager.remove_item(egg.item_id, 1)
    GameManager.incubator_state.clear()
    changed.emit()
    # UI รับ signal นี้เพื่อเล่น white flash + SFX ในเฟรมเดียวกับผลฟักสำเร็จ
    hatch_completed.emit(egg.egg_partner_id)
    feedback.emit("ฟักสำเร็จ: %s • ส่งเข้า Creature Archive" % roster.family(egg.egg_partner_id).display_name)
    return true
