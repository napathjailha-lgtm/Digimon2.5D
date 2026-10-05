class_name PregameCatalog
extends Resource
## Catalog แก้รายการใน Inspector ข้อมูลภาพ/ฐานสเตตัสไม่ฝังในหน้าจอ UI
@export var tamers: Array[TamerModelData] = []
@export var starters: Array[StarterPartnerData] = []

func tamer_by_id(id: StringName) -> TamerModelData:
    for data: TamerModelData in tamers:
        if data.id == id:
            return data
    return null

func canonical_starter_id(id: StringName) -> StringName:
    # Save compatibility: ชื่อเก่าถูก map เข้าสาย original โดยไม่แสดงชื่อเดิมในเกมใหม่
    match id:
        &"agumon":
            return &"cindrake"
        &"gabumon":
            return &"frostfang"
    return id

func canonical_form_id(id: StringName) -> StringName:
    var aliases: Dictionary = {
        "agumon_0":"cindrake_0", "agumon_1":"cindrake_1", "agumon_2":"cindrake_2", "agumon_3":"cindrake_3",
        "gabumon_0":"frostfang_0", "gabumon_1":"frostfang_1", "gabumon_2":"frostfang_2", "gabumon_3":"frostfang_3"
    }
    return StringName(str(aliases.get(String(id), String(id))))

func starter_by_id(id: StringName) -> StarterPartnerData:
    var canonical: StringName = canonical_starter_id(id)
    for data: StarterPartnerData in starters:
        if data.id == canonical:
            return data
    return null
