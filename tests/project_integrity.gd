extends SceneTree
## Check every shipped resource, including scripts loaded only when a menu opens.
var failures: int = 0
var checked: int = 0

func _initialize() -> void:
    for folder: String in ["assets", "data", "scenes", "scripts"]:
        inspect_directory("res://" + folder)
    print("INTEGRITY RESULT: %d failures / %d resources" % [failures, checked])
    quit(1 if failures else 0)

func inspect_directory(path: String) -> void:
    var directory := DirAccess.open(path)
    if directory == null:
        fail("Cannot open " + path)
        return
    for child: String in directory.get_directories():
        if not child.begins_with("."):
            inspect_directory(path.path_join(child))
    for filename: String in directory.get_files():
        if filename.get_extension() not in ["gd", "tres", "tscn", "png", "jpg", "svg"]:
            continue
        var resource_path: String = path.path_join(filename)
        checked += 1
        var resource: Resource = load(resource_path)
        if resource == null:
            fail(resource_path)
        elif resource is Script and not resource.can_instantiate():
            fail("Invalid script: " + resource_path)

func fail(message: String) -> void:
    failures += 1
    push_error(message)
