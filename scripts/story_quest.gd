class_name StoryQuest
extends Resource
## ข้อมูลต้นแบบเควสต์หนึ่งขั้น ไม่เก็บ Progress ของผู้เล่นใน Resource

enum Objective { TALK, KILL, REACH }
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var zone_id: StringName
@export var objective: Objective = Objective.TALK
@export var target_id: StringName
@export_range(1, 999) var required_count: int = 1
@export_range(1, 99) var recommended_level: int = 1
@export_group("รางวัล")
@export_range(0, 100000) var reward_exp: int = 0
@export_range(0, 1000000) var reward_bits: int = 0
@export_group("ปลดล็อก")
@export var unlock_flags: Array[StringName] = []
@export var unlock_zones: Array[StringName] = []
# -1 = ไม่มีรางวัลเพิ่มระดับร่าง; 0 Rookie / 1 Champion / 2 Ultimate / 3 Mega
@export_enum("None:-1", "Rookie:0", "Champion:1", "Ultimate:2", "Mega:3") var unlock_stage: int = -1
