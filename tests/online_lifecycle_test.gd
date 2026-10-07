extends Node
## Real loopback WebSockets; never connect test characters to production.
var listener := TCPServer.new()
var sockets: Array[WebSocketPeer] = []
var packets: Array[Dictionary] = []
var assertions: int = 0
var failures: int = 0
var trade_events: int = 0
var economy_migrated: bool = false
var economy_revision: int = 0
var economy_state: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    OnlineManager.disconnect_from_server()
    OnlineManager.configure("", false)
    run.call_deferred()

func _process(_delta: float) -> void:
    while listener.is_connection_available():
        var peer := WebSocketPeer.new()
        peer.accept_stream(listener.take_connection())
        sockets.append(peer)
    for peer: WebSocketPeer in sockets:
        peer.poll()
        while peer.get_available_packet_count() > 0:
            var packet: Dictionary = JSON.parse_string(peer.get_packet().get_string_from_utf8())
            packets.append(packet)
            if packet.get("type") == "hello":
                peer.send_text(JSON.stringify({"type": "online_ready", "id": "loopback", "character_key": packet.character_key}))
                peer.send_text(JSON.stringify({
                    "type": "economy_snapshot",
                    "character_key": packet.character_key,
                    "migrated": economy_migrated,
                    "revision": economy_revision,
                    "state": economy_state
                }))
            elif packet.get("type") == "economy_migrate" and not economy_migrated:
                economy_migrated = true
                economy_revision = 1
                economy_state = packet.get("state", {}).duplicate(true)
                peer.send_text(JSON.stringify({
                    "type": "economy_ack",
                    "character_key": "v2:" + "a".repeat(64),
                    "migrated": true,
                    "revision": economy_revision
                }))
            elif packet.get("type") == "economy_update" and int(packet.get("revision", -1)) == economy_revision:
                economy_revision += 1
                economy_state = packet.get("state", {}).duplicate(true)
                peer.send_text(JSON.stringify({
                    "type": "economy_ack",
                    "character_key": "v2:" + "a".repeat(64),
                    "migrated": true,
                    "revision": economy_revision
                }))

func check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + message)

func wait_connected() -> void:
    var deadline: int = Time.get_ticks_msec() + 3000
    while not OnlineManager.connected and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame

func wait_economy_migrated() -> void:
    var deadline: int = Time.get_ticks_msec() + 3000
    while not OnlineManager.economy_migrated and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame


func wait_disconnect() -> void:
    var deadline: int = Time.get_ticks_msec() + 3000
    while sockets[0].get_ready_state() != WebSocketPeer.STATE_CLOSED and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame

func count_type(kind: String) -> int:
    return packets.filter(func(p: Dictionary) -> bool: return p.get("type") == kind).size()

func on_trade(_payload: Dictionary) -> void:
    trade_events += 1

func run() -> void:
    var error: Error = listener.listen(0, "127.0.0.1")
    check(error == OK, "loopback server starts")
    if error != OK:
        get_tree().quit(1)
        return
    OnlineManager.configure("ws://127.0.0.1:%d" % listener.get_local_port(), false)
    GameManager.logout()
    OnlineManager.connect_to_server()
    check(not OnlineManager.connecting, "login/menu cannot open an online session")
    GameManager.ensure_catalog()
    GameManager.characters[0] = {"online_uid": "a".repeat(64)}
    GameManager.gameplay_active = true
    var player: Tamer = load("res://scenes/tamer.tscn").instantiate()
    player.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(player)
    player.survival.autosave_enabled = false
    OnlineManager.bind_world(player, &"file_island")
    await wait_connected()
    check(OnlineManager.connected and count_type("hello") == 1, "world binds and authenticates exactly once")
    await wait_economy_migrated()
    check(OnlineManager.economy_migrated and OnlineManager.economy_revision >= 1,
        "legacy local economy migrates once and receives a server revision")
    OnlineManager.trade_prepare.connect(on_trade)
    OnlineManager.trade_commit.connect(on_trade)
    var original_bits: int = GameManager.bits
    for kind: String in ["trade_open", "trade_prepare", "trade_commit", "trade_closed"]:
        OnlineManager._handle_packet(JSON.stringify({"type": kind, "success": true, "incoming": {"bits": 1000000}}))
    check(trade_events == 0 and OnlineManager.trade.is_empty() and GameManager.bits == original_bits,
        "legacy server cannot open or commit local trade")
    check(not OnlineManager.request_trade("other"), "trade request fails closed")
    OnlineManager.unbind_world(player)
    await wait_disconnect()
    check(sockets[0].get_ready_state() == WebSocketPeer.STATE_CLOSED and not OnlineManager.connected, "world exit closes the remote socket and clears session")
    OnlineManager._handle_packet(JSON.stringify({"type": "online_ready", "id": "stale", "character_key": "v2:" + "a".repeat(64)}))
    check(not OnlineManager.connected, "late acknowledgement cannot resurrect menu presence")
    GameManager.gameplay_active = false
    OnlineManager._process(10.0)
    check(not OnlineManager.connecting and OnlineManager._reconnect_left == 0.0, "menu does not auto-reconnect")
    GameManager.gameplay_active = true
    OnlineManager.bind_world(player, &"file_island")
    await wait_connected()
    check(OnlineManager.connected and count_type("hello") == 2, "returning to a world opens a fresh session")
    # The final JSON notification may be lost when its close frame arrives.
    sockets[-1].close(4001, "session replaced")
    var close_deadline: int = Time.get_ticks_msec() + 3000
    while OnlineManager.connected and Time.get_ticks_msec() < close_deadline:
        await get_tree().process_frame
    OnlineManager._process(10.0)
    check(not OnlineManager.connected and not OnlineManager.connecting and OnlineManager._manual_disconnect,
        "replaced tab stays offline without reconnect competition")
    OnlineManager.bind_world(player, &"file_island")
    await wait_connected()
    check(OnlineManager.connected, "explicit world re-entry can reconnect")
    GameManager.logout()
    check(not OnlineManager.connected and OnlineManager.guild.is_empty() and OnlineManager.total_online == 0,
        "logout clears presence, guild snapshot and counts")
    check(not OnlineManager.economy_migrated and OnlineManager.economy_revision == 0,
        "logout clears economy session revision without deleting server data")
    OnlineManager.unbind_world(player)
    OnlineManager.configure("", false)
    player.queue_free()
    for peer: WebSocketPeer in sockets:
        peer.close()
    listener.stop()
    await get_tree().process_frame
    print("ONLINE LIFECYCLE RESULT: %d failures / %d assertions" % [failures, assertions])
    get_tree().quit(1 if failures else 0)
