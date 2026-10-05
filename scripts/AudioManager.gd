extends Node
## AudioManager กลางของเกมสำหรับ Web + Mobile
##
## สำคัญ:
## - ไม่สร้าง PCM/AudioStreamWAV แบบ runtime อีกต่อไป เพราะเสียงสังเคราะห์เดิมแตก/เพี้ยนบน Web Mobile บางเครื่อง
## - ใช้ไฟล์เสียงจริง (.ogg/.wav) เท่านั้น
## - ถ้ายังไม่มีไฟล์เสียง จะ "เงียบ" อย่างปลอดภัยแทนการสร้างเสียง fallback ที่ผิดเพี้ยน
##
## โครงสร้างไฟล์ที่รองรับโดยอัตโนมัติ:
## res://assets/audio/bgm/shard_isle.ogg
## res://assets/audio/evolution/evolution_theme.ogg
## res://assets/audio/sfx/ui_click.ogg
## res://assets/audio/sfx/evolution_start.ogg
## res://assets/audio/sfx/evolution_burst.ogg
## res://assets/audio/sfx/hatch_success.ogg
## res://assets/audio/sfx/electric_attack.ogg

const SILENCE_DB: float = -60.0
const DEFAULT_BGM_DB: float = -12.0
const DEFAULT_EVOLUTION_DB: float = -7.0
const DEFAULT_SFX_DB: float = -6.0

const DEFAULT_BGM_PATH := "res://assets/audio/bgm/shard_isle.ogg"
const DEFAULT_EVOLUTION_PATH := "res://assets/audio/evolution/evolution_theme.ogg"

const SFX_PATHS := {
    &"ui_click": "res://assets/audio/sfx/ui_click.ogg",
    &"evolution_start": "res://assets/audio/sfx/evolution_start.ogg",
    &"evolution_burst": "res://assets/audio/sfx/evolution_burst.ogg",
    &"hatch_success": "res://assets/audio/sfx/hatch_success.ogg",
    &"electric_attack": "res://assets/audio/sfx/electric_attack.ogg",
}

var music_player: AudioStreamPlayer
var evolution_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var _audio_unlocked: bool = false
var _bgm_resume_after_evolution: bool = false
var _bgm_target_db: float = DEFAULT_BGM_DB
var _evolution_target_db: float = DEFAULT_EVOLUTION_DB

var _bgm_tween: Tween
var _evolution_tween: Tween

var _stream_cache: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_players()

func _build_players() -> void:
    # สร้าง Player จาก Autoload เพื่อให้เสียงไม่หายตอนเปลี่ยน Scene
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.process_mode = Node.PROCESS_MODE_ALWAYS
    music_player.bus = &"Master"
    music_player.volume_db = SILENCE_DB
    add_child(music_player)

    evolution_player = AudioStreamPlayer.new()
    evolution_player.name = "EvolutionPlayer"
    evolution_player.process_mode = Node.PROCESS_MODE_ALWAYS
    evolution_player.bus = &"Master"
    evolution_player.volume_db = SILENCE_DB
    add_child(evolution_player)

    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "SFXPlayer"
    sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
    sfx_player.bus = &"Master"
    sfx_player.volume_db = DEFAULT_SFX_DB
    add_child(sfx_player)

    music_player.finished.connect(_on_bgm_finished)

func _input(event: InputEvent) -> void:
    # Browser Web Audio ต้องได้รับ user gesture ก่อน
    if _audio_unlocked:
        return

    var gesture := false
    if event is InputEventMouseButton:
        gesture = event.pressed
    elif event is InputEventScreenTouch:
        gesture = event.pressed and not event.canceled
    elif event is InputEventKey:
        gesture = event.pressed and not event.echo

    if gesture:
        unlock_audio()

func unlock_audio() -> void:
    # เรียก synchronous จาก Login / Start Game
    # ไม่เล่น fake sound เพื่อปลดล็อกอีกต่อไป เพราะนั่นเป็นต้นเหตุเสียงแตกบนบาง browser
    if _audio_unlocked:
        return

    _audio_unlocked = true
    var master_index := AudioServer.get_bus_index(&"Master")
    if master_index >= 0:
        AudioServer.set_bus_mute(master_index, false)

func is_audio_unlocked() -> bool:
    return _audio_unlocked

func play_bgm(
    stream: AudioStream = null,
    fade_seconds: float = 0.65,
    target_db: float = DEFAULT_BGM_DB
) -> void:
    # ถ้าไม่ได้ส่ง stream มา จะลองโหลดไฟล์ default
    # ถ้าไฟล์ยังไม่มี ให้เงียบโดยไม่ error และไม่สร้างเสียง fallback
    var next_stream: AudioStream = stream
    if next_stream == null:
        next_stream = _load_stream(DEFAULT_BGM_PATH)

    if next_stream == null:
        return

    _bgm_target_db = target_db

    if music_player.stream == next_stream and music_player.playing:
        music_player.stream_paused = false
        _fade_player(music_player, target_db, fade_seconds, &"bgm")
        return

    _kill_bgm_tween()
    music_player.stop()
    music_player.stream = next_stream
    music_player.stream_paused = false
    music_player.volume_db = SILENCE_DB
    music_player.play()
    _fade_player(music_player, target_db, fade_seconds, &"bgm")

func stop_bgm(fade_seconds: float = 0.35) -> void:
    if not music_player.playing:
        return

    _kill_bgm_tween()
    _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _bgm_tween.tween_property(
        music_player,
        "volume_db",
        SILENCE_DB,
        maxf(0.01, fade_seconds)
    )
    _bgm_tween.tween_callback(func() -> void:
        music_player.stop()
        music_player.stream_paused = false
    )

func play_evolution_theme(
    stream: AudioStream = null,
    fade_seconds: float = 0.22,
    target_db: float = DEFAULT_EVOLUTION_DB
) -> void:
    # หรี่ BGM ก่อนเสมอ แม้ยังไม่มีไฟล์ Evolution Theme
    # ถ้าไม่มีไฟล์ theme คัตซีนจะเล่นแบบเงียบ แต่ไม่เกิดเสียงแตก
    _evolution_target_db = target_db
    _bgm_resume_after_evolution = music_player.playing

    if _bgm_resume_after_evolution:
        _kill_bgm_tween()
        _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _bgm_tween.tween_property(music_player, "volume_db", SILENCE_DB, 0.30)
        _bgm_tween.tween_callback(func() -> void:
            if music_player.playing:
                music_player.stream_paused = true
        )

    var theme_stream: AudioStream = stream
    if theme_stream == null:
        theme_stream = _load_stream(DEFAULT_EVOLUTION_PATH)

    _kill_evolution_tween()
    evolution_player.stop()

    if theme_stream != null:
        evolution_player.stream = theme_stream
        evolution_player.volume_db = SILENCE_DB
        evolution_player.play()
        _fade_player(
            evolution_player,
            target_db,
            fade_seconds,
            &"evolution"
        )

    play_sfx(&"evolution_start", -8.0)

func finish_evolution_theme(fade_seconds: float = 0.40) -> void:
    # เรียกทั้ง success และ cancel
    _kill_evolution_tween()

    if evolution_player.playing:
        _evolution_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _evolution_tween.tween_property(
            evolution_player,
            "volume_db",
            SILENCE_DB,
            maxf(0.01, fade_seconds)
        )
        _evolution_tween.tween_callback(func() -> void:
            evolution_player.stop()
            evolution_player.stream = null
        )

    if _bgm_resume_after_evolution and music_player.stream != null:
        music_player.stream_paused = false
        music_player.volume_db = SILENCE_DB

        _kill_bgm_tween()
        _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _bgm_tween.tween_property(
            music_player,
            "volume_db",
            _bgm_target_db,
            maxf(0.01, fade_seconds + 0.12)
        )

    _bgm_resume_after_evolution = false

func play_sfx(
    effect: Variant = &"ui_click",
    volume_db: float = DEFAULT_SFX_DB
) -> void:
    # รองรับทั้ง AudioStream จริงและชื่อ SFX
    # ถ้าไม่มีไฟล์ ให้ return เงียบ ๆ ไม่สร้าง tone ปลอม
    var stream: AudioStream = null

    if effect is AudioStream:
        stream = effect as AudioStream
    else:
        var id := StringName(str(effect))
        if SFX_PATHS.has(id):
            stream = _load_stream(str(SFX_PATHS[id]))

    if stream == null:
        return

    sfx_player.stop()
    sfx_player.stream = stream
    sfx_player.volume_db = volume_db
    sfx_player.play()

func _load_stream(path: String) -> AudioStream:
    if path.is_empty():
        return null

    if _stream_cache.has(path):
        return _stream_cache[path] as AudioStream

    if not ResourceLoader.exists(path):
        return null

    var resource := ResourceLoader.load(path)
    var stream := resource as AudioStream
    if stream != null:
        _stream_cache[path] = stream
    return stream

func _on_bgm_finished() -> void:
    # รองรับไฟล์ BGM ที่ไม่ได้ตั้ง Loop ใน Import
    if music_player.stream != null and not music_player.stream_paused:
        music_player.play()

func _fade_player(
    player: AudioStreamPlayer,
    target_db: float,
    seconds: float,
    channel: StringName
) -> void:
    if channel == &"bgm":
        _kill_bgm_tween()
        _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _bgm_tween.tween_property(
            player,
            "volume_db",
            target_db,
            maxf(0.01, seconds)
        )
    else:
        _kill_evolution_tween()
        _evolution_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _evolution_tween.tween_property(
            player,
            "volume_db",
            target_db,
            maxf(0.01, seconds)
        )

func _kill_bgm_tween() -> void:
    if _bgm_tween != null and _bgm_tween.is_valid():
        _bgm_tween.kill()
    _bgm_tween = null

func _kill_evolution_tween() -> void:
    if _evolution_tween != null and _evolution_tween.is_valid():
        _evolution_tween.kill()
    _evolution_tween = null
