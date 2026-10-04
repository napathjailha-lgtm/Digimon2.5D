> อัปเดต v19: คู่มือระบบนี้อ้างอิงรุ่นก่อน สกิลปัจจุบันใช้ `mp_cost` และหัก MP คู่หู ส่วน DS เป็นของ Tamer สำหรับเปลี่ยนร่าง/รักษาร่าง อ่าน `README_SURVIVAL_STATUS_TH.md` สำหรับ API และสเตตัสปัจจุบัน

# v9 — แอนิเมชันตามการเคลื่อนที่ และสกิลเฉพาะร่าง (Godot 4)

ต่อยอดจาก v8 ที่มี Story Quest, EXP/Level, คู่หูสลบเป็นไข่, Recover และคัตซีน Digivolve ใช้ Landscape 1280×720 / canvas_items / Compatibility เช่นเดิม

**สิ่งที่พร้อม:** Tamer เปลี่ยนเป็น AnimatedSprite2D; ทั้งสองตัวใช้ DirectionalAnimator เพื่อเลือก Idle/Walk/Attack, จำทิศล่าสุด และปรับ speed_scale จากความเร็วจริง; แต่ละร่างใช้ Resource สกิลและไอคอนคนละชุด; เปลี่ยนร่างแล้วสร้างปุ่มสกิลใหม่ทันที

**ข้อจำกัดภาพ:** ภาพเดิมเป็นภาพนิ่ง! Tamer มีภาพ 4 มุม แต่มุมละหนึ่งเฟรม; Partner มีภาพหนึ่งมุมต่อร่าง จึงใช้ fallback idle/walk/attack เดิม ระบบนี้ไม่ได้สร้างเฟรมขาก้าวจากภาพนิ่งให้เอง และยังไม่ใช่ชุดแอนิเมชันเดินสมบูรณ์ ต้องใส่ SpriteFrames ที่มีท่าก้าวจริงตามขั้นตอนด้านล่าง จึงเห็นการเดินที่ขาสลับกันและภาพ Partner ด้านหลังจริง

## 1. เปิดโปรเจกต์และทดลอง

1. แตก ZIP ไปโฟลเดอร์ใหม่ แล้ว Import `project.godot` ใน Godot 4.4+
2. กด F5: ลาก Joystick, แตะศัตรู, ใช้สกิล และแตะ Digivolve
3. Rookie มี Baby Flame และ Quick Bite; Champion มี Mega Flame, Heavy Claw, Flame Burst, Nova Fang; Ultimate และ Mega ใช้สกิลแยกทั้งหมด
4. แตะ Status เพื่อดู ATK ที่รวมโบนัสเลเวลแล้ว หากคู่หูแพ้ แตะ Recover เพื่อกลับ Rookie พร้อมชุดสกิล Rookie
5. เควสต์ยังปลดล็อกร่างเหมือน v8: Champion ใช้ได้ตั้งแต่เริ่ม, Ultimate หลัง Etemon, Mega หลัง Myotismon ทุกครั้งใช้ DS 25; ยังไม่มีเงื่อนไขเลเวลเปลี่ยนร่าง
6. ถ้ามี Save เดิมจะโหลดร่าง/เลเวลเดิม จึงอาจเริ่มที่ร่างอื่น ใช้โฟลเดอร์ user:// ใน Godot เพื่อสำรอง/ลบไฟล์ Save เมื่อต้องการเริ่มทดสอบใหม่

## 2. โครงสร้าง Node ที่ใช้งานจริง

เส้นทางในตารางหมายถึง Node ลูกของ Scene นั้น ๆ ไม่ต้องเพิ่ม CanvasLayer ซ้ำในตัวละคร

| Scene / เส้นทาง Node | Type | หน้าที่ / Script |
|---|---|---|
| Tamer | CharacterBody2D | `tamer.gd`: เดินและส่งคำสั่งให้คู่หู |
| Tamer/AnimatedSprite2D | AnimatedSprite2D | `data/tamer_frames.tres` |
| Tamer/DirectionalAnimator | Node | `directional_animator.gd`, ตั้ง sprite เป็น ../AnimatedSprite2D |
| Tamer/NavigationAgent2D | NavigationAgent2D | Auto-Navigation |
| Tamer/CollisionShape2D | CollisionShape2D | Collider ใต้เท้า |
| Tamer/Progress | Node | `character_progress.gd`: EXP และโบนัสเลเวล |
| Partner | CharacterBody2D | `partner_monster.gd`: AI/HP/DS/สกิล/เปลี่ยนร่าง |
| Partner/AnimatedSprite2D | AnimatedSprite2D | เปลี่ยน SpriteFrames ตาม MonsterData |
| Partner/DirectionalAnimator | Node | ตัวควบคุมภาพเดียวกับ Tamer |
| Partner/NavigationAgent2D | NavigationAgent2D | หาเส้นทางไปหา Tamer/ศัตรู |
| Partner/Progress | Node | เลเวลคู่หู |
| Partner/EggSprite | Sprite2D | แสดงไข่หลังแพ้ |
| MobileHUD | CanvasLayer | `mobile_hud.gd` |
| MobileHUD/Root | Control | Full Rect |
| MobileHUD/Root/Joystick | Control | MobileJoystick |
| MobileHUD/Root/Attack | Control | Main Attack |
| MobileHUD/Root/SkillPanel | Control | `form_skill_panel.gd`, Full Rect, Mouse Filter Ignore |
| MobileHUD/Root/SkillPanel/Skill0…3 | Control | สร้าง runtime ด้วย TouchCommand ตามจำนวนสกิลจริง |

ตั้ง Motion Mode ของ CharacterBody2D เป็น Floating เมื่อนำไปใช้ใน Scene ใหม่แบบ top-down และตั้ง collision layer/mask เหมือนตัวอย่าง

## 3. ใส่เฟรม Idle/Walk/Attack จริง

สำหรับ Tamer: เลือก AnimatedSprite2D → Sprite Frames → แก้ `tamer_frames.tres` หรือสร้าง Resource ใหม่
สำหรับคู่หู: เปิด `rookie.tres`, `champion.tres`, `ultimate.tres`, `mega.tres` แล้วกำหนด Sprite Frames ของแต่ละร่างคนละไฟล์

| ทิศ | Idle | Walk | Attack (ถ้ามี) |
|---|---|---|---|
| ลง | idle_down | walk_down | attack_down |
| ขวา | idle_right | walk_right | attack_right |
| ขึ้น | idle_up | walk_up | attack_up |
| ซ้าย | idle_left | walk_left | attack_left |

- Idle ใช้ 1–4 เฟรม; Walk ใช้ 4–8 เฟรมที่ขาซ้าย/ขวาสลับจริง เช่น contact → passing → contact อีกข้าง → passing
- เปิด Loop สำหรับ Idle/Walk; ปิด Loop สำหรับ Attack เพื่อให้ animation_finished ปลด lock
- Walk เริ่มที่ประมาณ 8 FPS แล้วปรับตามจังหวะก้าวในภาพ
- ตัดจาก SpriteSheet ด้วย Add Frames from a Sprite Sheet และใช้ขนาดช่องเท่ากันทุกเฟรม
- ให้ตำแหน่งเท้าและขนาดตัวละครคงที่ทุกเฟรม; อย่าครอปแต่ละเฟรมจนจุดเท้าเลื่อน ถ้ามีพื้นที่โปร่งใสใต้เท้าให้ปิด Align Feet ที่ DirectionalAnimator แล้วตั้ง sprite.offset ด้วยตนเอง
- หลังใส่ชุด 4 ทิศครบ ตั้ง MonsterData `idle_animation = idle_down`, `walk_animation = walk_down`, `attack_animation = attack_down` (ถ้ามีท่าโจมตี) และเปิด `require_directional_animations` ระบบจะตรวจ Idle/Walk ครบก่อนโหลด
- `idle_animation` ยังใช้แสดงรูปในคัตซีน จึงต้องชี้ไปแอนิเมชันที่มีเฟรมจริง
- ถ้ายังไม่มี Attack ใช้ชื่อ fallback เดิมที่มีอยู่ หรือปล่อยชื่อไม่มีเฟรม ระบบจะข้ามภาพโจมตี แต่ดาเมจยังลงตามปกติ
- ไม่ต้อง flip_h ในโค้ดเจ้าของ เมื่อมีท่าซ้ายจริง controller จะปิด flip_h เอง; ภาพเก่าที่ใช้ fallback จะกลับภาพเฉพาะเวลาหันซ้าย

**ตัวอย่างจังหวะก้าว:** ถ้าศิลปินวาด Walk 8 FPS สำหรับความเร็ว 240px/s ตั้ง animation_reference_speed = 240.0 เมื่อวิ่งจริง 120px/s จะเล่นด้วย speed_scale 0.5 หรือ 4 FPS ถ้าวิ่ง 300px/s จะเล่น 10 FPS อย่านำ move_speed ที่รวมโบนัสเลเวลมาเป็นค่าอ้างอิงใหม่ทุกครั้ง เพราะจะทำให้วิ่งเร็วขึ้นแต่จังหวะขาเท่าเดิม

การปรับ FPS ลดการลื่นได้เมื่อภาพมีระยะก้าวที่เหมาะสมด้วย ความเร็วภาพอย่างเดียวไม่สามารถทำให้ภาพนิ่งมีขาก้าวได้

## 4. การควบคุมทิศทางและความเร็ว

ใน `_physics_process` ของ Tamer หลังคำนวณการเคลื่อนที่:

```gdscript
# เดินได้ 360 องศา แต่เลือกภาพแสดงผลเป็น 4 ทิศ
velocity = joystick.move_vector.limit_length(1.0) * move_speed
move_and_slide()
# ใช้ความเร็วหลังแก้ collision จริง ไม่ใช้ joystick เพื่อเล่น Walk
animator.update_motion(get_real_velocity(), animation_reference_speed)
```

ในคู่หู หลัง State Machine/Navigation ตั้ง velocity แล้ว:

```gdscript
move_and_slide()
animator.update_motion(
    get_real_velocity(),
    current_form.animation_reference_speed,
    current_form.idle_animation,
    current_form.walk_animation
)
```

โค้ดตัวอย่างในไฟล์จริงมีเงื่อนไขกันทับ Attack และงดอัปเดตภาพคู่หูตอน Fainted/Egg รวมถึงหยุดสนามตอนคัตซีนแล้ว ไม่ต้องเขียน `_physics_process` อีกฟังก์ชันซ้อนใน Script เดิม

| ฟังก์ชัน DirectionalAnimator | พฤติกรรม |
|---|---|
| `_ready()` | เชื่อมสัญญาณเฟรมเปลี่ยนและแอนิเมชันจบ |
| `face_direction()` | เลือกแกนเด่นและจำทิศล่าสุด มี hysteresis 1.15 ลดสลับทิศตอนเฉียง |
| `update_motion()` | ความเร็วเกิน 2px/s เป็น Walk, ต่ำกว่านั้น Idle; คำนวณ speed_scale และเก็บเฟรมก้าวเมื่อเปลี่ยนทิศ |
| `resolve_animation()` | ลองชื่อ 4 ทิศก่อนแล้วค่อยใช้ fallback จากข้อมูลร่าง |
| `play_attack()` | หันหาเป้าหมาย, speed_scale = 1, เล่น Attack แบบไม่ Loop และล็อกไม่ให้ Walk ทับ |
| `reset_actions()` | ล้าง lock ของท่าเก่าหลังเปลี่ยนร่าง/สลบ |
| `_has_frames()` | ตรวจชื่อและจำนวนเฟรมก่อนเล่น |
| `_align_feet()` | จัดขอบล่างภาพไว้ที่จุดเท้า สำหรับภาพครอปที่ไม่มีขอบโปร่งใสใต้เท้า |
| `_on_animation_finished()` | ปลด lock หลัง Attack แล้วเจ้าของจะเลือก Idle/Walk ในเฟรมถัดไป |

## 5. Resource สกิลและข้อมูลร่าง

`MonsterSkill` ใน `skill_data.gd` มี ID, ชื่อ, icon, multiplier, cast_range, cooldown, ds_cost, impact_radius, effect_color และ effect_size

`MonsterData.attack` คือ Base ATK ของร่าง ส่วน `PartnerMonster.attack_power` คือ ATK ปัจจุบันที่รวมโบนัสเลเวลจาก CharacterProgress เลือกค่านี้ในการสร้างดาเมจ เพื่อให้เลเวลมีผลต่อสกิล ไม่มีการแก้ค่าต้นแบบ Resource

**สร้างสกิลใหม่ใน Inspector:** FileSystem → New Resource → MonsterSkill → Save เช่น `data/baby_flame.tres` ตั้ง ID ไม่ซ้ำ, Icon เป็น Texture2D, Multiplier 1.2, Cooldown 3, DS Cost 5 และ Cast Range 180 จากนั้นลาก Resource เข้า MonsterData.skills

ไฟล์ตัวอย่างจริงยังคงชื่อ `rookie_strike.tres` เพื่อให้ Scene เก่าอ้างอิงได้ แต่ ID/ชื่อภายในเปลี่ยนเป็น Baby Flame แล้ว ใช้ ID ภายในเพื่อเก็บคูลดาวน์ ไม่ใช้ชื่อไฟล์

| ร่าง | Base ATK Lv1 | สกิล 1 | Multiplier | CD | ระเบิดรอบเป้าหมาย |
|---|---:|---|---:|---:|---:|
| Rookie | 15 | Baby Flame | 1.2 | 3s | 0px (เป้าหมายเดียว) |
| Champion | 30 | Mega Flame | 2.5 | 6s | 90px |
| Ultimate | 50 | Solar Lance | 3.0 | 5s | 0px |
| Mega | 75 | Astral Cannon | 4.0 | 6s | 120px |

ชื่อ Baby/Mega Flame ใช้ตามตัวอย่างที่ร้องขอ ส่วนตัวละครและไอคอนในโปรเจกต์เป็นภาพต้นฉบับของตัวอย่าง ไม่ใช่ไฟล์ภาพที่ดึงจากเกม DMO

สูตรใน `MonsterSkill.roll_damage()`:

```gdscript
# +/-5% ของผลคูณทั้งหมด; 100 * 2.5 * สุ่ม(0.95, 1.05)
return maxi(1, int(round(
    float(base_attack) * multiplier * rng.randf_range(0.95, 1.05)
)))
```

ATK 0 จะคืน 0 ก่อนสูตรนี้ ส่วนผลที่มากกว่า 0 ปัดเป็น int ท้ายสุด เช่น ATK 100 / multiplier 2.5 ให้ค่าประมาณ 238–263 เพราะการปัดจำนวนเต็ม

| ฟังก์ชัน | หน้าที่ |
|---|---|
| `MonsterSkill.validation_error()` | ปฏิเสธ ID ว่าง/ตัวเลขไม่ถูกต้องก่อนใช้ Resource |
| `MonsterSkill.roll_damage()` | คำนวณดาเมจจาก ATK ปัจจุบันและ RNG ของคู่หู |
| `PartnerMonster._try_skill()` | ตรวจสถานะ/ช่อง/ระยะ/ผนัง/CD/DS ก่อนหัก DS และตั้ง CD ครั้งเดียว |
| `PartnerMonster._apply_skill_hit()` | เก็บตำแหน่งและเหยื่อก่อนโจมตี, สุ่มดาเมจหนึ่งครั้งต่อ cast, ตีทุกตัวในวงที่ไม่มีผนังกั้น และสร้างภาพระเบิด |
| `PartnerMonster.cooldown_remaining()` | อ่าน CD จาก Dictionary ของตัวละคร |
| `PartnerMonster.load_monster_data()` | เปลี่ยนฐานสเตตัส, คำนวณโบนัสเลเวลใหม่, สลับภาพและชุดสกิล, รักษาสัดส่วน HP และส่ง Signal |

**ขอบเขตการต่อสู้ในตัวอย่าง:** สกิลทำดาเมจทันทีเมื่อถึงระยะ จากนั้นแสดงวงระเบิดสีต่างกัน ยังไม่ใช่ลูกไฟเดินทางและชนเป้าหมายจริง หากเพิ่ม projectile ให้ย้ายการเรียก take_damage ไปจุดที่ projectile ชนเพื่อไม่ให้ดาเมจลงซ้ำทั้งตอน cast และตอนชน

## 6. เปลี่ยนร่างแล้วอัปเดตปุ่มสกิล

Partner ประกาศ:

```gdscript
signal skills_changed(skills: Array[MonsterSkill])
```

ใน `load_monster_data()` หลังอัปเดตสเตตัสและภาพครบ:

```gdscript
# คัดลอกเฉพาะ Array ไม่แก้ชุดต้นแบบ และไม่เก็บ CD ใน Resource
active_skills.assign(data.skills)
# ...สลับภาพ / ตั้งค่าสเตตัส / ล้าง pending skill ของร่างเก่า...
var skill_snapshot: Array[MonsterSkill] = []
skill_snapshot.assign(active_skills)
skills_changed.emit(skill_snapshot)
form_changed.emit(data)
```

ใน HUD เรียกเพียงครั้งเดียว:

```gdscript
skill_panel.configure(partner, tamer)
skill_panel.skill_requested.connect(tamer.command_skill)
```

| ฟังก์ชัน FormSkillPanel | หน้าที่ |
|---|---|
| `configure()` | ตัดการเชื่อมกับคู่หูเก่า, เชื่อม skills_changed และโหลดชุดปัจจุบันทันที |
| `rebuild()` | ปล่อยนิ้วบนปุ่มเก่า, remove_child เพื่อหยุดรับ input ทันที, queue_free, สร้างสูงสุด 4 ปุ่ม พร้อมไอคอนและชื่อใหม่ |
| `_process()` / `_refresh_buttons()` | อ่าน CD และ DS เพื่อปิดปุ่ม แสดงตัวเลข CD โดยไม่แก้ Resource |
| `_request_slot()` | ตรวจ ID ให้ตรงกับร่างปัจจุบัน แล้วส่ง slot ให้ Tamer ป้องกัน callback ของปุ่มเก่า |
| `release_input()` | เคลียร์นิ้วก่อนเปิดคัตซีน เช่นเดียวกับ Joystick/Main Attack |

ปุ่มจัดตาม SLOT_OFFSETS รอบปุ่มโจมตีหลัก ทั้ง SkillPanel และปุ่มอ้างอิงมุมขวาล่าง จึงย้ายตามหน้าจอ Landscape ที่กว้างขึ้น Resource แต่ละร่างควรมีสกิลไม่เกิน 4 รายการ หากเพิ่มเกินนั้นต้องออกแบบหน้า/แผงเพิ่มเติม

คูลดาวน์เก็บตาม skill.id ต่อ instance ไม่ล้างเมื่อ Digivolve/DS หมด เพื่อป้องกันสลับร่างกลับมาล้าง CD; Recover ยังล้าง CD ตามกติกา v8 ทุก ID ในสาย Rookie→Mega ของตัวอย่างไม่ซ้ำกัน

## 7. นำเฉพาะระบบไปใส่โปรเจกต์เดิม

1. เพิ่ม `directional_animator.gd`, `form_skill_panel.gd`, `skill_impact.gd` และอัปเดต `skill_data.gd` / `monster_data.gd`
2. เพิ่ม Node DirectionalAnimator ใต้ทั้งสอง CharacterBody2D และลาก AnimatedSprite2D เข้า exported sprite
3. Tamer เปลี่ยน Sprite2D เป็น AnimatedSprite2D และอัปเดต NodePath เดิมทุกจุด
4. Resource สกิลเก่าที่ใช้ `damage` ต้องเปลี่ยนเป็น `multiplier` ตัวอย่าง v9 แปลงทุกไฟล์ให้แล้ว ค่าต่อสู้ใหม่อิงสัดส่วน ATK จึงเปลี่ยน balance จาก v8
5. MonsterData เพิ่ม animation_reference_speed และ require_directional_animations ตามความพร้อมของภาพ
6. Partner เพิ่ม Signal skills_changed, เรียกตัวควบคุมภาพหลัง move_and_slide, เปลี่ยน `_try_skill` ให้เรียก `_apply_skill_hit` และส่ง Signal เมื่อโหลดร่างเสร็จ
7. HUD ลบ Skill0–3 ที่เป็น Node เก่า เพิ่ม SkillPanel Control Full Rect แล้ว configure และเชื่อม Signal แค่ครั้งเดียว ไม่ต้องเชื่อมปุ่มชุดเดิมซ้ำ
8. ถ้าไม่ใช้ตัวอย่างเต็ม ให้ปรับการอ้างอิง QuestManager, WildMonster, Tamer, CharacterProgress ให้ตรงคลาสและกติกาของโปรเจกต์คุณ Script Partner/Tamer/HUD ฉบับนี้อ้างอิงระบบ v8 ครบ จึงไม่ใช่ไฟล์เดี่ยวที่วางในโปรเจกต์ว่างแล้วรันได้ทันที

## 8. ผลทดสอบและเอกสารอ้างอิง

ทดสอบบน Godot 4.4.1 แบบ headless:

- `form_skills_animation_test.tscn`: 4 ทิศ, Idle จำทิศ, gait phase, speed_scale, Attack lock, ชนกำแพงแล้ว Idle, ID/ไอคอนแยกร่าง, สัมผัสปุ่มใหม่, callback เก่าถูกปฏิเสธ, ATK รวมเลเวล, +/-5%, AoE, CD/DS ครั้งเดียว และ Recover คืนชุด Rookie
- `recovery_progress_cutscene_test.tscn`: ไข่/ฟื้น/EXP/คัตซีน/pause/DS/Save
- `smoke_test.tscn`: Joystick/Target/Follow/Battle/Skills/DS
- `story_quest_test.tscn`: เควสต์/ประตู/ปลดล็อกร่าง/เปลี่ยนโซน
- `art_integration_test.tscn`: ภาพทิศและ origin เท้า/แตะตัวศัตรูและ NPC
- `damage_popup_test.tscn` และ `spawner_test.tscn`: Popup และ Respawn

รันทีละ Scene ด้วย `godot --headless --path <project-folder> res://tests/form_skills_animation_test.tscn` ผลสุดท้ายต้องเป็น `RESULT: 0 failure(s)` การทดสอบนี้ยืนยัน logic ไม่ได้ยืนยันเฟรมขาก้าวที่ยังไม่มีหรือ FPS ของเครื่อง Android จริง

เอกสารทางการ:

- https://docs.godotengine.org/en/4.4/classes/class_characterbody2d.html — get_real_velocity() หลัง move_and_slide()
- https://docs.godotengine.org/en/4.4/classes/class_animatedsprite2d.html — speed_scale, animation_finished และ set_frame_and_progress()

## 9. โค้ด component ฉบับเต็ม

ไฟล์ต่อไปนี้มีคอมเมนต์ภาษาไทย ใช้คู่กับ Node ตามตารางด้านบน Script Resource ไม่ต้อง attach ลง Node

### directional_animator.gd

```gdscript
class_name DirectionalAnimator
extends Node
## Component ภาพเท่านั้น ไม่แก้ velocity หรือ State ของเจ้าของ
## เรียก update_motion() หลัง move_and_slide() โดยส่ง get_real_velocity()
@export var sprite: AnimatedSprite2D
@export_range(0.1, 20.0) var idle_threshold: float = 2.0
@export_range(1.0, 2.0) var direction_bias: float = 1.15
@export var align_feet: bool = true
var facing: StringName = &"down"
var action_locked: bool = false

func _ready() -> void:
    # Attack ปิด Loop จึงส่ง animation_finished แล้วกลับไป Idle/Walk ได้
    if is_instance_valid(sprite):
        sprite.animation_finished.connect(_on_animation_finished)
        sprite.frame_changed.connect(_align_feet)

func face_direction(direction: Vector2) -> void:
    # จำทิศล่าสุดเมื่อหยุด และมี hysteresis ลดการสลับทิศรัวที่มุม 45 องศา
    if direction.length_squared() < 0.0001:
        return
    var horizontal: bool = facing in [&"left", &"right"]
    var ax: float = absf(direction.x)
    var ay: float = absf(direction.y)
    if ax > ay * direction_bias:
        horizontal = true
    elif ay > ax * direction_bias:
        horizontal = false
    facing = (&"right" if direction.x > 0.0 else &"left") if horizontal else (&"down" if direction.y > 0.0 else &"up")

func update_motion(real_velocity: Vector2, reference_speed: float,
        idle_fallback: StringName = &"idle", walk_fallback: StringName = &"walk") -> void:
    # ชนกำแพงแล้วความเร็วจริงเป็น 0 แม้ Joystick ยังชี้ไปข้างหน้า
    if not is_instance_valid(sprite) or sprite.sprite_frames == null or action_locked:
        return
    var actual_speed: float = real_velocity.length()
    var walking: bool = actual_speed > idle_threshold
    if walking:
        face_direction(real_velocity)
    var prefix: String = "walk" if walking else "idle"
    var fallback: StringName = walk_fallback if walking else idle_fallback
    var animation: StringName = resolve_animation(prefix, fallback)
    if animation == &"":
        return
    # 8 FPS ที่วาดสำหรับ 240px/s: วิ่ง 120px/s จะเล่น 4 FPS
    sprite.speed_scale = actual_speed / maxf(1.0, reference_speed) if walking else 1.0
    var keep_gait: bool = walking and String(sprite.animation).begins_with("walk")
    var old_frame: int = sprite.frame
    var old_progress: float = sprite.frame_progress
    if sprite.animation != animation:
        sprite.play(animation)
        if keep_gait:
            var count: int = sprite.sprite_frames.get_frame_count(animation)
            sprite.set_frame_and_progress(mini(old_frame, count - 1), old_progress)
    elif not sprite.is_playing():
        sprite.play(animation)
    _align_feet()

func resolve_animation(prefix: String, fallback: StringName) -> StringName:
    # ชอบชื่อ 4 ทิศก่อน; ภาพเก่าไม่ครบใช้ชื่อเดิมเพื่อให้โปรเจกต์ยังเปิดได้
    var directional := StringName(prefix + "_" + String(facing))
    if _has_frames(directional):
        sprite.flip_h = false # มีท่าซ้ายจริงแล้ว ห้ามกลับภาพซ้ำ
        return directional
    if _has_frames(fallback):
        sprite.flip_h = facing == &"left"
        return fallback
    return &""

func play_attack(direction: Vector2, fallback: StringName = &"attack") -> bool:
    # ล็อกท่า Attack ไม่ให้ Walk ทับ และใช้ความเร็วปกติเสมอ
    if not is_instance_valid(sprite) or sprite.sprite_frames == null:
        return false
    face_direction(direction)
    var animation: StringName = resolve_animation("attack", fallback)
    if animation == &"" or sprite.sprite_frames.get_animation_loop(animation):
        return false
    action_locked = true
    sprite.speed_scale = 1.0
    sprite.stop()
    sprite.play(animation)
    _align_feet()
    return true

func reset_actions() -> void:
    # เปลี่ยนร่าง/สลบต้องล้าง lock ของชุดภาพเก่า
    action_locked = false
    if is_instance_valid(sprite):
        sprite.speed_scale = 1.0

func _has_frames(animation: StringName) -> bool:
    # ตรวจทั้งชื่อและจำนวนเฟรมก่อน play เพื่อไม่ให้เกิด error จาก Resource ว่าง
    return is_instance_valid(sprite) and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation) and sprite.sprite_frames.get_frame_count(animation) > 0

func _align_feet() -> void:
    # ปิด align_feet หากเฟรมมีพื้นที่โปร่งใสใต้เท้า แล้วตั้ง offset เอง
    if not align_feet or not is_instance_valid(sprite) or not _has_frames(sprite.animation):
        return
    var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
    if texture != null:
        sprite.offset.y = -texture.get_height() * 0.5

func _on_animation_finished() -> void:
    # เจ้าของอัปเดต Idle/Walk อีกครั้งใน physics frame ถัดไป
    action_locked = false
```

### skill_data.gd

```gdscript
class_name MonsterSkill
extends Resource
## ข้อมูลต้นแบบสกิล: คูลดาวน์และเป้าหมายเก็บในคู่หู ไม่แก้ Resource ร่วมกัน

@export var id: StringName = &"strike"
@export var display_name: String = "Strike"
@export var icon: Texture2D
@export_range(0.01, 20.0) var multiplier: float = 1.2
@export_range(1.0, 1000.0) var cast_range: float = 90.0
@export_range(0.1, 60.0) var cooldown: float = 3.0
@export_range(0.0, 100.0) var ds_cost: float = 5.0
## 0 = เป้าหมายเดียว; มากกว่า 0 = ระเบิดรอบตำแหน่งเป้าหมาย
@export_range(0.0, 500.0) var impact_radius: float = 0.0
@export var effect_color: Color = Color(1.0, 0.45, 0.1)
@export_range(4.0, 100.0) var effect_size: float = 12.0

func validation_error() -> String:
    # ตรวจ runtime ด้วย เพราะแก้ .tres ด้วยมือข้ามข้อจำกัด Inspector ได้
    if id == &"" or display_name.strip_edges().is_empty():
        return "สกิลต้องมี ID และชื่อ"
    if not is_finite(multiplier) or multiplier <= 0.0:
        return "Multiplier ต้องเป็นจำนวนบวก"
    if not is_finite(cast_range) or cast_range <= 0.0 or not is_finite(cooldown) or cooldown <= 0.0:
        return "ระยะและคูลดาวน์ต้องมากกว่า 0"
    if not is_finite(ds_cost) or ds_cost < 0.0 or not is_finite(impact_radius) or impact_radius < 0.0:
        return "DS และรัศมีต้องไม่ติดลบ"
    if not is_finite(effect_size) or effect_size <= 0.0:
        return "ขนาดเอฟเฟกต์ต้องมากกว่า 0"
    return ""

func roll_damage(base_attack: int, rng: RandomNumberGenerator) -> int:
    # แกว่ง +/-5% ของผลคูณทั้งหมด และปัดเป็นจำนวนเต็มท้ายสุด
    if base_attack <= 0:
        return 0
    return maxi(1, int(round(float(base_attack) * multiplier * rng.randf_range(0.95, 1.05))))
```

### monster_data.gd

```gdscript
class_name MonsterData
extends Resource
## Template ข้อมูลแต่ละร่าง: สร้าง .tres แยก Rookie / Champion / Ultimate / Mega
## Resource เป็นข้อมูลต้นแบบที่หลายตัวอ่านร่วมกัน ห้ามเก็บ HP ปัจจุบันที่นี่

enum EvolutionStage { ROOKIE, CHAMPION, ULTIMATE, MEGA }

@export_group("ข้อมูลมอนสเตอร์")
@export var id: StringName = &"rookie"
@export var monster_name: String = "Rookie"
@export var evolution_stage: EvolutionStage = EvolutionStage.ROOKIE
# ว่าง = ใช้ระดับร่างอย่างเดียว; เช่น Angemon กำหนด &"angemon"
@export var required_story_flag: StringName = &""

@export_group("สเตตัสพื้นฐาน")
@export_range(1, 99999) var max_hp: int = 120
## ATK ฐานของร่างนี้; CharacterProgress บวกโบนัสเลเวลให้เป็น attack_power
@export_range(0, 99999) var attack: int = 15
@export_range(1.0, 1000.0) var move_speed: float = 240.0
@export_range(1.0, 1000.0) var attack_range: float = 58.0
@export_range(0.1, 10.0) var attack_interval: float = 0.8

@export_group("ภาพและแอนิเมชัน")
# SpriteFrames เก็บเฟรมที่ตัดจาก SpriteSheet หรือรูป PNG แยกเฟรมได้
@export var sprite_frames: SpriteFrames
@export var sprite_scale: Vector2 = Vector2.ONE
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
## ความเร็วสนามที่ศิลปินใช้วาดจังหวะเดิน ไม่ใช่ความเร็วหลังโบนัสเลเวล
@export_range(1.0, 1000.0) var animation_reference_speed: float = 240.0
## เปิดเมื่อใส่เฟรมจริงครบแล้ว เพื่อป้องกันโหลดร่างที่ขาดแอนิเมชัน 4 ทิศ
@export var require_directional_animations: bool = false

@export_group("สกิลและค่า DS")
@export var skills: Array[MonsterSkill] = []
@export_range(0.0, 1000.0) var evolution_cost: float = 0.0
@export_range(0.0, 100.0) var ds_drain_per_second: float = 0.0

func validation_error() -> String:
    # ตรวจด้วยก่อนใช้จริง เพราะค่าอาจมาจากโค้ดหรือไฟล์ที่แก้มือ
    if id == &"" or monster_name.strip_edges().is_empty():
        return "ต้องกำหนด id และชื่อมอนสเตอร์"
    if max_hp < 1 or attack < 0 or move_speed <= 0.0:
        return "HP/ความเร็วต้องมากกว่า 0 และ Attack ต้องไม่ติดลบ"
    if attack_range <= 0.0 or attack_interval <= 0.0:
        return "ระยะโจมตีและช่วงเวลาโจมตีต้องมากกว่า 0"
    if evolution_cost < 0.0 or ds_drain_per_second < 0.0:
        return "ค่า DS ต้องไม่ติดลบ"
    if sprite_scale.x <= 0.0 or sprite_scale.y <= 0.0:
        return "ขนาด Sprite ต้องมากกว่า 0"
    if sprite_frames == null:
        return "ต้องกำหนด SpriteFrames"
    if not sprite_frames.has_animation(idle_animation):
        return "ไม่มีแอนิเมชัน Idle ที่กำหนด"
    if sprite_frames.get_frame_count(idle_animation) == 0:
        return "แอนิเมชัน Idle ต้องมีอย่างน้อยหนึ่งเฟรม"
    if not is_finite(animation_reference_speed) or animation_reference_speed <= 0.0:
        return "ความเร็วอ้างอิงแอนิเมชันต้องมากกว่า 0"
    if require_directional_animations:
        for direction: String in ["down", "right", "up", "left"]:
            for prefix: String in ["idle", "walk"]:
                var key := StringName(prefix + "_" + direction)
                if not sprite_frames.has_animation(key) or sprite_frames.get_frame_count(key) == 0:
                    return "ขาดแอนิเมชัน " + String(key)
    var ids: Array[StringName] = []
    for skill: MonsterSkill in skills:
        if skill == null or skill.id == &"":
            return "สกิลต้องไม่เป็น null และต้องมี id"
        if skill.id in ids:
            return "id สกิลซ้ำในร่างเดียวกัน"
        var skill_error: String = skill.validation_error()
        if not skill_error.is_empty():
            return skill_error
        ids.append(skill.id)
    return ""
```

### form_skill_panel.gd

```gdscript
class_name FormSkillPanel
extends Control
## ถอดปุ่มเก่าออกทันที แล้วสร้างปุ่มใหม่จาก Resource ของร่าง
signal skill_requested(slot: int)
@export var partner: PartnerMonster
@export var tamer: Tamer
var buttons: Array[TouchCommand] = []
const BUTTON_SIZE := Vector2(86, 86)
# ตำแหน่งสัมพันธ์กับมุมขวาล่าง ล้อมด้านบน/ซ้ายของ Main Attack
const SLOT_OFFSETS: Array[Vector2] = [Vector2(-300, -154), Vector2(-280, -248), Vector2(-182, -294), Vector2(-87, -255)]

func configure(owner_partner: PartnerMonster, owner_tamer: Tamer) -> void:
    # รองรับสลับคู่หูภายหลัง: ตัดการเชื่อมกับตัวเก่าก่อน
    if is_instance_valid(partner) and partner.skills_changed.is_connected(rebuild):
        partner.skills_changed.disconnect(rebuild)
    partner = owner_partner
    tamer = owner_tamer
    if is_instance_valid(partner):
        partner.skills_changed.connect(rebuild)
        rebuild(partner.active_skills) # Signal โหลด Save อาจเกิดก่อน UI พร้อม

func rebuild(skills: Array[MonsterSkill]) -> void:
    # ล้างนิ้วและรูปเก่า โดยไม่ล้างคูลดาวน์ของคู่หู
    for button: TouchCommand in buttons:
        button.release_input()
        remove_child(button) # หยุดรับ _input ระหว่างรอ queue_free ท้ายเฟรม
        button.queue_free()
    buttons.clear()
    for slot: int in range(mini(4, skills.size())):
        var skill: MonsterSkill = skills[slot]
        if skill == null:
            continue
        var button := TouchCommand.new()
        button.name = "Skill%d" % slot
        button.anchor_left = 1.0
        button.anchor_top = 1.0
        button.anchor_right = 1.0
        button.anchor_bottom = 1.0
        button.offset_left = SLOT_OFFSETS[slot].x
        button.offset_top = SLOT_OFFSETS[slot].y
        button.offset_right = button.offset_left + BUTTON_SIZE.x
        button.offset_bottom = button.offset_top + BUTTON_SIZE.y
        button.icon = skill.icon
        button.caption = skill.display_name
        button.tint = skill.effect_color.darkened(0.55)
        button.pressed.connect(_request_slot.bind(slot, skill.id))
        add_child(button)
        buttons.append(button)
    _refresh_buttons()

func _process(_delta: float) -> void:
    # อ่านคูลดาวน์ของ instance ไม่เขียนกลับ Resource
    _refresh_buttons()

func _refresh_buttons() -> void:
    if not is_instance_valid(partner) or not is_instance_valid(tamer):
        return
    for index: int in range(buttons.size()):
        var button: TouchCommand = buttons[index]
        # หากระบบอื่นแก้ Array ชั่วคราว ให้ปิดปุ่มก่อนรอ Signal ชุดใหม่
        if index >= partner.active_skills.size() or partner.active_skills[index] == null:
            button.locked = true
            continue
        var skill: MonsterSkill = partner.active_skills[index]
        var remaining: float = partner.cooldown_remaining(skill)
        button.locked = partner.evolution_busy or not partner.is_alive() or remaining > 0.0 or tamer.ds < skill.ds_cost
        button.set_caption("%.1fs" % remaining if remaining > 0.0 else skill.display_name)

func _request_slot(slot: int, expected_id: StringName) -> void:
    # ตรวจ ID ป้องกัน callback ชุดเก่าสั่งสกิลร่างใหม่ผิดช่อง
    if not is_instance_valid(partner) or slot < 0 or slot >= partner.active_skills.size():
        return
    if partner.active_skills[slot].id == expected_id:
        skill_requested.emit(slot)

func release_input() -> void:
    # HUD เรียกก่อนคัตซีน เพื่อไม่ให้นิ้วค้างหลัง Resume
    for button: TouchCommand in buttons:
        button.release_input()
```

### skill_impact.gd

```gdscript
extends Node2D
## เอฟเฟกต์เบาใช้กับ Compatibility บนมือถือได้
## ดาเมจลงทันทีเมื่อ cast สำเร็จ ภาพนี้ไม่ใช่ projectile ฟิสิกส์
var color: Color = Color.ORANGE
var radius: float = 12.0
var expansion: float = 0.2:
    set(value):
        expansion = value
        queue_redraw()

func _ready() -> void:
    # อยู่ในโลกจึงหยุดตามคัตซีน และลบตัวเองหลังเอฟเฟกต์จบ
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(self, "expansion", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 0.28)
    tween.chain().tween_callback(queue_free)

func _draw() -> void:
    draw_circle(Vector2.ZERO, radius * expansion, Color(color, 0.35))
    draw_arc(Vector2.ZERO, radius * expansion, 0.0, TAU, 32, color, 3.0)
```
