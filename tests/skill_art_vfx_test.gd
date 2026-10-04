extends Node
## ยืนยันว่าภาพชุดใหม่เชื่อมข้อมูลจริง และงบเอฟเฟกต์ไม่ลดจำนวน hit
var failures: int = 0
var assertions: int = 0

func _ready() -> void:
    run.call_deferred()

func check(ok: bool, detail: String) -> void:
    assertions += 1
    if ok:
        print("PASS: ", detail)
    else:
        failures += 1
        push_error("FAIL: " + detail)

func run() -> void:
    QuestManager.save_path = "user://skill_art_v24_test.json"
    QuestManager.reset_progress(false)
    var paths: Array[String] = []
    for family: String in ["agumon", "gabumon", "piyomon", "tentomon", "palmon"]:
        for stage: int in range(3):
            paths.append("res://data/pregame/%s_%d_skill.tres" % [family, stage])
    for stem: String in ["rookie_strike", "rookie_bolt", "champion_claw", "champion_flare", "champion_burst", "champion_nova", "ultimate_lance", "ultimate_wave", "ultimate_claw", "ultimate_nova", "mega_cannon", "mega_wave", "mega_claw", "mega_nova"]:
        paths.append("res://data/%s.tres" % stem)
    for path: String in paths:
        var skill: MonsterSkill = load(path)
        check(skill != null and skill.validation_error().is_empty() and skill.icon != null and skill.icon.resource_path.begins_with("res://assets/skills_painted/") and skill.icon.get_width() <= 256,
            path.get_file() + " ใช้ภาพใหม่ที่จำกัดขนาด GPU และข้อมูลสกิลถูกต้อง")
    var world := Node2D.new()
    add_child(world)
    var source := Node2D.new()
    world.add_child(source)
    var enemy: WildMonster = preload("res://scenes/wild_monster.tscn").instantiate()
    enemy.max_hp = 10000
    enemy.position = Vector2(300, 300)
    world.add_child(enemy)
    enemy.set_physics_process(false)
    var before: int = enemy.hp
    for style: String in ["fire", "ice", "wind", "lightning", "nature", "claw", "missile", "wing", "astral"]:
        SkillHitResolver.apply_hit(world, enemy.position, enemy, source, 10, 0, Color.ORANGE, 24, 1, style)
    check(enemy.hp == before - 90, "แต่ละภาพลงดาเมจครั้งเดียวผ่าน HitResolver")
    check(get_tree().get_nodes_in_group("skill_vfx").size() == 9, "ทุกสไตล์สร้างเอฟเฟกต์ได้")
    var first: Node = get_tree().get_nodes_in_group("skill_vfx")[0]
    var age: float = first.elapsed
    get_tree().paused = true
    await get_tree().create_timer(0.10, true).timeout
    check(is_equal_approx(first.elapsed, age), "เอฟเฟกต์หยุดขณะ pause")
    get_tree().paused = false
    await get_tree().create_timer(0.8).timeout
    check(get_tree().get_nodes_in_group("skill_vfx").is_empty(), "เอฟเฟกต์หมดอายุแล้วลบตัวเองทั้งหมด")
    check(enemy.hp == before - 90, "ระหว่างแอนิเมชันไม่มีดาเมจแฝงเพิ่ม")
    GameVisualSettings.low_effects = true
    before = enemy.hp
    for i: int in range(40):
        SkillHitResolver.apply_hit(world, enemy.position, enemy, source, 1, 0, Color.ORANGE, 24, 1, "lightning")
    check(get_tree().get_nodes_in_group("skill_vfx").size() == 12, "โหมดเอฟเฟกต์น้อยจำกัด burst ไว้ 12 ภาพ")
    check(enemy.hp == before - 40, "แม้งบภาพเต็มยังลงดาเมจครบ 40 hit")
    await get_tree().create_timer(0.6).timeout
    GameVisualSettings.low_effects = false
    var button := HybridCommand.new()
    button.size = Vector2(72, 72)
    button.illustrated = true
    button.icon = load("res://assets/skills_painted/lightning.png")
    button.caption = "Super Shocker"
    add_child(button)
    button.set_cooldown(2.1, 3)
    check(button._countdown.text == "3" and button._countdown.visible, "ภาพใหญ่ยังมีเลขคูลดาวน์ปัดขึ้น")
    button.set_cooldown(0, 3)
    check(not button._countdown.visible and button._label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
        "จบ CD ซ่อน overlay และชื่อยาวตัดบรรทัดในปุ่ม")
    button.queue_free()
    world.queue_free()
    await get_tree().process_frame
    print("RESULT: ", failures, " failure(s), ", assertions, " assertions")
    get_tree().quit(1 if failures else 0)
