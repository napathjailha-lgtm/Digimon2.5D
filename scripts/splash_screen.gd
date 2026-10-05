extends Control

@export_file("*.tscn") var next_scene: String = "res://scenes/pregame/loading_screen.tscn"
@export var minimum_wait: float = 0.65

@onready var start_label: Label = $Safe/StartArea/TapToStart
@onready var fade: ColorRect = $Fade

var _ready_to_start := false
var _starting := false
var _pulse := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    fade.modulate.a = 1.0
    var intro := create_tween()
    intro.tween_property(fade, "modulate:a", 0.0, 0.42)
    await get_tree().create_timer(minimum_wait).timeout
    _ready_to_start = true

func _process(delta: float) -> void:
    _pulse += delta
    start_label.modulate.a = 0.68 + sin(_pulse * 3.2) * 0.22

func _input(event: InputEvent) -> void:
    if not _ready_to_start or _starting:
        return
    var activate := false
    if event is InputEventScreenTouch:
        activate = event.pressed and not event.canceled
    elif event is InputEventMouseButton:
        activate = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    elif event is InputEventKey:
        activate = event.pressed and not event.echo
    if activate:
        get_viewport().set_input_as_handled()
        _start_game()

func _start_game() -> void:
    _starting = true
    _ready_to_start = false
    start_label.text = "CONNECTING..."
    var outro := create_tween()
    outro.tween_property(fade, "modulate:a", 1.0, 0.28)
    await outro.finished
    get_tree().change_scene_to_file(next_scene)
