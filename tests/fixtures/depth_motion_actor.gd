extends CharacterBody2D
## Actor ทดสอบที่วิ่งและชนจริง ใช้ตรวจ get_real_velocity() ของภาพเงา/กล้อง
var commanded_velocity := Vector2.ZERO
func _physics_process(_delta: float) -> void:
    velocity = commanded_velocity
    move_and_slide()
