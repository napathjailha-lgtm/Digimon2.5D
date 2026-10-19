extends Node3D

var owner_player: Node3D
var hp: int = 100
var level: int = 1
var attack_power: int = 12
var form_name: String = "Sproutmon"
var visual: Node3D
var attack_animation_time: float = 0.0

func _ready() -> void:
    _build_visual()

func _process(delta: float) -> void:
    if not is_instance_valid(owner_player):
        return
    attack_animation_time = maxf(0.0, attack_animation_time - delta)
    var behind: Vector3 = owner_player.global_position + owner_player.global_transform.basis * Vector3(-1.4, 0.0, 1.1)
    var distance: float = global_position.distance_to(behind)
    if distance > 0.12:
        global_position = global_position.move_toward(behind, minf(delta * 5.0, distance))
    look_at(Vector3(owner_player.global_position.x, global_position.y, owner_player.global_position.z), Vector3.UP)
    if visual != null:
        visual.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.025)
        visual.position.z = -0.25 if attack_animation_time > 0.0 else 0.0

func play_attack() -> void:
    attack_animation_time = 0.18

func evolve() -> void:
    if level < 5:
        level = 5
    form_name = "Bloomdramon"
    attack_power = 24
    _rebuild_visual()

func _build_visual() -> void:
    visual = Node3D.new()
    visual.name = "StylizedCreature"
    add_child(visual)
    var body: MeshInstance3D = MeshInstance3D.new()
    var body_mesh: SphereMesh = SphereMesh.new()
    body_mesh.radius = 0.62
    body_mesh.height = 1.24
    body.mesh = body_mesh
    body.position.y = 0.68
    body.material_override = _mat(Color(0.26, 0.78, 0.56))
    visual.add_child(body)
    var belly: MeshInstance3D = MeshInstance3D.new()
    var belly_mesh: SphereMesh = SphereMesh.new()
    belly_mesh.radius = 0.38
    belly_mesh.height = 0.76
    belly.mesh = belly_mesh
    belly.position = Vector3(0.0, 0.62, -0.34)
    belly.material_override = _mat(Color(0.91, 0.91, 0.72))
    visual.add_child(belly)
    for side: float in [-1.0, 1.0]:
        var ear: MeshInstance3D = MeshInstance3D.new()
        var ear_mesh: PrismMesh = PrismMesh.new()
        ear_mesh.size = Vector3(0.28, 0.6, 0.22)
        ear.mesh = ear_mesh
        ear.position = Vector3(side * 0.38, 1.25, 0.0)
        ear.rotation.z = side * -0.35
        ear.material_override = _mat(Color(0.14, 0.52, 0.38))
        visual.add_child(ear)
        var eye: MeshInstance3D = MeshInstance3D.new()
        var eye_mesh: SphereMesh = SphereMesh.new()
        eye_mesh.radius = 0.08
        eye_mesh.height = 0.16
        eye.mesh = eye_mesh
        eye.position = Vector3(side * 0.2, 0.82, -0.53)
        eye.material_override = _mat(Color(0.08, 0.12, 0.18))
        visual.add_child(eye)
    var gem: MeshInstance3D = MeshInstance3D.new()
    var gem_mesh: PrismMesh = PrismMesh.new()
    gem_mesh.size = Vector3(0.24, 0.32, 0.2)
    gem.mesh = gem_mesh
    gem.position = Vector3(0.0, 1.13, -0.48)
    gem.material_override = _mat(Color(0.3, 0.9, 1.0), 0.25, 0.8)
    visual.add_child(gem)

func _rebuild_visual() -> void:
    if is_instance_valid(visual):
        visual.queue_free()
    _build_visual()
    visual.scale = Vector3(1.35, 1.35, 1.35)
    for child: Node in visual.get_children():
        if child is MeshInstance3D:
            var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
            if mat != null:
                mat.albedo_color = mat.albedo_color.lerp(Color(0.68, 0.38, 0.95), 0.55)

func _mat(color: Color, roughness: float = 0.75, emission: float = 0.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    return material
