extends Node

const REMOTE_TAMER_SCENE := preload("res://scenes/online/remote_tamer.tscn")
const THAI_FONT: Font = preload("res://assets/fonts/NotoSansThai.ttf")

@export var zone_id: StringName = &"file_island"
@export var actors_path: NodePath = NodePath("../Actors")
@export var local_tamer_path: NodePath = NodePath("../Actors/Tamer")

var remotes: Dictionary = {}
var local_chat_bubble: WorldChatBubble
var local_guild_label: Label

var _last_remote_interaction_ms: int = -1000
var _last_remote_interaction_peer: String = ""
const REMOTE_INTERACTION_DEBOUNCE_MS := 180

func _ready() -> void:
    OnlineManager.remote_joined.connect(_on_remote_joined)
    OnlineManager.remote_left.connect(_on_remote_left)
    OnlineManager.remote_state.connect(_on_remote_state)
    OnlineManager.remote_chat.connect(_on_remote_chat)
    OnlineManager.connection_changed.connect(_on_connection_changed)
    OnlineManager.guild_changed.connect(_on_guild_changed)
    GameChat.local_message_submitted.connect(_on_local_chat_submitted)

    var tamer := get_node_or_null(local_tamer_path) as Tamer
    if tamer != null:
        _ensure_local_chat_bubble(tamer)
        _ensure_local_guild_label(tamer)
        OnlineManager.bind_world(tamer, zone_id)
        _on_guild_changed(OnlineManager.guild)

func _exit_tree() -> void:
    var tamer := get_node_or_null(local_tamer_path) as Tamer
    if tamer != null:
        OnlineManager.unbind_world(tamer)
    for node: Variant in remotes.values():
        if is_instance_valid(node):
            node.queue_free()
    remotes.clear()

func _on_remote_joined(peer_id: String, payload: Dictionary) -> void:
    if str(payload.get("zone", String(zone_id))) != String(zone_id):
        return
    _ensure_remote(peer_id, payload)

func _on_remote_state(peer_id: String, payload: Dictionary) -> void:
    if str(payload.get("zone", "")) != String(zone_id):
        _remove_remote(peer_id)
        return
    var remote := _ensure_remote(peer_id, payload)
    remote.apply_state(payload)

func _on_remote_left(peer_id: String) -> void:
    _remove_remote(peer_id)

func _on_remote_chat(peer_id: String, sender: String, text: String) -> void:
    GameChat.add_remote(sender, text)
    if remotes.has(peer_id):
        var remote: Variant = remotes[peer_id]
        if is_instance_valid(remote) and remote is RemoteTamer:
            (remote as RemoteTamer).show_chat(text)

func _on_local_chat_submitted(text: String) -> void:
    if is_instance_valid(local_chat_bubble):
        local_chat_bubble.show_message(text)

func _ensure_local_chat_bubble(tamer: Tamer) -> void:
    if is_instance_valid(local_chat_bubble):
        return
    local_chat_bubble = WorldChatBubble.new()
    local_chat_bubble.name = "OnlineChatBubble"
    local_chat_bubble.position = Vector2(-120.0, -198.0)
    local_chat_bubble.size = Vector2(240.0, 56.0)
    tamer.add_child(local_chat_bubble)

func _ensure_local_guild_label(tamer: Tamer) -> void:
    if is_instance_valid(local_guild_label):
        return
    local_guild_label = Label.new()
    local_guild_label.name = "GuildLabel"
    local_guild_label.position = Vector2(-90.0, -158.0)
    local_guild_label.size = Vector2(180.0, 24.0)
    local_guild_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    local_guild_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    local_guild_label.add_theme_font_override("font", THAI_FONT)
    local_guild_label.add_theme_font_size_override("font_size", 12)
    local_guild_label.add_theme_color_override("font_color", Color("c8a7ff"))
    local_guild_label.add_theme_color_override("font_outline_color", Color("080512"))
    local_guild_label.add_theme_constant_override("outline_size", 3)
    local_guild_label.visible = false
    tamer.add_child(local_guild_label)


func _on_guild_changed(snapshot: Dictionary) -> void:
    if not is_instance_valid(local_guild_label):
        return
    var guild_name: String = str(snapshot.get("name", "")).strip_edges().substr(0, 20)
    local_guild_label.visible = not guild_name.is_empty()
    local_guild_label.text = "<%s>" % guild_name if not guild_name.is_empty() else ""


func _on_connection_changed(is_connected: bool, message: String) -> void:
    GameChat.add_system(message)
    if not is_connected:
        for id: String in remotes.keys():
            _remove_remote(id)

func _ensure_remote(peer_id: String, payload: Dictionary) -> RemoteTamer:
    if remotes.has(peer_id) and is_instance_valid(remotes[peer_id]):
        return remotes[peer_id] as RemoteTamer
    var remote := REMOTE_TAMER_SCENE.instantiate() as RemoteTamer
    remote.name = "Online_" + peer_id.left(8)
    get_node(actors_path).add_child(remote)
    remote.setup(peer_id, payload)
    if not remote.interaction_requested.is_connected(_on_remote_interaction_requested):
        remote.interaction_requested.connect(_on_remote_interaction_requested)
    remotes[peer_id] = remote
    return remote

func _unhandled_input(event: InputEvent) -> void:
    if remotes.is_empty() or not OnlineManager.connected:
        return

    var point := Vector2.ZERO
    var activate: bool = false

    if event is InputEventMouseButton:
        activate = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
        point = event.position
    elif event is InputEventScreenTouch:
        activate = event.pressed and not event.canceled
        point = event.position

    if not activate:
        return

    var picked := _remote_at_screen_point(point)
    if picked == null:
        return

    var now: int = Time.get_ticks_msec()
    if (
        picked.peer_id == _last_remote_interaction_peer
        and now - _last_remote_interaction_ms < REMOTE_INTERACTION_DEBOUNCE_MS
    ):
        get_viewport().set_input_as_handled()
        return

    _last_remote_interaction_peer = picked.peer_id
    _last_remote_interaction_ms = now
    picked.request_interaction()
    get_viewport().set_input_as_handled()


func _remote_at_screen_point(screen_point: Vector2) -> RemoteTamer:
    var best: RemoteTamer = null
    var best_distance: float = INF

    for value: Variant in remotes.values():
        if not is_instance_valid(value) or not (value is RemoteTamer):
            continue
        var remote := value as RemoteTamer
        if not remote.contains_screen_point(screen_point):
            continue

        # ถ้าผู้เล่นซ้อนกัน ให้เลือกตัวที่จุดกึ่งกลางใกล้ pointer มากที่สุด
        var center: Vector2 = remote.get_global_transform_with_canvas() * Vector2(0.0, -68.0)
        var distance: float = center.distance_squared_to(screen_point)
        if distance < best_distance:
            best = remote
            best_distance = distance

    return best


func _on_remote_interaction_requested(peer_id: String, display_name: String, guild_name: String) -> void:
    OnlineManager.request_remote_interaction(peer_id, display_name, guild_name)


func _remove_remote(peer_id: String) -> void:
    if not remotes.has(peer_id):
        return
    var remote: Variant = remotes[peer_id]
    remotes.erase(peer_id)
    if is_instance_valid(remote):
        remote.queue_free()
