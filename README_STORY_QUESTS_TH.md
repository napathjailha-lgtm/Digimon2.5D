> เวอร์ชันนี้เป็น v8 อ่าน README_RECOVERY_LEVEL_CUTSCENE_TH.md สำหรับระบบคู่หูเป็นไข่ เลเวล และคัตซีนล่าสุด

> โปรเจกต์นี้เป็น v7 พร้อมภาพเกม อ่าน README_ART_TH.md สำหรับภาพและการเปิดเล่นล่าสุด

# ระบบ Story Quest — Godot 4

โปรเจกต์ v6 ต่อจาก Tamer, Follow/Battle AI, MonsterData, Damage Popups และ Monster Spawner เดิม เพิ่มเควสต์หลัก 8 ขั้นและ Scene ตัวอย่าง 4 โซน ใช้ GDScript และฟอนต์ Noto Sans Thai ที่แนบใบอนุญาต OFL มาให้แล้ว

## เปิดโปรเจกต์

1. แตก ZIP ลงโฟลเดอร์ใหม่ แล้ว Import `project.godot` ใน Godot
2. กด F5 เริ่มจาก `scenes/story_boot.tscn` ซึ่งเปิดโซนตาม Save ถ้าไม่มี Save จะเริ่ม File Island
3. แตะกรอบเควสต์ฝั่งซ้ายเพื่อเดินไปเป้าหมาย แตะ Joystick แล้วลากเพื่อยกเลิกการเดินอัตโนมัติ
4. ถึง NPC แล้วตัวอย่างจะจบขั้นสนทนาทันที ส่วนบอสต้องแตะเลือกศัตรู/กด Attack หรือ Auto-Battle เอง
5. เมื่อเคลียร์บอส ประตูฝั่งขวาจะเปิด แตะ Tracker เพื่อเดินไปประตู เมื่อโหลดโซนใหม่ให้แตะ Tracker อีกครั้งเพื่อไปเป้าหมายในโซนใหม่

เวอร์ชันนี้เพิ่มภาพฉากและตัวละครต้นฉบับแล้ว ดู README_ART_TH.md ไม่มีคัตซีนจากอนิเมะ บทเควสต์เป็นโครงย่อสำหรับเกม และรางวัลปลดล็อกร่างเป็นกติกาเกมตัวอย่าง ไม่ใช่การจำลองจังหวะวิวัฒนาการในอนิเมะทุกตอน

## รายการเควสต์

| ID | โซน | Objective / Target ID | สิ่งที่ต้องทำ | ปลดล็อก |
|---|---|---|---|---|
| q01_agumon | file_island | TALK / agumon | คุยกับ Agumon | เควสต์ถัดไป |
| q02_friends | file_island | REACH / friends_reunion | เดินถึงจุดนัดพบเพื่อน | เควสต์ถัดไป |
| q03_devimon | file_island | KILL / devimon | ปราบ Devimon | flag angemon และ server_continent |
| q04_gennai | server_continent | TALK / gennai | คุยกับ Gennai | เควสต์ถัดไป |
| q05_etemon | server_continent | KILL / etemon | ปราบ Etemon | Ultimate และ odaiba |
| q06_eighth | odaiba | REACH / odaiba_clue | ไปจุดเบาะแสผู้ถูกเลือกคนที่แปด | เควสต์ถัดไป |
| q07_myotismon | odaiba | KILL / myotismon | ปราบ Myotismon | Mega และ spiral_mountain |
| q08_piedmon | spiral_mountain | KILL / piedmon | ปราบ Piedmon | flag adventure_complete |

ลำดับเควสต์อยู่ใน `data/quest_catalog.tres` ระบบนี้มี Main Quest ที่ Active ครั้งละหนึ่งขั้น ถ้าต้องการทำหลายเควสต์พร้อมกัน ให้ขยาย Manager เป็นรายการ Active แทนการเปลี่ยน Resource ระหว่างเล่น

## ไฟล์สำคัญ

| ไฟล์ | หน้าที่ |
|---|---|
| scripts/story_quest.gd | Custom Resource สำหรับ ID/ชื่อ/รายละเอียด/Objective/รางวัล |
| scripts/quest_catalog.gd | Array ของ StoryQuest ที่เรียงตามเนื้อเรื่อง |
| scripts/quest_manager.gd | Autoload: สถานะ Progress, รับ event, Save/Load และปลดล็อก |
| scripts/quest_tracker.gd | UI ภาษาไทย, รับ touch, หาเป้าหมายหรือประตูโซน |
| scripts/quest_target.gd | Marker2D ของ NPC/บอส/จุดหมาย/ประตู |
| scripts/tamer.gd | Auto-Navigation ผ่าน NavigationAgent2D และยกเลิกด้วย Joystick |
| scripts/story_npc.gd | Area2D สำหรับคุย NPC เมื่ออยู่ใกล้ |
| scripts/story_reach.gd | Area2D นับ Objective REACH เมื่อ Tamer เดินถึง |
| scripts/story_portal.gd | Area2D เช็กเควสต์ก่อนเปลี่ยนโซน |
| scripts/story_cutscene_trigger.gd | จุดส่ง signal ขอเล่นคัตซีนหลังผ่านเควสต์ |
| scripts/story_world.gd | กำหนดโซนและคืนค่า DS/HP/ร่างข้าม Scene |
| scripts/story_boot.gd | เปิดโซนตาม Save ตอนเริ่มเกม |
| scripts/partner_monster.gd | เช็กระดับร่างและ flag ก่อนโหลดร่าง/หัก DS |
| data/quests/*.tres | ข้อมูลเควสต์ 8 ขั้น แก้ได้ใน Inspector |
| data/angemon_example.tres | ตัวอย่างร่าง Champion ที่ต้องมี flag angemon |

## ตั้ง Autoload และสร้างข้อมูล

Project > Project Settings > Globals > Autoload: เพิ่ม `res://scripts/quest_manager.gd` ชื่อ **QuestManager** และเปิด Enable ใน ZIP ตั้งไว้แล้ว

Script นี้ใช้ `extends Node` โดยไม่ใส่ `class_name QuestManager` เพราะจะชนกับชื่อ Autoload ส่วน `StoryQuest`, `QuestCatalog`, `QuestTracker` เป็น class_name ตามปกติ Joystick เดิมใช้ `MobileJoystick` ต่อไป

สร้าง Resource ใหม่ชนิด StoryQuest ใน FileSystem แล้ว Save เป็น `.tres` ตั้ง `id` ไม่ซ้ำ และให้ `target_id` ตรงกับเป้าหมาย เช่น `devimon` ค่า `required_count` ต้องมากกว่า 0 เพิ่ม Resource เข้า `quest_catalog.tres` ตามลำดับ

Resource เก็บข้อมูลต้นแบบเท่านั้น ค่า Progress และสถานะของผู้เล่นอยู่ใน Manager เพราะ Resource อาจถูกแชร์โดยหลาย instance จึงไม่ควรเก็บสถานะผู้เล่นไว้ใน `.tres`

อ่านสถานะได้ดังนี้:

```gdscript
var active: StoryQuest = QuestManager.get_current_quest()
var status = QuestManager.get_status(&"q03_devimon")
var progress: int = QuestManager.get_progress(&"q03_devimon")
var completed: bool = QuestManager.is_completed(&"q03_devimon")
```

Status เป็น LOCKED / ACTIVE / COMPLETED เควสต์ที่ถูกล็อกจะไม่รับ event แม้ผู้เล่นจะฆ่าบอสก่อนถึงขั้นนั้น

## จัด Node ในเกมเดิม

1. World เป็น Node2D มี `NavigationRegion2D` และ NavigationPolygon ครอบพื้นที่เดินได้ ต้องตัดสิ่งกีดขวางออกจาก polygon และ bake ใหม่เมื่อแก้แผนที่
2. Actors เป็น Node2D มี Tamer (CharacterBody2D) และ Partner (CharacterBody2D) เพิ่ม `NavigationAgent2D` เป็นลูกของ Tamer ชื่อให้ตรงกับ Script
3. MobileHUD เป็น CanvasLayer มี Root (Control) ที่เต็มจอ และมี QuestTracker (Control) อยู่ฝั่งซ้ายเหนือ Joystick
4. QuestTracker มี Panel (PanelContainer), Margin (MarginContainer), VBox (VBoxContainer) และ Label ชื่อ Title / Detail / Progress ตาม path ใน Script
5. NPC, บอส, จุด REACH และประตูมีลูก `QuestTarget` (Marker2D) ตั้ง target_id ให้ตรงกับเควสต์ ยกเว้นประตูซึ่ง Tracker เลือกจาก destination_zone

`MobileHUD._ready()` ในตัวอย่างสร้าง QuestTracker และเชื่อม signal ให้แล้ว หากใส่ Tracker ด้วยมือในเกมเดิม ให้เชื่อมเองและไม่สร้างซ้ำ:

```gdscript
tracker.tamer = tamer
tracker.navigation_requested.connect(tamer.start_auto_navigation)
tracker.feedback.connect(_show_message)
```

QuestTarget เพิ่มตัวเองเข้า group `quest_targets` เมื่อพร้อม Tracker หา target_id ที่ตรงและใกล้ Tamer ที่สุด การอ้างอิงเป็น Node ทำให้เป้าหมายที่เดินได้ เช่น บอส ใช้พิกัดล่าสุดได้ ไม่เก็บพิกัดเก่าตายตัว

Tracker รับ InputEventScreenTouch และ consume touch ของตนก่อน `_unhandled_input()` ของ Tamer จึงไม่เลือกศัตรูทะลุ UI ลูก Control ทั้งหมดตั้ง Mouse Filter = Ignore ส่วน Project ใช้ emulate_touch_from_mouse เพื่อกดทดสอบด้วยเมาส์บนคอมพิวเตอร์ได้

Tamer อัปเดต target_position ทุก 0.2 วินาที และใช้ get_next_path_position ใน physics frame ก่อน move_and_slide ถ้ายังไม่มี navigation map ที่ sync แล้วจะรอ ไม่สั่งเดินตรงผ่านกำแพง ถ้าเดินไปสุด path แล้วยังไม่ถึง หรือชนค้าง ระบบหยุดและส่ง auto_navigation_failed

## ส่ง Event จากระบบเกม

```gdscript
# เรียกตอนจบบทสนทนาจริง ไม่ใช่ตอนเปิดหน้าต่างสนทนา
QuestManager.report_event(StoryQuest.Objective.TALK, &"agumon")

# เรียกเมื่อเข้า Area2D จุดหมาย โดยต้องเช็ก body is Tamer
QuestManager.report_event(StoryQuest.Objective.REACH, &"friends_reunion")

# เรียกตอน HP บอสเหลือ 0 เท่านั้น ไม่เรียกทุก hit
# event_id ของการตายครั้งเดียวกันต้องใช้ค่าเดียวกันหากส่งซ้ำ
QuestManager.report_event(StoryQuest.Objective.KILL, &"devimon", 1, death_event_id)
```

`story_npc.gd` ส่ง `dialogue_requested` ให้ UI ภายนอก แต่ต้นแบบจบ TALK ทันทีใน try_talk เมื่อสร้างระบบบทสนทนาจริงให้ย้าย report_event ไปหลังผู้เล่นอ่านบทสนทนาจบ

`wild_monster.gd` ส่ง KILL เฉพาะ hit ที่ทำให้ตายและ attacker เป็น PartnerMonster พร้อม event ID ไม่ส่งจากการ despawn/queue_free ปกติ เพื่อไม่ให้การลบศัตรูหรือเปลี่ยนแผนที่นับเป็นการปราบบอส

Manager ตรวจ Objective, Target, โซนปัจจุบัน และเควสต์ Active ก่อนเพิ่ม Progress เช็ก event ID ซ้ำเมื่อมีการส่งมา เมื่อครบจะบันทึกว่า completed ก่อน emit signal เพื่อไม่แจก reward ซ้ำ

## ปลดล็อก Digivolve

`max_unlocked_stage` เริ่มที่ Champion ใช้ค่าจาก MonsterData.EvolutionStage: Rookie 0 / Champion 1 / Ultimate 2 / Mega 3

ร่างเฉพาะตัวใช้ `MonsterData.required_story_flag` เพิ่มอีกเงื่อนไข เช่น Angemon มี stage Champion แต่ required_story_flag เป็น `angemon` จึงยังถูกล็อกจน q03 สำเร็จ ขณะที่ Champion ทั่วไปที่ flag ว่างใช้ได้ตั้งแต่เริ่ม

```gdscript
# ตรวจทั้งสองเงื่อนไขผ่าน Manager
if not QuestManager.can_use_form(next_data):
    feedback.emit("ต้องผ่านเควสต์เนื้อเรื่องก่อน")
    return false

# จากนั้นจึงตรวจข้อมูล, DS และโหลดร่าง
```

Partner เชื่อม unlocks_changed ใน _ready และอ่านค่า cap ปัจจุบันทันที เผื่อผู้เล่นโหลด Save ที่ผ่านเควสต์มาแล้ว ทั้ง `digivolve()` และ `load_monster_data()` ตรวจสิทธิ์ จึงไม่สามารถเรียก loader โดยตรงเพื่อข้ามการล็อกได้

ตัวอย่างสายร่างใน partner.tscn เป็น Rookie -> Champion -> Ultimate -> Mega แบบทั่วไป ส่วน `angemon_example.tres` เป็นข้อมูลแยกสำหรับสาธิต flag หากสร้างสาย Patamon ให้ใส่ Rookie ของ Patamon และ Angemon ลงใน forms ตามลำดับ ร่างตัวอย่างต้องเปลี่ยน SpriteFrames/สกิลเป็นของคุณเอง

## ประตูและคัตซีน

StoryPortal สืบทอด Area2D มี CollisionShape2D, Visual (Polygon2D), Name (Label) และ QuestTarget ตั้ง:

- required_quest เช่น q03_devimon
- destination_zone เช่น server_continent
- destination_scene เช่น res://scenes/server_continent.tscn
- collision_mask รวม layer ของ Tamer (ตัวอย่าง layer 2)

`can_enter()` ต้องผ่าน required_quest และปลดล็อก destination_zone ทั้งคู่ ประตูเปลี่ยนสีเมื่อปลดล็อก มี guard ป้องกันการวาร์ปซ้ำ และ defer เปลี่ยน Scene เพื่อไม่ลบ Node ระหว่าง callback ฟิสิกส์

Area2D นี้เป็นตัวกระตุ้น ไม่ใช่กำแพงฟิสิกส์ ประตูที่ล็อกจะไม่วาร์ป ถ้าต้องการกั้นทางบนแผนที่เดียวกัน ให้เพิ่ม StaticBody2D และเปิด/ปิด collision ตามเงื่อนไขด้วย set_deferred

StoryPortal ส่ง cutscene_requested แล้วตัวอย่างวาร์ปทันที หากต้องเล่นคัตซีนก่อน ให้ย้ายการเรียก _change_zone ไปหลัง AnimationPlayer/บทสนทนาจบ หรือวาง StoryCutsceneTrigger แยกและเชื่อม signal กับระบบคัตซีน ตัวอย่างไม่ได้สร้างเนื้อหาคัตซีนและ Trigger แบบ once จำสถานะเฉพาะ instance ถ้าต้องการจำข้ามโซนให้เพิ่ม persistent cutscene flags

เปลี่ยนโซนแล้ว Autoload ยังอยู่ ส่วน Node เดิมถูกสร้างใหม่ ตัวอย่างเก็บ DS, HP และ form_id ใน party_snapshot แล้วคืนให้ปาร์ตี้ใน World ใหม่ ค่าเหล่านี้เก็บเฉพาะ session ไม่ได้เป็น Save ค่าตัวละครเต็มรูปแบบ

## Save และข้อจำกัดสำหรับ MMORPG

เควสต์บันทึกลง `user://story_progress.json` มี version, completed IDs, partial progress, zone และ event IDs ตอน Load คำนวณสิทธิ์โซน/ร่างใหม่จากเควสต์ที่จบเพื่อไม่ให้ reward state หลายแหล่งขัดกัน ไม่ emit quest_completed ซ้ำจากการโหลด Save

เรียก `QuestManager.reset_progress()` เพื่อเริ่มใหม่ แล้วเปิด world.tscn ใหม่จากระบบเมนูของคุณ ค่าแผนที่กับ Tamer/Partner ไม่ได้ถูกรีเซ็ตครบเพียงแค่รีเซ็ตเควสต์

นี่เป็นต้นแบบ local client ต่อเกมได้จริง แต่ยังไม่มีระบบออนไลน์ ใน MMORPG จริง เก็บ Progress แยกตาม player/account บนเซิร์ฟเวอร์ ให้เซิร์ฟเวอร์ตรวจสิทธิ์เครดิตการฆ่าบอส, ระยะ NPC, เงื่อนไขวาร์ปและสิทธิ์วิวัฒนาการ แล้วส่งสถานะที่ยืนยันแล้วให้ UI ฝั่ง client แสดงผล JSON ในเครื่องไม่ได้ป้องกันการแก้ Save

## ตรวจสอบ

ทดสอบด้วย Godot 4.4.1 stable แบบ headless ผ่านเควสต์ครบ 8 ขั้น, touch navigation, ยกเลิกด้วย Joystick, ประตู, เปลี่ยน Scene, เก็บ DS/HP/ร่างข้ามโซน, event ซ้ำ, partial save/load และการปลดล็อก Partner พร้อมทดสอบ regression ของระบบเดิม

```sh
godot --headless --editor --import --quit
godot --headless res://tests/story_quest_test.tscn
godot --headless res://tests/smoke_test.tscn
godot --headless res://tests/damage_popup_test.tscn
godot --headless res://tests/spawner_test.tscn
godot --headless res://tests/layout_check.tscn
```

รันจากโฟลเดอร์โปรเจกต์ หรือเพิ่ม --path ให้ถูกต้อง รันเป็น Scene เพื่อให้ Autoload พร้อมก่อน Script ทดสอบ Tests ใช้ไฟล์ Save แยกจาก story_progress.json ไม่แก้ความคืบหน้าปกติ

การทดสอบ headless ไม่ใช่การรับรองประสิทธิภาพ/การแสดงผลบนอุปกรณ์มือถือจริง ควรทดสอบบนมือถือเป้าหมายหลังใส่แผนที่และแอนิเมชันจริง

## เอกสาร Godot

- Autoload: https://docs.godotengine.org/en/4.4/tutorials/scripting/singletons_autoload.html
- NavigationAgent: https://docs.godotengine.org/en/4.4/tutorials/navigation/navigation_using_navigationagents.html
- Resource: https://docs.godotengine.org/en/4.4/tutorials/scripting/resources.html
- FileAccess: https://docs.godotengine.org/en/4.4/classes/class_fileaccess.html
