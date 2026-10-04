@tool
class_name MonsterSpawner
extends Marker2D
## หนึ่ง Spawner ดูแลมอนสเตอร์ที่มีชีวิตหนึ่งตัว
## คัดลอก Scene ไปวางหลายจุด แต่ละตัวมี Timer และสถานะแยกกัน

signal monster_spawned(monster: WildMonster)

@export var monster_scene: PackedScene
@export_range(0.0, 1000.0) var spawn_radius: float = 100.0:
    set(value):
        spawn_radius = maxf(0.0, value)
        queue_redraw()
@export_range(0.1, 600.0) var respawn_time: float = 5.0
# กำหนด Actors เพื่อให้มอนสเตอร์เข้า Y Sort เดียวกับ Tamer/Partner
# หากไม่กำหนดจะสร้างเป็นลูกของ Spawner นี้
@export var monster_parent: Node2D
@export var popup_layer: Node2D
@export_range(0.0, 4000.0) var activation_radius: float = 0.0

@onready var respawn_timer: Timer = $RespawnTimer
var current_monster: WildMonster
var _monster_id: int = 0
var _stopping: bool = false
var _respawn_ready: bool = true
var _activity_left: float = 0.0
var _awake: bool = true

func _ready() -> void:
    # @tool ใช้แสดงวงรัศมีใน Editor เท่านั้น ไม่สร้างมอนสเตอร์ใน Editor
    if Engine.is_editor_hint():
        return
    respawn_timer.one_shot = true
    respawn_timer.autostart = false
    respawn_timer.timeout.connect(_on_respawn_timeout)
    # รอให้ Node อื่นใน World พร้อมก่อนสร้างมอนสเตอร์
    _spawn_monster.call_deferred()

func _spawn_monster() -> void:
    if Engine.is_editor_hint() or _stopping or not is_inside_tree() or is_queued_for_deletion():
        return
    # ป้องกันเกิดซ้อนเมื่อมีการเรียกซ้ำ
    if is_instance_valid(current_monster):
        return
    if not _respawn_ready or not _player_nearby():
        return
    if monster_scene == null:
        push_warning("MonsterSpawner: ต้องกำหนด monster_scene")
        return

    var instance: Node = monster_scene.instantiate()
    var monster: WildMonster = instance as WildMonster
    if monster == null:
        instance.free()
        push_warning("MonsterSpawner: Root ของ monster_scene ต้องใช้ WildMonster")
        return

    var parent: Node2D = monster_parent if is_instance_valid(monster_parent) else self
    # กำหนดตำแหน่งก่อน add_child เพราะ WildMonster._ready จำตำแหน่งบ้าน
    monster.position = parent.to_local(_random_spawn_position())
    monster.home_anchor = self
    monster.wander_radius = spawn_radius
    monster.popup_layer = popup_layer

    current_monster = monster
    _monster_id = monster.get_instance_id()
    # เริ่มนับตั้งแต่ died ส่วน tree_exited เป็น fallback เมื่อถูกลบโดยตรง
    monster.died.connect(_on_monster_died, CONNECT_ONE_SHOT)
    monster.tree_exited.connect(_on_monster_tree_exited.bind(_monster_id), CONNECT_ONE_SHOT)
    _awake = true
    parent.add_child(monster)
    monster_spawned.emit(monster)

func _player_nearby(extra: float = 0.0) -> bool:
    if activation_radius <= 0.0:
        return true
    if not is_instance_valid(monster_parent):
        return false
    var player: Node2D = monster_parent.get_node_or_null("Tamer") as Node2D
    return is_instance_valid(player) and global_position.distance_squared_to(player.global_position) <= pow(activation_radius + extra, 2)

func _process(delta: float) -> void:
    if Engine.is_editor_hint() or _stopping or activation_radius <= 0.0:
        return
    _activity_left -= delta
    if _activity_left > 0.0:
        return
    _activity_left = 0.45
    if not is_instance_valid(current_monster):
        if _respawn_ready and _player_nearby():
            _spawn_monster.call_deferred()
        return
    # Hysteresis 300 px ป้องกันสลับตื่น/หลับถี่เมื่อยืนตรงขอบระยะ
    var awake: bool = _player_nearby(300.0 if _awake else 0.0)
    if awake != _awake:
        _awake = awake
        current_monster.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
        current_monster.visible = awake
        current_monster.velocity = Vector2.ZERO

func _random_spawn_position() -> Vector2:
    # sqrt ทำให้สุ่มกระจายสม่ำเสมอในพื้นที่วงกลม
    var environment: OpenWorldEnvironment = null
    if is_instance_valid(monster_parent):
        environment = monster_parent.get_parent().get_node_or_null("OpenWorldEnvironment") as OpenWorldEnvironment
    for attempt: int in range(48):
        var angle: float = randf() * TAU
        var distance: float = sqrt(randf()) * spawn_radius
        var point: Vector2 = global_position + Vector2.from_angle(angle) * distance
        if environment == null or environment.can_spawn_at(point):
            return point
    return global_position

func _on_monster_died(monster: WildMonster) -> void:
    if is_instance_valid(monster):
        _schedule_respawn(monster.get_instance_id())

func _on_monster_tree_exited(instance_id: int) -> void:
    _schedule_respawn(instance_id)

func _schedule_respawn(instance_id: int) -> void:
    if _stopping or not is_inside_tree() or is_queued_for_deletion():
        return
    # died และ tree_exited ของตัวเดียวกันจะเริ่ม Timer เพียงครั้งเดียว
    # signal จากมอนสเตอร์เก่าไม่สามารถล้าง reference ของตัวใหม่ได้
    if instance_id != _monster_id:
        return
    current_monster = null
    _monster_id = 0
    _respawn_ready = false
    respawn_timer.start(maxf(0.1, respawn_time))

func _on_respawn_timeout() -> void:
    _respawn_ready = true
    _spawn_monster.call_deferred()

func get_respawn_time_left() -> float:
    # ใช้ต่อยอด UI นับถอยหลังได้ คืน 0 ขณะมีมอนสเตอร์อยู่
    return respawn_timer.time_left if is_instance_valid(respawn_timer) else 0.0

func _exit_tree() -> void:
    if Engine.is_editor_hint():
        return
    _stopping = true
    _monster_id = 0
    if is_instance_valid(respawn_timer):
        respawn_timer.stop()
    # มอนสเตอร์อาจเป็นลูก Actors จึงต้องเก็บกวาดเมื่อเอา Spawner ออก
    if is_instance_valid(current_monster):
        current_monster.queue_free()
    current_monster = null

func _draw() -> void:
    if Engine.is_editor_hint():
        draw_arc(Vector2.ZERO, spawn_radius, 0.0, TAU, 64, Color(0.3, 1.0, 0.6, 0.75), 2.0)
