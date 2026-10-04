> อัปเดต v19: คู่มือระบบนี้อ้างอิงรุ่นก่อน สกิลปัจจุบันใช้ `mp_cost` และหัก MP คู่หู ส่วน DS เป็นของ Tamer สำหรับเปลี่ยนร่าง/รักษาร่าง อ่าน `README_SURVIVAL_STATUS_TH.md` สำหรับ API และสเตตัสปัจจุบัน

> เวอร์ชันปัจจุบัน v10: อ่าน README_CLASSIC_HUD_TH.md สำหรับกรอบเลือด แชต และ Minimap ใหม่ ระบบแชตยังเป็นการทดสอบในเครื่อง

> เวอร์ชันปัจจุบัน v9: อ่าน README_FORM_SKILLS_ANIMATION_TH.md สำหรับแอนิเมชัน 4 ทิศ สกิลเฉพาะร่าง และ UI ใหม่ คู่มือด้านล่างเป็นประวัติระบบฐานข้อมูลรุ่นก่อน ค่า damage ของสกิลเปลี่ยนเป็น multiplier แล้ว

> เวอร์ชันนี้เป็น v8 อ่าน README_RECOVERY_LEVEL_CUTSCENE_TH.md สำหรับระบบคู่หูเป็นไข่ เลเวล และคัตซีนล่าสุด

> โปรเจกต์นี้เป็น v7 พร้อมภาพเกม อ่าน README_ART_TH.md สำหรับภาพและการเปิดเล่นล่าสุด

> คู่มือระบบก่อนหน้า: โปรเจกต์ v6 เพิ่ม Story Quest อ่าน README_STORY_QUESTS_TH.md สำหรับขั้นตอนเปิดและใช้งานล่าสุด

# MonsterData / Custom Resource — Godot 4

โปรเจกต์นี้ต่อยอด Tamer + Partner + MobileJoystick รุ่น v2 เป็นฐานข้อมูลมอนสเตอร์แบบไฟล์ .tres
ทดสอบด้วย Godot 4.4.1 ตัวโปรเจกต์ใช้ Top-Down, Landscape 1280×720, canvas_items และ Compatibility

## ทดลองโปรเจกต์

แตก ZIP เป็นโฟลเดอร์ใหม่ → Godot Project Manager → Import project.godot → กด F5
ยังมี Joystick, Target Lock, Attack, สกิล, Auto และปุ่ม Digivolve เหมือนรุ่นเดิม
ชื่อ Custom Joystick ยังคงเป็น MobileJoystick เพื่อไม่ชนคลาส VirtualJoystick ของ Godot รุ่นใหม่

## หลักการข้อมูล

| ส่วน | เก็บอะไร | ตัวอย่าง |
|---|---|---|
| MonsterData | ข้อมูลต้นแบบหนึ่งร่าง | rookie.tres |
| MonsterSkill | ข้อมูลต้นแบบหนึ่งสกิล | rookie_strike.tres |
| SpriteFrames | เฟรมและรายชื่อแอนิเมชัน | rookie_frames.tres |
| MonsterDatabase | รายการมอนสเตอร์ ค้นด้วย id | monster_database.tres |
| PartnerMonster | HP ปัจจุบัน, คูลดาวน์, State, Target และค่าสเตตัสระหว่างเล่น | Partner ใน Scene |

Resource หลายตัวละครอาจใช้ไฟล์เดียวกันและเป็น object เดียวกันในหน่วยความจำ
ไม่เก็บ current_hp หรือ cooldown_remaining ใน MonsterData/MonsterSkill
load_monster_data คัดลอกสเตตัสมาใช้ และคัดลอก Array รายการสกิลด้วย assign()
แต่ยังอ่านข้อมูล Resource ของสกิลและ SpriteFrames ร่วมกันได้ เพราะไม่แก้ต้นแบบระหว่างเล่น
หากจะปรับค่าระดับสกิลเฉพาะตัว ควรมีข้อมูล instance แยก หรือ duplicate Resource ก่อนแก้

## ไฟล์สำคัญ

- scripts/monster_data.gd — Template สเตตัสและรูปร่าง
- scripts/skill_data.gd — MonsterSkill เดิม ใช้ต่อได้ ไม่ต้องสร้าง class ซ้ำ
- scripts/monster_database.gd — แค็ตตาล็อกค้น id
- scripts/partner_monster.gd — AI เดิม + load_monster_data + AnimatedSprite2D
- scripts/mobile_hud.gd — รับ MonsterData และแสดง active_skills
- scenes/partner.tscn — เปลี่ยน Sprite2D เป็น AnimatedSprite2D แล้ว
- data/rookie.tres และ champion.tres — MonsterData ตัวอย่าง
- data/rookie_frames.tres และ champion_frames.tres — SpriteFrames ตัวอย่าง
- data/monster_database.tres — รวมข้อมูลสองร่าง

## สร้าง MonsterData ใน Editor

1. วาง monster_data.gd และ skill_data.gd ใน scripts/ แล้วบันทึกให้ Godot ลงทะเบียน class_name
2. FileSystem → คลิกขวาโฟลเดอร์ data → Create New → Resource
3. ค้นหา MonsterData แล้วบันทึกเป็น เช่น flame_cub_rookie.tres
4. กำหนด id ให้ไม่ซ้ำในฐานข้อมูล, monster_name และ evolution_stage
5. กำหนด max_hp, attack, move_speed, attack_range, attack_interval
6. สร้าง SpriteFrames แล้วใส่ใน sprite_frames
7. กำหนด sprite_scale และชื่อ animation ให้ตรงกับ SpriteFrames
8. เพิ่ม MonsterSkill Resources ใน skills; HUD เดโมแสดงได้สูงสุด 4 ปุ่ม
9. ตั้ง evolution_cost และ ds_drain_per_second ตามร่าง

EvolutionStage มี ROOKIE / CHAMPION / ULTIMATE / MEGA
เพิ่ม enum ค่าอื่นได้ แต่ไฟล์ .tres เก็บค่าตัวเลข จึงควรเพิ่มต่อท้ายแทนเปลี่ยนลำดับค่าเดิม
Stage เป็นข้อมูลประเภทของร่าง การเปลี่ยนร่างจริงใช้ลำดับใน Partner.forms
อย่าจัดเรียง forms อัตโนมัติด้วย Stage เพราะหลายสายพันธุ์มีหลายร่างใน Stage เดียวกันได้

## สร้าง SpriteFrames จาก SpriteSheet

Partner Scene ใช้ AnimatedSprite2D ลูกชื่อ AnimatedSprite2D

1. เลือก AnimatedSprite2D → Inspector → Sprite Frames → New SpriteFrames
2. เปิด SpriteFrames editor แถบด้านล่าง
3. สร้างชื่อแอนิเมชัน idle, walk, attack
4. กด Add frames from a Sprite Sheet แล้วเลือกรูป PNG ของคุณ
5. ระบุจำนวนคอลัมน์/แถว เลือกเฟรมตามลำดับ แล้ว Add Frames
6. ตั้ง FPS เช่น idle 4, walk 8, attack 10
7. เปิด Loop สำหรับ idle/walk และปิด Loop สำหรับ attack
8. บันทึก SpriteFrames เป็นไฟล์ .tres แยก แล้วลากลง MonsterData.sprite_frames

Godot ตัดเฟรมจาก SpriteSheet เป็น AtlasTexture ใน SpriteFrames
จึงไม่ต้องเก็บทั้ง SpriteSheet และ SpriteFrames ซ้ำใน MonsterData
หากภาพเป็น PNG แยกเฟรมก็เพิ่มรูปลง SpriteFrames ได้เช่นกัน

ภาพตัวอย่างยังเป็น placeholder; แต่ละ animation มีภาพหนึ่งเฟรมเพื่อทดสอบการสลับข้อมูล
ต้องใส่ SpriteSheet ของคุณเพื่อให้เห็นการเดิน/โจมตีหลายเฟรมจริง
โค้ดเดโมใช้ idle/walk/attack และ flip_h ตามแกน X
ยังไม่มีการเลือกแอนิเมชัน 4 หรือ 8 ทิศ; สามารถต่อยอดชื่อ idle_down / walk_up / walk_left ฯลฯ

## Partner Scene และโหลดข้อมูล

| Node | ชนิด |
|---|---|
| Partner | CharacterBody2D |
| AnimatedSprite2D | AnimatedSprite2D |
| CollisionShape2D | CollisionShape2D |
| NavigationAgent2D | NavigationAgent2D |

Inspector ของ Partner:
- forms เป็น Array[MonsterData] ใส่ rookie.tres, champion.tres, ultimate.tres ตามสายที่ต้องการ
- tamer อ้างอิง Tamer เดิม
- ขนาด Collider ไม่เปลี่ยนตาม Sprite Scale; ปรับ collider/navigation แยกเมื่อจำเป็น

เรียก load_monster_data เมื่อ Partner อยู่ใน Scene และ @onready ได้ Node แล้ว
_ready ของ Partner โหลด forms[0] ให้เอง

```gdscript
# ใช้ใน _ready() ของ World เมื่อ Partner พร้อมแล้ว
const CHAMPION: MonsterData = preload("res://data/champion.tres")

func change_partner_form() -> void:
    var partner := $Actors/Partner as PartnerMonster
    if partner.load_monster_data(CHAMPION):
        print(partner.current_form.monster_name)
```

load_monster_data เป็นการสวมข้อมูล จึงไม่หัก DS เอง
เกมควรเรียก digivolve() สำหรับการเปลี่ยนร่างที่มีค่าใช้จ่าย
load_monster_data(data, false) ตั้ง HP เต็ม เหมาะกับการสร้าง/รีเซ็ตตัวละคร
ค่า preserve_hp ปกติเป็น true: ถ้ามีข้อมูลเดิมจะรักษา HP ratio
ถ้าตัวละครตายอยู่ จะคง HP = 0 และไม่เล่นแอนิเมชันต่อ

การโหลดจะอัปเดต max_hp, hp, attack_power, move_speed, active_skills,
sprite.sprite_frames, sprite.scale และ agent.max_speed พร้อมส่ง form_changed และ hp_changed
Target และ State เดิมคงอยู่ จึงเปลี่ยนร่างระหว่างต่อสู้ได้
ยกเลิกสกิลที่ค้างจากร่างเก่า และไม่ล้างคูลดาวน์

ถ้าส่ง MonsterData ที่ไม่ได้อยู่ใน forms ก็โหลดได้ แต่ form_index จะเป็น -1
ต้องเพิ่ม Resource เดียวกันลง forms ก่อนใช้ระบบพัฒนาร่างตามลำดับ

## ใช้แค็ตตาล็อกฐานข้อมูล

```gdscript
const DATABASE: MonsterDatabase = preload("res://data/monster_database.tres")

func equip_monster(monster_id: StringName) -> void:
    var data: MonsterData = DATABASE.find_by_id(monster_id)
    if data == null:
        push_warning("ไม่พบมอนสเตอร์: " + String(monster_id))
        return
    ($Actors/Partner as PartnerMonster).load_monster_data(data)
```

เพิ่มมอนสเตอร์ใน MonsterDatabase.monsters ผ่าน Inspector
id ต้องไม่ซ้ำ; find_by_id คืนข้อมูลตัวแรกที่ตรงกัน และคืน null หากไม่พบ
แค็ตตาล็อกและสายพัฒนาร่างเป็นคนละรายการ:
แค็ตตาล็อกรวมทุกมอนสเตอร์ของเกม ส่วน Partner.forms เก็บเฉพาะสายของคู่หูตัวนั้น

## Digivolve

Tamer.command_digivolve() เรียก Partner.digivolve() เหมือนรุ่นเดิม

1. ตรวจคู่หูมีชีวิต และ current_form อยู่ใน forms
2. อ่าน next_data = forms[form_index + 1]
3. ตรวจ validation_error() ก่อนหัก DS
4. ใช้ tamer.consume_ds(next_data.evolution_cost)
5. เรียก load_monster_data(next_data)
6. HUD รับ form_changed เพื่อสลับจำนวนปุ่มสกิล

ตัวอย่าง HP 60/120 → Champion 120/240, Attack 15→30, Speed 240→270
ขยาย Sprite 1.0→1.35 และเปลี่ยนสกิล 2→4 ช่อง
ค่าเข้าร่าง Champion = DS 25 ค่ารักษาร่าง = 6 ต่อวินาที
เมื่อ DS หมดกลับ forms[0] โดยใช้ loader เดียวกัน
สกิลที่ปรากฏหลายร่างควรใช้ id เดียวกันเพื่อรักษาคูลดาวน์ต่อเนื่อง

แอนิเมชัน attack ต้องปิด Loop เพราะ animation_finished ไม่ถูกส่งสำหรับ loop
ถ้าไม่มี walk จะใช้ idle แทน ถ้าไม่มี attack จะยังโจมตีได้แต่ไม่เล่นภาพโจมตี
สกิลและ Basic Attack ยังคิด damage ทันทีเหมือนระบบเดิม
หากต้องการ damage ตรงเฟรมตี ควรเพิ่ม AnimationPlayer/event หรือ pending hit แยกต่างหาก

## ย้ายจากรุ่น v2

แนะนำเปิดโปรเจกต์นี้ในโฟลเดอร์ใหม่เพื่อตรวจสอบก่อนนำไปผสานโค้ดของคุณ

- MonsterForm เปลี่ยนเป็น MonsterData ทั้งชนิด forms, current_form และ signal form_changed
- เปลี่ยน display_name ของข้อมูลมอนสเตอร์เป็น monster_name; MonsterSkill ยังใช้ display_name เดิม
- เปลี่ยน Sprite2D ของ Partner เป็น AnimatedSprite2D และ path ใน @onready ให้ตรงกัน
- สร้าง .tres แบบ MonsterData ใหม่และกำหนด SpriteFrames แทน texture เดิม
- อัปเดต MobileHUD._refresh_form(form: MonsterData)
- ใช้ partner.active_skills และ partner.max_hp ใน HUD
- เรียก load_monster_data แทนการแก้ texture/สเตตัสทีละค่า
- อย่าวางสคริปต์ class_name เดียวกันซ้ำหลายไฟล์ในโปรเจกต์เดียว

## การตรวจสอบ

```bash
godot --headless --editor --import --quit
godot --headless res://tests/smoke_test.tscn
```

ทดสอบ runtime stats, แค็ตตาล็อก id, null/ข้อมูลผิด, shared Resource,
Array สกิลไม่กระทบต้นแบบ, HP ratio, SpriteFrames, Digivolve, DS,
สัมผัสสองนิ้ว, Follow, Target, cooldown, การโต้กลับ, Auto และคู่หูล้ม
ยังไม่ได้ build APK หรือทดสอบมือถือจริง

เอกสารอ้างอิง:
- https://docs.godotengine.org/en/4.4/tutorials/scripting/resources.html
- https://docs.godotengine.org/en/4.4/classes/class_animatedsprite2d.html
