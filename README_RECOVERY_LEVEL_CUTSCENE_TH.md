> อัปเดต v19: คู่มือระบบนี้อ้างอิงรุ่นก่อน สกิลปัจจุบันใช้ `mp_cost` และหัก MP คู่หู ส่วน DS เป็นของ Tamer สำหรับเปลี่ยนร่าง/รักษาร่าง อ่าน `README_SURVIVAL_STATUS_TH.md` สำหรับ API และสเตตัสปัจจุบัน

# Partner Recovery, EXP/Level และ Digivolve Cutscene — v8

## เปิดโปรเจกต์

แตก ZIP ลงโฟลเดอร์ใหม่ Import project.godot ใน Godot 4 แล้วกด F5 ภาพฉาก/ตัวละครจาก v7 อยู่ครบ

- คู่หู HP 0 จะหดตัว 0.28 วินาทีเป็นไข่และเดินตาม Tamer ไม่มีการลบคู่หู
- แตะ Recover ที่กลางด้านล่าง หรือเดินเข้า Safe Zone สีเขียวที่พิกัด (460,560)
- ฟื้นกลับ forms[0] ซึ่งต้องเป็น Rookie พร้อม HP เต็มตามเลเวลเดิม
- ฆ่าศัตรูหนึ่งตัวได้ EXP ให้ทั้ง Tamer และคู่หู คนละ exp_reward เต็มจำนวน
- หลอด HP/EXP อยู่บนซ้าย แตะ Status บนขวาเพื่อดูค่าตัวเลข EXP/HP/ATK/SPD
- แตะ Digivolve เพื่อเล่นคัตซีน 2.7 วินาที ฉากต่อสู้และ Timer Respawn หยุดชั่วคราว

Recover ในตัวอย่างฟรี ใช้ได้ทุกที่เฉพาะคู่หูที่แพ้ ไม่ใช้เติม HP ระหว่างยังมีชีวิต ถ้าต้องการไอเทม ค่า DS หรือเวลาคูลดาวน์ ให้เพิ่มการตรวจใน recover() ก่อนโหลดร่าง

## แก้สาเหตุเดิม

สคริปต์เดิม return จาก _physics_process ทันทีเมื่อ HP 0 จึงหยุด Follow ไปด้วย เวอร์ชันนี้เช็ก State.FAINTED/EGG ก่อนเช็ก is_alive()

Partner ไม่เรียก queue_free() และไม่ emit died แล้ว ใช้ defeated สำหรับการแพ้แทน สัญญาณ died เดิมยังประกาศไว้ให้ย้ายระบบได้ แต่ไม่ถูกส่ง อย่าเชื่อม defeated กับการลบคู่หู ตรวจและลบโค้ดเก่าที่ queue_free() คู่หูจาก HUD, signal callback หรือ Manager ภายนอกด้วย

WildMonster ยังตายด้วย queue_free() ตามปกติ ใช้ MonsterSpawner เกิดใหม่ แยกจากการฟื้นคู่หู

## Node ที่ต้องมี

| Parent | Node | ชนิด/Script |
|---|---|---|
| World | Actors | Node2D, y_sort_enabled |
| Actors | Tamer | CharacterBody2D, tamer.gd |
| Tamer | Sprite2D | ภาพ Tamer เดิม |
| Tamer | CollisionShape2D | Collision ใต้เท้า |
| Tamer | NavigationAgent2D | Auto-Navigation เดิม |
| Tamer | Progress | Node, character_progress.gd; attack_per_level=0 |
| Actors | Partner | CharacterBody2D, partner_monster.gd |
| Partner | AnimatedSprite2D | ภาพแต่ละร่างจาก MonsterData |
| Partner | EggSprite | Sprite2D, digitama.svg; เริ่มซ่อน |
| Partner | CollisionShape2D | Collision เดิม ไม่ลบเมื่อแพ้ |
| Partner | NavigationAgent2D | ใช้ Follow ทั้งร่างปกติและไข่ |
| Partner | Progress | Node, character_progress.gd |
| World | SafeZone | Area2D, safe_zone.gd |
| SafeZone | CollisionShape2D | Circle/Rectangle; collision_mask รวม layer Tamer |
| World | MobileHUD | CanvasLayer, mobile_hud.gd |
| SceneTree root | DigivolveCutscene | CanvasLayer, process_mode ALWAYS, layer 100 |

Tamer/Partner ในตัวอย่างใช้ NodePath ชื่อ Progress, EggSprite, AnimatedSprite2D และ NavigationAgent2D ตรงตามตาราง ถ้าตั้งชื่ออื่นต้องแก้ @onready path

MobileHUD สร้าง Card ของ HP/EXP, Recover, StatsDetails และ Status button ใน _ready จากโค้ด มีชื่อ Node ชัดเจน สามารถแยกเป็น .tscn ในภายหลังได้ UI ที่มีอยู่ไม่ต้องสร้างซ้ำ

## State Machine คู่หู

| State | การทำงาน | เหตุการณ์ออกจาก State |
|---|---|---|
| IDLE | รอคำสั่ง อยู่ใกล้ Tamer | เดินห่าง -> FOLLOW, เลือกศัตรู -> BATTLE |
| FOLLOW | เดินตามผ่าน NavigationAgent | ถึงระยะหยุด -> IDLE, รับคำสั่งต่อสู้ -> BATTLE |
| BATTLE | ไล่/โจมตี/ใช้สกิล | ยกเลิกเป้า -> IDLE; HP 0 -> FAINTED |
| FAINTED | HP 0 หดตัว หยุดโจมตี | Tween จบ -> EGG, Recover -> IDLE |
| EGG | HP 0 แต่ยังเดินตาม ไม่ใช้ DS | Recover สำเร็จ -> IDLE ร่าง Rookie |

ฟังก์ชันหลักใน partner_monster.gd:

- take_damage: ลด HP ครั้งเดียวต่อ hit; แพ้แล้วไม่รับ hit เพิ่ม
- enter_fainted: ยกเลิกเป้า/Auto-Battle, หยุดแอนิเมชัน, emit defeated, เล่น Tween และ Save สถานะแพ้
- _enter_egg_form: ซ่อนร่างต่อสู้ แสดง EggSprite และเริ่ม Follow ได้
- recover: ฆ่า Tween เดิมหากยังหดตัวอยู่ โหลด Rookie ด้วยทางภายใน คืน HP เต็ม ล้างคูลดาวน์ และส่ง recovered
- is_alive: คืน false สำหรับ FAINTED/EGG แม้มีใครแก้ HP ผิดพลาด
- load_monster_data: ห้ามใช้ loader ปกติชุบไข่หรือเปลี่ยนข้อมูลระหว่างคัตซีน

`cancel_battle()` จะไม่เปลี่ยน EGG กลับเป็น IDLE ส่วน Attack/Skill/Digivolve ตรวจ is_alive ก่อน ไข่จึงไม่หลุดกลับเข้าสถานะต่อสู้

Level Up ระหว่างไข่เพิ่มเพดานสเตตัส แต่ HP ยังคง 0 Recover เท่านั้นที่คืนชีวิต โดยจะรักษา Level/EXP เดิม

SafeZone ฟื้นตอน Tamer เข้า Area ถ้าอยู่ใน Area อยู่แล้วให้เดินออกแล้วเข้าใหม่ ตัวอย่างไม่ได้ให้สถานะ invulnerable หรือเปลี่ยน Aggro ทั้งแผนที่

## CharacterProgress และสเตตัส

Component ใช้ร่วมได้ทั้งสองตัวละคร แต่เป็น Node คนละ instance มี level, current_exp, max_exp และ base_stats

สูตร EXP: `max_exp = 100 + (level - 1) * 50`

สูตรสเตตัส: `ค่าจริง = ค่าฐานของร่าง + (level - 1) * โบนัสต่อเลเวล`

เริ่ม Lv1 เพดาน Lv99 โบนัสตัวอย่าง HP +50, ATK +5, SPD +1 ต่อเลเวล Tamer ตั้ง ATK ต่อเลเวลเป็น 0 ตามบทบาทผู้สั่งการเดิม

ตัวอย่างคู่หู Rookie ที่ฐาน HP 120, ATK 15, SPD 240 พอ Lv3 ได้ HP 220, ATK 25, SPD 242 ถ้าเปลี่ยน Champion ที่ฐาน HP 240 จะได้ HP 340 ไม่ใช่นำ HP Rookie มาบวกซ้ำ

MonsterData ไม่ถูกแก้ไข แค่เรียก progress.set_base_stats ตอนสวมร่าง แล้วอ่าน get_effective_stats EXP/Level จึงคงอยู่ข้ามร่าง

```gdscript
# ใช้เพิ่ม EXP ตามเครดิตจากระบบเกม
tamer.grant_party_exp(60)

# อ่านสถานะ
var level: int = partner.progress.level
var exp: int = partner.progress.current_exp
var required: int = partner.progress.max_exp
var stats: Dictionary = partner.progress.get_effective_stats()
```

check_level_up ใช้ while รองรับรางวัลครั้งเดียวขึ้นหลายเลเวล และเก็บ EXP ส่วนเกินไว้ เมื่อถึง cap ไม่สะสม EXP เพิ่ม

แต่ละ level ส่ง leveled_up ให้เจ้าของคำนวณสเตตัสใหม่ เพิ่ม HP เท่าค่า Max HP ที่เพิ่มเฉพาะเมื่อยังมีชีวิต แล้วสร้าง level_up_effect.gd วงแสง Tween ที่ลบตัวเองหลังจบ ไม่ลบตัวละคร

progress_changed(level, current_exp, max_exp), hp_changed และ ds_changed เชื่อมกับ MobileHUD._refresh_bars หน้าจอจึงอ่านค่าปัจจุบันจาก signal การโหลด Save ส่ง progress_changed แต่ไม่ส่ง leveled_up เพื่อไม่แจกโบนัส/เอฟเฟกต์ซ้ำ

Attack ปกติใช้ attack_power ที่รวมโบนัสเลเวล ส่วนสกิลในต้นแบบยังใช้ค่า damage ของ MonsterSkill หากต้องการสกิลโตตาม ATK ให้เพิ่มสูตรใน _try_skill

## ให้ EXP เมื่อศัตรูตาย

WildMonster มี @export exp_reward ค่าเริ่มต้น 60 เปลี่ยนแต่ละชนิดใน Inspector ได้

ใน take_damage เมื่อลด HP เหลือ 0 จะเลือก Tamer เจ้าของ attacker ถ้า attacker เป็น PartnerMonster หรือใช้ attacker เองเมื่อเป็น Tamer จากนั้นเรียก grant_party_exp หนึ่งครั้งก่อน died/queue_free

HP ที่เป็น 0 ทำให้ hit ซ้ำ return จึงไม่ให้ EXP ซ้ำ การ despawn หรือลบ Node เปล่า ๆ ไม่ให้ EXP คู่หูที่อยู่ในไข่ยังรับ shared EXP ได้ แต่ไม่ฟื้นชีวิตด้วยการขึ้นเลเวล

## Scene คัตซีน

| Parent | Node | หน้าที่ |
|---|---|---|
| DigivolveCutscene | Root | Control เต็มจอ |
| Root | Backdrop | Control, digital_tunnel.gd วาดอุโมงค์ |
| Root | OldSprite | Sprite2D ร่างเดิม + ShaderMaterial white_flash |
| Root | NewSprite | Sprite2D ร่างใหม่ที่เริ่มโปร่งใส |
| Root | Flash | ColorRect สีขาว เต็มจอ |
| Root | Title / Caption | Label |
| DigivolveCutscene | AnimationPlayer | AnimationLibrary ชื่อว่าง มี animation evolve |
| DigivolveCutscene | Watchdog | Timer one_shot 4.2 วินาที |

เปิด scenes/digivolve_cutscene.tscn ใน Editor แล้วเลือก AnimationPlayer สามารถแก้ track ใน animation evolve ได้โดยตรง Loop ปิด ความยาว 2.7 วินาที

| Track | จังหวะสำคัญ |
|---|---|
| Root/Backdrop:phase | หมุน/เลื่อนวงอุโมงค์ตลอด 2.7 วินาที |
| .:old_size_multiplier | ขยายร่างเดิมแล้วหดก่อนสลับ |
| Root/OldSprite:rotation | หมุนร่างเดิมราวสองรอบ |
| .:flash_amount | เรืองสีขาวด้วย shader แล้วคืนค่า |
| Root/OldSprite:modulate | หายไปช่วง 1.45 วินาที |
| Root/NewSprite:modulate | ร่างใหม่ปรากฏช่วง 1.55 วินาที |
| .:new_size_multiplier | ขยายร่างใหม่เกินขนาดเล็กน้อยแล้วคืนขนาด |
| Root/Flash:modulate | แฟลชขาวช่วงเปลี่ยนภาพ |

ค่า scale จริงคำนวณจากขนาด texture ทำให้แต่ละร่างมีขนาดพรีวิวพอดี ไม่ต้องตั้งค่า pixel ของ atlas เท่ากัน

## Pause / Resume และธุรกรรมเปลี่ยนร่าง

ใช้ get_tree().paused = true เพื่อหยุด physics, ตัวละคร, input ของสนาม และ Timer ส่วน CanvasLayer คัตซีนตั้ง PROCESS_MODE_ALWAYS ลูก AnimationPlayer/Watchdog ใช้ Inherit จึงเล่นต่อได้ คัตซีนสร้างใต้ SceneTree root ไม่อยู่ใต้ World ที่หยุด

ไม่ใช้ Engine.time_scale = 0 เพราะจะทำให้เวลาที่ใช้เล่นคัตซีนหยุดด้วย ตัวอย่างไม่ตั้ง World เป็น DISABLED เพราะ SceneTree.paused จัดการหยุดฟิสิกส์ให้ครบ และแยก UI ที่เล่นต่อได้ชัดเจน

ลำดับปุ่ม UI:

1. Tamer.command_digivolve ส่ง digivolve_requested ให้ HUD
2. HUD สร้าง DigivolveCutscene และเรียก play_for(partner)
3. prepare_digivolve ตรวจ HP/ร่าง/เควสต์/DS จากนั้นจอง DS และตั้ง evolution_busy
4. ล้าง Joystick/นิ้วที่ถือปุ่มก่อน pause เพื่อไม่ให้เดินหรือปุ่มค้างหลังจบ
5. AnimationPlayer เล่นภาพพรีวิว ร่างในสนามยังไม่เปลี่ยน
6. animation_finished เรียก finish_digivolve ตรวจสิทธิ์ใหม่ แล้วโหลดร่างจริง
7. Resume, emit finished และลบเฉพาะ Node คัตซีน

ถ้าปิดคัตซีน เปลี่ยน Scene หรือ Watchdog timeout จะเรียก abort_digivolve คืน DS ครั้งเดียว และคืน pause state เดิม _exit_tree มี cleanup เผื่อมีการ queue_free คัตซีนโดยตรงด้วย

คัตซีนไม่เปิดทับ pause ของระบบอื่น และจะไม่ unpause เมนูอื่นที่ตนไม่ได้ถือครอง ปุ่มกดซ้ำถูกกันด้วย active_cutscene และ evolution_busy

Partner.digivolve() ยังเป็น API เปลี่ยนทันทีสำหรับการทดสอบ/ระบบภายใน หากต้องการคัตซีน ให้เรียก Tamer.command_digivolve หรือเปิด Scene คัตซีนผ่าน HUD อย่าเชื่อมปุ่มเข้ากับ partner.digivolve โดยตรง

## Save และเกมออนไลน์

QuestManager เพิ่ม party_profile ลง JSON เดิม user://story_progress.json โดยเก็บ DS, HP, form_id, egg flag และ level/exp ของทั้งสองตัวละคร ไม่บันทึก Node/Resource

Save เดิมที่ไม่มี party ยังโหลดได้ เมื่อเริ่มโซน story_world คืนเลเวลก่อนคำนวณ HP ของร่าง แล้วคืนไข่ถ้า HP 0/egg=true เมื่อเป็นไข่แล้วเปลี่ยนโซนหรือเปิดเกมใหม่จึงไม่ชุบเอง

เกมบันทึกตอนรับ EXP, แพ้, Recover, เปลี่ยนร่างสำเร็จ/ยกเลิก และเปลี่ยนโซน ค่า DS ที่จองระหว่างคัตซีนไม่ถูกบันทึกเป็นธุรกรรมสำเร็จ ควรเรียก tamer.save_party_progress จากเมนูออกเกม/ระบบ Save ของคุณด้วยหากมีการแก้ค่าตัวละครจากระบบอื่น

ต้นแบบนี้ทำงาน offline/local ใน MMORPG จริง เซิร์ฟเวอร์ต้องยืนยัน EXP/HP/Recover/สิทธิ์วิวัฒนาการ การ pause ฝั่ง client ไม่หยุดเวลาหรือศัตรูบนเซิร์ฟเวอร์ ต้องออกแบบนโยบายคัตซีนออนไลน์เพิ่มเติม

## ตรวจสอบ

ทดสอบ Godot 4.4.1 stable แบบ headless: HP 0 ไม่ลบคู่หู, ไข่ Follow, Recover UI/Safe Zone, EXP หลายเลเวล, ไม่ชุบด้วย Level Up, โบนัสไม่ซ้ำข้ามร่าง, เครดิตการฆ่าครั้งเดียว, คัตซีน pause/resume/ภาพพรีวิว, Timer สนามหยุด, cancel/refund และ Save/Load ไข่/เลเวล

```sh
godot --headless --editor --import --quit
godot --headless res://tests/recovery_progress_cutscene_test.tscn
godot --headless res://tests/smoke_test.tscn
godot --headless res://tests/story_quest_test.tscn
godot --headless res://tests/art_integration_test.tscn
godot --headless res://tests/damage_popup_test.tscn
godot --headless res://tests/spawner_test.tscn
```

Tests แต่ละชุดใช้ Save แยก ไม่แก้ Save ปกติ ตัวทดสอบ Tween มีช่วงเวลาสั้น ควรรันทีละชุดหากเครื่องมีภาระสูงเพื่อหลีกเลี่ยงการข้ามช่วง animation ที่กำลังตรวจ

ยังไม่ได้ทดสอบภาพคัตซีน/ประสิทธิภาพบนมือถือจริง ภาพตัวละครเดิมเป็นภาพนิ่ง เอฟเฟกต์หมุน/ขยาย/แฟลชของคัตซีนเล่นจริงผ่าน AnimationPlayer ไม่ได้เพิ่มแอนิเมชันเดินหลายเฟรม

## เอกสารอ้างอิง

- https://docs.godotengine.org/en/4.4/tutorials/scripting/pausing_games.html
- https://docs.godotengine.org/en/4.4/classes/class_animationplayer.html
- https://docs.godotengine.org/en/4.4/classes/class_tween.html
