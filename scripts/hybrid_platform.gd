class_name HybridPlatform
extends RefCounted
## ตัวช่วยตรวจแพลตฟอร์ม Hybrid โดยแยก "Web" ออกจาก "Touch device"
## Web บนมือถือจะเป็นทั้ง web=true และ touchscreen=true แม้ OS.has_feature("mobile") จะเป็น false

static func is_touch_device() -> bool:
    return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

static func is_web_touch() -> bool:
    return OS.has_feature("web") and is_touch_device()

static func is_compact_viewport(viewport: Viewport) -> bool:
    var size: Vector2 = viewport.get_visible_rect().size
    return size.x < 980.0 or size.y < 600.0

static func is_portrait(viewport: Viewport) -> bool:
    var size: Vector2 = viewport.get_visible_rect().size
    return size.y > size.x

static func configure_web_touch_surface() -> void:
    # ป้องกัน browser scroll / pinch / text selection แย่ง gesture จาก Godot canvas
    # เรียกซ้ำได้อย่างปลอดภัยทุก Scene
    if not OS.has_feature("web"):
        return
    JavaScriptBridge.eval("""
(() => {
  const html = document.documentElement;
  const body = document.body;
  if (html) {
    html.style.overscrollBehavior = 'none';
    html.style.touchAction = 'none';
    html.style.margin = '0';
    html.style.padding = '0';
    html.style.width = '100%';
    html.style.height = '100%';
  }
  if (body) {
    body.style.overscrollBehavior = 'none';
    body.style.touchAction = 'none';
    body.style.userSelect = 'none';
    body.style.webkitUserSelect = 'none';
    body.style.margin = '0';
    body.style.padding = '0';
    body.style.overflow = 'hidden';
    body.style.width = '100%';
    body.style.height = '100%';
  }
  const canvas = document.querySelector('canvas');
  if (canvas) {
    canvas.style.touchAction = 'none';
    canvas.style.webkitUserSelect = 'none';
    canvas.style.userSelect = 'none';
  }
})();
""", true)
