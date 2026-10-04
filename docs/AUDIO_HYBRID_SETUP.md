# Hybrid Input + Audio Architecture

## Runtime Node Tree

```text
/root
├─ AudioManager (Autoload Node)
│  ├─ MusicPlayer (AudioStreamPlayer)
│  ├─ EvolutionPlayer (AudioStreamPlayer)
│  └─ SFXPlayer (AudioStreamPlayer)
│
└─ World
   ├─ Actors
   │  ├─ Tamer
   │  │  └─ Camera2D
   │  └─ Partner
   ├─ MobileHUD
   │  ├─ MobileJoystick        <- Touch movement
   │  └─ SkillPanel           <- Touch skill 1-4
   └─ WorldServiceController
      └─ IncubatorUI          <- hatch flash + success SFX
```

## Hybrid Input

- Web/PC movement: WASD or Arrow keys.
- Mobile movement: Virtual Joystick.
- Web/PC skills: 1, 2, 3, 4.
- Mobile skills: right-bottom skill controls.
- Target selection: mouse left click or screen touch.
- Interaction: E, mouse click, or touch where the service object supports it.
- Keyboard movement takes priority when keyboard and joystick both provide input.

## Web Audio Unlock

`AudioManager.unlock_audio()` must be called synchronously from a real user gesture.
The project calls it from:

- Login button
- Start Game / enter-world button
- Starter confirmation
- First mouse/touch/key event as a fallback

Do not put `await` or `call_deferred()` before the unlock call.

## Evolution audio timing

```text
Digivolve button accepted
       |
       +--> AudioManager.play_evolution_theme()
       |       +--> fade map BGM down
       |       +--> start EvolutionPlayer
       |
AnimationPlayer "evolve"
       |
       +-- 1.37s energy_burst()
       |       +--> camera shake
       |       +--> evolution_burst SFX
       |
       +-- 2.70s animation_finished
               +--> finish_digivolve()
               +--> AudioManager.finish_evolution_theme()
                       +--> fade theme out
                       +--> resume/fade map BGM in
```

## Incubator success timing

```text
Inject reaches 5/5
  -> add_hatched_to_storage()
  -> consume Digitama
  -> hatch_completed signal
       -> hatch_success SFX
       -> white screen flash
```

The success sound is only emitted after the storage transaction succeeds.

## Custom audio files

The repository currently contains no production audio assets. AudioManager deliberately stays silent when an audio file is missing. This avoids distorted runtime-generated PCM on Web Mobile and keeps the playback path identical between Web and native Mobile.

To use production audio later:

```gdscript
var map_bgm: AudioStream = load("res://assets/audio/file_island.ogg")
AudioManager.play_bgm(map_bgm)

var evolution_theme: AudioStream = load("res://assets/audio/evolution_theme.ogg")
AudioManager.play_evolution_theme(evolution_theme)
```

Use original/licensed audio. Recommended production paths are res://assets/audio/bgm/, res://assets/audio/evolution/, and res://assets/audio/sfx/.
