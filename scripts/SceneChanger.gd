extends CanvasLayer
## ตัวกลาง transition ของทั้งเกม: ใช้ ColorRect + Tween เท่านั้น เพื่อให้เบาบน Mobile Web
## Browser loader รับผิดชอบก่อน Godot พร้อม จากนั้น Singleton นี้รับช่วงโดยไม่มี white flash

var _fade_rect: ColorRect
var _active_tween: Tween
var _transitioning: bool = false

func _ready() -> void:
    layer = 1000
    process_mode = Node.PROCESS_MODE_ALWAYS
    _fade_rect = ColorRect.new()
    _fade_rect.name = "SceneFadeOverlay"
    _fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _fade_rect.color = Color.BLACK
    # เริ่ม Godot ด้วยดำ 100% เพื่อให้รอยต่อจาก Browser Boot เป็นสีเดียวกัน
    _fade_rect.modulate.a = 1.0
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_fade_rect)

func reveal_scene(duration: float = 1.5) -> void:
    if not is_instance_valid(_fade_rect):
        return
    _kill_tween()
    _fade_rect.show()
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    # ถ้าเรียกตอนเปิดเกม ให้เริ่มจากค่าปัจจุบัน แต่บังคับไม่ให้ต่ำกว่า 0
    _fade_rect.modulate.a = clampf(_fade_rect.modulate.a, 0.0, 1.0)
    _active_tween = create_tween()
    _active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _active_tween.set_trans(Tween.TRANS_QUINT)
    _active_tween.set_ease(Tween.EASE_OUT)
    _active_tween.tween_property(_fade_rect, "modulate:a", 0.0, maxf(duration, 0.01))
    _active_tween.finished.connect(_on_reveal_finished, CONNECT_ONE_SHOT)

func cover_scene(duration: float = 0.45) -> void:
    if not is_instance_valid(_fade_rect):
        return
    _kill_tween()
    _fade_rect.show()
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    _active_tween = create_tween()
    _active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _active_tween.set_trans(Tween.TRANS_QUAD)
    _active_tween.set_ease(Tween.EASE_IN)
    _active_tween.tween_property(_fade_rect, "modulate:a", 1.0, maxf(duration, 0.01))
    await _active_tween.finished
    _active_tween = null

func change_scene(scene_path: String, fade_out_duration: float = 0.45, reveal_duration: float = 1.0) -> bool:
    if _transitioning or scene_path.is_empty() or not ResourceLoader.exists(scene_path):
        return false
    _transitioning = true
    await cover_scene(fade_out_duration)
    var error := get_tree().change_scene_to_file(scene_path)
    if error != OK:
        _transitioning = false
        reveal_scene(reveal_duration)
        push_error("SceneChanger: เปลี่ยน Scene ไม่สำเร็จ: %s" % error_string(error))
        return false
    await get_tree().process_frame
    await get_tree().process_frame
    reveal_scene(reveal_duration)
    _transitioning = false
    return true

func change_scene_to_packed(scene: PackedScene, fade_out_duration: float = 0.35, reveal_duration: float = 0.8) -> bool:
    if _transitioning or scene == null:
        return false
    _transitioning = true
    await cover_scene(fade_out_duration)
    var error := get_tree().change_scene_to_packed(scene)
    if error != OK:
        _transitioning = false
        reveal_scene(reveal_duration)
        push_error("SceneChanger: เปลี่ยน PackedScene ไม่สำเร็จ: %s" % error_string(error))
        return false
    await get_tree().process_frame
    await get_tree().process_frame
    reveal_scene(reveal_duration)
    _transitioning = false
    return true

func _on_reveal_finished() -> void:
    if not is_instance_valid(_fade_rect):
        return
    _fade_rect.modulate.a = 0.0
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fade_rect.hide()
    _active_tween = null

func _kill_tween() -> void:
    if _active_tween != null and _active_tween.is_valid():
        _active_tween.kill()
    _active_tween = null
