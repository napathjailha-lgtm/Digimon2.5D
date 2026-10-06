class_name EquipmentInventory
extends RefCounted
## สถานะกระเป๋าต่อผู้เล่น แยกจาก Resource; ใส่/ถอดเป็นธุรกรรมเดียวก่อนส่ง changed
signal changed
signal feedback(message: String)
const SLOTS: Array[StringName] = [&"head", &"face", &"chest", &"legs", &"gloves", &"boots", &"back", &"neck", &"ring", &"bracelet", &"belt", &"charm", &"device", &"chip_a", &"chip_b"]
const LABELS: Dictionary = {"head":"ศีรษะ", "face":"แว่นตา", "chest":"เสื้อ", "legs":"กางเกง", "gloves":"ถุงมือ", "boots":"รองเท้า", "back":"หลัง", "neck":"สร้อย", "ring":"แหวน", "bracelet":"ข้อมือ", "belt":"เข็มขัด", "charm":"เครื่องราง", "device":"Digivice", "chip_a":"Chip A", "chip_b":"Chip B"}
const CATALOG_PATH: String = "res://data/equipment/catalog.tres"
const SAVE_VERSION: int = 2
var catalog: EquipmentCatalog
var bag: Dictionary = {}
var equipped: Dictionary = {}
var owner: Node # ใช้ Node เพื่อไม่สร้างวงจร dependency กลับไปยังสคริปต์ Tamer

func initialize(tamer: Node) -> void:
    # เริ่มเกมโดยไม่มีอุปกรณ์ใด ๆ ตามกติกา Boss-Exclusive
    # Catalog เป็นฐานข้อมูลอย่างเดียว ของจริงเข้ากระเป๋าเมื่อ World Boss ดรอป
    owner = tamer
    catalog = load(CATALOG_PATH) as EquipmentCatalog
    bag.clear()
    equipped.clear()

func item_at(slot_id: StringName) -> EquipmentItemData:
    return catalog.find_item(StringName(equipped.get(String(slot_id), ""))) if catalog != null else null

func count(item_id: StringName) -> int:
    return int(bag.get(String(item_id), 0))

func _can_change() -> bool:
    # ไม่เปลี่ยนสเตตัสระหว่างคัตซีนที่จอง DS / ร่างไว้แล้ว
    if not is_instance_valid(owner):
        return false
    if is_instance_valid(owner.partner) and owner.partner.evolution_busy:
        feedback.emit("รอให้คัตซีนเปลี่ยนร่างจบก่อน")
        return false
    return true

func put_on(item_id: StringName, preferred_slot: StringName = &"") -> bool:
    # ตรวจทุกเงื่อนไขก่อนลดจำนวน ป้องกันไอเทมหายเมื่อใส่ไม่ได้
    if not _can_change():
        return false
    var item: EquipmentItemData = catalog.find_item(item_id)
    if item == null or count(item_id) <= 0:
        feedback.emit("ไม่มีไอเทมนี้ในกระเป๋า")
        return false
    if owner.progress.level < item.required_level:
        feedback.emit("ต้องมี Tamer Lv%d ก่อนสวมใส่" % item.required_level)
        return false
    var destination: StringName = preferred_slot
    if destination == &"":
        destination = item.slot
        if item.slot == &"chip":
            destination = &"chip_a" if item_at(&"chip_a") == null else &"chip_b"
    if destination not in SLOTS or not item.fits_slot(destination):
        feedback.emit("ไอเทมไม่ตรงกับช่องอุปกรณ์")
        return false
    var previous: EquipmentItemData = item_at(destination)
    if previous != null:
        bag[String(previous.id)] = count(previous.id) + 1
    bag[String(item_id)] = count(item_id) - 1
    equipped[String(destination)] = String(item_id)
    changed.emit()
    feedback.emit("สวมใส่ " + item.item_name)
    return true

func take_off(slot_id: StringName) -> bool:
    # คืนไอเทมเข้ากระเป๋าก่อนแจ้ง UI ไม่มีการสร้างสำเนา Resource ใหม่
    if not _can_change():
        return false
    var item: EquipmentItemData = item_at(slot_id)
    if item == null:
        return false
    bag[String(item.id)] = count(item.id) + 1
    equipped.erase(String(slot_id))
    changed.emit()
    feedback.emit("ถอด " + item.item_name)
    return true

func grant_item(item_id: StringName, quantity: int = 1) -> bool:
    # ใช้ต่อยอดรางวัลเควสต์ / ดรอปของ; ไม่รับ ID ที่ไม่มีใน catalog
    if catalog.find_item(item_id) == null or quantity <= 0:
        return false
    bag[String(item_id)] = mini(999, count(item_id) + quantity)
    changed.emit()
    return true

func remove_item(item_id: StringName, quantity: int = 1) -> bool:
    # ร้านค้า/ระบบภายนอกตัดได้เฉพาะของที่อยู่ใน bag; ของที่สวมอยู่ต้องถอดก่อน
    if not _can_change() or catalog == null or catalog.find_item(item_id) == null or quantity <= 0:
        return false
    var owned: int = count(item_id)
    if owned < quantity:
        feedback.emit("จำนวนอุปกรณ์ไม่พอ")
        return false
    var left: int = owned - quantity
    if left <= 0:
        bag.erase(String(item_id))
    else:
        bag[String(item_id)] = left
    changed.emit()
    return true

func total_bonuses() -> Dictionary:
    # รวมใหม่จากช่องจริงทุกครั้ง ไม่เพิ่มซ้ำเมื่อรีเฟรช UI / เปลี่ยนร่าง
    var result: Dictionary = {"attack":0, "hp":0, "ds":0, "defense":0, "critical":0.0, "speed":0.0, "partner_hp":0, "partner_attack":0, "partner_speed":0.0,
        "str":0, "dex":0, "int":0, "vit":0, "agi":0}
    for slot_id: StringName in SLOTS:
        var item: EquipmentItemData = item_at(slot_id)
        if item != null:
            var values: Dictionary = item.bonuses()
            for key: String in result:
                result[key] += values[key]
    return result

func get_save_data() -> Dictionary:
    # v2 = ไม่มี starter gear อีกต่อไป ทุกชิ้นต้องมาจาก drop/reward หลังระบบใหม่
    return {"version":SAVE_VERSION, "bag":bag.duplicate(), "equipped":equipped.duplicate()}

func restore_data(data: Dictionary) -> void:
    # Migration ครั้งเดียว: v1 เป็นยุคที่ prototype แจก starter gear จึงไม่ยกของเดิมเข้ากติกาใหม่
    bag.clear()
    equipped.clear()
    if int(data.get("version", 0)) < SAVE_VERSION:
        return
    var saved_bag: Variant = data.get("bag", {})
    if saved_bag is Dictionary:
        for key: Variant in saved_bag:
            var quantity: Variant = saved_bag[key]
            if catalog.find_item(StringName(str(key))) != null and (quantity is int or quantity is float) and is_finite(float(quantity)):
                bag[str(key)] = clampi(int(quantity), 0, 999)
    var saved_slots: Variant = data.get("equipped", {})
    if saved_slots is Dictionary:
        for slot_id: StringName in SLOTS:
            var item: EquipmentItemData = catalog.find_item(StringName(str(saved_slots.get(String(slot_id), ""))))
            if item == null or not item.fits_slot(slot_id):
                continue
            if owner.progress.level < item.required_level:
                bag[String(item.id)] = mini(999, count(item.id) + 1)
            else:
                equipped[String(slot_id)] = String(item.id)
    # โหลดไม่ส่ง changed เพราะ World ต้องคืน HP/DS/ร่างให้ครบก่อนเซฟครั้งใหม่
