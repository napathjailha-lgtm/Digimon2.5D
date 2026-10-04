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

func sell(item_id: String, quantity: int = 1) -> bool:
    var item: ItemData = InventoryManager.catalog.find_item(item_id)
    if item == null or quantity <= 0 or item.sell_price <= 0:
        feedback.emit("ไอเทมนี้ขายไม่ได้")
        return false
    if item.item_type == ItemData.ItemType.EGG:
        feedback.emit("Digitama ขายให้ร้านทั่วไปไม่ได้")
        return false
    if InventoryManager.count(item_id) < quantity:
        feedback.emit("จำนวนไอเทมไม่พอ")
        return false
    if not InventoryManager.remove_item(item_id, quantity):
        return false
    GameManager.add_bits(item.sell_price * quantity)
    changed.emit()
    _save_player()
    feedback.emit("ขาย %s x%d • +%d Bits" % [item.item_name, quantity, item.sell_price * quantity])
    return true

func _save_player() -> void:
    # Inventory.changed อาจเซฟก่อน Bits เปลี่ยน จึง commit snapshot อีกรอบหลัง transaction ครบ
    var player: Node = InventoryManager.player_node()
    if is_instance_valid(player) and player.has_method("save_party_progress"):
        player.call("save_party_progress")
