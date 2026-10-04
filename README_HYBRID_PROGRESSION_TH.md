# Hybrid Input / Level Evolution / Jogress

โค้ดรวมเข้ากับโปรเจกต์เดิมบน `main` แล้วใน branch ของงานนี้ ใช้ GDScript 4 และทดสอบกับ Godot 4.4.1 Compatibility renderer เปิด `project.godot` แล้วรอ Import Assets ให้ครบ

## การควบคุม

| คำสั่ง | Web / PC | Mobile |
|---|---|---|
| เดิน | WASD หรือปุ่มลูกศร | Virtual Joystick |
| โจมตี | Space | ปุ่มโจมตี |
| สกิลช่อง 1–4 | 1, 2, 3, 4 | ปุ่มสกิลครึ่งวงกลม |
| เลือกและล็อกเป้า | คลิกซ้ายมอนสเตอร์ | แตะมอนสเตอร์ |
| Jogress / แยกร่าง | J | ปุ่ม Jogress / แยกร่าง |
| พัฒนาร่างปกติ | คลิก Evolve | แตะ Evolve |

`HybridInput.ensure_actions()` ลงทะเบียน physical keys ตอน Tamer เริ่มทำงาน เรียกซ้ำได้โดยไม่เพิ่ม binding ซ้ำและไม่ลบค่าที่ตั้งเองใน Input Map ไม่ต้องแยกสคริปต์ตาม OS: เว็บบนมือถือหรือคอมพิวเตอร์ที่มีจอสัมผัสใช้ทั้งสองทางพร้อมกันได้ คีย์บอร์ดมีลำดับก่อน joystick และเวกเตอร์ถูกจำกัดความยาว 1 เพื่อไม่ให้เดินทแยงเร็วกว่าเดินตรง

`Input.get_vector()` เป็นการอ่านสถานะคีย์ดิบ จึงต้องตรวจ `controls_blocked` และ focus ของ LineEdit/TextEdit อีกครั้ง การใช้ `_unhandled_input()` อย่างเดียวไม่พอสำหรับการกันเดินขณะพิมพ์แชต เมนู/หน้าต่าง/คัตซีนจะบล็อกคำสั่ง และไม่รับ key echo เพื่อกันการกดค้างยิงซ้ำ

โปรเจกต์เปิด `emulate_touch_from_mouse=true` และ `emulate_mouse_from_touch=false` ตาม HUD เดิม เมาส์จึงใช้เส้นทาง ScreenTouch ของปุ่มและ joystick เดิม ส่วน Tamer รับ native MouseButton เมื่อปิด emulation เท่านั้น จึงไม่สั่งโจมตีซ้ำหรือคลิกทะลุ HUD ด้วย MouseButton ที่มาคู่กับ touch จำลอง การหาเป้าแปลงพิกัดด้วย canvas transform ก่อน point query รองรับกล้องและการย่อขยายจอ

คีย์สกิลเรียก `FormSkillPanel.request_visible_slot()` จึงผ่าน guard เดียวกับนิ้ว: ร่างปัจจุบัน, slot, revision, MP, cooldown และสถานะต่อสู้ ช่องว่างไม่ใช้สกิลใดและไม่หัก MP

## เลเวลและสายร่าง

| ช่วงเลเวล / ร่างสูงสุดที่ปลดล็อก | Agumon | Gabumon |
|---|---|---|
| 1–14 / Rookie | Agumon | Gabumon |
| 15–59 / Champion | Greymon | Garurumon |
| 60–89 / Ultimate | MetalGreymon | WereGarurumon |
| 90 / Mega | WarGreymon | MetalGarurumon |

ใช้แบบ **ปลดล็อกตามเลเวลแล้วกด Evolve** ตามลำดับร่าง ผู้เล่นคง Rookie หรือกลับ Rookie เมื่อ DS หมดได้ จึงไม่บังคับให้อยู่ร่างสูงสุดตลอดเวลา `EvolutionRules.FORM_LEVELS` เป็นแหล่งกติกาเดียวสำหรับปุ่ม, loader, คัตซีนและการโหลดสมาชิก ไม่ใช้ความคืบหน้าเควสต์เป็นเงื่อนไขวิวัฒนาการ

`MonsterData` และ `.tres` เดิมยังใช้ได้และเก็บ ID เดิมทั้งหมด สกิลของร่างอยู่ใน `MonsterData.skills`; เมื่อเปลี่ยนร่าง `PartnerMonster.load_monster_data()` จะยกเลิกท่าร่าย/คำสั่งเก่า แล้วแทนที่ `active_skills` พร้อมส่ง `skills_changed` เพื่อสร้างแผงใหม่ หน้า UI ไม่แสดงร่างอื่น และ `_try_skill_resource()` ปฏิเสธ Resource สกิลที่ไม่อยู่ในร่างปัจจุบันด้วย

คู่หูมีเพดาน Lv90 แยกจากระบบเลเวล Tamer เดิม แต่ละสมาชิกเก็บ EXP/level ของตนเอง ตัวใหม่เริ่ม Lv1 และได้ EXP เมื่อเป็นตัวที่ใช้งานอยู่ เซฟ roster รุ่น 3 ยังอ่านรุ่น 1/2 ได้: คง progress ที่มีในแต่ละสมาชิก และใช้ `shared_progress` เป็น fallback เฉพาะสมาชิกเก่าที่ไม่มี progress ไม่ลดเลเวลที่ผู้เล่นได้จากระบบ shared เดิม และไม่ยกระดับสมาชิกใหม่ตามตัวที่เก่งที่สุด

## Jogress และเซฟ

`JogressManager` ตรวจว่ามี Agumon และ Gabumon ใน roster, ทั้งคู่ Lv90, ยังไม่เป็นไข่/HP0 และตัวที่ใช้งานอยู่เป็นหนึ่งในสองสายนี้ Tamer ต้องต่อสู้ได้ มี DS และไม่ได้พัก/เปิดคัตซีน จากนั้นเล่น JogressCutscene และตรวจส่วนผสมซ้ำก่อน commit

Omegamon ใช้ฐาน HP 1200, ATK 155 ก่อนโบนัสเลเวล/อุปกรณ์ ซึ่งสูงกว่าร่าง Mega เดิม มี Grey Sword (5.4x, MP16, CD6s) และ Garuru Cannon (5.8x, MP20, CD8s) แทนสกิลเดิมทั้งหมด Skill MP เป็นของคู่หู แยกจาก Tamer DS ซึ่งบางหน้าจอเดิมเรียก T-MP

รวมร่างใช้ actor บนสนามตัวเดิม ไม่มีสมาชิก Omegamon ตัวใหม่ ปิดการสลับสมาชิกระหว่างรวมร่างเพื่อไม่ให้ส่วนประกอบลงสนามซ้ำ กด J อีกครั้งเพื่อแยกร่างเป็น Mega ของตัวหลัก โดยรักษา %HP, MP และ cooldown ตัวสำรองคงข้อมูลของตัวเอง

เซฟสมาชิกเก็บ ID Mega ที่โหลดได้ตามปกติ ส่วน `jogress` แยกเก็บสถานะรวมร่างกับสัดส่วน HP หลังโหลด roster แล้วจึงคืน Omegamon หากส่วนผสมยังถูกต้อง การโหลดไม่เล่นคัตซีนซ้ำ ไม่รีเซ็ต cooldown และไม่ฮีลฟรี เมื่อ DS หมดจะคืน Rookie; เมื่อแพ้จะเป็นไข่และล้างสถานะ fusion ก่อน Recover

สไปรต์ `assets/jogress/omegamon_actions.png` มีสี่ภาพท่า (Idle/Walk/Grey Sword/Garuru Cannon) ใช้ AtlasTexture ใน `data/omegamon_frames.tres` ปักเท้าด้วย margin โดยไม่แก้ PNG ระหว่างเล่น Action มี 4 timing frames และปล่อยสกิลที่เฟรม 2 ภาพชุดนี้ใช้มุมร่วมและกลับซ้ายผ่าน DirectionalAnimator เดิม ยังไม่ใช่ชุดภาพวาดครบทุกทิศ

## สมดุล DS และศัตรู

`EvolutionRules.ds_drain(rate)` คืน `rate * 0.5`; PartnerMonster หัก `balanced_rate * delta` ไม่แก้ Resource ต้นแบบและไม่คูณลดซ้ำตอนเปลี่ยนร่าง ค่าเริ่มต้นสองสาย: Champion 5 → 2.5, Ultimate 10 → 5, Mega 6 → 3 DS/วินาที; Omegamon 8 → 4 ค่าเปลี่ยนร่างครั้งแรกยังแยกจากอัตราคงร่าง

`DynamicScaling.stats(base_hp, base_attack, level, boss)` คำนวณจากฐาน Lv1 ที่จับครั้งเดียวตอนเกิด:

```gdscript
var factor: float = float(clampi(level, 1, 90))
if boss:
    factor *= 2.5
var scaled_hp: int = maxi(1, roundi(base_hp * factor))
var scaled_attack: int = maxi(1, roundi(base_attack * factor))
```

ฐานปัจจุบัน wild คือ HP160 / ATK9; บอสทั้ง Devimon, Etemon, Myotismon, Piedmon ใช้ฐานเดียวกันก่อนตัวคูณ เพื่อไม่คูณทับค่าเลือดบอสเก่าที่สูงอยู่แล้ว

| เลเวลคู่หู | Wild HP / ATK | Boss HP / ATK |
|---|---|---|
| 1 | 160 / 9 | 400 / 23 |
| 10 | 1,600 / 90 | 4,000 / 225 |
| 90 | 14,400 / 810 | 36,000 / 2,025 |

ค่าทศนิยมปัดเป็นจำนวนเต็มใกล้ที่สุด บอสจึงได้ ATK23 จาก 22.5 ที่ Lv1 ข้อมูลที่เกิดอยู่แล้วฟัง `progress_changed` และรักษา %HP เมื่อเลเวลเปลี่ยน/สลับสมาชิก ศัตรู HP1 จะไม่ตายจากการปัดเศษ และศพ HP0 ไม่คืนชีพ สูตรไม่คูณค่าที่สเกลแล้วซ้ำ

บอสเปิด proactive aggro ระยะ 360, โจมตีทุก 0.65 วินาที และ leash 600 ไม่ไล่ข้ามขอบเขตเกิดไม่สิ้นสุด ส่วนมอนสเตอร์ปกติยังโต้กลับตาม AI เดิม ตัวคูณ 2.5 เป็น HP/ATK; ความถี่โจมตีบอสเพิ่มความอันตรายอีกส่วนหนึ่ง

## Web export และการทดสอบ

เพิ่ม preset **Web** ใช้ Compatibility และ single-thread (`variant/thread_support=false`) แล้ว ติดตั้ง export templates ให้ตรง Godot ที่ใช้และ export เป็น `build/web/index.html` เสิร์ฟไฟล์ผ่าน HTTP/HTTPS พร้อมไฟล์ `.wasm`, `.pck`, `.js` ที่ Godot สร้าง ไม่เปิด `index.html` ด้วย file://

อ้างอิง: https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_web.html

ทดสอบด้วย Godot 4.4.1 headless:

```sh
godot --headless --editor --path . --import
godot --headless --path . res://tests/hybrid_progression_test.tscn
godot --headless --path . res://tests/pregame_flow_test.tscn
godot --headless --path . res://tests/single_world_test.tscn
```

ผลจริงอยู่ที่ `docs/HYBRID_PROGRESSION_RESULTS.json` และ `docs/test_logs/hybrid_progression/` ภาพสนาม/ท่าสกิล/หน้าสเตตัสมาจาก Compatibility renderer จริงใน `preview/hybrid_jogress/` สร้างซ้ำได้ด้วย `tools/hybrid_jogress_preview.tscn`

การทดสอบนี้ครอบคลุม input mapping, คำสั่งเมาส์/สัมผัส/คีย์บอร์ดจำลองใน engine, เลเวลรอยต่อ, สกิล, การรวม/แยกร่าง, การเซฟลงดิสก์แล้วเปิดใหม่, DS, การตายและ scaling ยังไม่ได้ export และทดสอบบนเบราว์เซอร์จริงหรืออุปกรณ์มือถือจริง และไม่ได้สร้าง APK
