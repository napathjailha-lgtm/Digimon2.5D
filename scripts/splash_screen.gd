extends Control

@export_file("*.tscn") var next_scene: String = "res://scenes/pregame/loading_screen.tscn"
@export var minimum_wait: float = 0.45

@onready var artwork_wide: TextureRect = $ArtworkWide
@onready var artwork_portrait: TextureRect = $ArtworkPortrait
@onready var fade: ColorRect = $Fade

var _ready_to_start := false
var _starting := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP

    fade.modulate.a = 0.0
    _refresh_artwork()
    get_viewport().size_changed.connect(_refresh_artwork)

    await get_tree().create_timer(minimum_wait).timeout
    _ready_to_start = true

func _refresh_artwork() -> void:
    var size := get_viewport().get_visible_rect().size
    var portrait := size.y > size.x
    artwork_portrait.visible = portrait
    artwork_wide.visible = not portrait

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

    var outro := create_tween()
    outro.tween_property(fade, "modulate:a", 0.42, 0.20)
    await outro.finished
    get_tree().change_scene_to_file(next_scene)
