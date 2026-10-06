class_name ShopService
extends RefCounted
## ธุรกรรมร้านค้า: ตรวจเงิน/ของ/ช่องกระเป๋าก่อน commit เสมอ

signal changed
signal feedback(message: String)

func buy(item_id: String, quantity: int = 1) -> bool:
    var item: ItemData = InventoryManager.catalog.find_item(item_id)
    if item == null or not item.shop_sold or item.buy_price <= 0 or quantity <= 0:
        feedback.emit("ไอเทมนี้ไม่มีขายในร้าน")
        return false
    var total: int = item.buy_price * quantity
    if not GameManager.can_afford_bits(total):
        feedback.emit("Bits ไม่พอ")
        return false
    # เพิ่มของก่อน แล้วจึงหักเงิน ถ้ากระเป๋าเต็มจะไม่เสีย Bits
    if not InventoryManager.add_item(item, quantity):
        return false
    if not GameManager.spend_bits(total):
        InventoryManager.remove_item(item_id, quantity)
        return false
    changed.emit()
    _save_player()
    feedback.emit("ซื้อ %s x%d • -%d Bits" % [item.item_name, quantity, total])
    return true

func item_sell_price(item: ItemData) -> int:
    if item == null:
        return 0
    if item.sell_price > 0:
        return item.sell_price
    # Digitama รุ่นเก่าหลายไฟล์ยังไม่มี sell_price ให้ขายได้โดยไม่ต้องแก้ resource ทุกใบ
    if item.item_type == ItemData.ItemType.EGG:
        return 50
    return 0

func equipment_sell_price(item: EquipmentItemData) -> int:
    if item == null:
        return 0
    # อุปกรณ์เป็นของดรอป จึงคำนวณราคารับซื้อจาก rarity + level แทนการเพิ่มราคาใน .tres หลายสิบไฟล์
    var rarity_index: int = clampi(item.rarity, 0, 3)
    var base: Array[int] = [25, 65, 160, 400]
    var per_level: Array[int] = [2, 3, 5, 8]
    return base[rarity_index] + item.required_level * per_level[rarity_index]

func sell(item_id: String, quantity: int = 1) -> bool:
    var item: ItemData = InventoryManager.catalog.find_item(item_id)
    var unit_price: int = item_sell_price(item)
    if item == null or quantity <= 0 or unit_price <= 0:
        feedback.emit("ไอเทมนี้ขายไม่ได้")
        return false
    if InventoryManager.count(item_id) < quantity:
        feedback.emit("จำนวนไอเทมไม่พอ")
        return false
    if not InventoryManager.remove_item(item_id, quantity):
        return false
    var total: int = unit_price * quantity
    GameManager.add_bits(total)
    changed.emit()
    _save_player()
    feedback.emit("ขาย %s x%d • +%d Bits" % [item.item_name, quantity, total])
    return true

func sell_equipment(item_id: StringName, quantity: int = 1) -> bool:
    var player: Node = InventoryManager.player_node()
    if not is_instance_valid(player) or not ("equipment" in player):
        feedback.emit("ไม่พบกระเป๋าอุปกรณ์")
        return false
    var inventory: EquipmentInventory = player.equipment
    var item: EquipmentItemData = inventory.catalog.find_item(item_id) if inventory.catalog != null else null
    var unit_price: int = equipment_sell_price(item)
    if item == null or quantity <= 0 or unit_price <= 0:
        feedback.emit("อุปกรณ์นี้ขายไม่ได้")
        return false
    if inventory.count(item_id) < quantity:
        feedback.emit("จำนวนอุปกรณ์ไม่พอ หรือกำลังสวมใส่อยู่")
        return false
    if not inventory.remove_item(item_id, quantity):
        return false
    var total: int = unit_price * quantity
    GameManager.add_bits(total)
    changed.emit()
    _save_player()
    feedback.emit("ขาย %s x%d • +%d Bits" % [item.item_name, quantity, total])
    return true

func _save_player() -> void:
    # Inventory.changed อาจเซฟก่อน Bits เปลี่ยน จึง commit snapshot อีกรอบหลัง transaction ครบ
    var player: Node = InventoryManager.player_node()
    if is_instance_valid(player) and player.has_method("save_party_progress"):
        player.call("save_party_progress")
