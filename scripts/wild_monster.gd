class_name WildMonster
extends CharacterBody2D
## เดินสุ่มในลานโล่ง และโต้กลับเฉพาะคู่หูที่ตีตนเอง
## ถ้าต้องอ้อมกำแพง ให้เพิ่ม NavigationAgent2D เช่นเดียวกับคู่หู

signal died(enemy: WildMonster)
const DAMAGE_POPUP_SCENE: PackedScene = preload("res://scenes/damage_popup.tscn")
# กำหนดเป็น World/DamagePopups ซึ่งเป็น Node2D ในโลกเดียวกับศัตรู
@export var popup_layer: Node2D
@onready var damage_origin: Marker2D = $DamageOrigin
@export var monster_id: StringName = &"wild"
@export_range(0, 100000) var exp_reward: int = 60
## Inspector เลือก LootTable ของมอนสเตอร์แต่ละชนิด; ไม่กำหนดใช้ตารางสามไอเทมตัวอย่าง
@export var drop_table: LootTable
@export var loot_enabled: bool = true
var _loot_rolled: bool = false
var _loot_rng := RandomNumberGenerator.new()
@export var max_hp: int = 160
@export var move_speed: float = 95.0
@export var attack_damage: int = 9
@export var attack_range: float = 58.0
@export var wander_radius: float = 100.0
# Spawner กำหนดให้เดินสุ่มรอบศูนย์กลางจุดเกิด ไม่ใช่รอบตำแหน่งสุ่มแรก
@export var home_anchor: Node2D
@export var leash_distance: float = 260.0
@onready var ring: Node2D = $TargetRing
var hp: int
var _home: Vector2
var _wander_goal: Vector2
var _wander_left: float = 0.0
var _attack_left: float = 0.0
var _attacker: CharacterBody2D
var _world_environment: OpenWorldEnvironment
var _navigation: NavigationAgent2D
var _path_left: float = 0.0
var _path_goal: Vector2 = Vector2.INF

func _ready() -> void:
    add_to_group("wild_monsters")
    hp = max_hp
    _loot_rng.randomize()
    if drop_table == null:
        drop_table = load("res://data/items/default_loot.tres") as LootTable
    _home = home_anchor.global_position if is_instance_valid(home_anchor) else global_position
    _wander_goal = _home
    ring.hide()
    _world_environment = get_parent().get_parent().get_node_or_null("OpenWorldEnvironment") as OpenWorldEnvironment
    if _world_environment != null:
        _navigation = NavigationAgent2D.new()
        _navigation.path_desired_distance = 10.0
        _navigation.target_desired_distance = 8.0
        _navigation.avoidance_enabled = false
        add_child(_navigation)
    # ขอบเขตรับ Touch ครอบภาพจริง แยกจาก Collision ฟิสิกส์ที่ใต้เท้า
    var image: Sprite2D = $Sprite2D
    var touch_shape := RectangleShape2D.new()
    touch_shape.size = image.texture.get_size() * image.scale.abs()
    $TouchTarget/CollisionShape2D.shape = touch_shape
    $TouchTarget/CollisionShape2D.position.y = -touch_shape.size.y * 0.5

func is_alive() -> bool:
    return hp > 0

func set_selected(selected: bool) -> void:
    ring.visible = selected and is_alive()

func take_damage(amount: int, attacker: Node2D = null) -> void:
    # attacker เป็น optional: เรียก take_damage(30) ได้ และรองรับคู่หูเดิมที่ส่ง self
    if not is_alive() or amount <= 0:
        return

    hp = maxi(0, hp - amount)
    if is_instance_valid(attacker):
        _attacker = attacker as CharacterBody2D

    # สร้างก่อนลบศัตรู ตัวเลข hit สุดท้ายจึงยังมองเห็น
    _spawn_damage_popup(amount)
    if hp == 0:
        ring.hide()
        collision_layer = 0
        # นับเควสต์เมื่อคู่หูผู้เล่นเป็นผู้โจมตี ไม่ใช่การลบโดย Spawner
        if attacker is PartnerMonster:
            var event_id: String = "%s:%s" % [Time.get_unix_time_from_system(), get_instance_id()]
            QuestManager.report_event(StoryQuest.Objective.KILL, monster_id, 1, event_id)
        # hp == 0 ทำให้ take_damage ครั้งถัดไป return จึงให้ EXP ครั้งเดียว
        var credited_tamer: Tamer = null
        if attacker is PartnerMonster:
            credited_tamer = attacker.tamer
        elif attacker is Tamer:
            credited_tamer = attacker
        if is_instance_valid(credited_tamer):
            credited_tamer.grant_party_exp(exp_reward)
        _spawn_loot()
        died.emit(self)
        queue_free()

func _spawn_loot() -> void:
    # เรียกจาก HP==0 เท่านั้น ไม่ใช้ tree_exited ซึ่งเกิดได้จากการวาร์ป/ปิด Scene
    if _loot_rolled or not loot_enabled or drop_table == null:
        return
    _loot_rolled = true
    var layer: Node2D = get_parent() as Node2D
    if layer == null:
        return
    var drops: Array[Dictionary] = drop_table.roll(_loot_rng)
    for index: int in range(drops.size()):
        # แยกจุดตกเล็กน้อยไม่ให้ไอคอนซ้อน; Loot ไม่เป็นลูกมอนสเตอร์ที่กำลังถูกลบ
        var offset: Vector2 = Vector2.from_angle(float(index) * 2.4) * (10.0 + index * 8.0)
        InventoryManager.create_loot(drops[index].item, int(drops[index].quantity), layer, global_position + offset)

func _spawn_damage_popup(amount: int) -> void:
    var layer: Node2D = popup_layer
    if not is_instance_valid(layer):
        layer = get_tree().current_scene as Node2D
    if not is_instance_valid(layer):
        layer = get_parent() as Node2D
    if not is_instance_valid(layer):
        return

    var popup: DamagePopup = DAMAGE_POPUP_SCENE.instantiate() as DamagePopup
    popup.damage_amount = amount
    # แปลงพิกัดหัวจากโลกเป็น local ของ layer ก่อน add_child
    # เพราะ _ready เริ่ม Tween ทันทีที่เพิ่มเข้า SceneTree
    popup.position = layer.to_local(damage_origin.global_position)
    layer.add_child(popup)
    # Popup เป็นลูก layer แยกจากศัตรู ไม่วิ่งตามศัตรูและไม่ถูกลบเมื่อศัตรูตาย

func _physics_process(delta: float) -> void:
    if not is_alive():
        return
    _attack_left -= delta
    _path_left -= delta
    velocity = Vector2.ZERO
    if is_instance_valid(_attacker):
        if not bool(_attacker.call("is_alive")) or _home.distance_to(_attacker.global_position) > leash_distance:
            _attacker = null
    if is_instance_valid(_attacker):
        if global_position.distance_to(_attacker.global_position) > attack_range:
            velocity = _movement_direction(_attacker.global_position) * move_speed
        elif _attack_left <= 0.0:
            _attack_left = 1.0
            _attacker.call("take_damage", attack_damage, self)
    else:
        _wander_left -= delta
        if _wander_left <= 0.0:
            _wander_left = randf_range(1.5, 3.0)
            _wander_goal = _choose_wander_goal()
        if global_position.distance_to(_wander_goal) > 8.0:
            velocity = _movement_direction(_wander_goal) * move_speed
    move_and_slide()
    # สไปรต์ศัตรูหันตามทิศทางแนวนอนขณะ Wander/Battle
    if absf(velocity.x) > 2.0:
        $Sprite2D.flip_h = velocity.x < 0.0

func _choose_wander_goal() -> Vector2:
    # แผนที่กว้างมีสิ่งกีดขวาง: ไม่สุ่มเป้าหมายไปกลางน้ำหรือในบ้าน
    for attempt: int in range(24):
        var point: Vector2 = _home + Vector2.from_angle(randf() * TAU) * randf_range(0.0, wander_radius)
        if not is_instance_valid(_world_environment) or _world_environment.can_spawn_at(point):
            return point
    return _home

func _movement_direction(goal: Vector2) -> Vector2:
    if _navigation == null:
        return global_position.direction_to(goal)
    var map: RID = _navigation.get_navigation_map()
    if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
        return Vector2.ZERO
    if _path_left <= 0.0 or _path_goal.distance_squared_to(goal) > 144.0:
        _path_left = 0.25
        _path_goal = goal
        _navigation.target_position = goal
    if _navigation.is_navigation_finished():
        return Vector2.ZERO
    return global_position.direction_to(_navigation.get_next_path_position())
