class_name SmoothMotion
extends RefCounted
## ตัวช่วยเร่ง/เบรก ไม่เลื่อน position ข้าม collision และไม่อิง FPS ของจอ

static func step(current: Vector2, desired: Vector2, acceleration: float,
        braking: float, delta: float) -> Vector2:
    # ปล่อยนิ้วหรือกลับทิศใช้เบรกแรงกว่าเร่ง เพื่อไม่ให้ควบคุมแล้วรู้สึกลื่นไถล
    var reversing: bool = current.dot(desired) < 0.0
    var slowing: bool = desired.length_squared() < current.length_squared()
    var rate: float = braking if reversing or slowing else acceleration
    var next: Vector2 = current.move_toward(desired, maxf(0.0, rate) * delta)
    return Vector2.ZERO if desired.is_zero_approx() and next.length_squared() < 1.0 else next

static func arrival_speed(distance: float, stop_distance: float, maximum: float,
        braking: float) -> float:
    # v² = 2ad: ลดความเร็วตามระยะเบรกจริงเมื่อใกล้เป้าหมาย
    return minf(maximum, sqrt(maxf(0.0, 2.0 * braking * (distance - stop_distance))))
