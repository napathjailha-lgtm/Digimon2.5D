extends Node3D

const PLAYER_SCRIPT: Script = preload("res://scripts/player.gd")
const COMPANION_SCRIPT: Script = preload("res://scripts/companion.gd")
const PORT: int = 8910

var player: CharacterBody3D
var companion: Node3D
var enemies: Array[Node3D] = []
var remote_players: Dictionary = {}
var status_label: Label
var network_label: Label
var attack_timer: float = 0.0
var network_timer: float = 0.0
var next_enemy_id: int = 1

func _ready() -> void:
    _build_world()
    _build_player()
    _build_companion()
    _build_enemies()
    _build_ui()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    attack_timer = maxf(0.0, attack_timer - delta)
    network_timer += delta
    if multiplayer.multiplayer_peer != null and network_timer >= 0.08:
        network_timer = 0.0
        if multiplayer.is_server():
            _broadcast_local_state()
        else:
            _send_local_state()
    _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_mouse_capture"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    elif event.is_action_pressed("attack"):
        _command_companion_attack()
    elif event.is_action_pressed("interact"):
        _evolve_companion()

func _build_world() -> void:
    var env: WorldEnvironment = WorldEnvironment.new()
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky: Sky = Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.68, 0.78, 1.0)
    environment.ambient_light_energy = 0.7
    env.environment = environment
    add_child(env)

    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)

    var ground: MeshInstance3D = MeshInstance3D.new()
    var ground_mesh: PlaneMesh = PlaneMesh.new()
    ground_mesh.size = Vector2(90.0, 90.0)
    ground.mesh = ground_mesh
    ground.material_override = _material(Color(0.16, 0.36, 0.25), 0.95)
    ground.position.y = 0.0
    add_child(ground)

    var ground_body: StaticBody3D = StaticBody3D.new()
    ground_body.name = "GroundCollision"
    var ground_shape: CollisionShape3D = CollisionShape3D.new()
    var ground_box: BoxShape3D = BoxShape3D.new()
    ground_box.size = Vector3(90.0, 1.0, 90.0)
    ground_shape.shape = ground_box
    ground_shape.position.y = -0.5
    ground_body.add_child(ground_shape)
    add_child(ground_body)

    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 20261019
    for i: int in range(42):
        var tree: Node3D = Node3D.new()
        var x: float = rng.randf_range(-36.0, 36.0)
        var z: float = rng.randf_range(-36.0, 36.0)
        if Vector2(x, z).length() < 9.0:
            x += 14.0
        tree.position = Vector3(x, 0.0, z)
        var trunk: MeshInstance3D = MeshInstance3D.new()
        var trunk_mesh: CylinderMesh = CylinderMesh.new()
        trunk_mesh.top_radius = 0.22
        trunk_mesh.bottom_radius = 0.36
        trunk_mesh.height = 2.0
        trunk.mesh = trunk_mesh
        trunk.position.y = 1.0
        trunk.material_override = _material(Color(0.30, 0.18, 0.11))
        tree.add_child(trunk)
        var crown: MeshInstance3D = MeshInstance3D.new()
        var crown_mesh: SphereMesh = SphereMesh.new()
        crown_mesh.radius = rng.randf_range(1.1, 1.8)
        crown_mesh.height = crown_mesh.radius * 2.0
        crown.mesh = crown_mesh
        crown.position.y = 2.6
        crown.material_override = _material(Color(0.10, rng.randf_range(0.28, 0.42), 0.23))
        tree.add_child(crown)
        add_child(tree)

    for i: int in range(8):
        var crystal: MeshInstance3D = MeshInstance3D.new()
        var crystal_mesh: PrismMesh = PrismMesh.new()
        crystal_mesh.size = Vector3(0.7, 1.5, 0.7)
        crystal.mesh = crystal_mesh
        crystal.position = Vector3(float(i % 4) * 4.5 - 7.0, 0.75, -12.0 - float(i / 4) * 4.0)
        crystal.rotation_degrees.y = float(i) * 17.0
        crystal.material_override = _material(Color(0.18, 0.72, 0.96), 0.25, 0.3)
        add_child(crystal)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "LocalPlayer"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0.0, 0.15, 0.0)
    add_child(player)

func _build_companion() -> void:
    companion = Node3D.new()
    companion.name = "Partner"
    companion.set_script(COMPANION_SCRIPT)
    companion.set("owner_player", player)
    companion.position = Vector3(-1.7, 0.0, 1.2)
    add_child(companion)

func _build_enemies() -> void:
    for i: int in range(5):
        var enemy: Node3D = _make_enemy(next_enemy_id)
        next_enemy_id += 1
        enemy.position = Vector3(5.0 + float(i % 3) * 3.0, 0.0, -3.0 - float(i / 3) * 4.0)
        add_child(enemy)
        enemies.append(enemy)

func _make_enemy(enemy_id: int) -> Node3D:
    var enemy: Node3D = Node3D.new()
    enemy.name = "WildBitling_%d" % enemy_id
    enemy.set_meta("enemy_id", enemy_id)
    enemy.set_meta("hp", 40)
    enemy.set_meta("max_hp", 40)
    var body: MeshInstance3D = MeshInstance3D.new()
    var body_mesh: SphereMesh = SphereMesh.new()
    body_mesh.radius = 0.62
    body_mesh.height = 1.24
    body.mesh = body_mesh
    body.position.y = 0.65
    body.material_override = _material(Color(0.88, 0.30, 0.36))
    enemy.add_child(body)
    var eye_left: MeshInstance3D = _make_eye()
    eye_left.position = Vector3(-0.22, 0.78, -0.48)
    enemy.add_child(eye_left)
    var eye_right: MeshInstance3D = _make_eye()
    eye_right.position = Vector3(0.22, 0.78, -0.48)
    enemy.add_child(eye_right)
    return enemy

func _make_eye() -> MeshInstance3D:
    var eye: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.095
    mesh.height = 0.19
    eye.mesh = mesh
    eye.material_override = _material(Color(0.97, 0.97, 1.0), 0.2)
    return eye

func _build_ui() -> void:
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var panel: PanelContainer = PanelContainer.new()
    panel.position = Vector2(18.0, 18.0)
    panel.custom_minimum_size = Vector2(320.0, 104.0)
    layer.add_child(panel)
    var col: VBoxContainer = VBoxContainer.new()
    panel.add_child(col)
    var title: Label = Label.new()
    title.text = "PRISM TAMER 3D  |  FIELD TEST"
    title.add_theme_font_size_override("font_size", 18)
    col.add_child(title)
    status_label = Label.new()
    col.add_child(status_label)
    network_label = Label.new()
    col.add_child(network_label)
    var help: Label = Label.new()
    help.text = "WASD Move  |  Mouse Look  |  Space Partner Attack  |  E Evolve"
    help.position = Vector2(18.0, 680.0)
    layer.add_child(help)
    var host_button: Button = Button.new()
    host_button.text = "Host LAN"
    host_button.position = Vector2(18.0, 132.0)
    host_button.pressed.connect(_host_game)
    layer.add_child(host_button)
    var join_button: Button = Button.new()
    join_button.text = "Join 127.0.0.1"
    join_button.position = Vector2(110.0, 132.0)
    join_button.pressed.connect(_join_local_game)
    layer.add_child(join_button)
    var disconnect_button: Button = Button.new()
    disconnect_button.text = "Offline"
    disconnect_button.position = Vector2(242.0, 132.0)
    disconnect_button.pressed.connect(_disconnect_game)
    layer.add_child(disconnect_button)

func _update_hud() -> void:
    if status_label == null:
        return
    var hp: int = int(companion.get("hp"))
    var level: int = int(companion.get("level"))
    var evo_name: String = str(companion.get("form_name"))
    var target: Node3D = _nearest_enemy()
    var target_text: String = "No target"
    if is_instance_valid(target):
        target_text = "%s HP %d/40" % [target.name, int(target.get_meta("hp"))]
    status_label.text = "Partner: %s  Lv.%d  HP %d/100\nTarget: %s" % [evo_name, level, hp, target_text]
    if multiplayer.multiplayer_peer == null:
        network_label.text = "Network: Offline  |  LAN port %d" % PORT
    else:
        network_label.text = "Network: %s  |  Players: %d" % ["Host" if multiplayer.is_server() else "Client", multiplayer.get_peers().size() + (1 if multiplayer.is_server() else 0)]

func _nearest_enemy() -> Node3D:
    var best: Node3D = null
    var best_distance: float = 999999.0
    for enemy: Node3D in enemies:
        if is_instance_valid(enemy) and int(enemy.get_meta("hp")) > 0:
            var distance: float = player.global_position.distance_to(enemy.global_position)
            if distance < best_distance:
                best_distance = distance
                best = enemy
    return best

func _command_companion_attack() -> void:
    if attack_timer > 0.0:
        return
    attack_timer = 0.5
    var target: Node3D = _nearest_enemy()
    if target == null or player.global_position.distance_to(target.global_position) > 15.0:
        return
    companion.call("play_attack")
    var new_hp: int = maxi(0, int(target.get_meta("hp")) - int(companion.get("attack_power")))
    target.set_meta("hp", new_hp)
    if new_hp == 0:
        player.set_meta("exp", int(player.get_meta("exp", 0)) + 20)
        target.queue_free()
        enemies.erase(target)
        var timer: SceneTreeTimer = get_tree().create_timer(4.0)
        timer.timeout.connect(_respawn_enemy)
    else:
        target.scale = Vector3(1.12, 0.9, 1.12)
        var tween: Tween = create_tween()
        tween.tween_property(target, "scale", Vector3.ONE, 0.15)

func _respawn_enemy() -> void:
    var enemy: Node3D = _make_enemy(next_enemy_id)
    next_enemy_id += 1
    enemy.position = Vector3(randf_range(5.0, 13.0), 0.0, randf_range(-10.0, -2.0))
    add_child(enemy)
    enemies.append(enemy)

func _evolve_companion() -> void:
    companion.call("evolve")
    status_label.text = "Evolution unlocked! Partner form changed."

func _material(color: Color, roughness: float = 0.8, emission: float = 0.0) -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _host_game() -> void:
    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var result: Error = peer.create_server(PORT, 8)
    if result != OK:
        network_label.text = "Host failed: %s" % error_string(result)
        return
    multiplayer.multiplayer_peer = peer
    if not multiplayer.peer_connected.is_connected(_on_peer_connected):
        multiplayer.peer_connected.connect(_on_peer_connected)
    network_label.text = "Hosting LAN on UDP %d" % PORT

func _join_local_game() -> void:
    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var result: Error = peer.create_client("127.0.0.1", PORT)
    if result != OK:
        network_label.text = "Join failed: %s" % error_string(result)
        return
    multiplayer.multiplayer_peer = peer
    network_label.text = "Connecting to localhost..."

func _disconnect_game() -> void:
    multiplayer.multiplayer_peer = null
    for peer_id: Variant in remote_players.keys():
        var avatar: Node3D = remote_players[peer_id]
        if is_instance_valid(avatar):
            avatar.queue_free()
    remote_players.clear()
    network_label.text = "Network disconnected"

func _on_peer_connected(_peer_id: int) -> void:
    _broadcast_local_state()

func _send_local_state() -> void:
    submit_player_state.rpc_id(1, multiplayer.get_unique_id(), player.global_position, player.rotation.y)

func _broadcast_local_state() -> void:
    var own_id: int = multiplayer.get_unique_id()
    receive_player_state(own_id, player.global_position, player.rotation.y)
    for peer_id: int in multiplayer.get_peers():
        relay_player_state.rpc_id(peer_id, own_id, player.global_position, player.rotation.y)

@rpc("any_peer", "call_remote", "unreliable")
func submit_player_state(peer_id: int, pos: Vector3, yaw: float) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if sender != peer_id:
        return
    receive_player_state(peer_id, pos, yaw)
    for other_id: int in multiplayer.get_peers():
        if other_id != peer_id:
            relay_player_state.rpc_id(other_id, peer_id, pos, yaw)

@rpc("authority", "call_remote", "unreliable")
func relay_player_state(peer_id: int, pos: Vector3, yaw: float) -> void:
    receive_player_state(peer_id, pos, yaw)

func receive_player_state(peer_id: int, pos: Vector3, yaw: float) -> void:
    if peer_id == multiplayer.get_unique_id():
        return
    var avatar: Node3D
    if remote_players.has(peer_id) and is_instance_valid(remote_players[peer_id]):
        avatar = remote_players[peer_id]
    else:
        avatar = _make_remote_avatar(peer_id)
        remote_players[peer_id] = avatar
        add_child(avatar)
    avatar.position = pos
    avatar.rotation.y = yaw

func _make_remote_avatar(peer_id: int) -> Node3D:
    var avatar: Node3D = Node3D.new()
    avatar.name = "RemoteTamer_%d" % peer_id
    var body: MeshInstance3D = MeshInstance3D.new()
    var mesh: CapsuleMesh = CapsuleMesh.new()
    mesh.radius = 0.38
    mesh.height = 1.8
    body.mesh = mesh
    body.position.y = 0.9
    body.material_override = _material(Color(0.25, 0.62, 0.98))
    avatar.add_child(body)
    var head: MeshInstance3D = MeshInstance3D.new()
    var head_mesh: SphereMesh = SphereMesh.new()
    head_mesh.radius = 0.28
    head_mesh.height = 0.56
    head.mesh = head_mesh
    head.position.y = 1.95
    head.material_override = _material(Color(0.95, 0.72, 0.56))
    avatar.add_child(head)
    return avatar
