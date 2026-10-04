class_name TamerModelData
extends Resource
## ต้นแบบ Tamer 5 แบบ แยกจากข้อมูลเซฟของตัวละครจริง
@export var id: StringName
@export var display_name: String
@export var gender: String = "ชาย"
@export var play_style: String = "สายบาลานซ์"
@export_multiline var description: String
@export var portrait: Texture2D
## เปลี่ยนเป็นชุดเดิน 4 ทิศของแต่ละโมเดลได้โดยไม่แก้ระบบเลือกตัวละคร
@export var sprite_frames: SpriteFrames
@export var sprite_scale: Vector2 = Vector2(0.25, 0.25)
@export var base_hp: int = 200
@export var base_ds: float = 100.0
@export var move_speed: float = 190.0
