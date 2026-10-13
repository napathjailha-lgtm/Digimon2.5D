extends Node
## Runtime regression checks for remote actor presentation and duplicate interaction input.

var assertions: int = 0
var failures: int = 0
var interaction_events: int = 0
var last_interaction_peer: String = ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # This test is fully local and must never connect to production.
    OnlineManager.disconnect_from_server()
    OnlineManager.configure("", false)
    GameManager.logout()
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + message)

func _on_interaction_requested(peer_id: String, _display_name: String, _guild_name: String) -> void:
    interaction_events += 1
    last_interaction_peer = peer_id

func run() -> void:
    GameManager.ensure_catalog()
    var remote_scene := load("res://scenes/online/remote_tamer.tscn") as PackedScene
    check(remote_scene != null, "remote tamer scene loads")
    if remote_scene == null:
        get_tree().quit(1)
        return

    var remote := remote_scene.instantiate() as RemoteTamer
    check(remote != null, "remote tamer scene has RemoteTamer script")
    if remote == null:
        get_tree().quit(1)
        return
    add_child(remote)
    await get_tree().process_frame

    remote.setup("presence-test-peer", {
        "name": "Presence Tester",
        "position": {"x": 100.0, "y": 200.0},
        "velocity": {"x": 0.0, "y": 0.0},
        "facing": "down",
        "partner": {},
    })
    remote.interaction_requested.connect(_on_interaction_requested)
    remote.request_interaction()
    remote.request_interaction()
    check(interaction_events == 1, "one tap cannot emit duplicate interaction requests")
    check(last_interaction_peer == "presence-test-peer", "interaction keeps the selected remote peer id")

    # Move the guard timestamp explicitly to test the post-debounce path
    # deterministically, without relying on CI frame scheduling.
    remote._last_interaction_ms = Time.get_ticks_msec() - 200
    remote.request_interaction()
    check(interaction_events == 2, "a later intentional interaction is still accepted")

    var form_id: String = ""
    if GameManager.catalog != null:
        for family: StarterPartnerData in GameManager.catalog.starters:
            if family == null:
                continue
            for form: MonsterData in family.forms:
                if form != null:
                    form_id = String(form.id)
                    break
            if not form_id.is_empty():
                break
    check(not form_id.is_empty(), "catalog contains a partner form for remote presentation")

    if not form_id.is_empty():
        remote.apply_state({
            "name": "Presence Tester",
            "position": {"x": 300.0, "y": 400.0},
            "velocity": {"x": 24.0, "y": 0.0},
            "facing": "right",
            "partner": {
                "visible": true,
                "form_id": form_id,
                "name": "Remote Partner",
                "position": {"x": 318.0, "y": 402.0},
                "velocity": {"x": 18.0, "y": 0.0},
                "facing": "right",
                "animation": "walk_right",
                "scale": {"x": 0.25, "y": 0.25},
                "offset": {"x": 0.0, "y": 0.0},
            },
        }, true)
        await get_tree().process_frame
        check(remote.partner_visible and remote.partner_initialized, "partner snapshot initializes the remote partner")
        check(remote.partner_form_id == StringName(form_id), "partner form id is applied")
        check(remote.partner_visual.visible, "visible partner snapshot makes the partner visible")
        check(remote.target_partner_position == Vector2(318.0, 402.0), "partner position is synchronized")
        check(remote.target_position == Vector2(300.0, 400.0), "tamer position is synchronized")

    remote.show_chat("ทดสอบแชตลอย")
    check(remote.chat_bubble.visible, "remote chat appears in a world bubble")
    check(remote.chat_bubble.message_label.text == "ทดสอบแชตลอย", "world bubble renders the received text")

    remote.queue_free()
    await get_tree().process_frame
    print("ONLINE WORLD PRESENCE RESULT: %d failures / %d assertions" % [failures, assertions])
    get_tree().quit(1 if failures else 0)
