class_name QuestTarget
extends Marker2D
## Marker ใต้ NPC / บอส / Reach Area / Portal สำหรับ Auto-Navigation
@export var target_id: StringName

func _ready() -> void:
    add_to_group("quest_targets")

func interact_on_arrival(tamer: Tamer) -> void:
    var owner_node: Node = get_parent()
    if owner_node is StoryNPC:
        owner_node.try_talk(tamer)
    elif owner_node is StoryPortal:
        owner_node.try_enter(tamer)
    # เป้าหมายบอสต้องสั่งคู่หูโจมตีเองผ่านปุ่ม Attack/Target Lock
