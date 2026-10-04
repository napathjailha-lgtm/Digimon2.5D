class_name LootDropEntry
extends Resource
## หนึ่งแถวของตารางดรอป โอกาสเป็น 0–1 ไม่ใช่เปอร์เซ็นต์ 0–100
@export var item: ItemData
@export_range(0.0, 1.0, 0.01) var chance: float = 0.5
@export_range(1, 999) var min_quantity: int = 1
@export_range(1, 999) var max_quantity: int = 1
