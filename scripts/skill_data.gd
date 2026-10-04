class_name MonsterSkill
extends Resource
## ข้อมูลต้นแบบสกิล: คูลดาวน์และเป้าหมายเก็บในคู่หู ไม่แก้ Resource ร่วมกัน

@export var id: StringName = &"strike"
@export var display_name: String = "Strike"
@export var icon: Texture2D
## เปลี่ยนเฉพาะรูปลักษณ์ของพลัง ไม่กระทบดาเมจ/ธาตุ/ระยะในระบบต่อสู้
@export_enum("fire", "ice", "wind", "lightning", "nature", "claw", "missile", "wing", "astral") var vfx_style: String = "fire"
@export_group("ท่าใช้สกิล")
## cast ใช้ท่าร่าย/พ่นพลัง; attack ใช้ท่ากรงเล็บ/กัด
@export var animation_prefix: StringName = &"cast"
@export_range(0, 30) var release_frame: int = 2
@export_group("ค่าต่อสู้")
@export_range(0.01, 20.0) var multiplier: float = 1.2
@export_range(1.0, 1000.0) var cast_range: float = 90.0
@export_range(0.1, 60.0) var cooldown: float = 3.0
@export_range(0.0, 100.0) var mp_cost: float = 5.0
## 0 = เป้าหมายเดียว; มากกว่า 0 = ระเบิดรอบตำแหน่งเป้าหมาย
@export_range(0.0, 500.0) var impact_radius: float = 0.0
@export var effect_color: Color = Color(1.0, 0.45, 0.1)
@export_range(4.0, 100.0) var effect_size: float = 12.0
@export_group("ลูกไฟเดินทาง")
## 0 = โจมตีทันที; ค่าบวก = ความเร็วลูกไฟเป็นพิกเซลต่อวินาที
@export_range(0.0, 3000.0) var projectile_speed: float = 0.0
## กำหนดอายุสูงสุด ป้องกันลูกไฟไล่เป้าหมายที่วิ่งหนีไม่สิ้นสุด
@export_range(0.1, 10.0) var projectile_lifetime: float = 3.0

func validation_error() -> String:
    # ตรวจ runtime ด้วย เพราะแก้ .tres ด้วยมือข้ามข้อจำกัด Inspector ได้
    if id == &"" or display_name.strip_edges().is_empty():
        return "สกิลต้องมี ID และชื่อ"
    if animation_prefix not in [&"attack", &"cast"] or release_frame < 0:
        return "ต้องเลือกท่า attack/cast และ release_frame ต้องไม่ติดลบ"
    if not is_finite(multiplier) or multiplier <= 0.0:
        return "Multiplier ต้องเป็นจำนวนบวก"
    if not is_finite(cast_range) or cast_range <= 0.0 or not is_finite(cooldown) or cooldown <= 0.0:
        return "ระยะและคูลดาวน์ต้องมากกว่า 0"
    if not is_finite(mp_cost) or mp_cost < 0.0 or not is_finite(impact_radius) or impact_radius < 0.0:
        return "MP และรัศมีต้องไม่ติดลบ"
    if not is_finite(effect_size) or effect_size <= 0.0:
        return "ขนาดเอฟเฟกต์ต้องมากกว่า 0"
    if not is_finite(projectile_speed) or projectile_speed < 0.0:
        return "ความเร็วลูกไฟต้องไม่ติดลบ"
    if not is_finite(projectile_lifetime) or projectile_lifetime <= 0.0:
        return "อายุลูกไฟต้องมากกว่า 0"
    return ""

func roll_damage(base_attack: int, rng: RandomNumberGenerator) -> int:
    # แกว่ง +/-5% ของผลคูณทั้งหมด และปัดเป็นจำนวนเต็มท้ายสุด
    if base_attack <= 0:
        return 0
    return maxi(1, int(round(float(base_attack) * multiplier * rng.randf_range(0.95, 1.05))))

var ds_cost: float:
    # Alias ของ API เก่าเท่านั้น; Inspector v19 ใช้ mp_cost และไม่หัก DS ตอนร่าย
    get: return mp_cost
    set(value): mp_cost = value
