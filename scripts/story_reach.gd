extends Area2D
@export var target_id: StringName

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body is Tamer:
        QuestManager.report_event(StoryQuest.Objective.REACH, target_id)
