class_name HybridPlatform
extends RefCounted
## ตัวช่วยตรวจแพลตฟอร์ม Hybrid โดยแยก "Web" ออกจาก "Touch device"
## Web บนมือถือจะเป็นทั้ง web=true และ touchscreen=true แม้ OS.has_feature("mobile") จะเป็น false

static func is_mobile_device() -> bool:
    # แยก "มือถือจริง" ออกจาก PC ที่มีจอสัมผัส เพื่อไม่เปิด Mobile layout บน laptop/tablet-PC โดยไม่ตั้งใจ
    return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

static func is_touch_device() -> bool:
    # ใช้กับการรับ input เท่านั้น: PC touchscreen ยังถือว่า touch ได้ แต่ไม่จำเป็นต้องใช้ Mobile layout
    return is_mobile_device() or DisplayServer.is_touchscreen_available()

static func is_web_touch() -> bool:
    return OS.has_feature("web") and is_touch_device()

static func use_mobile_layout(viewport: Viewport = null) -> bool:
    if is_mobile_device():
        return true
    # fallback สำหรับ browser ที่ไม่รายงาน web_android/web_ios: ต้องเป็น touchscreen + viewport เล็กจริง
    if OS.has_feature("web") and DisplayServer.is_touchscreen_available() and viewport != null:
        return is_compact_viewport(viewport)
    return false

static func is_web_mobile(viewport: Viewport = null) -> bool:
    # Profile ประหยัดทรัพยากรใช้เฉพาะ browser บนมือถือ ไม่กระทบ Android native / Web PC
    return OS.has_feature("web") and use_mobile_layout(viewport)

static func is_compact_viewport(viewport: Viewport) -> bool:
    var size: Vector2 = viewport.get_visible_rect().size
    return size.x < 980.0 or size.y < 600.0

static func is_portrait(viewport: Viewport) -> bool:
    var size: Vector2 = viewport.get_visible_rect().size
    return size.y > size.x

static func configure_web_touch_surface() -> void:
    # Desktop Web ต้องปล่อยให้ Godot คุม canvas resize เอง เพื่อให้ภาพกับ mouse coordinates ตรงกัน
    # ปิด browser gesture เฉพาะ Web ที่มี touch เท่านั้น และห้ามกำหนด CSS width/height ของ canvas
    if not is_web_touch():
        return

    JavaScriptBridge.eval("""
(() => {
  let viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = document.createElement('meta');
    viewport.name = 'viewport';
    document.head.appendChild(viewport);
  }
  viewport.content = 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover';

  const html = document.documentElement;
  const body = document.body;

  if (html) {
    html.style.overscrollBehavior = 'none';
    html.style.touchAction = 'none';
  }

  if (body) {
    body.style.overscrollBehavior = 'none';
    body.style.touchAction = 'none';
    body.style.userSelect = 'none';
    body.style.webkitUserSelect = 'none';
    body.style.overflow = 'hidden';
  }

  const canvas = document.querySelector('canvas');
  if (canvas) {
    canvas.style.touchAction = 'none';
    canvas.style.webkitUserSelect = 'none';
    canvas.style.userSelect = 'none';

    // สำคัญ: ไม่แตะ width/height ของ canvas
    // html/canvas_resize_policy=2 ให้ Godot จัด backing size และ pointer mapping เอง
  }
})();
""", true)
