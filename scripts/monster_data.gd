class_name MonsterData
extends Resource
## Template ข้อมูลแต่ละร่าง: สร้าง .tres แยก Base / Growth / Ascended / Apex
## Resource เป็นข้อมูลต้นแบบที่หลายตัวอ่านร่วมกัน ห้ามเก็บ HP ปัจจุบันที่นี่

enum EvolutionStage { BASE, GROWTH, ASCENDED, APEX }

@export_group("ข้อมูลมอนสเตอร์")
@export var id: StringName = &"base"
@export var monster_name: String = "Base"
@export var evolution_stage: EvolutionStage = EvolutionStage.BASE
# ว่าง = ใช้ระดับร่างอย่างเดียว; เช่นร่างเนื้อเรื่องกำหนด flag เฉพาะของเกม
@export var required_story_flag: StringName = &""

@export_group("สเตตัสพื้นฐาน")
@export_range(1, 99999) var max_hp: int = 120
## ATK ฐานของร่างนี้; CharacterProgress บวกโบนัสเลเวลให้เป็น attack_power
@export_range(0, 99999) var attack: int = 15
@export_range(1.0, 1000.0) var move_speed: float = 240.0
@export_range(1.0, 1000.0) var attack_range: float = 58.0
@export_range(0.1, 10.0) var attack_interval: float = 0.8

@export_group("สเตตัสต่อสู้ขั้นสูง")
## ค่าเริ่มต้นเป็นกลาง เพื่อรักษาสมดุลเดิม เปลี่ยนได้แยกแต่ละร่างใน Inspector
@export_range(0.0, 100.0) var critical_chance: float = 0.0
@export_range(1.0, 5.0) var critical_multiplier: float = 1.5
@export_range(0.0, 100.0) var hit_chance: float = 100.0
@export_range(0, 99999) var defense: int = 0
@export_range(0.0, 100.0) var block_chance: float = 0.0
@export_range(0.0, 100.0) var evasion_chance: float = 0.0

@export_group("ภาพและแอนิเมชัน")
## รูปหน้าสำหรับสล็อตปาร์ตี้; ไม่กำหนดจะตัดครึ่งบนจากท่า Idle ตามเดิม
@export var portrait_texture: Texture2D
# SpriteFrames เก็บเฟรมที่ตัดจาก SpriteSheet หรือรูป PNG แยกเฟรมได้
@export var sprite_frames: SpriteFrames
@export var sprite_scale: Vector2 = Vector2.ONE
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var cast_animation: StringName = &"cast_down"
## เลขเฟรมเริ่มนับจาก 0; 2 = ท่าที่สามของชุด 4 เฟรม
@export_range(0, 30) var attack_hit_frame: int = 2
@export var attack_sprite_scale: Vector2 = Vector2.ONE
@export var cast_sprite_scale: Vector2 = Vector2.ONE
@export var require_action_animations: bool = false
## ความเร็วสนามที่ศิลปินใช้วาดจังหวะเดิน ไม่ใช่ความเร็วหลังโบนัสเลเวล
@export_range(1.0, 1000.0) var animation_reference_speed: float = 240.0
## เปิดเมื่อใส่เฟรมจริงครบแล้ว เพื่อป้องกันโหลดร่างที่ขาดแอนิเมชัน 4 ทิศ
@export var require_directional_animations: bool = false

@export_group("สกิลและค่า DS")
@export var skills: Array[MonsterSkill] = []
@export_range(0.0, 1000.0) var evolution_cost: float = 0.0
@export_range(0.0, 100.0) var ds_drain_per_second: float = 0.0

func validation_error() -> String:
    # ตรวจด้วยก่อนใช้จริง เพราะค่าอาจมาจากโค้ดหรือไฟล์ที่แก้มือ
    if id == &"" or monster_name.strip_edges().is_empty():
        return "ต้องกำหนด id และชื่อมอนสเตอร์"
    if max_hp < 1 or attack < 0 or move_speed <= 0.0:
        return "HP/ความเร็วต้องมากกว่า 0 และ Attack ต้องไม่ติดลบ"
    if attack_range <= 0.0 or attack_interval <= 0.0:
        return "ระยะโจมตีและช่วงเวลาโจมตีต้องมากกว่า 0"
    if evolution_cost < 0.0 or ds_drain_per_second < 0.0:
        return "ค่า DS ต้องไม่ติดลบ"
    if sprite_scale.x <= 0.0 or sprite_scale.y <= 0.0:
        return "ขนาด Sprite ต้องมากกว่า 0"
    if sprite_frames == null:
        return "ต้องกำหนด SpriteFrames"
    if not sprite_frames.has_animation(idle_animation):
        return "ไม่มีแอนิเมชัน Idle ที่กำหนด"
    if sprite_frames.get_frame_count(idle_animation) == 0:
        return "แอนิเมชัน Idle ต้องมีอย่างน้อยหนึ่งเฟรม"
    if not is_finite(animation_reference_speed) or animation_reference_speed <= 0.0:
        return "ความเร็วอ้างอิงแอนิเมชันต้องมากกว่า 0"
    if require_directional_animations:
        for direction: String in ["down", "right", "up", "left"]:
            for prefix: String in ["idle", "walk"]:
                var key := StringName(prefix + "_" + direction)
                if not sprite_frames.has_animation(key) or sprite_frames.get_frame_count(key) == 0:
                    return "ขาดแอนิเมชัน " + String(key)
    if require_action_animations:
        if attack_sprite_scale.x <= 0.0 or attack_sprite_scale.y <= 0.0 or cast_sprite_scale.x <= 0.0 or cast_sprite_scale.y <= 0.0:
            return "สเกลภาพ Attack/Cast ต้องมากกว่า 0"
        for direction: String in ["down", "right", "up", "left"]:
            for prefix: String in ["attack", "cast"]:
                var key := StringName(prefix + "_" + direction)
                if not sprite_frames.has_animation(key) or sprite_frames.get_frame_count(key) < 4:
                    return "แอคชั่นต้องมีอย่างน้อย 4 เฟรม: " + String(key)
                if sprite_frames.get_animation_loop(key):
                    return "แอคชั่นต้องปิด Loop: " + String(key)
                if sprite_frames.get_animation_speed(key) <= 0.0:
                    return "แอคชั่นต้องมี FPS มากกว่า 0: " + String(key)
                if prefix == "attack" and attack_hit_frame >= sprite_frames.get_frame_count(key):
                    return "attack_hit_frame อยู่นอกชุดภาพ"
    var ids: Array[StringName] = []
    for skill: MonsterSkill in skills:
        if skill == null or skill.id == &"":
            return "สกิลต้องไม่เป็น null และต้องมี id"
        if skill.id in ids:
            return "id สกิลซ้ำในร่างเดียวกัน"
        var skill_error: String = skill.validation_error()
        if not skill_error.is_empty():
            return skill_error
        if require_action_animations:
            for direction: String in ["down", "right", "up", "left"]:
                var key := StringName(String(skill.animation_prefix) + "_" + direction)
                if skill.release_frame >= sprite_frames.get_frame_count(key):
                    return "release_frame ของสกิลอยู่นอกชุดภาพ: " + String(skill.id)
        ids.append(skill.id)
    return ""
