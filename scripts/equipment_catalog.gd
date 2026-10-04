class_name EquipmentCatalog
extends Resource
## เพิ่มไอเทมโดยสร้าง .tres แล้วใส่ในรายการนี้ ไม่ต้องแก้โค้ด UI
@export var items: Array[EquipmentItemData] = []

func find_item(item_id: StringName) -> EquipmentItemData:
    for item: EquipmentItemData in items:
        if item != null and item.id == item_id:
            return item
    return null
