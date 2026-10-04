extends Node
var failures: int = 0
func _ready() -> void:
    var tracker = preload("res://scenes/quest_tracker.tscn").instantiate()
    add_child(tracker)
    await get_tree().process_frame
    for quest in QuestManager.catalog.quests:
        tracker.title_label.text = "[เควสต์หลัก] " + quest.title
        tracker.detail_label.text = quest.description
        tracker.progress_label.text = "1 / 1  •  แตะเพื่อนำทาง"
        await get_tree().process_frame
        await get_tree().process_frame
        var panel_size: Vector2 = tracker.get_node("Panel").size
        if panel_size.x > tracker.size.x or panel_size.y > tracker.size.y:
            failures += 1
            push_error("ข้อความเควสต์เกินพื้นที่ Touch: " + String(quest.id))
        else:
            print("PASS: Tracker ครอบข้อความและพื้นที่ Touch: ", quest.id)
    print("RESULT: ", failures, " failure(s)")
    get_tree().quit(1 if failures else 0)
