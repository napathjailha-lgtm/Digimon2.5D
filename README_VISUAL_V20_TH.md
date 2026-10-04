# Godot 4 — Digital Pixel Visual Polish v20

ปรับต่อจาก Survival v19: HUD ใช้กรอบโลหะพิกเซลและเส้น cyan, หลอดพลังไหลด้วย Tween, กระเป๋า/สถานะ/อุปกรณ์/คัตซีนเบลอฉากหลัง, ปุ่มยุบและวาบแสงเมื่อแตะ, ขอบแดงเตือน Cannot Battle และคัตซีนมีละอองแสงกับกล้องสั่นช่วงระเบิดพลัง

## เปิดทดลองทันที

1. แตกโปรเจกต์ลงโฟลเดอร์ใหม่ แล้ว Import `mobile_survival_v20/project.godot` ด้วย Godot **4.4.1 ขึ้นไป**
2. เปิด `tools/visual_preview.tscn` แล้วกด **F6** มีปุ่ม HP 19%, ฟื้นเต็ม, กระเป๋า, สถานะ และเปลี่ยนร่าง
3. กด **F5** เพื่อเข้าเกมผ่าน Loading → Login → เลือกตัวละคร/คู่หู → สนาม
4. ในสนามแตะ **เมนู + → ตั้งค่า** เพื่อเลือกการเคลื่อนไหว, เบลอ/หรี่แสง และเอฟเฟกต์เต็ม/น้อย
5. ภาพจาก renderer จริงอยู่ใน `docs/previews/Visual_v20_*.png`; วิดีโออยู่ใน `docs/previews/Visual_v20_Demo.mp4`

ฉากสาธิตใช้ `user://visual_preview_v20.json` แยกจากสล็อตตัวละครจริง ชื่อแอปคงเป็น Digital Adventure Form Skills เพื่อให้เกมอ่านโฟลเดอร์เซฟเดิมได้ ส่วนเวอร์ชันแอปเป็น 0.20.0

## แนวทางภาพที่ใช้

| ส่วน | สี / จังหวะ | เหตุผลทางสายตา |
| --- | --- | --- |
| พื้น HUD | navy `#081522` | อ่านข้อมูลได้บนหญ้า ถนน และแสงเมือง |
| เส้นโลหะ / วงจร | cyan `#44CDDC`, เงิน `#90ABC0` | ให้ความรู้สึกอุปกรณ์ดิจิตอล โดยไม่ใช้พื้นสี neon เต็มแผง |
| HP คู่หู / Tamer | coral / mint | เห็นว่าเป็นคนละเจ้าของ พร้อมข้อความระบุชื่อ |
| DS / MP | blue / violet | แยกพลังเปลี่ยนร่างของ Tamer กับพลังสกิลของคู่หู |
| อิ่ม / แรง | amber / lime | อ่านแยกจากการต่อสู้ได้เร็ว |
| ความเสียหาย / ฟื้น | 0.32s / 0.45s | ลดเร็วพอให้รู้ว่าโดนโจมตี ฟื้นไหลนุ่มกว่า |
| popup | 0.8 → 1.05 → 1.0 | เด้งอย่างควบคุมได้ในประมาณ 0.3s |
| press / release | 1.0 → 0.93 → 1.035 → 1.0 | สื่อว่ารับสัมผัสแล้ว และไม่สะสมสเกลจากการกดเร็ว |
| คำเตือน | ขอบแดง alpha 0.10–0.22, จังหวะ 1.8s | ไม่บดบังศัตรูตรงกลางจอ; Reduce Motion แสดงขอบนิ่ง |
| evolution | สั่น 5px เป็นเวลา 0.32s ที่ 1.37s | เน้นจุดระเบิดพลัง ไม่สั่นตลอดคัตซีน |

PNG ใน `assets/ui/digital/` เป็นงานพิกเซลขนาดเล็กที่สร้างด้วยโค้ด กรอบหลอดมีสามชั้นและใช้ Nine Patch เพื่อไม่ยืดมุมโลหะ สามารถแก้สี/รอยบากที่ `tools/build_digital_ui_assets.py` แล้วสร้าง texture ใหม่ได้

## ไฟล์หลักและจุดเชื่อม

| ไฟล์ | หน้าที่ |
| --- | --- |
| `scripts/visual/smooth_texture_bar.gd` | TextureProgressBar + Tween ที่ยกเลิกค่ารอบเก่าและตามเป้าหมายล่าสุด |
| `shaders/ui_screen_blur.gdshader` | shader เบลอฉากหลังหนึ่งชิ้น ใช้ Screen Texture mipmap |
| `scripts/visual/mobile_button_fx.gd` | scale/flash ที่นำไปใช้กับ Control หรือ BaseButton ได้ |
| `scripts/visual/modal_visual_fx.gd` | BackBufferCopy → ColorRect Blur → Panel, พร้อม popup Tween |
| `scripts/visual/critical_screen_fx.gd` | ขอบแดงอยู่ใต้ HUD และไม่บังสัมผัส |
| `scripts/visual/camera_shake_2d.gd` | สั่นด้วย noise แล้วคืน offset ฐานเมื่อจบ/ยกเลิก |
| `scripts/visual/digital_pixel_dust.gd` | GPUParticles2D + ParticleProcessMaterial และ CPU preset |
| `scripts/visual/visual_settings.gd` | ตัวเลือกภาพร่วมกันสำหรับทุกสคริปต์ |
| `scripts/visual/visual_director.gd` | Autoload ของโปรเจกต์เต็ม ติด FX ให้ Button หน้าเมนูที่สร้างภายหลัง |

## 1. ตั้งค่าหลอดพลังใน Scene

สร้าง Node ชื่อ `HP` ชนิด **TextureProgressBar** แล้วแนบ `smooth_texture_bar.gd`; ใต้ HP เพิ่ม Label ชื่อ **Value** ตั้ง Full Rect, Horizontal/Vertical Alignment = Center และ Mouse Filter = Ignore

สคริปต์โหลด `bar_under.png` / `bar_fill.png` / `bar_frame.png` เอง ตั้ง `nine_patch_stretch=true`, ขอบซ้าย/ขวา 8px, บน/ล่าง 6px, `step=0.0` และ Texture Filter = Nearest เพื่อให้ภาพพิกเซลคม แต่การเคลื่อนของหลอดยังลื่น ตั้งความสูงหลอด 24px; แถว Needs ใช้ 20px

ตัวอย่างการเชื่อมกับข้อมูลจริง:

```gdscript
@onready var hp_bar: SmoothTextureBar = $HP

func _ready() -> void:
    # อ่านค่าปัจจุบันครั้งแรกเพื่อไม่ให้หลอดวิ่งมาจากศูนย์ตอนโหลดเซฟ
    hp_bar.set_vitals(player.hp, player.max_hp, "HP %d/%d" % [player.hp, player.max_hp], true)
    player.hp_changed.connect(_on_hp_changed)

func _on_hp_changed(hp: int, maximum: int) -> void:
    # ค่าจริงใน player เปลี่ยนแล้ว; Tween นี้เปลี่ยนเฉพาะภาพที่ผู้เล่นเห็น
    hp_bar.set_vitals(hp, maximum, "HP %d/%d" % [hp, maximum])
```

ในโปรเจกต์ v20 เชื่อมผ่าน `party_status_hud.gd` แล้ว ครอบคลุม HP ทั้งสองตัว, DS, MP, Hunger และ Stamina ส่วนเลือดเป้าหมายเปลี่ยนเป็น SmoothTextureBar ด้วย เมื่อเปลี่ยนศัตรูจะ snap ค่าครั้งแรก เพื่อไม่แสดงเลือดของตัวเก่าค่อยไหลมาเป็นตัวใหม่

**หลักสำคัญ:** ใช้ `tamer.hp` / `partner.hp` ตัดสินชีวิตและสิทธิ์ต่อสู้เสมอ ตัวเลขบน label เปลี่ยนทันที ส่วนค่า `bar.value` กำลังแอนิเมตและอาจตามหลังข้อมูลจริง 0.32–0.45s ห้ามเขียน `bar.value` ตรง ๆ จาก Signal เดิมร่วมกับ `set_vitals()`

## 2. ตั้งค่า Blur และ Popup

ลำดับที่ต้องวาดใน CanvasLayer ของหน้าต่าง:

| ลำดับ | Node | ค่าที่ตั้ง |
| --- | --- | --- |
| 1 | BackBufferCopy | Copy Mode = Viewport |
| 2 | ColorRect | Full Rect; material เป็น ShaderMaterial ที่ใช้ `ui_screen_blur.gdshader` |
| 3 | PanelContainer / Control ของหน้าต่าง | วาดข้อความ ปุ่มและไอคอนหลัง Blur เพื่อให้คมชัด |

`ModalVisualFX.attach(root, panel)` สร้างสอง Node แรกให้เอง Material แยกแต่ละหน้าต่าง ก่อนเปิดให้เจ้าของหน้าต่างจัด `_layout()`, เปิด root แล้วเรียก `animate_open()` ก่อนปิดเรียก `reset()` แล้วจึงซ่อน root และคืน pause

```gdscript
var visual_fx: ModalVisualFX

func _ready() -> void:
    # root ครอบหน้าจอ ส่วน panel เป็นหน้าต่างที่ต้องการเด้ง
    process_mode = Node.PROCESS_MODE_ALWAYS
    visual_fx = ModalVisualFX.attach($Root, $Root/Panel)
    $Root.hide()

func show_window() -> void:
    # จัดขนาดด้วย Container/Anchor ให้เสร็จก่อนเก็บสเกลฐานของ popup
    $Root.show()
    visual_fx.animate_open()

func hide_window() -> void:
    # ล้าง Tween ก่อนซ่อน เพื่อเปิดครั้งถัดไปได้แม้ผู้เล่นปิดอย่างรวดเร็ว
    visual_fx.reset()
    $Root.hide()
```

ให้ระบบ Inventory/Status ของเกมเป็นผู้ถือครอง pause ต่อไป และตั้ง Process Mode ของหน้าต่างเป็น **Always** ตัวเอฟเฟกต์ใช้ `Tween.TWEEN_PAUSE_PROCESS` จึงเล่นได้ขณะสนามหยุด ไม่มีการเปลี่ยนสเตตัสจากเอฟเฟกต์ภาพ

Shader ใช้ `hint_screen_texture`, `filter_linear_mipmap` และ `textureLod`; `radius_px=5` ให้ blur อ่อนนุ่ม ไม่ใช่การจำลอง bokeh แบบกล้องจริง หลังปิดหน้าต่าง BackBufferCopy ถูกปิดและ ColorRect ถูกซ่อน เมื่อเลือกเอฟเฟกต์น้อยใช้แผงหรี่แสงแทนการอ่าน Screen Texture

## 3. เอฟเฟกต์ทุกปุ่มบน Mobile

ในโปรเจกต์เต็ม `TouchCommand._ready()` แนบ MobileButtonFX ครั้งเดียว ปุ่ม Attack/Skill/Digivolve, ปุ่มเมนู, ช่องไอเทม และปุ่มอุปกรณ์จึงรับเอฟเฟกต์ร่วมกัน แม้เป็น subclass ที่วาดกรอบต่างกัน ส่วน VisualDirector ติดให้ BaseButton หน้า Loading/Login/เลือกตัวละครโดยอัตโนมัติ

ปุ่ม TouchCommand ส่ง `set_down(true)` **ก่อน** emit คำสั่งเกม และส่ง `set_down(false)` เมื่อปล่อย/ลากออกจากปุ่ม ยังคงเก็บ finger index แยกจาก Joystick เมื่อ pause เปลี่ยน Scene หรือตัวแอปเสีย focus ให้เรียก `release_input()` เพื่อเคลียร์นิ้วและคืนภาพ

ใช้กับปุ่มมาตรฐานในโปรเจกต์อื่น:

```gdscript
func _ready() -> void:
    # BaseButton มี button_down/up อยู่แล้ว Attach ต่อ Signal ของภาพให้เอง
    MobileButtonFX.attach($Panel/ConfirmButton)
```

ใช้กับ Control ที่มีระบบสัมผัสของตัวเอง:

```gdscript
var fx: MobileButtonFX

func _ready() -> void:
    fx = MobileButtonFX.attach(self)

func on_touch_down() -> void:
    # ให้ visual ตอบสนองก่อนเรียกคำสั่งจริงของเกม
    fx.set_down(true)

func on_touch_up_or_cancel() -> void:
    fx.set_down(false)
```

MobileButtonFX ไม่ emit คำสั่งโจมตีหรือเพิ่ม/ลดไอเทม ใช้ overlay `ColorRect` แบบ Mouse Filter Ignore สำหรับแสง Additive ไม่ต้องเปิด HDR/Bloom ทั้งฉาก Hitbox ของ TouchCommand ชดเชยเฉพาะสเกลแอนิเมชันแล้ว จึงไม่หดตามภาพปุ่มและไม่หลุดนิ้วเมื่อกดยุบ

## 4. Cannot Battle Vignette

HUD เพิ่ม CriticalScreenFX อยู่ CanvasLayer ชั้น **5** ส่วน HUD อยู่ชั้น **10**, อุปกรณ์/กระเป๋า/สถานะอยู่ชั้น **80/85/86**, คัตซีนอยู่ชั้น **100** คำเตือนจึงไม่ย้อมข้อความหรือปุ่มเป็นแดง

เรียก `critical_fx.set_critical(not tamer.can_battle())` ใน callback ของข้อมูลจริง v19 มี latch ของ Cannot Battle; คำเตือนจะอยู่จน HP ฟื้นถึงเกณฑ์ปลดสถานะที่ Survival กำหนด ไม่เปิด/ปิดสลับถี่ ๆ เมื่อ HP อยู่แถวเส้น 20% เมื่อเลือก Reduce Motion ใช้ขอบแดงนิ่ง alpha 0.14

## 5. Evolution: Camera Shake และ Digital Dust

Scene คัตซีนมี `Root/Stage/OldSprite`, `Root/Stage/NewSprite` และเพิ่ม DigitalPixelDust ใต้ Stage ใน runtime AnimationPlayer เรียก `energy_burst()` ที่ **1.37s**; ฟังก์ชันนี้เรียก `shake_fx.shake(5.0, 0.32)` ใช้ FastNoiseLite กับ decay และคืน `Camera2D.offset` เดิมทุกครั้งเมื่อจบ/ยกเลิก/ออก Scene

Sprite ของคัตซีนอยู่ใน CanvasLayer จึงไม่เคลื่อนตาม Camera2D ของโลก สคริปต์สั่น Stage ควบคู่กล้องเพื่อให้เห็นแรงระเบิดบนภาพคัตซีนด้วย โดยไม่แก้พิกัด Tamer หรือคู่หู

ค่าละอองที่สร้างให้:

| ค่า | ปกติ | เอฟเฟกต์น้อย |
| --- | --- | --- |
| Node | GPUParticles2D | CPUParticles2D |
| จำนวน | 56 | 24 |
| lifetime | 1.6s | 1.6s |
| direction / gravity | ขึ้น `(0,-1)` / `(0,-25)` | ใช้ preset เดียวกัน |
| initial velocity | 55–140 | 55–140 |
| emission shape | Box 210×20px ใกล้เท้า | ใช้ preset เดียวกัน |
| texture | พิกเซล 4×4px; scale 0.7–1.8 | texture เดียวกัน |
| camera shake | เปิด | ปิด |

ParticleProcessMaterial ถูกสร้างแยกแต่ละคัตซีน GPUParticles และ UI สืบทอด **Always** จึงไม่หยุดพร้อมสนาม CPU preset สร้างด้วย `convert_from_particles()` เก็บพฤติกรรมเดิม มีการหยุด emission และคืน offset ใน `_finish()`/`_exit_tree()`; การคืน DS และ commit ร่างยังใช้ transaction ของเกม

## 6. นำชุดโค้ดไปใช้ในโปรเจกต์อื่น

`Godot4_VisualFX_Kit_v20.zip` มีสคริปต์ visual ทั่วไป, shader 3 ชิ้น, PNG 6 ชิ้น และฟอนต์ไทย คัดลอกโฟลเดอร์ `scripts/visual/`, `shaders/`, `assets/ui/digital/` ไปให้ตรง `res://` ตามโค้ด แล้วแนบสคริปต์ใน Scene ของคุณ ปุ่ม BaseButton ใช้ `MobileButtonFX.attach()` ได้ทันที; ปุ่ม Control ที่เขียน input เองเรียก set_down/release ตามตัวอย่างด้านบน

ค่าสี/ความเร็วปรับได้ใน Inspector ของ SmoothTextureBar/MobileButtonFX ส่วนตัวเลือกกลางตั้ง `GameVisualSettings.motion_enabled`, `blur_enabled`, `low_effects` สำหรับโปรเจกต์ v20 ตัวเลือกถูกเก็บโดย HudPreferences และโหลดตั้งแต่หน้าแรก

## ตรวจสอบผล

รันด้วย **Godot 4.4.1**: import/parse, visual_polish_test, clean_hud_test, classic_hud_test, survival_status_test, inventory_loot_test, recovery_progress_cutscene_test, smoke_test และ pregame_flow_test ผ่าน ภาพและวิดีโอถ่ายจาก OpenGL Compatibility renderer จริง ค่าพลัง/คำสั่ง/การ pause ตรวจผ่าน Signal และ input pipeline

ทดสอบ renderer ครั้งนี้บน Linux ด้วย Mesa software renderer; ค่า FPS บนอุปกรณ์ Android ยังต้องวัดบนเครื่องเป้าหมาย เลือกเอฟเฟกต์น้อยและหรี่แสงได้จากเมนูเกมเพื่อลดงานภาพ

## เอกสาร Godot ที่ใช้อ้างอิง

- [TextureProgressBar](https://docs.godotengine.org/en/4.4/classes/class_textureprogressbar.html)
- [Tween](https://docs.godotengine.org/en/4.4/classes/class_tween.html)
- [Screen-reading shaders](https://docs.godotengine.org/en/4.4/tutorials/shaders/screen-reading_shaders.html)
- [BackBufferCopy](https://docs.godotengine.org/en/4.4/classes/class_backbuffercopy.html)
- [GPUParticles2D](https://docs.godotengine.org/en/4.4/classes/class_gpuparticles2d.html)
- [ParticleProcessMaterial](https://docs.godotengine.org/en/4.4/classes/class_particleprocessmaterial.html)


## โค้ดอ้างอิงจากไฟล์จริงใน v20

โค้ดต่อไปนี้เป็นสำเนาจากไฟล์ที่รันและตรวจแล้วในโปรเจกต์ ใช้ GameVisualSettings และ paths ตามที่อธิบายด้านบน

### SmoothTextureBar — โค้ดฉบับเต็ม

`scripts/visual/smooth_texture_bar.gd`

```gdscript
class_name SmoothTextureBar
extends TextureProgressBar
## หลอดแสดงผลเท่านั้น: ห้ามใช้ value ที่กำลัง Tween มาตัดสินความตายหรือสิทธิ์ต่อสู้
@export var fill_color: Color = Color("ef7189")
@export_range(0.05, 1.0, 0.01) var drain_seconds: float = 0.32
@export_range(0.05, 1.0, 0.01) var recover_seconds: float = 0.45
var _value_tween: Tween
var _initialized: bool = false
var _goal: float = -1.0
var _limit: float = -1.0

func _ready() -> void:
    add_to_group("smooth_texture_bars")
    # กรอบสามชั้นใช้ PNG พิกเซลจริง; Nine Patch ยืดเฉพาะกลาง ไม่บิดมุมโลหะ
    texture_under = preload("res://assets/ui/digital/bar_under.png")
    texture_progress = preload("res://assets/ui/digital/bar_fill.png")
    texture_over = preload("res://assets/ui/digital/bar_frame.png")
    tint_progress = fill_color
    nine_patch_stretch = true
    stretch_margin_left = 8
    stretch_margin_right = 8
    stretch_margin_top = 6
    stretch_margin_bottom = 6
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    step = 0.0 # เลขทศนิยมระหว่าง Tween ทำให้หลอดไหล ไม่กระโดดทีละ 1 HP
    var label := get_node_or_null("Value") as Label
    if label != null:
        label.add_theme_color_override("font_color", Color("f2fbff"))
        label.add_theme_color_override("font_outline_color", Color("08111b"))
        label.add_theme_constant_override("outline_size", 2)

func set_vitals(current: float, maximum: float, caption: String = "", instant: bool = false) -> void:
    # รับค่าจริงผ่าน Signal; label เปลี่ยนทันที แต่ภาพหลอดค่อย ๆ ตามค่าจริง
    if not is_finite(current) or not is_finite(maximum):
        return
    var safe_max: float = maxf(1.0, maximum)
    var target_value: float = clampf(current, 0.0, safe_max)
    var label := get_node_or_null("Value") as Label
    if label != null:
        label.text = caption
    if _initialized and is_equal_approx(_goal, target_value) and is_equal_approx(_limit, safe_max) and not instant:
        return # ไม่สร้าง Tween ซ้ำเมื่อ Signal อื่นส่งค่า HP เดิมมา
    _stop_tween()
    var previous_ratio: float = value / maxf(1.0, max_value)
    max_value = safe_max
    if _initialized and not is_equal_approx(_limit, safe_max):
        value = previous_ratio * safe_max # เพิ่ม max HP แล้วไม่กระพริบเป็นเลือดเต็มฟรี
    _goal = target_value
    _limit = safe_max
    if instant or not _initialized or not GameVisualSettings.motion_enabled:
        value = target_value
        _initialized = true
        return
    var duration: float = recover_seconds if target_value > value else drain_seconds
    _value_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _value_tween.tween_property(self, "value", target_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func snap_to_target() -> void:
    # เรียกตอนเลือก Reduce Motion; หยุดหลอดที่ยังไหลอยู่แล้วแสดงข้อมูลล่าสุด
    _stop_tween()
    if _initialized:
        value = _goal

func _stop_tween() -> void:
    # Kill ก่อนเริ่มอันใหม่ เพื่อไม่ให้ Tween เก่ากับใหม่แย่งเขียน value
    if _value_tween != null and _value_tween.is_valid():
        _value_tween.kill()
```

### Screen Blur — Shader ฉบับเต็ม

`shaders/ui_screen_blur.gdshader`

```glsl
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float radius_px : hint_range(0.0, 12.0) = 5.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 0.7) = 0.28;

void fragment() {
    // Godot สร้าง mipmap ที่กรองภาพไว้แล้ว; LOD สูงทำให้เบลอนุ่มโดยไม่เห็นตัวอักษรซ้อน
    float lod = log2(max(radius_px, 1.0)) * strength;
    vec3 color = textureLod(screen_texture, SCREEN_UV, lod).rgb;
    // ลดแสงและเติมน้ำเงินนิดเดียว เพื่อให้หน้าต่างสว่างเด่นโดยไม่แสบตา
    color = mix(color, vec3(0.025, 0.045, 0.085), darken * strength);
    COLOR = vec4(color, 1.0);
}
```

### MobileButtonFX — โค้ดฉบับเต็ม

`scripts/visual/mobile_button_fx.gd`

```gdscript
class_name MobileButtonFX
extends Node
## เพิ่มเป็นลูกของ Control หรือ BaseButton; เอฟเฟกต์ไม่ emit คำสั่งเกมเอง
@export var visual_target: Control
@export_range(0.85, 1.0, 0.01) var press_scale: float = 0.93
var _rest_scale := Vector2.ONE
var _scale_tween: Tween
var _flash_tween: Tween
var _glow: ColorRect
var _material: ShaderMaterial
var _down: bool = false

static func attach(button: Control) -> MobileButtonFX:
    # ปุ่มที่สร้าง runtime เช่นสกิล/ช่องกระเป๋าใช้สคริปต์เดียวกันและไม่ต่อ Signal ซ้ำ
    var existing := button.get_node_or_null("VisualFX") as MobileButtonFX
    if existing != null:
        return existing
    var fx := MobileButtonFX.new()
    fx.name = "VisualFX"
    fx.visual_target = button
    button.add_child(fx)
    return fx

func _ready() -> void:
    # PROCESS_ALWAYS ทำให้การเด้งคืนทำงานแม้ปุ่มนั้นเป็นปุ่มเปิดหน้าต่าง Pause
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("button_visual_fx")
    if visual_target == null:
        visual_target = get_parent() as Control
    if visual_target == null:
        return
    _rest_scale = visual_target.scale
    _glow = ColorRect.new()
    _glow.name = "PressGlow"
    _glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _material = ShaderMaterial.new()
    _material.shader = preload("res://shaders/ui_button_glow.gdshader")
    _glow.material = _material
    _glow.visible = false
    visual_target.add_child(_glow)
    visual_target.move_child(_glow, 0)
    visual_target.resized.connect(_update_pivot)
    visual_target.visibility_changed.connect(_on_visibility_changed)
    if visual_target is BaseButton:
        var button := visual_target as BaseButton
        button.button_down.connect(set_down.bind(true))
        button.button_up.connect(set_down.bind(false))
    _update_pivot()

func _update_pivot() -> void:
    # ตั้ง pivot กลางปุ่มก่อน scale; Container ยังเป็นผู้จัด position/size ตามเดิม
    if is_instance_valid(visual_target):
        visual_target.pivot_offset = visual_target.size * 0.5

func contains_screen_point(screen_point: Vector2) -> bool:
    # ยกเลิกเฉพาะสเกลเอฟเฟกต์ตอนตรวจ hitbox: นิ้วไม่หลุดปุ่มเพราะภาพยุบ 7%
    var local: Vector2 = visual_target.get_global_transform_with_canvas().affine_inverse() * screen_point
    local = (local - visual_target.pivot_offset) * (visual_target.scale / _rest_scale) + visual_target.pivot_offset
    return Rect2(Vector2.ZERO, visual_target.size).has_point(local)

func set_down(down: bool) -> void:
    # Tween scale กับ flash แยกกัน กดเร็วหลายครั้งก็ไม่ทิ้งปุ่มไว้ในสเกลผิด
    if _down == down or not is_instance_valid(visual_target):
        return
    _down = down
    _kill(_scale_tween)
    if not GameVisualSettings.motion_enabled:
        visual_target.scale = _rest_scale
        return
    _update_pivot()
    _scale_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    if down:
        _scale_tween.tween_property(visual_target, "scale", _rest_scale * press_scale, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _flash()
    else:
        _scale_tween.tween_property(visual_target, "scale", _rest_scale * 1.035, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _scale_tween.tween_property(visual_target, "scale", _rest_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _flash() -> void:
    # วาบสั้น 0.22s: สื่อว่ารับการแตะแล้ว โดยไม่บดบังเลข cooldown นานเกินไป
    _kill(_flash_tween)
    _glow.show()
    _material.set_shader_parameter("flash", 0.85)
    _flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _flash_tween.tween_method(_set_flash, 0.85, 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _flash_tween.tween_callback(_glow.hide)

func _set_flash(value: float) -> void:
    # ส่ง uniform ให้ material ของปุ่มนี้เท่านั้น ไม่แก้ shared ShaderMaterial ของปุ่มอื่น
    _material.set_shader_parameter("flash", value)

func reset() -> void:
    # ใช้เมื่อย้าย Scene, เปิด modal, ปล่อยนิ้วแบบ canceled หรือแอปเสีย focus
    _down = false
    _kill(_scale_tween)
    _kill(_flash_tween)
    if is_instance_valid(visual_target):
        visual_target.scale = _rest_scale
    if is_instance_valid(_glow):
        _glow.hide()

func _on_visibility_changed() -> void:
    # ไม่ให้ Tween เก่ายังหดปุ่มที่เปิดกลับมาครั้งต่อไป
    if not visual_target.is_visible_in_tree():
        reset()

func _notification(what: int) -> void:
    # นิ้วที่ปล่อยนอกแอปจะไม่มี touch-up; ต้องคืนภาพเองตอน focus หาย
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        reset()

func _kill(tween: Tween) -> void:
    # ล้าง Tween ที่ยัง valid เท่านั้น เพื่อเรียก reset ซ้ำได้อย่างปลอดภัย
    if tween != null and tween.is_valid():
        tween.kill()
```

### ModalVisualFX — ลำดับหน้าต่างและ popup

`scripts/visual/modal_visual_fx.gd`

```gdscript
class_name ModalVisualFX
extends Node
## ติดให้ modal แต่ละอัน; Pause ownership และคำสั่งปิดยังอยู่ในสคริปต์หน้าต่างเดิม
var root: Control
var panel: Control
var blur: ColorRect
var copy: BackBufferCopy
var _material: ShaderMaterial
var _tween: Tween
var _rest_scale := Vector2.ONE

static func attach(overlay_root: Control, popup_panel: Control) -> ModalVisualFX:
    # BackBufferCopy ต้องถูกวาดก่อน Blur ส่วน Panel ต้องอยู่หลัง Blur ในลำดับลูก
    var fx := ModalVisualFX.new()
    fx.root = overlay_root
    fx.panel = popup_panel
    overlay_root.add_child(fx)
    return fx

func _ready() -> void:
    # Blur ทำงานเฉพาะตอน modal เปิด ไม่อ่านหน้าจอเพิ่มขณะเดินบนสนาม
    process_mode = Node.PROCESS_MODE_ALWAYS
    for child: Node in root.get_children():
        if child is ColorRect and child.name in ["Shade", "Dim"]:
            (child as ColorRect).color.a = 0.0 # แทน Shade เดิม แต่เก็บ input blocking ไว้
    copy = BackBufferCopy.new()
    copy.name = "BackdropCopy"
    copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
    root.add_child(copy)
    root.move_child(copy, 0)
    blur = ColorRect.new()
    blur.name = "ScreenBlur"
    blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
    blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _material = ShaderMaterial.new()
    _material.shader = preload("res://shaders/ui_screen_blur.gdshader")
    blur.material = _material
    root.add_child(blur)
    root.move_child(blur, 1)
    blur.hide()

func animate_open() -> void:
    # เก็บสเกล adaptive ที่ _layout คำนวณไว้ แล้วขยาย 0.8 → 1.05 → 1.0
    _stop()
    _rest_scale = panel.scale
    panel.pivot_offset = panel.size * 0.5
    var use_blur: bool = GameVisualSettings.blur_enabled and not GameVisualSettings.low_effects
    copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if use_blur else BackBufferCopy.COPY_MODE_DISABLED
    blur.material = _material if use_blur else null
    blur.color = Color.WHITE if use_blur else Color(0.01, 0.025, 0.06, 0.56)
    blur.show()
    _material.set_shader_parameter("radius_px", 3.0 if GameVisualSettings.low_effects else 5.0)
    _material.set_shader_parameter("strength", 1.0)
    if not GameVisualSettings.motion_enabled:
        panel.scale = _rest_scale
        return
    panel.scale = _rest_scale * 0.8
    panel.modulate.a = 0.0
    _material.set_shader_parameter("strength", 0.0)
    _tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _tween.set_parallel(true)
    _tween.tween_property(panel, "modulate:a", 1.0, 0.12)
    _tween.tween_method(_set_blur, 0.0, 1.0, 0.22)
    _tween.tween_property(panel, "scale", _rest_scale * 1.05, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.chain().tween_property(panel, "scale", _rest_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Container อาจจัดขนาดหลัง show: ปรับ pivot อีกครั้งหลังเฟรม layout โดยไม่ขยับตำแหน่ง
    _update_pivot.call_deferred()

func reset() -> void:
    # ปิดได้ทันทีและคืนภาพเดิม ก่อนเจ้าของหน้าต่างปล่อย pause
    _stop()
    panel.scale = _rest_scale
    panel.modulate.a = 1.0
    copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
    blur.hide()

func _update_pivot() -> void:
    # Anchor/Container ยังคุมขนาด หน้าต่างจึงอยู่กลางจอทุกอัตราส่วน Landscape
    if is_instance_valid(panel):
        panel.pivot_offset = panel.size * 0.5

func _set_blur(value: float) -> void:
    # การ fade uniform ไม่สร้าง material ใหม่ทุกเฟรม
    _material.set_shader_parameter("strength", value)

func _stop() -> void:
    # เปิด-ปิดเร็วไม่ให้ tween ของรอบก่อนดัน scale รอบใหม่
    if _tween != null and _tween.is_valid():
        _tween.kill()
```

### Camera Shake — โค้ดฉบับเต็ม

`scripts/visual/camera_shake_2d.gd`

```gdscript
class_name PolishedCameraShake2D
extends Node
## Offset เสริม ไม่แก้ตำแหน่ง Tamer และไม่กระทบ Camera Smooth Follow
@export var camera: Camera2D
@export var stage: Node2D
var _camera_rest := Vector2.ZERO
var _stage_rest := Vector2.ZERO
var _elapsed: float = 0.0
var _duration: float = 0.0
var _strength: float = 0.0
var _active: bool = false
var _noise := FastNoiseLite.new()

func _ready() -> void:
    # คัตซีน pause โลก แต่ตัวขยับ offset ต้องเดินต่อด้วยเวลา UI
    process_mode = Node.PROCESS_MODE_ALWAYS
    _noise.seed = 2048
    _noise.frequency = 0.8
    set_process(false)

func shake(strength_px: float = 4.0, duration: float = 0.28) -> void:
    # เก็บฐานใหม่หลังยกเลิกรอบเก่า ป้องกันสะสม offset จนกล้องเลื่อนถาวร
    stop_shake()
    if not GameVisualSettings.motion_enabled or GameVisualSettings.low_effects:
        return
    if is_instance_valid(camera):
        _camera_rest = camera.offset
    if is_instance_valid(stage):
        _stage_rest = stage.position
    _strength = clampf(strength_px, 0.0, 8.0)
    _duration = maxf(0.05, duration)
    _elapsed = 0.0
    _active = true
    set_process(true)

func _process(delta: float) -> void:
    # Noise ต่อเนื่องให้สั่นเนียนกว่า randf ทุกเฟรม แล้วลดแรงกลับศูนย์อย่างนุ่มนวล
    _elapsed += delta
    var decay: float = pow(maxf(0.0, 1.0 - _elapsed / _duration), 2.0)
    var time: float = _elapsed * 38.0
    var offset: Vector2 = Vector2(_noise.get_noise_1d(time), _noise.get_noise_1d(time + 73.0)) * _strength * decay * 2.0
    if is_instance_valid(camera):
        camera.offset = _camera_rest + offset
        camera.force_update_scroll() # Camera ของโลกที่ถูก pause ยังแสดง offset ได้
    if is_instance_valid(stage):
        stage.position = _stage_rest + offset # ภาพคัตซีนใน CanvasLayer ไม่ตาม Camera2D จึงขยับ stage ด้วย
    if _elapsed >= _duration:
        stop_shake()

func stop_shake() -> void:
    # คืนฐานตรง ๆ เมื่อจบ/ยกเลิกคัตซีน ไม่ปล่อยเศษค่าของ noise ติดกล้อง
    if _active:
        if is_instance_valid(camera):
            camera.offset = _camera_rest
            camera.force_update_scroll()
        if is_instance_valid(stage):
            stage.position = _stage_rest
    _active = false
    set_process(false)

func _exit_tree() -> void:
    # ปิด Scene ระหว่าง burst ก็ต้องคืน offset ก่อน Node ถูกลบ
    stop_shake()

```

### Digital Pixel Dust — โค้ดฉบับเต็ม

`scripts/visual/digital_pixel_dust.gd`

```gdscript
class_name DigitalPixelDust
extends Node2D
## ละอองสี่เหลี่ยมขึ้นจากเท้า: GPU + ParticleProcessMaterial, มี CPU preset สำหรับ Reduce Effects
var gpu: GPUParticles2D
var cpu: CPUParticles2D

func _ready() -> void:
    # พื้นที่คัตซีนเล็ก ปิด collision/trail และใช้แค่ 56 เม็ด ไม่คำนวณทั่วแผนที่
    process_mode = Node.PROCESS_MODE_ALWAYS
    var process := ParticleProcessMaterial.new()
    process.particle_flag_disable_z = true
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(105, 10, 0)
    process.direction = Vector3(0, -1, 0)
    process.spread = 18.0
    process.initial_velocity_min = 55.0
    process.initial_velocity_max = 140.0
    process.gravity = Vector3(0, -25, 0)
    process.scale_min = 0.7
    process.scale_max = 1.8
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.75, 1.0])
    gradient.colors = PackedColorArray([Color(0.3, 0.8, 1, 0), Color(0.4, 0.95, 1, 0.9), Color(0.8, 0.9, 1, 0.7), Color(0.5, 0.8, 1, 0)])
    var ramp := GradientTexture1D.new()
    ramp.gradient = gradient
    process.color_ramp = ramp
    var additive := CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    gpu = GPUParticles2D.new()
    gpu.name = "DigitalDustGPU"
    gpu.amount = 56
    gpu.lifetime = 1.6
    gpu.preprocess = 0.35
    gpu.local_coords = true
    gpu.visibility_rect = Rect2(-160, -350, 320, 420)
    gpu.texture = preload("res://assets/ui/digital/pixel_dust.png")
    gpu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    gpu.process_material = process
    gpu.material = additive
    gpu.emitting = false
    add_child(gpu)
    cpu = CPUParticles2D.new()
    cpu.name = "DigitalDustCPU"
    cpu.convert_from_particles(gpu)
    cpu.amount = 24
    cpu.material = additive
    cpu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    cpu.emitting = false
    add_child(cpu)

func start_dust() -> void:
    # ลดเอฟเฟกต์เลือก CPU 24 เม็ด; โหมดปกติใช้ GPU ตามที่กำหนด
    stop_dust()
    if GameVisualSettings.low_effects:
        cpu.restart()
        cpu.emitting = true
    else:
        gpu.restart()
        gpu.emitting = true

func stop_dust() -> void:
    # จบคัตซีนแล้วไม่ปล่อย emission ต่อ; ทั้งคู่ถูกลบพร้อม stage
    if is_instance_valid(gpu):
        gpu.emitting = false
    if is_instance_valid(cpu):
        cpu.emitting = false

```

