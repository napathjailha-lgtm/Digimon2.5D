class_name MonsterDatabase
extends Resource
## แค็ตตาล็อกข้อมูลทุกสายพันธุ์/ร่างของเกม โหลดตาม id ได้
## ลำดับ Evolution ของคู่หูยังใช้ Partner.forms แยกจากรายการแค็ตตาล็อก

@export var monsters: Array[MonsterData] = []

func find_by_id(monster_id: StringName) -> MonsterData:
    for data: MonsterData in monsters:
        if data != null and data.id == monster_id:
            return data
    return null
