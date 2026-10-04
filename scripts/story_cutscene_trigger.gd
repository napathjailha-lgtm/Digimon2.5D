extends Area2D
## ตัวอย่างจุดตัดเนื้อเรื่อง: เล่นได้เมื่อเควสต์ที่กำหนดสำเร็จ
signal cutscene_requested(cutscene_id: StringName)
@export var required_quest: StringName
@export var cutscene_id: StringName
var _triggered: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body is Tamer and not _triggered and QuestManager.is_completed(required_quest):
        _triggered = true
        cutscene_requested.emit(cutscene_id)
        # เชื่อมกับ AnimationPlayer / Dialogue UI ตามระบบ cutscene ของเกม
