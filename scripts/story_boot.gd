extends Node
func _ready() -> void:
    _open_saved_zone.call_deferred()

func _open_saved_zone() -> void:
    var paths: Dictionary = {&"file_island": "res://scenes/world.tscn", &"server_continent": "res://scenes/server_continent.tscn", &"odaiba": "res://scenes/odaiba.tscn", &"spiral_mountain": "res://scenes/spiral_mountain.tscn"}
    get_tree().change_scene_to_file(paths.get(QuestManager.current_zone, "res://scenes/world.tscn"))
