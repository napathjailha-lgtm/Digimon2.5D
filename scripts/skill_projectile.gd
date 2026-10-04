class_name SkillProjectile
extends Node2D
## ลูกไฟแบบเบาสำหรับมือถือ ตรวจเส้นทางทุก physics frame กันพุ่งทะลุ
## Physics อยู่ที่จุดเท้า ภาพลูกไฟยกขึ้น 18px เพื่อให้เห็นกลางลำตัว
signal impacted(enemy: WildMonster)
var source: Node2D
var target: WildMonster
var damage: int = 0
var speed: float = 0.0
var lifetime: float = 0.0
var impact_radius: float = 0.0
var color: Color = Color.ORANGE
var visual_size: float = 12.0
var wall_mask: int = 1
var enemy_mask: int = 4
var _resolved: bool = false
var _configured: bool = false
var _direction: Vector2 = Vector2.RIGHT
## แยกจุดวาดจากเส้นฟิสิกส์ที่เท้า ให้พลังออกจากปากคู่หูแต่ยังชน Collider เดิม
var launch_visual_offset: Vector2 = Vector2(0, -18)
var _launch_position: Vector2
var _initial_distance: float = 1.0
var _visual_progress: float = 0.0
var style: String = "fire"
var _trail: Array[Vector2] = []
var _age: float = 0.0

func setup(caster: Node2D, enemy: WildMonster, skill: MonsterSkill,
        rolled_damage: int, walls: int = 1, enemies: int = 4) -> void:
    # สำเนาค่าตอนยิง เปลี่ยนร่างกลางทางจึงไม่เปลี่ยนดาเมจลูกไฟเดิม
    source = caster
    target = enemy
    _launch_position = caster.global_position
    _initial_distance = maxf(1.0, caster.global_position.distance_to(enemy.global_position))
    damage = rolled_damage
    speed = skill.projectile_speed
    lifetime = skill.projectile_lifetime
    impact_radius = skill.impact_radius
    color = skill.effect_color
    visual_size = skill.effect_size
    style = skill.vfx_style
    wall_mask = walls
    enemy_mask = enemies
    _configured = true
    queue_redraw()

func _ready() -> void:
    # inherited process mode ทำให้หยุดพร้อมสนามระหว่างคัตซีน
    add_to_group("skill_projectiles")
    z_index = 5
    material = SkillVFXPaint.unlit_material()
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _trail.append(global_position + launch_visual_offset)

func _physics_process(delta: float) -> void:
    # หมดอายุ/ผู้ยิงสลบ/เป้าหมายตาย ให้ยกเลิกโดยไม่สร้างดาเมจ
    if not _configured or _resolved:
        return
    lifetime -= delta
    _age += delta
    if lifetime <= 0.0 or not is_instance_valid(source) or not is_instance_valid(target):
        _expire()
        return
    if not target.is_alive() or (source is PartnerMonster and not source.can_battle()):
        _expire()
        return
    var destination: Vector2 = target.global_position
    _direction = global_position.direction_to(destination)
    var next_position: Vector2 = global_position.move_toward(destination, speed * delta)
    # Ray ครอบคลุมช่วงที่วิ่งในเฟรมนี้ ไม่ตรวจเฉพาะตำแหน่งปลายทาง
    var ray := PhysicsRayQueryParameters2D.create(global_position, next_position, wall_mask | enemy_mask)
    ray.collide_with_areas = false # ไม่ชน Area รับ Touch ที่ครอบภาพศัตรู
    ray.hit_from_inside = true
    var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
    if not hit.is_empty():
        global_position = hit.position
        var enemy := hit.collider as WildMonster
        if is_instance_valid(enemy) and enemy.is_alive():
            _impact(enemy)
        else:
            _expire() # ชนกำแพง ลูกไฟดับและไม่ระเบิดทะลุไปอีกด้าน
        return
    global_position = next_position
    _visual_progress = clampf(global_position.distance_to(_launch_position) / _initial_distance, 0.0, 1.0)
    # เก็บตำแหน่งโลก จึงเกิดหางโค้งตามทางจริงเมื่อเป้าหมายวิ่งเปลี่ยนทิศ
    _trail.append(global_position + launch_visual_offset.lerp(Vector2(0, -18), _visual_progress))
    var trail_limit: int = 4 if GameVisualSettings.low_effects else 10
    if _trail.size() > trail_limit:
        _trail.pop_front()
    if global_position.distance_squared_to(destination) <= 0.01:
        _impact(target) # รองรับเป้าหมายที่ไม่ได้เปิด collider
    queue_redraw()

func _impact(enemy: WildMonster) -> void:
    # ล็อกก่อนส่งสัญญาณและลงดาเมจ ป้องกัน hit ซ้ำในเฟรมเดียวกัน
    if _resolved:
        return
    if source is PartnerMonster and not source.can_battle():
        _expire()
        return
    _resolved = true
    var world := get_parent() as Node2D
    SkillHitResolver.apply_hit(world, enemy.global_position, enemy, source,
        damage, impact_radius, color, visual_size, wall_mask, style)
    impacted.emit(enemy)
    queue_free()

func _expire() -> void:
    # ลบเฉพาะ projectile ไม่ลบ Partner
    _resolved = true
    queue_free()

func _draw() -> void:
    # ภาพพลังแยกจากตำแหน่งฟิสิกส์เดิม: ไม่เปลี่ยน raycast หรือความเร็วลูกไฟ
    var center: Vector2 = launch_visual_offset.lerp(Vector2(0.0, -18.0), _visual_progress)
    for i: int in range(1, _trail.size()):
        var strength := float(i) / float(_trail.size())
        var a := to_local(_trail[i - 1])
        var b := to_local(_trail[i])
        draw_line(a, b, Color(color, strength * 0.2), visual_size * strength * 1.8, true)
        draw_line(a, b, Color(color.lightened(0.45), strength * 0.65), maxf(1, visual_size * strength * 0.35), true)
    SkillVFXPaint.glow(self, center, visual_size * 2.3, Color(color, 0.7))
    match style:
        "lightning":
            for i: int in range(3):
                var axis := _direction.rotated((i - 1) * 0.7)
                SkillVFXPaint.bolt(self, center - axis * visual_size * 1.7, center + axis * visual_size, float(i), Color(color.lightened(0.6)), 1.5)
        "ice":
            for i: int in range(3):
                var at := center + _direction.orthogonal() * (i - 1) * visual_size * 0.5
                SkillVFXPaint.spark(self, at, _direction, visual_size * (1.0 if i == 1 else 0.7), Color(color.lightened(0.6)))
        "nature":
            for i: int in range(4):
                var angle := _age * 8.0 + float(i) * TAU / 4.0
                SkillVFXPaint.leaf(self, center + Vector2.from_angle(angle) * visual_size * 0.5, angle, visual_size * 0.6, color)
        "wind", "astral":
            for i: int in range(3):
                var angle := _age * 9.0 + i * TAU / 3.0
                draw_arc(center, visual_size * (0.65 + i * 0.15), angle, angle + 1.8, 16, color.lightened(0.5), 2.0, true)
        "missile":
            for side: int in [-1, 1]:
                var at := center + _direction.orthogonal() * side * visual_size * 0.40
                SkillVFXPaint.spark(self, at, _direction, visual_size, Color("dce9ff"))
                SkillVFXPaint.glow(self, at - _direction * visual_size, visual_size * 0.65, Color("ff942f"))
        "wing":
            for side: int in [-1, 1]:
                var tip := center - _direction * visual_size * 0.6 + _direction.orthogonal() * side * visual_size * 1.4
                draw_line(center + _direction * visual_size, tip, Color(color, 0.6), 7, true)
                draw_line(center + _direction * visual_size, tip, Color("fff2c0"), 2, true)
        "claw":
            for i: int in range(3):
                SkillVFXPaint.spark(self, center + _direction.orthogonal() * (i - 1) * 6, _direction, visual_size, color.lightened(0.6))
        _:
            for i: int in range(3):
                var at := center - _direction * visual_size * i * 0.45 + _direction.orthogonal() * sin(_age * 12 + i) * 3
                SkillVFXPaint.glow(self, at, visual_size * (1.0 - i * 0.18), Color(color, 0.85))
    SkillVFXPaint.glow(self, center, visual_size * 0.65, Color(1, 0.98, 0.88, 0.95))
