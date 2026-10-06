class_name HudPreferences
extends RefCounted
## ค่าความสบายในการใช้งานเป็น preferences ของเครื่อง แยกจาก HP/Quest ของตัวละคร
var animations_enabled: bool = true
var blur_enabled: bool = true
var low_effects: bool = false
var combat_scale: float = 1.0
var minimap_visible: bool = true
var chat_collapsed: bool = true
var quick_item_slots: Array[String] = ["tamer_medkit", "tamer_ration", "meat", "mp_drink"]
var save_path: String = "user://hud_preferences_v18.cfg"

func load_data() -> void:
    var config := ConfigFile.new()
    if config.load(save_path) != OK:
        return
    animations_enabled = bool(config.get_value("hud", "animations", true))
    blur_enabled = bool(config.get_value("hud", "blur", true))
    low_effects = bool(config.get_value("hud", "low_effects", false))
    var factor: Variant = config.get_value("hud", "combat_scale", 1.0)
    combat_scale = clampf(float(factor), 1.0, 1.15) if (factor is float or factor is int) and is_finite(float(factor)) else 1.0
    minimap_visible = bool(config.get_value("hud", "minimap", true))
    chat_collapsed = bool(config.get_value("hud", "chat_collapsed", true))
    var saved_quick: Variant = config.get_value("hud", "quick_item_slots", quick_item_slots)
    if saved_quick is Array:
        var parsed: Array[String] = []
        for value: Variant in saved_quick:
            parsed.append(str(value))
        if parsed.size() == 4:
            quick_item_slots = parsed
    # HUD รุ่นเก่าซ่อนมินิแมพเป็นค่าเริ่มต้น: แสดงแผนที่ของดีไซน์ใหม่ครั้งแรกเท่านั้น
    # คง Reduce Motion/ขนาดปุ่ม/แชตไว้ และเคารพการซ่อนแผนที่ที่ตั้งใหม่หลังอัปเดต
    if int(config.get_value("hud", "layout_version", 0)) < 23:
        minimap_visible = true
        save_data()

func save_data() -> Error:
    # ไม่บันทึกตำแหน่งนิ้ว/Target หรือ Node จึงคืนค่าได้หลังเปลี่ยน Scene/บัญชี
    var config := ConfigFile.new()
    config.set_value("hud", "layout_version", 24)
    config.set_value("hud", "animations", animations_enabled)
    config.set_value("hud", "blur", blur_enabled)
    config.set_value("hud", "low_effects", low_effects)
    config.set_value("hud", "combat_scale", combat_scale)
    config.set_value("hud", "minimap", minimap_visible)
    config.set_value("hud", "chat_collapsed", chat_collapsed)
    config.set_value("hud", "quick_item_slots", quick_item_slots)
    return config.save(save_path)
