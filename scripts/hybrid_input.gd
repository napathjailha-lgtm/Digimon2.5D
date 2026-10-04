class_name HybridInput
extends RefCounted
## สร้าง Input Map ตอน runtime เพื่อให้ Mobile + Web/PC ใช้โค้ดชุดเดียวกัน
## เรียกซ้ำได้อย่างปลอดภัย และไม่ลบ binding ที่ผู้พัฒนาเพิ่มเองใน Project Settings

static func ensure_actions() -> void:
    _ensure_keys(&"move_left", [KEY_A, KEY_LEFT])
    _ensure_keys(&"move_right", [KEY_D, KEY_RIGHT])
    _ensure_keys(&"move_up", [KEY_W, KEY_UP])
    _ensure_keys(&"move_down", [KEY_S, KEY_DOWN])
    _ensure_keys(&"skill_1", [KEY_1])
    _ensure_keys(&"skill_2", [KEY_2])
    _ensure_keys(&"skill_3", [KEY_3])
    _ensure_keys(&"skill_4", [KEY_4])
    _ensure_keys(&"basic_attack", [KEY_SPACE])
    _ensure_keys(&"jogress", [KEY_J])

static func _ensure_keys(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for keycode: int in keys:
        var exists := false
        for existing: InputEvent in InputMap.action_get_events(action):
            if existing is InputEventKey and existing.physical_keycode == keycode:
                exists = true
                break
        if exists:
            continue
        var event := InputEventKey.new()
        event.physical_keycode = keycode
        InputMap.action_add_event(action, event)
