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

func starter_by_id(id: StringName) -> StarterPartnerData:
    for data: StarterPartnerData in starters:
        if data.id == id:
            return data
    return null
