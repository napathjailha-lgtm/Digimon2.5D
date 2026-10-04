extends Node
## AudioManager เป็น Singleton กลางของเกม
## - MusicPlayer: BGM ของแผนที่
## - EvolutionPlayer: เพลงคัตซีนเปลี่ยนร่าง
## - SFXPlayer: เสียงปุ่ม/สกิล/ฟักไข่
##
## Web HTML5:
## Browser จะไม่ยอมเริ่ม AudioContext ก่อนมี user gesture
## จึงต้องเรียก unlock_audio() แบบ synchronous จาก Login/Start และมี _input เป็น fallback

const SILENCE_DB: float = -60.0
const DEFAULT_BGM_DB: float = -12.0
const DEFAULT_EVOLUTION_DB: float = -7.0
const DEFAULT_SFX_DB: float = -5.0
const MIX_RATE: int = 22050

var music_player: AudioStreamPlayer
var evolution_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var _audio_unlocked: bool = false
var _bgm_resume_after_evolution: bool = false
var _bgm_target_db: float = DEFAULT_BGM_DB
var _evolution_target_db: float = DEFAULT_EVOLUTION_DB
var _bgm_tween: Tween
var _evolution_tween: Tween
var _sfx_cache: Dictionary = {}
var _fallback_bgm: AudioStreamWAV
var _fallback_evolution_theme: AudioStreamWAV

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_players()

func _build_players() -> void:
    # สร้าง Player จาก Autoload โดยตรง ทำให้ไม่มี dependency กับ Scene ใด ๆ
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

    # ถ้า external BGM ไม่ได้เปิด loop ใน Import ให้เล่นซ้ำเอง
    music_player.finished.connect(_on_bgm_finished)

func _input(event: InputEvent) -> void:
    # Fallback สำหรับ Web: gesture แรกของผู้เล่นปลดล็อกเสียง
    # ห้าม await/call_deferred เพราะ browser ต้องเห็นการเล่นเสียงใน call stack ของ gesture เดิม
    if _audio_unlocked:
        return
    var gesture: bool = false
    if event is InputEventMouseButton:
        gesture = event.pressed
    elif event is InputEventScreenTouch:
        gesture = event.pressed and not event.canceled
    elif event is InputEventKey:
        gesture = event.pressed and not event.echo
    if gesture:
        unlock_audio()

func unlock_audio() -> void:
    # เรียกตรงจาก Login/Start Game ก่อนเปลี่ยน Scene
    # การ play stream สั้น ๆ ใน user gesture ทำให้ Web AudioContext ของ Godot ถูก resume ตาม policy browser
    if _audio_unlocked:
        return
    _audio_unlocked = true
    var master_index: int = AudioServer.get_bus_index(&"Master")
    if master_index >= 0:
        AudioServer.set_bus_mute(master_index, false)
    play_sfx(&"ui_click", -18.0)

func is_audio_unlocked() -> bool:
    return _audio_unlocked

func play_bgm(stream: AudioStream = null, fade_seconds: float = 0.65, target_db: float = DEFAULT_BGM_DB) -> void:
    # ถ้าไม่ได้ส่งไฟล์เพลงมา ใช้ fallback original digital ambience ที่สร้างใน runtime
    # สามารถเปลี่ยนเป็น .ogg ของเกมภายหลังโดยส่ง stream เข้ามาโดยไม่แก้ระบบคัตซีน
    _bgm_target_db = target_db
    var next_stream: AudioStream = stream if stream != null else _get_fallback_bgm()
    if next_stream == null:
        return

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

func stop_bgm(fade_seconds: float = 0.45) -> void:
    if not music_player.playing:
        return
    _kill_bgm_tween()
    _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _bgm_tween.tween_property(music_player, "volume_db", SILENCE_DB, maxf(0.01, fade_seconds))
    _bgm_tween.tween_callback(func() -> void:
        music_player.stop()
        music_player.stream_paused = false
    )

func play_evolution_theme(stream: AudioStream = null, fade_seconds: float = 0.22, target_db: float = DEFAULT_EVOLUTION_DB) -> void:
    # BGM หรี่จนเงียบพร้อมกับเริ่ม Evolution Theme ทันที
    _evolution_target_db = target_db
    _bgm_resume_after_evolution = music_player.playing

    if _bgm_resume_after_evolution:
        _kill_bgm_tween()
        _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _bgm_tween.tween_property(music_player, "volume_db", SILENCE_DB, 0.32)
        _bgm_tween.tween_callback(func() -> void:
            # pause ไว้ที่ตำแหน่งเดิม เพื่อกลับมาเล่นต่อหลังคัตซีน
            if music_player.playing:
                music_player.stream_paused = true
        )

    _kill_evolution_tween()
    evolution_player.stop()
    evolution_player.stream = stream if stream != null else _get_fallback_evolution_theme()
    evolution_player.volume_db = SILENCE_DB
    evolution_player.play()
    _fade_player(evolution_player, target_db, fade_seconds, &"evolution")
    play_sfx(&"evolution_start", -7.0)

func finish_evolution_theme(fade_seconds: float = 0.40) -> void:
    # เรียกทั้ง success/cancel เพื่อไม่ทิ้งเพลงคัตซีนค้างบน Web
    _kill_evolution_tween()
    if evolution_player.playing:
        _evolution_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _evolution_tween.tween_property(evolution_player, "volume_db", SILENCE_DB, maxf(0.01, fade_seconds))
        _evolution_tween.tween_callback(func() -> void:
            evolution_player.stop()
        )

    if _bgm_resume_after_evolution and music_player.stream != null:
        music_player.stream_paused = false
        music_player.volume_db = SILENCE_DB
        _kill_bgm_tween()
        _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _bgm_tween.tween_property(music_player, "volume_db", _bgm_target_db, maxf(0.01, fade_seconds + 0.12))

    _bgm_resume_after_evolution = false

func play_sfx(effect: Variant = &"ui_click", volume_db: float = DEFAULT_SFX_DB) -> void:
    # effect รับได้ทั้ง AudioStream จริง หรือ StringName ของ fallback SFX
    var stream: AudioStream = null
    if effect is AudioStream:
        stream = effect as AudioStream
    else:
        stream = _get_sfx(StringName(str(effect)))
    if stream == null:
        return

    # Player เดียวตามสเปก: เอฟเฟกต์ใหม่มีสิทธิ์แทนเสียงสั้นเดิม
    sfx_player.stop()
    sfx_player.stream = stream
    sfx_player.volume_db = volume_db
    sfx_player.play()

func _on_bgm_finished() -> void:
    # Fallback WAV loop อยู่แล้ว แต่ external stream บางไฟล์ไม่ได้ตั้ง loop ใน import
    if music_player.stream != null and not music_player.stream_paused:
        music_player.play()

func _fade_player(player: AudioStreamPlayer, target_db: float, seconds: float, channel: StringName) -> void:
    if channel == &"bgm":
        _kill_bgm_tween()
        _bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _bgm_tween.tween_property(player, "volume_db", target_db, maxf(0.01, seconds))
    else:
        _kill_evolution_tween()
        _evolution_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _evolution_tween.tween_property(player, "volume_db", target_db, maxf(0.01, seconds))

func _kill_bgm_tween() -> void:
    if _bgm_tween != null and _bgm_tween.is_valid():
        _bgm_tween.kill()
    _bgm_tween = null

func _kill_evolution_tween() -> void:
    if _evolution_tween != null and _evolution_tween.is_valid():
        _evolution_tween.kill()
    _evolution_tween = null

func _get_sfx(id: StringName) -> AudioStream:
    if _sfx_cache.has(id):
        return _sfx_cache[id]

    var stream: AudioStreamWAV
    match id:
        &"ui_click":
            stream = _make_chirp(0.055, 720.0, 1180.0, 0.16)
        &"evolution_start":
            stream = _make_chirp(0.28, 180.0, 860.0, 0.23)
        &"evolution_burst":
            stream = _make_burst(0.46, 0.38)
        &"hatch_success":
            stream = _make_success_jingle()
        &"electric_attack":
            stream = _make_electric_sfx()
        _:
            stream = _make_chirp(0.08, 440.0, 660.0, 0.12)

    _sfx_cache[id] = stream
    return stream

func _get_fallback_bgm() -> AudioStreamWAV:
    if _fallback_bgm == null:
        _fallback_bgm = _make_bgm_loop()
    return _fallback_bgm

func _get_fallback_evolution_theme() -> AudioStreamWAV:
    if _fallback_evolution_theme == null:
        _fallback_evolution_theme = _make_evolution_theme()
    return _fallback_evolution_theme

func _make_bgm_loop() -> AudioStreamWAV:
    # Original fallback ambience 4 วินาที ไม่อ้างอิงเพลงลิขสิทธิ์ใด ๆ
    var duration: float = 4.0
    var frames: int = int(duration * MIX_RATE)
    var pcm := PackedByteArray()
    pcm.resize(frames * 4)
    var roots: Array[float] = [220.0, 196.0, 246.94, 174.61]

    for i: int in range(frames):
        var t: float = float(i) / MIX_RATE
        var segment: int = mini(3, int(t))
        var root: float = roots[segment]
        var local_t: float = fmod(t, 1.0)
        var pulse: float = 0.65 + 0.35 * sin(TAU * 2.0 * local_t)
        var sample: float = (
            sin(TAU * root * t) * 0.10
            + sin(TAU * root * 1.25 * t) * 0.055
            + sin(TAU * root * 1.5 * t) * 0.045
        ) * pulse
        _write_stereo_sample(pcm, i, sample)

    return _make_wav(pcm, frames, true)

func _make_evolution_theme() -> AudioStreamWAV:
    # Original 2.7s evolution cue ให้พอดีกับ AnimationPlayer ปัจจุบัน
    var duration: float = 2.7
    var frames: int = int(duration * MIX_RATE)
    var pcm := PackedByteArray()
    pcm.resize(frames * 4)
    var notes: Array[float] = [261.63, 329.63, 392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5]

    for i: int in range(frames):
        var t: float = float(i) / MIX_RATE
        var note_index: int = mini(notes.size() - 1, int(t / 0.3375))
        var frequency: float = notes[note_index]
        var phase_t: float = fmod(t, 0.3375)
        var envelope: float = minf(1.0, phase_t / 0.025) * minf(1.0, (0.3375 - phase_t) / 0.065)
        envelope = clampf(envelope, 0.0, 1.0)
        var rise: float = 0.65 + (t / duration) * 0.35
        var sample: float = (
            sin(TAU * frequency * t) * 0.20
            + sin(TAU * frequency * 2.0 * t) * 0.06
            + sin(TAU * 98.0 * t) * 0.035
        ) * envelope * rise
        _write_stereo_sample(pcm, i, sample)

    return _make_wav(pcm, frames, false)

func _make_chirp(duration: float, start_hz: float, end_hz: float, amplitude: float) -> AudioStreamWAV:
    var frames: int = maxi(1, int(duration * MIX_RATE))
    var pcm := PackedByteArray()
    pcm.resize(frames * 4)
    var phase: float = 0.0
    for i: int in range(frames):
        var ratio: float = float(i) / maxi(1.0, float(frames - 1))
        var frequency: float = lerpf(start_hz, end_hz, ratio)
        phase += TAU * frequency / MIX_RATE
        var envelope: float = sin(PI * ratio)
        _write_stereo_sample(pcm, i, sin(phase) * amplitude * envelope)
    return _make_wav(pcm, frames, false)

func _make_burst(duration: float, amplitude: float) -> AudioStreamWAV:
    var frames: int = maxi(1, int(duration * MIX_RATE))
    var pcm := PackedByteArray()
    pcm.resize(frames * 4)
    var phase: float = 0.0
    for i: int in range(frames):
        var ratio: float = float(i) / maxi(1.0, float(frames - 1))
        var frequency: float = lerpf(1450.0, 120.0, ratio)
        phase += TAU * frequency / MIX_RATE
        var envelope: float = pow(1.0 - ratio, 2.2)
        var digital: float = sin(phase) + sin(phase * 1.91) * 0.45 + sin(phase * 0.51) * 0.30
        _write_stereo_sample(pcm, i, digital * amplitude * envelope * 0.58)
    return _make_wav(pcm, frames, false)

func _make_success_jingle() -> AudioStreamWAV:
    var duration: float = 0.82
    var frames: int = int(duration * MIX_RATE)
    var pcm := PackedByteArray()
    pcm.resize(frames * 4)
    var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]

    for i: int in range(frames):
        var t: float = float(i) / MIX_RATE
        var note_index: int = mini(notes.size() - 1, int(t / 0.205))
        var local_t: float = fmod(t, 0.205)
        var envelope: float = clampf(minf(local_t / 0.015, (0.205 - local_t) / 0.06), 0.0, 1.0)
        var f: float = notes[note_index]
        var sample: float = (sin(TAU * f * t) * 0.22 + sin(TAU * f * 2.0 * t) * 0.05) * envelope
        _write_stereo_sample(pcm, i, sample)

    return _make_wav(pcm, frames, false)

func _make_electric_sfx() -> AudioStreamWAV:
    var duration: float = 0.30
    var frames: int = int(duration * MIX_RATE)
    var pcm := PackedByteArray()
    pcm.resize(frames * 4)

    for i: int in range(frames):
        var t: float = float(i) / MIX_RATE
        var ratio: float = float(i) / maxi(1.0, float(frames - 1))
        var carrier: float = sin(TAU * (980.0 + 1700.0 * ratio) * t)
        var crackle: float = sin(TAU * 3100.0 * t) * sin(TAU * 73.0 * t)
        var envelope: float = pow(1.0 - ratio, 1.4)
        _write_stereo_sample(pcm, i, (carrier * 0.22 + crackle * 0.16) * envelope)

    return _make_wav(pcm, frames, false)

func _write_stereo_sample(buffer: PackedByteArray, frame: int, sample: float) -> void:
    var signed_value: int = clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
    var unsigned_value: int = signed_value if signed_value >= 0 else signed_value + 65536
    var low: int = unsigned_value & 0xff
    var high: int = (unsigned_value >> 8) & 0xff
    var offset: int = frame * 4
    buffer[offset] = low
    buffer[offset + 1] = high
    buffer[offset + 2] = low
    buffer[offset + 3] = high

func _make_wav(pcm: PackedByteArray, frames: int, loop: bool) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = MIX_RATE
    stream.stereo = true
    stream.data = pcm
    if loop:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = frames
    return stream
