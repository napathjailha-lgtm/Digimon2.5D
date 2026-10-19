extends CharacterBody3D

const MOVE_SPEED: float = 6.5
const TURN_SPEED: float = 10.0
var camera_pivot: Node3D
var camera: Camera3D
var visual: Node3D
var gravity: float = 9.8
var camera_yaw: float = 0.0
var camera_pitch: float = -0.22

func _ready() -> void:
    set_meta("exp", 0)
    _build_body()
    _build_camera()

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis: Basis = Basis(Vector3.UP, camera_yaw)
    var direction: Vector3 = basis * Vector3(input_vector.x, 0.0, input_vector.y)
    if direction.length_squared() > 0.001:
        direction = direction.normalized()
        velocity.x = direction.x * MOVE_SPEED
        velocity.z = direction.z * MOVE_SPEED
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), TURN_SPEED * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 5.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 5.0 * delta)
    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * 0.003
        camera_pitch = clampf(camera_pitch - event.relative.y * 0.002, -0.75, 0.12)
        camera_pivot.rotation.y = camera_yaw
        camera.rotation.x = camera_pitch

func _build_body() -> void:
    var collision: CollisionShape3D = CollisionShape3D.new()
    var capsule: CapsuleShape3D = CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.65
    collision.shape = capsule
    collision.position.y = 0.83
    add_child(collision)
    visual = Node3D.new()
    visual.name = "AnimeTamerVisual"
    add_child(visual)
    var torso: MeshInstance3D = MeshInstance3D.new()
    var torso_mesh: CapsuleMesh = CapsuleMesh.new()
    torso_mesh.radius = 0.35
    torso_mesh.height = 0.95
    torso.mesh = torso_mesh
    torso.position.y = 1.0
    torso.material_override = _mat(Color(0.12, 0.38, 0.82))
    visual.add_child(torso)
    var head: MeshInstance3D = MeshInstance3D.new()
    var head_mesh: SphereMesh = SphereMesh.new()
    head_mesh.radius = 0.27
    head_mesh.height = 0.54
    head.mesh = head_mesh
    head.position.y = 1.72
    head.material_override = _mat(Color(0.96, 0.72, 0.55))
    visual.add_child(head)
    var hair: MeshInstance3D = MeshInstance3D.new()
    var hair_mesh: SphereMesh = SphereMesh.new()
    hair_mesh.radius = 0.29
    hair_mesh.height = 0.32
    hair.mesh = hair_mesh
    hair.position = Vector3(0.0, 1.91, 0.02)
    hair.material_override = _mat(Color(0.10, 0.12, 0.20))
    visual.add_child(hair)
    var pack: MeshInstance3D = MeshInstance3D.new()
    var pack_mesh: BoxMesh = BoxMesh.new()
    pack_mesh.size = Vector3(0.42, 0.42, 0.22)
    pack.mesh = pack_mesh
    pack.position = Vector3(0.0, 1.08, 0.31)
    pack.material_override = _mat(Color(0.95, 0.68, 0.16))
    visual.add_child(pack)

func _build_camera() -> void:
    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.5
    camera_pivot.rotation.y = camera_yaw
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0.0, 2.0, 7.0)
    camera.rotation.x = camera_pitch
    camera.current = true
    camera.fov = 65.0
    camera_pivot.add_child(camera)

func _mat(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.7
    return material
