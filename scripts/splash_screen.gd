extends Control

@export_file("*.tscn") var next_scene: String = "res://scenes/pregame/loading_screen.tscn"
## เวลาขั้นต่ำที่ให้ Splash ของ Godot แสดง หลัง Browser loader ส่งต่อมาแล้ว
@export_range(0.1, 5.0) var minimum_wait: float = 0.85

@onready var artwork_wide: TextureRect = $ArtworkWide
@onready var artwork_portrait: TextureRect = $ArtworkPortrait
@onready var fade: ColorRect = $Fade

var _starting: bool = false
var _can_skip: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP

    # SceneChanger เริ่มด้วยดำ 100% เพื่อรับช่วงจาก Browser loader โดยไม่มี white flash
    fade.modulate.a = 0.0
    _refresh_artwork()
    get_viewport().size_changed.connect(_refresh_artwork)

    # รอหนึ่งเฟรมให้ TextureRect/Layout พร้อมก่อนค่อยเปิดภาพ
    await get_tree().process_frame
    if not is_inside_tree():
        return

    SceneChanger.reveal_scene(0.75)

    # อนุญาตให้แตะเพื่อข้ามได้หลังเฟรมแรก แต่ไม่บังคับให้ผู้เล่นแตะ
    _can_skip = true

    # Boot ต้องเดินต่อเองเสมอ ป้องกันจอดำค้างรอ click บน Web/Mobile
    await get_tree().create_timer(minimum_wait, true).timeout
    if is_inside_tree() and not _starting:
        _start_game()

func _refresh_artwork() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var portrait: bool = viewport_size.y > viewport_size.x
    artwork_portrait.visible = portrait
    artwork_wide.visible = not portrait

func _input(event: InputEvent) -> void:
    # Touch/Click/Keyboard เป็นเพียง Skip Splash ไม่ใช่เงื่อนไขเริ่มเกม
    if not _can_skip or _starting:
        return

    var skip: bool = false
    if event is InputEventScreenTouch:
        skip = event.pressed and not event.canceled
    elif event is InputEventMouseButton:
        skip = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    elif event is InputEventKey:
        skip = event.pressed and not event.echo

    if skip:
        get_viewport().set_input_as_handled()
        _start_game()

func _start_game() -> void:
    if _starting:
        return
    _starting = true
    _can_skip = false

    # ใช้ SceneChanger เป็นสะพานไป Loading Screen:
    # Splash -> ดำ -> Scene ใหม่ -> ค่อย Fade เปิด Loading
    var changed: bool = await SceneChanger.change_scene(next_scene, 0.45, 0.85)
    if not changed and is_inside_tree():
        # ถ้าเปลี่ยน Scene ไม่สำเร็จ ให้เปิดภาพกลับและอนุญาตลองใหม่
        _starting = false
        _can_skip = true
