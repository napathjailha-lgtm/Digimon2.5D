class_name ResponsiveUI
extends RefCounted
## ตัวช่วยกลางสำหรับ UI ที่ต้องพอดีกับ Web/Mobile viewport
## หลักการคือให้ Container คำนวณ minimum size ตามปกติ แล้ว scale ภาพ+hitbox ทั้งก้อนรอบจุดกึ่งกลาง
## วิธีนี้แก้ปัญหา child custom_minimum_size ดัน Panel ทะลุจอ โดยไม่ต้องลดขนาดปุ่มทีละตัว

static func fit_centered(
        control: Control,
        viewport: Viewport,
        outer_padding: float = 18.0,
        maximum_scale: float = 1.0
) -> float:
    if control == null or viewport == null:
        return 1.0

    # reset ก่อนอ่าน minimum เพื่อไม่ให้ scale รอบก่อนปนกับการคำนวณรอบใหม่
    control.scale = Vector2.ONE

    var view_size: Vector2 = viewport.get_visible_rect().size
    var natural: Vector2 = control.get_combined_minimum_size()
    natural.x = maxf(natural.x, control.custom_minimum_size.x)
    natural.y = maxf(natural.y, control.custom_minimum_size.y)

    if natural.x <= 1.0:
        natural.x = maxf(1.0, control.size.x)
    if natural.y <= 1.0:
        natural.y = maxf(1.0, control.size.y)

    var available := Vector2(
        maxf(1.0, view_size.x - outer_padding * 2.0),
        maxf(1.0, view_size.y - outer_padding * 2.0)
    )

    var factor: float = minf(
        maximum_scale,
        minf(available.x / natural.x, available.y / natural.y)
    )
    factor = clampf(factor, 0.35, maximum_scale)

    # CenterContainer จะจัดตำแหน่งจากขนาด unscaled;
    # pivot กลางทำให้ภาพที่ scale แล้วยังคงอยู่กึ่งกลางและ input transform ตรงภาพ
    control.pivot_offset = natural * 0.5
    control.scale = Vector2.ONE * factor
    return factor


static func fit_absolute_design(
        control: Control,
        viewport: Viewport,
        design_size: Vector2,
        outer_padding: float = 18.0,
        maximum_scale: float = 1.0
) -> float:
    if control == null or viewport == null:
        return 1.0

    var view_size: Vector2 = viewport.get_visible_rect().size
    var available := Vector2(
        maxf(1.0, view_size.x - outer_padding * 2.0),
        maxf(1.0, view_size.y - outer_padding * 2.0)
    )
    var factor: float = minf(
        maximum_scale,
        minf(available.x / design_size.x, available.y / design_size.y)
    )
    factor = clampf(factor, 0.35, maximum_scale)

    control.size = design_size
    control.scale = Vector2.ONE * factor
    control.position = (view_size - design_size * factor) * 0.5
    return factor


static func apply_safe_margins(
        margin: MarginContainer,
        viewport: Viewport,
        minimum_padding: float = 12.0
) -> Vector4:
    if margin == null or viewport == null:
        return Vector4(minimum_padding, minimum_padding, minimum_padding, minimum_padding)

    var inset: Vector4 = HudSafeArea.for_viewport(viewport)
    inset.x = maxf(inset.x, minimum_padding)
    inset.y = maxf(inset.y, minimum_padding)
    inset.z = maxf(inset.z, minimum_padding)
    inset.w = maxf(inset.w, minimum_padding)

    margin.add_theme_constant_override("margin_left", roundi(inset.x))
    margin.add_theme_constant_override("margin_top", roundi(inset.y))
    margin.add_theme_constant_override("margin_right", roundi(inset.z))
    margin.add_theme_constant_override("margin_bottom", roundi(inset.w))
    return inset
