class_name SkillArcLayout
extends RefCounted
## คำนวณจุดศูนย์กลางบนวงโค้งในพิกัด local ของ Combat เท่านั้น
## ไม่ใส่ปุ่มเหล่านี้ใน Container เพราะ Container จะเขียนทับตำแหน่ง polar

static func positions(center: Vector2, radius: float, start_degrees: float,
        end_degrees: float, button_size: Vector2, count: int = 4) -> Array[Vector2]:
    var result: Array[Vector2] = []
    for index: int in range(maxi(0, count)):
        # กรณีมีปุ่มเดียวใช้กลางโค้ง ป้องกันหารด้วยศูนย์
        var weight: float = 0.5 if count == 1 else float(index) / float(count - 1)
        var angle: float = deg_to_rad(lerpf(start_degrees, end_degrees, weight))
        var direction := Vector2(cos(angle), sin(angle))
        # Control.position คือมุมซ้ายบน จึงลบครึ่งขนาดปุ่มออกจากจุดศูนย์กลาง
        result.append(center + direction * maxf(0.0, radius) - button_size * 0.5)
    return result
