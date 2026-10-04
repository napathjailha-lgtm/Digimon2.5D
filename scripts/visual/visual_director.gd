extends Node
## Autoload เล็กสำหรับปุ่มมาตรฐานหน้า Login/เลือกตัวละคร; TouchCommand ติด FX เอง
func _ready() -> void:
    # โหลด Reduce Motion ตั้งแต่หน้าแรก ไม่ต้องรอเข้า World
    var preferences := HudPreferences.new()
    preferences.load_data()
    GameVisualSettings.motion_enabled = preferences.animations_enabled
    GameVisualSettings.blur_enabled = preferences.blur_enabled
    GameVisualSettings.low_effects = preferences.low_effects
    get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
    # รอ _ready/layout ก่อนจับสเกลฐานของ Button และรองรับปุ่มสร้างทีหลัง
    if node is BaseButton:
        _attach_later.call_deferred(node)

func _attach_later(node: Variant) -> void:
    # Node อาจถูก free ระหว่าง deferred; guard ก่อนแปลงชนิดเพื่อไม่ให้ callback เก่าพัง
    if is_instance_valid(node) and node is BaseButton and node.is_inside_tree():
        MobileButtonFX.attach(node as Control)

