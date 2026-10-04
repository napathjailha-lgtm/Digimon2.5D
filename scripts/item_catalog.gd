class_name ItemCatalog
extends Resource
## รวมฐานข้อมูลไว้จุดเดียว โหลดจาก ID เมื่อคืนเซฟ ไม่บันทึก Texture ลง JSON
@export var items: Array[ItemData] = []

func find_item(id: String) -> ItemData:
    # คืน null เมื่อ ID ไม่อยู่ในฐานข้อมูล เพื่อปฏิเสธไอเทม/เซฟที่ไม่รู้จัก
    for item: ItemData in items:
        if item != null and item.item_id == id:
            return item
    return null
