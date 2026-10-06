class_name StarterPartnerData
extends Resource
## สายวิวัฒนาการ: Rookie → Champion → Ultimate → Mega (ถ้ามีข้อมูล)
## ต่อท้าย Array เพื่อรักษา ID และลำดับร่างเดิมในเซฟ
@export var id: StringName
@export var display_name: String
@export var attribute_name: String
@export var element_name: String
@export_multiline var description: String
@export var portrait: Texture2D
## false = หาได้จากไข่/กิจกรรมเท่านั้น และห้ามถูกสุ่มเป็น Starter
@export var starter_available: bool = true
@export var forms: Array[MonsterData] = []

func evolution_path() -> String:
    var names: PackedStringArray = []
    for form: MonsterData in forms:
        if form != null:
            names.append(form.monster_name)
    return " → ".join(names)
