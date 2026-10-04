class_name SkillHitResolver
extends RefCounted
## ใช้เส้นทางลงดาเมจเดียวกันทั้งสกิลทันทีและลูกไฟที่ชนแล้ว
const IMPACT_EFFECT = preload("res://scripts/skill_impact.gd")

static func apply_hit(world: Node2D, center: Vector2, primary: WildMonster,
        source: Node2D, damage: int, radius: float, color: Color,
        visual_size: float, wall_mask: int, visual_style: String = "fire") -> void:
    # เก็บเหยื่อก่อน take_damage เพราะ hit สุดท้ายอาจ queue_free ศัตรู
    if not is_instance_valid(world) or not world.is_inside_tree():
        return
    if source is PartnerMonster and not source.can_battle():
        return
    var victims: Array[WildMonster] = []
    if is_instance_valid(primary) and primary.is_alive():
        victims.append(primary)
    if radius > 0.0:
        for node: Node in world.get_tree().get_nodes_in_group("wild_monsters"):
            var enemy := node as WildMonster
            if not is_instance_valid(enemy) or not enemy.is_alive() or enemy == primary:
                continue
            if center.distance_to(enemy.global_position) > radius:
                continue
            # ระเบิดไม่ทำดาเมจทะลุกำแพง แม้ศัตรูอยู่ในรัศมี
            var ray := PhysicsRayQueryParameters2D.create(center, enemy.global_position, wall_mask)
            if world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
                victims.append(enemy)
    # จำกัดเฉพาะภาพเมื่อโจมตีรัว ไม่ข้ามการคำนวณดาเมจ
    var limit: int = 12 if GameVisualSettings.low_effects else 32
    if world.get_tree().get_nodes_in_group("skill_vfx").size() < limit:
        var effect := Node2D.new()
        effect.set_script(IMPACT_EFFECT)
        effect.color = color
        effect.radius = maxf(visual_size, radius)
        effect.style = visual_style
        effect.position = world.to_local(center)
        world.add_child(effect)
    var credited_source: Node2D = source if is_instance_valid(source) else null
    for enemy: WildMonster in victims:
        if is_instance_valid(enemy) and enemy.is_alive():
            enemy.take_damage(damage, credited_source)
