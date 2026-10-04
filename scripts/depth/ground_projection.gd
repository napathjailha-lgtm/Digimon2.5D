class_name GroundProjection
extends RefCounted
## ฐานพิกัดของภาพพื้น: หมุนในระนาบก่อน แล้วจึงบีบแกน Y และเฉือนแกน X
## ใช้กับลูก Visual เท่านั้น อย่านำไปใส่ CharacterBody2D / CollisionShape2D

static func make_transform(flatten_y: float = 0.46, shear_x: float = 0.12,
        heading: float = 0.0, origin: Vector2 = Vector2.ZERO) -> Transform2D:
    # คอลัมน์คือ P × R โดย P = [[1, shear], [0, flatten]]
    # บีบ Y อย่างเดียวทำให้วงกลมเป็นวงรี; shear เพิ่มความเฉียงแบบพื้น isometric
    # clamp กันฐานยุบเป็นเส้น จึงยังใช้ affine_inverse() แปลงจุดกลับได้
    var depth: float = clampf(flatten_y, 0.15, 1.0)
    var shear: float = clampf(shear_x, -0.45, 0.45)
    var c: float = cos(heading)
    var s: float = sin(heading)
    return Transform2D(Vector2(c + shear * s, depth * s),
        Vector2(-s + shear * c, depth * c), origin)

static func apply_to_visual(visual: Node2D, flatten_y: float = 0.46,
        shear_x: float = 0.12, heading: float = 0.0) -> void:
    # สร้างฐานใหม่เสมอ ไม่คูณ transform เดิมสะสม; เก็บตำแหน่งเดิมไว้
    # อย่าตั้ง scale/rotation ซ้ำหลังฟังก์ชันนี้ เพราะจะเขียนทับฐานที่คำนวณไว้
    visual.transform = make_transform(flatten_y, shear_x, heading, visual.position)

