class_name StoryNPC
extends Area2D
@export var npc_id: StringName = &"agumon"
@export var talk_distance: float = 90.0
signal dialogue_requested(npc_id: StringName)

func _ready() -> void:
    # พื้นที่แตะครอบตัว NPC ทั้งภาพ ไม่จำกัดอยู่ที่วงกลมใต้เท้า
    var shape := RectangleShape2D.new()
    shape.size = $Sprite2D.texture.get_size() * $Sprite2D.scale.abs()
    $CollisionShape2D.shape = shape
    $CollisionShape2D.position.y = -shape.size.y * 0.5

func try_talk(tamer: Tamer) -> bool:
    if not is_instance_valid(tamer) or global_position.distance_to(tamer.global_position) > talk_distance:
        return false
    dialogue_requested.emit(npc_id)
    # ตัวอย่างจบบทสนทนาทันที; ระบบจริงเรียก report_event หลังจบบทสนทนา
    return QuestManager.report_event(StoryQuest.Objective.TALK, npc_id)
