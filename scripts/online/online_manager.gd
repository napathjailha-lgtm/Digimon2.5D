extends Node
## Online Phase 1: presence / movement / chat เท่านั้น
## Gameplay, loot, economy และ combat ยังเป็น local เพื่อไม่เปิดช่องโกง/ทำเซฟพัง

signal connection_changed(connected: bool, message: String)
signal remote_joined(peer_id: String, payload: Dictionary)
signal remote_left(peer_id: String)
signal remote_state(peer_id: String, payload: Dictionary)
signal remote_chat(sender: String, text: String)

const DEFAULT_SEND_INTERVAL := 0.10
const RECONNECT_DELAY := 4.0
const MAX_CHAT_LENGTH := 160

var socket := WebSocketPeer.new()
var connected: bool = false
var connecting: bool = false
var local_peer_id: String = ""
var server_url: String = ""
var zone_id: StringName = &"file_island"
var local_player: Tamer
var _send_left: float = 0.0
var _reconnect_left: float = 0.0
var _manual_disconnect: bool = false
var _last_facing: String = "down"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    server_url = str(ProjectSettings.get_setting("online/server_url", "")).strip_edges()
    if GameChat.outgoing_message.is_connected(_on_chat_outgoing) == false:
        GameChat.outgoing_message.connect(_on_chat_outgoing)
    if bool(ProjectSettings.get_setting("online/auto_connect", false)) and not server_url.is_empty():
        connect_to_server()

func configure(url: String, auto_connect_now: bool = true) -> void:
    server_url = url.strip_edges()
    if auto_connect_now and not server_url.is_empty():
        connect_to_server()

func bind_world(player: Tamer, next_zone: StringName) -> void:
    local_player = player
    zone_id = next_zone
    if connected:
        _send_json({
            "type": "hello",
            "name": _display_name(),
            "zone": String(zone_id),
            "position": _vec2(local_player.global_position)
        })

func unbind_world(player: Tamer) -> void:
    if local_player == player:
        local_player = null

func connect_to_server() -> void:
    if server_url.is_empty() or connected or connecting:
        return
    _manual_disconnect = false
    socket = WebSocketPeer.new()
    var error := socket.connect_to_url(server_url)
    if error != OK:
        connecting = false
        _schedule_reconnect("เชื่อมต่อ Online Server ไม่สำเร็จ")
        return
    connecting = true
    connection_changed.emit(false, "กำลังเชื่อมต่อ Online Server...")

func disconnect_from_server() -> void:
    _manual_disconnect = true
    if socket.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
        socket.close(1000, "client disconnect")
    connected = false
    connecting = false
    local_peer_id = ""
    connection_changed.emit(false, "Offline")

func _process(delta: float) -> void:
    var state := socket.get_ready_state()
    if state in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CLOSING]:
        socket.poll()

    state = socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not connected:
            connected = true
            connecting = false
            _reconnect_left = 0.0
            connection_changed.emit(true, "Online")
            _send_json({
                "type": "hello",
                "name": _display_name(),
                "zone": String(zone_id),
                "position": _vec2(local_player.global_position) if is_instance_valid(local_player) else {"x": 0.0, "y": 0.0}
            })
        while socket.get_available_packet_count() > 0:
            _handle_packet(socket.get_packet().get_string_from_utf8())

        _send_left -= delta
        if _send_left <= 0.0 and is_instance_valid(local_player):
            _send_left = float(ProjectSettings.get_setting("online/send_interval", DEFAULT_SEND_INTERVAL))
            _send_player_state()
        return

    if connected or connecting:
        connected = false
        connecting = false
        local_peer_id = ""
        connection_changed.emit(false, "หลุดจาก Online Server")
        if not _manual_disconnect:
            _reconnect_left = RECONNECT_DELAY

    if not _manual_disconnect and not server_url.is_empty() and _reconnect_left > 0.0:
        _reconnect_left -= delta
        if _reconnect_left <= 0.0:
            connect_to_server()

func _send_player_state() -> void:
    var velocity := local_player.get_real_velocity()
    if velocity.length_squared() > 4.0:
        if absf(velocity.x) > absf(velocity.y):
            _last_facing = "right" if velocity.x > 0.0 else "left"
        else:
            _last_facing = "down" if velocity.y > 0.0 else "up"
    _send_json({
        "type": "state",
        "zone": String(zone_id),
        "name": _display_name(),
        "position": _vec2(local_player.global_position),
        "velocity": _vec2(velocity),
        "facing": _last_facing
    })

func send_chat(text: String) -> bool:
    if not connected:
        return false
    var clean := text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").substr(0, MAX_CHAT_LENGTH)
    if clean.is_empty():
        return false
    _send_json({"type": "chat", "zone": String(zone_id), "text": clean})
    return true

func _handle_packet(raw: String) -> void:
    var parsed: Variant = JSON.parse_string(raw)
    if not (parsed is Dictionary):
        return
    var payload := parsed as Dictionary
    match str(payload.get("type", "")):
        "welcome":
            local_peer_id = str(payload.get("id", ""))
        "join":
            var id := str(payload.get("id", ""))
            if not id.is_empty() and id != local_peer_id:
                remote_joined.emit(id, payload)
        "leave":
            var id := str(payload.get("id", ""))
            if not id.is_empty():
                remote_left.emit(id)
        "state":
            var id := str(payload.get("id", ""))
            if not id.is_empty() and id != local_peer_id:
                remote_state.emit(id, payload)
        "chat":
            remote_chat.emit(str(payload.get("name", "ผู้เล่น")), str(payload.get("text", "")))

func _on_chat_outgoing(_channel: StringName, text: String) -> void:
    send_chat(text)

func _send_json(payload: Dictionary) -> void:
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.send_text(JSON.stringify(payload))

func _schedule_reconnect(message: String) -> void:
    connection_changed.emit(false, message)
    if not _manual_disconnect:
        _reconnect_left = RECONNECT_DELAY

func _display_name() -> String:
    if is_instance_valid(local_player) and not local_player.display_name.is_empty():
        return local_player.display_name
    if not GameManager.tamer_name.is_empty():
        return GameManager.tamer_name
    return "Tamer"

func _vec2(value: Vector2) -> Dictionary:
    return {"x": value.x, "y": value.y}
