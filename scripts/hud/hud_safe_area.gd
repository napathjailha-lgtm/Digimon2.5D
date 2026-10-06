class_name HudSafeArea
extends RefCounted
## Safe-area ของ native กับ Web ใช้คนละแหล่ง:
## - Native Android/iOS ใช้ DisplayServer safe rect
## - Web mobile ใช้ visual viewport ที่ loader sync ให้แล้ว และ margin แบบ logical
##   เพราะ iOS WebKit อาจรายงาน screen/safe-area คนละ orientation กับ canvas

const DESKTOP_PADDING := Vector4(18, 18, 24, 20)
const WEB_LANDSCAPE_PADDING := Vector4(28, 14, 28, 18)
const WEB_PORTRAIT_PADDING := Vector4(18, 18, 18, 22)

static func logical_insets(logical_size: Vector2, physical_size: Vector2,
        safe_rect: Rect2, padding := Vector4(18, 18, 24, 20)) -> Vector4:
    if physical_size.x <= 0.0 or physical_size.y <= 0.0 or not safe_rect.has_area():
        return _sanitize(logical_size, padding)
    var bounded: Rect2 = safe_rect.intersection(Rect2(Vector2.ZERO, physical_size))
    if not bounded.has_area():
        return _sanitize(logical_size, padding)
    var ratio: Vector2 = logical_size / physical_size
    var result := Vector4(
        bounded.position.x * ratio.x + padding.x,
        bounded.position.y * ratio.y + padding.y,
        (physical_size.x - bounded.end.x) * ratio.x + padding.z,
        (physical_size.y - bounded.end.y) * ratio.y + padding.w
    )
    return _sanitize(logical_size, result)

static func for_viewport(viewport: Viewport) -> Vector4:
    var logical_size: Vector2 = viewport.get_visible_rect().size

    # Desktop Web/PC ใช้ margin ปกติ
    if not HybridPlatform.use_mobile_layout(viewport):
        return DESKTOP_PADDING

    # สำคัญ: iOS Safari/Chrome บน Web ใช้ WebKit และ Godot DisplayServer
    # อาจคืน physical screen/safe rect ใน orientation เก่า ทำ bottom inset ใหญ่มาก
    # Web loader sync canvas กับ visualViewport อยู่แล้ว จึงใช้ logical padding โดยตรง
    if OS.has_feature("web"):
        var padding := WEB_PORTRAIT_PADDING if logical_size.y > logical_size.x else WEB_LANDSCAPE_PADDING
        return _sanitize(logical_size, padding)

    # Native mobile ใช้ safe area จากระบบปฏิบัติการได้ตามปกติ
    var screen: Vector2i = DisplayServer.screen_get_size()
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    return logical_insets(logical_size, Vector2(screen), Rect2(safe))

static func _sanitize(logical_size: Vector2, inset: Vector4) -> Vector4:
    # กันค่าผิดปกติจาก OS/browser ไม่ให้ยก HUD เข้าไปกลางจอ
    var max_side: float = minf(72.0, logical_size.x * 0.10)
    var max_top: float = minf(56.0, logical_size.y * 0.12)
    var max_bottom: float = minf(48.0, logical_size.y * 0.12)
    return Vector4(
        clampf(inset.x, 0.0, max_side),
        clampf(inset.y, 0.0, max_top),
        clampf(inset.z, 0.0, max_side),
        clampf(inset.w, 0.0, max_bottom)
    )
