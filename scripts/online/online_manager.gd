extends Node
## Online presence + encrypted server persistence for economy/partner snapshots.
## Combat/loot validation ยังเป็น local; Trade จึงยังปิดจน gameplay events เป็น server-authoritative

signal connection_changed(connected: bool, message: String)
signal remote_joined(peer_id: String, payload: Dictionary)
signal remote_left(peer_id: String)
signal remote_state(peer_id: String, payload: Dictionary)
signal remote_chat(peer_id: String, sender: String, text: String)
signal online_count_changed(total: int, zone_count: int)
signal guild_changed(snapshot: Dictionary)
signal guild_chat(peer_id: String, sender: String, text: String)
signal guild_feedback(message: String, ok: bool)
signal guild_invite_received(invite: Dictionary)
signal remote_interaction_requested(peer_id: String, display_name: String, guild_name: String)
signal trade_invite_received(invite: Dictionary)
signal trade_opened(snapshot: Dictionary)
signal trade_changed(snapshot: Dictionary)
signal trade_prepare(payload: Dictionary)
signal trade_commit(payload: Dictionary)
signal trade_closed(message: String, success: bool)
signal trade_feedback(message: String, ok: bool)
signal economy_sync_changed(migrated: bool, revision: int)
signal economy_feedback(message: String, ok: bool)

const DEFAULT_SEND_INTERVAL := 0.10
const RECONNECT_DELAY := 4.0
const MAX_CHAT_LENGTH := 160
const HELLO_TIMEOUT := 10.0
const TRADE_UNAVAILABLE_MESSAGE := "Trade ปิดชั่วคราวเพื่อปรับปรุงความปลอดภัยของไอเทมและ Bits"

var socket := WebSocketPeer.new()
var connected: bool = false
var connecting: bool = false
var local_peer_id: String = ""
var total_online: int = 0
var zone_online: int = 0
var guild: Dictionary = {}
var trade: Dictionary = {}
var server_url: String = ""
var zone_id: StringName = &"file_island"
var local_player: Tamer
var _send_left: float = 0.0
var _reconnect_left: float = 0.0
var _manual_disconnect: bool = false
var _socket_open_announced: bool = false
var _hello_character_key: String = ""
var _hello_left: float = 0.0
var _last_facing: String = "down"
var economy_revision: int = 0
var economy_migrated: bool = false
var _economy_pending: Dictionary = {}
var _economy_inflight: bool = false
var _economy_applying: bool = false
var _economy_loaded_character_key: String = ""

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
    if bool(ProjectSettings.get_setting("online/auto_connect", false)):
        connect_to_server()
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _hello_character_key = ""
        _try_send_hello()

func unbind_world(player: Tamer) -> void:
    if local_player == player:
        local_player = null
        disconnect_from_server()

func connect_to_server() -> void:
    if not GameManager.gameplay_active or not is_instance_valid(local_player):
        return
    if server_url.is_empty() or connected or connecting:
        return
    _manual_disconnect = false
    _socket_open_announced = false
    _hello_character_key = ""
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
    _reconnect_left = 0.0
    _hello_left = 0.0
    _send_json({"type": "leave"})
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.poll()
    if socket.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
        socket.close(1000, "client disconnect")
    connected = false
    connecting = false
    _socket_open_announced = false
    _hello_character_key = ""
    local_peer_id = ""
    _set_online_counts(0, 0)
    guild.clear()
    guild_changed.emit({})
    trade.clear()
    trade_closed.emit("การเชื่อมต่อถูกปิด", false)
    economy_revision = 0
    economy_migrated = false
    _economy_pending.clear()
    _economy_inflight = false
    _economy_applying = false
    _economy_loaded_character_key = ""
    economy_sync_changed.emit(false, 0)
    connection_changed.emit(false, "Offline")

func _process(delta: float) -> void:
    if (connected or connecting) and (not GameManager.gameplay_active or not is_instance_valid(local_player)):
        disconnect_from_server()
    var state := socket.get_ready_state()
    if state in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CLOSING]:
        socket.poll()

    state = socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not _socket_open_announced:
            _socket_open_announced = true
            _reconnect_left = 0.0
            connection_changed.emit(false, "เชื่อมต่อ Online Server แล้ว · รอยืนยันตัวละคร")
        _try_send_hello()

        while socket.get_available_packet_count() > 0:
            _handle_packet(socket.get_packet().get_string_from_utf8())

        if not connected and _hello_left > 0.0:
            _hello_left -= delta
            if _hello_left <= 0.0:
                socket.close(1000, "hello timeout")
        if connected:
            _send_left -= delta
            if _send_left <= 0.0 and is_instance_valid(local_player):
                _send_left = float(ProjectSettings.get_setting("online/send_interval", DEFAULT_SEND_INTERVAL))
                _send_player_state()
        return

    if connected or connecting:
        # A close frame may arrive before the final JSON packet is delivered.
        # Honor the close code too, so replaced/obsolete clients cannot retry.
        var close_code: int = socket.get_close_code()
        if close_code in [4001, 1008]:
            _manual_disconnect = true
            _reconnect_left = 0.0
        connected = false
        connecting = false
        _socket_open_announced = false
        _hello_character_key = ""
        local_peer_id = ""
        _set_online_counts(0, 0)
        guild.clear()
        guild_changed.emit({})
        if not trade.is_empty():
            trade.clear()
            trade_closed.emit("หลุดจาก Online Server การแลกเปลี่ยนถูกยกเลิก", false)
        var disconnect_message: String = "หลุดจาก Online Server"
        if close_code == 4001:
            disconnect_message = "ตัวละครนี้เชื่อมต่อจากหน้าต่างอื่นแล้ว"
        elif close_code == 1008:
            disconnect_message = "Online identity ถูกปฏิเสธ กรุณารีเฟรช/อัปเดตเกม"
        connection_changed.emit(false, disconnect_message)
        if not _manual_disconnect:
            _reconnect_left = RECONNECT_DELAY

    if not _manual_disconnect and not server_url.is_empty() and _reconnect_left > 0.0:
        _reconnect_left -= delta
        if _reconnect_left <= 0.0:
            connect_to_server()

func _try_send_hello() -> void:
    if _manual_disconnect or not GameManager.gameplay_active or not is_instance_valid(local_player):
        return
    if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    var character_key := _character_key()
    if character_key.is_empty() or character_key == _hello_character_key:
        return
    _hello_character_key = character_key
    _hello_left = HELLO_TIMEOUT
    _send_json(_presence_payload("hello"))


func _send_player_state() -> void:
    var velocity := local_player.get_real_velocity()
    if velocity.length_squared() > 4.0:
        if absf(velocity.x) > absf(velocity.y):
            _last_facing = "right" if velocity.x > 0.0 else "left"
        else:
            _last_facing = "down" if velocity.y > 0.0 else "up"
    var payload: Dictionary = _presence_payload("state")
    payload["velocity"] = _vec2(velocity)
    payload["facing"] = _last_facing
    _send_json(payload)

func _presence_payload(packet_type: String) -> Dictionary:
    var position := Vector2.ZERO
    var tamer_scale := Vector2(0.24, 0.24)
    var tamer_offset := Vector2(0.0, -256.0)
    if is_instance_valid(local_player):
        position = local_player.global_position
        if is_instance_valid(local_player.sprite):
            tamer_scale = local_player.sprite.scale
            tamer_offset = local_player.sprite.offset
    return {
        "type": packet_type,
        "protocol_version": 3,
        "zone": String(zone_id),
        "name": _display_name(),
        "character_key": _character_key(),
        "position": _vec2(position),
        "tamer_model": String(GameManager.tamer_selected),
        "tamer_scale": _vec2(tamer_scale),
        "tamer_offset": _vec2(tamer_offset),
        "partner": _partner_payload()
    }

func _partner_payload() -> Dictionary:
    if not is_instance_valid(local_player) or not is_instance_valid(local_player.partner):
        return {}
    var partner: PartnerMonster = local_player.partner
    if partner.current_form == null or not is_instance_valid(partner.sprite):
        return {}
    var partner_facing := "down"
    if is_instance_valid(partner.animator):
        partner_facing = String(partner.animator.facing)
    return {
        "form_id": String(partner.current_form.id),
        "name": partner.current_form.monster_name,
        "position": _vec2(partner.global_position),
        "velocity": _vec2(partner.get_real_velocity()),
        "facing": partner_facing,
        "animation": String(partner.sprite.animation),
        "scale": _vec2(partner.sprite.scale),
        "offset": _vec2(partner.sprite.offset),
        "visible": partner.sprite.visible and partner.state not in [PartnerMonster.State.FAINTED, PartnerMonster.State.EGG]
    }

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
    if _manual_disconnect:
        return
    var payload := parsed as Dictionary
    # Also reject commits from an old server during a rolling deployment.
    if str(payload.get("type", "")).begins_with("trade_"):
        trade.clear()
        trade_feedback.emit(TRADE_UNAVAILABLE_MESSAGE, false)
        return
    match str(payload.get("type", "")):
        "welcome":
            local_peer_id = str(payload.get("id", ""))
        "online_ready":
            if _manual_disconnect or not GameManager.gameplay_active or not is_instance_valid(local_player):
                return
            if _hello_character_key.is_empty() or str(payload.get("character_key", "")) != _hello_character_key:
                return
            _hello_left = 0.0
            local_peer_id = str(payload.get("id", local_peer_id))
            if not connected:
                connected = true
                connecting = false
                _reconnect_left = 0.0
                connection_changed.emit(true, "Online")
        "economy_snapshot":
            _handle_economy_snapshot(payload)
        "economy_ack":
            _handle_economy_ack(payload)
        "economy_feedback":
            _handle_economy_feedback(payload)
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
            var id := str(payload.get("id", ""))
            if id != local_peer_id:
                remote_chat.emit(id, str(payload.get("name", "ผู้เล่น")), str(payload.get("text", "")))
        "online_count":
            _set_online_counts(
                maxi(0, int(payload.get("total", 0))),
                maxi(0, int(payload.get("zone_count", 0)))
            )
        "guild_snapshot":
            var next_guild: Variant = payload.get("guild", {})
            guild = next_guild.duplicate(true) if next_guild is Dictionary else {}
            guild_changed.emit(guild.duplicate(true))
        "guild_chat":
            guild_chat.emit(
                str(payload.get("id", "")),
                str(payload.get("name", "ผู้เล่น")),
                str(payload.get("text", ""))
            )
        "guild_feedback":
            guild_feedback.emit(
                str(payload.get("message", "")),
                bool(payload.get("ok", false))
            )
        "guild_invite":
            guild_invite_received.emit(payload.duplicate(true))
        "session_replaced":
            disconnect_from_server()
            var session_message: String = str(payload.get("message", "ตัวละครนี้เชื่อมต่อจากหน้าต่างอื่นแล้ว"))
            GameChat.add_system(session_message)
            connection_changed.emit(false, session_message)
        "identity_error":
            var identity_message: String = str(payload.get("message", "Online identity ไม่ถูกต้อง"))
            GameChat.add_system(identity_message)
            disconnect_from_server()
            connection_changed.emit(false, identity_message)
            if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
                socket.close(1008, "identity rejected")

func _set_online_counts(total: int, current_zone: int) -> void:
    var safe_total: int = maxi(0, total)
    var safe_zone: int = clampi(current_zone, 0, safe_total)
    if total_online == safe_total and zone_online == safe_zone:
        return
    total_online = safe_total
    zone_online = safe_zone
    online_count_changed.emit(total_online, zone_online)


func is_applying_server_economy() -> bool:
    return _economy_applying


func sync_economy(state: Dictionary) -> void:
    if _economy_applying or not connected or state.is_empty():
        return
    _economy_pending = state.duplicate(true)
    _flush_economy()


func request_economy_snapshot() -> void:
    if connected:
        _send_json({"type": "economy_request"})


func _flush_economy() -> void:
    if not connected or _economy_inflight or not economy_migrated or _economy_pending.is_empty():
        return
    var state: Dictionary = _economy_pending.duplicate(true)
    _economy_pending.clear()
    _economy_inflight = true
    _send_json({
        "type": "economy_update",
        "revision": economy_revision,
        "state": state
    })


func _handle_economy_snapshot(payload: Dictionary) -> void:
    if not connected or not is_instance_valid(local_player):
        return
    var key: String = str(payload.get("character_key", ""))
    if key.is_empty() or key != _character_key():
        return

    var migrated: bool = bool(payload.get("migrated", false))
    economy_revision = maxi(0, int(payload.get("revision", 0)))
    economy_migrated = migrated
    _economy_inflight = false

    if not migrated:
        _economy_pending.clear()
        var local_state: Dictionary = local_player.capture_party_state()
        if local_state.is_empty():
            economy_feedback.emit("ยังไม่มีข้อมูลสำหรับย้ายขึ้น Server", false)
            return
        _economy_inflight = true
        _send_json({
            "type": "economy_migrate",
            "state": local_state
        })
        economy_sync_changed.emit(false, economy_revision)
        return

    var server_state: Variant = payload.get("state", {})
    if server_state is Dictionary and _economy_loaded_character_key != key:
        _economy_applying = true
        var applied: bool = local_player.apply_server_economy_state(server_state)
        _economy_applying = false
        if applied:
            _economy_loaded_character_key = key
            _economy_pending.clear()
        else:
            economy_feedback.emit("โหลดข้อมูล Economy จาก Server ไม่สำเร็จ", false)
    economy_sync_changed.emit(true, economy_revision)
    _flush_economy()


func _handle_economy_ack(payload: Dictionary) -> void:
    if str(payload.get("character_key", "")) != _character_key():
        return
    economy_revision = maxi(economy_revision, int(payload.get("revision", economy_revision)))
    economy_migrated = bool(payload.get("migrated", true))
    _economy_inflight = false
    if _economy_loaded_character_key.is_empty():
        _economy_loaded_character_key = _character_key()
    economy_sync_changed.emit(economy_migrated, economy_revision)
    _flush_economy()


func _handle_economy_feedback(payload: Dictionary) -> void:
    _economy_inflight = false
    var code: String = str(payload.get("code", ""))
    var message: String = "บันทึกข้อมูลฝั่ง Server ไม่สำเร็จ"
    if code == "revision_conflict":
        message = "ข้อมูล Server ใหม่กว่า กำลังโหลดข้อมูลล่าสุด"
        _economy_pending.clear()
    elif code == "storage_error":
        message = "Server Storage ขัดข้อง ข้อมูลรอบนี้ยังไม่ถูกยืนยัน"
    economy_feedback.emit(message, false)
    GameChat.add_system(message)


func request_trade(_peer_id: String) -> bool:
    trade_feedback.emit(TRADE_UNAVAILABLE_MESSAGE, false)
    return false


func respond_trade_invite(invite_id: String, accept: bool) -> bool:
    if not connected:
        return false
    var clean: String = invite_id.strip_edges().substr(0, 80)
    if clean.is_empty():
        return false
    _send_json({
        "type": "trade_invite_response",
        "invite_id": clean,
        "accept": accept
    })
    return true


func update_trade_offer(items: Array, bits: int) -> bool:
    if not connected or trade.is_empty():
        return false
    _send_json({
        "type": "trade_offer",
        "offer": {
            "items": items,
            "bits": clampi(bits, 0, 2_000_000_000)
        }
    })
    return true


func set_trade_ready(ready: bool) -> bool:
    if not connected or trade.is_empty():
        return false
    _send_json({"type": "trade_ready", "ready": ready})
    return true


func confirm_trade() -> bool:
    if not connected or trade.is_empty():
        return false
    _send_json({"type": "trade_confirm"})
    return true


func send_trade_prepare_result(trade_id: String, ok: bool, message: String = "") -> void:
    if not connected:
        return
    _send_json({
        "type": "trade_prepare_result",
        "trade_id": trade_id,
        "ok": ok,
        "message": message.substr(0, 160)
    })


func cancel_trade() -> void:
    if connected and not trade.is_empty():
        _send_json({"type": "trade_cancel"})


func create_guild(name: String) -> bool:
    if not connected:
        return false
    var clean: String = name.strip_edges().substr(0, 20)
    if clean.length() < 3:
        guild_feedback.emit("ชื่อกิลด์ต้องยาว 3–20 ตัวอักษร", false)
        return false
    _send_json({"type": "guild_create", "name": clean})
    return true


func join_guild(code: String) -> bool:
    if not connected:
        return false
    var clean: String = code.strip_edges().to_upper().substr(0, 12)
    if clean.is_empty():
        guild_feedback.emit("กรอกรหัสกิลด์ก่อน", false)
        return false
    _send_json({"type": "guild_join", "code": clean})
    return true


func invite_to_guild(peer_id: String) -> bool:
    if not connected:
        guild_feedback.emit("ยังไม่ได้เชื่อมต่อ Online Server", false)
        return false
    if guild.is_empty():
        guild_feedback.emit("ต้องอยู่ในกิลด์ก่อนจึงจะเชิญผู้เล่นได้", false)
        return false
    var clean: String = peer_id.strip_edges().substr(0, 80)
    if clean.is_empty() or clean == local_peer_id:
        return false
    _send_json({"type": "guild_invite", "target_peer_id": clean})
    return true


func respond_guild_invite(invite_id: String, accept: bool) -> bool:
    if not connected:
        return false
    var clean: String = invite_id.strip_edges().substr(0, 80)
    if clean.is_empty():
        return false
    _send_json({
        "type": "guild_invite_response",
        "invite_id": clean,
        "accept": accept
    })
    return true


func request_remote_interaction(peer_id: String, display_name: String, guild_name: String) -> void:
    if peer_id.is_empty() or peer_id == local_peer_id:
        return
    remote_interaction_requested.emit(
        peer_id,
        display_name.strip_edges().substr(0, 24),
        guild_name.strip_edges().substr(0, 20)
    )


func leave_guild() -> bool:
    if not connected or guild.is_empty():
        return false
    _send_json({"type": "guild_leave"})
    return true


func request_guild() -> void:
    if connected:
        _send_json({"type": "guild_request"})


func send_guild_chat(text: String) -> bool:
    if not connected or guild.is_empty():
        return false
    var clean: String = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").substr(0, MAX_CHAT_LENGTH)
    if clean.is_empty():
        return false
    _send_json({"type": "guild_chat", "text": clean})
    return true


func _character_key() -> String:
    # Login ปัจจุบันเป็น local/demo จึงห้ามใช้ username+slot เป็น online identity:
    # คนละเครื่องสามารถใช้ username เดียวกันได้และจะชนกันทันที
    var uid: String = GameManager.online_character_uid()
    if uid.is_empty():
        return ""
    return "v2:" + uid


func _on_chat_outgoing(_channel: StringName, text: String) -> void:
    if not send_chat(text):
        GameChat.add_system("ยังไม่ได้เชื่อมต่อ Online Server ข้อความนี้ยังไม่ถูกส่ง")

func _send_json(payload: Dictionary) -> void:
    if str(payload.get("type", "")).begins_with("trade_"):
        return
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
