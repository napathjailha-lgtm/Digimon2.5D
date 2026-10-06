extends Node

const REMOTE_TAMER_SCENE := preload("res://scenes/online/remote_tamer.tscn")

@export var zone_id: StringName = &"file_island"
@export var actors_path: NodePath = NodePath("../Actors")
@export var local_tamer_path: NodePath = NodePath("../Actors/Tamer")

var remotes: Dictionary = {}
var local_chat_bubble: WorldChatBubble

func _ready() -> void:
    OnlineManager.remote_joined.connect(_on_remote_joined)
    OnlineManager.remote_left.connect(_on_remote_left)
    OnlineManager.remote_state.connect(_on_remote_state)
    OnlineManager.remote_chat.connect(_on_remote_chat)
    OnlineManager.connection_changed.connect(_on_connection_changed)
    GameChat.local_message_submitted.connect(_on_local_chat_submitted)

    var tamer := get_node_or_null(local_tamer_path) as Tamer
    if tamer != null:
        _ensure_local_chat_bubble(tamer)
        OnlineManager.bind_world(tamer, zone_id)

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
    remotes[peer_id] = remote
    return remote

func _remove_remote(peer_id: String) -> void:
    if not remotes.has(peer_id):
        return
    var remote: Variant = remotes[peer_id]
    remotes.erase(peer_id)
    if is_instance_valid(remote):
        remote.queue_free()
