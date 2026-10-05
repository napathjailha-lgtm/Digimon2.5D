extends SceneTree
## CI smoke test: โหลด resource สำคัญแบบเดียวกับ LoadingScreen โดยไม่ instantiate gameplay
## จับ circular SubResource / path หาย / PackedScene โหลดไม่ได้ ซึ่ง --editor --quit อาจไม่เจอ

const TARGETS: Array[String] = [
    "res://scenes/pregame/login_screen.tscn",
    "res://data/pregame/catalog.tres",
    "res://data/equipment/catalog.tres",
    "res://scenes/wild_monster.tscn",
    "res://scenes/forest_byte.tscn",
    "res://scenes/forest_crab.tscn",
    "res://scenes/boss_forest_guardian.tscn",
    "res://data/quest_catalog.tres",
    "res://scenes/boss_devimon.tscn",
    "res://scenes/boss_etemon.tscn",
    "res://scenes/boss_myotismon.tscn",
    "res://scenes/boss_piedmon.tscn",
    "res://scenes/world.tscn",
]

func _initialize() -> void:
    var failed: bool = false
    for path: String in TARGETS:
        if not ResourceLoader.exists(path):
            push_error("SMOKE missing: " + path)
            failed = true
            continue
        var resource: Resource = ResourceLoader.load(path)
        if resource == null:
            push_error("SMOKE failed to load: " + path)
            failed = true
        else:
            print("SMOKE OK: ", path, " -> ", resource.get_class())
    quit(1 if failed else 0)
