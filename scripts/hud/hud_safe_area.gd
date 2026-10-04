class_name HudSafeArea
extends RefCounted
## Android/iOS ส่ง Safe Area เป็นพิกเซลจอจริง แต่ HUD ใช้หน่วย logical ของ viewport
## เกมนี้ใช้หน้าต่างเต็มจอ + canvas_items/expand จึงแปลงด้วยอัตราส่วนแต่ละแกนได้

static func logical_insets(logical_size: Vector2, physical_size: Vector2,
        safe_rect: Rect2, padding := Vector4(18, 18, 24, 20)) -> Vector4:
    if physical_size.x <= 0.0 or physical_size.y <= 0.0 or not safe_rect.has_area():
        return padding
    var bounded: Rect2 = safe_rect.intersection(Rect2(Vector2.ZERO, physical_size))
    if not bounded.has_area():
        return padding
    var ratio: Vector2 = logical_size / physical_size
    # เพิ่มพื้นที่นิ้วโป้งหลังแนวรอยบากอีกชั้น ไม่วางปุ่มชิดขอบ safe area
    return Vector4(bounded.position.x * ratio.x + padding.x,
        bounded.position.y * ratio.y + padding.y,
        (physical_size.x - bounded.end.x) * ratio.x + padding.z,
        (physical_size.y - bounded.end.y) * ratio.y + padding.w)

static func for_viewport(viewport: Viewport) -> Vector4:
    if not OS.has_feature("mobile"):
        return Vector4(18, 18, 24, 20)
    var screen: Vector2i = DisplayServer.screen_get_size()
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    return logical_insets(viewport.get_visible_rect().size, Vector2(screen), Rect2(safe))
