> เวอร์ชันนี้เป็น v8 อ่าน README_RECOVERY_LEVEL_CUTSCENE_TH.md สำหรับระบบคู่หูเป็นไข่ เลเวล และคัตซีนล่าสุด

> โปรเจกต์นี้เป็น v7 พร้อมภาพเกม อ่าน README_ART_TH.md สำหรับภาพและการเปิดเล่นล่าสุด

> คู่มือระบบก่อนหน้า: โปรเจกต์ v6 เพิ่ม Story Quest อ่าน README_STORY_QUESTS_TH.md สำหรับขั้นตอนเปิดและใช้งานล่าสุด

# Monster Spawner — Godot 4

หนึ่งจุดเกิดดูแลมอนสเตอร์ที่มีชีวิตหนึ่งตัว เมื่อ died เริ่ม Timer แล้วสร้าง instance ใหม่เมื่อครบเวลา
Spawner ทุกจุดมี reference และ Timer แยกกัน คัดลอก Scene ไปวางได้ทันที

## เปิดโปรเจกต์

แตก ZIP เป็นโฟลเดอร์ใหม่ → Import project.godot → กด F5
ฉากมี SpawnerA / SpawnerB / SpawnerC สร้างศัตรูคนละหนึ่งตัว
ใช้ Joystick, Attack, Skill หรือ Auto เพื่อฆ่าศัตรู แล้วรอ 5 วินาทีให้เกิดใหม่
ระบบ MonsterData, Digivolve และ Damage Popup จากรุ่นก่อนยังใช้ต่อได้

## Scene ของ Spawner

| Parent | Node | ชนิด |
|---|---|---|
| ไม่มี | MonsterSpawner | Marker2D |
| MonsterSpawner | RespawnTimer | Timer |

1. สร้าง Marker2D ชื่อ MonsterSpawner แล้วติด scripts/monster_spawner.gd
2. เพิ่ม Timer ชื่อ RespawnTimer ตามตัวพิมพ์ให้ตรง
3. One Shot = On และ Autostart = Off
4. บันทึกเป็น scenes/monster_spawner.tscn
5. สคริปต์เชื่อม timeout เอง ไม่ต้องเชื่อมใน Editor ซ้ำ

Scene ที่ให้มาทำขั้นตอนเหล่านี้แล้ว และเลือก wild_monster.tscn เป็นค่าเริ่มต้น
@tool แสดงวงสีเขียวใน Editor และไม่สร้างมอนสเตอร์ใน Editor
ใช้ Scale (1,1) เพื่อให้วงที่เห็นตรงกับรัศมีพิกัดโลก

## จัดวางในแผนที่

| Node | ชนิด | หน้าที่ |
|---|---|---|
| World | Node2D | ฉากแผนที่ |
| World/Actors | Node2D | รวม Tamer, Partner และศัตรู; เปิด Y Sort |
| World/Spawners | Node2D | รวมจุดเกิด |
| World/Spawners/SpawnerA | Instance ของ monster_spawner.tscn | จุดเกิด A |
| World/Spawners/SpawnerB | Instance ของ monster_spawner.tscn | จุดเกิด B |
| World/DamagePopups | Node2D | ชั้นตัวเลขดาเมจ |

ลาก monster_spawner.tscn ลง Spawners → ย้ายตำแหน่ง → ตั้งค่าผ่าน Inspector
เลือก Spawner แล้ว Ctrl+D เพื่อเพิ่มจุดใหม่ ย้ายและปรับค่าของแต่ละจุดได้
วางวงรัศมีให้ครอบเฉพาะพื้นที่เดินได้ในแผนที่

## Inspector

| Property | ค่าเริ่มต้น | ความหมาย |
|---|---|---|
| monster_scene | wild_monster.tscn ใน Scene ตัวอย่าง | PackedScene ที่จะสร้าง |
| spawn_radius | 100 | สุ่มจุดเกิดในวง และกำหนดรัศมี Wander |
| respawn_time | 5 | เวลารอหลังตาย เป็นวินาที |
| monster_parent | World/Actors ในฉากตัวอย่าง | Parent ของมอนสเตอร์ที่เกิด |
| popup_layer | World/DamagePopups | ส่งต่อให้มอนสเตอร์แสดง Damage Popup |

monster_parent ไม่กำหนดได้ มอนสเตอร์จะเป็นลูกของ Spawner
กำหนดเป็น Actors เมื่อใช้ Y Sort เพื่อเรียงตัวละครร่วมกัน
popup_layer ใช้เชื่อม Damage Popup รุ่นเดิม
แต่ละจุดเลือก PackedScene ต่างกันได้ เช่น slime.tscn / wolf.tscn
Root ของ PackedScene ต้องใช้ WildMonster script หรือสืบทอดจาก WildMonster

## วงจรทำงาน

1. _ready ตั้ง Timer.one_shot และเชื่อม timeout
2. call_deferred สร้างมอนสเตอร์หลัง Node อื่นใน World พร้อม
3. สุ่มมุมและระยะ sqrt(randf()) เพื่อกระจายสม่ำเสมอในพื้นที่วงกลม
4. แปลงจุดเกิดจากโลกเป็น local ของ monster_parent ก่อน add_child
5. เชื่อม died และ tree_exited พร้อมจำ instance id
6. เมื่อ died ล้าง reference ของตัวที่มีชีวิตและเริ่ม Timer
7. tree_exited ของตัวเดียวกันจะไม่เริ่ม Timer ซ้ำ เพราะ instance id ถูกเคลียร์แล้ว
8. timeout สร้าง instance ใหม่ HP จึงถูกตั้งเต็มโดย WildMonster._ready
9. ทำซ้ำตลอดจนออกจากแผนที่หรือลบ Spawner

หากมี death animation ศพอาจยังอยู่ขณะเริ่มนับเวลา แต่ Spawner จะดูแลเฉพาะตัวที่มีชีวิต
WildMonster ต้องจัดการลบศพเองหลัง animation; รุ่นตัวอย่าง queue_free หลัง died ทันที
หากมอนสเตอร์ถูก queue_free โดยตรง tree_exited จะเริ่ม Respawn เป็น fallback
Timer นับตั้งแต่การตาย และไม่เริ่มจากเวลา Spawn

การป้องกันเกิดซ้อนมีสองส่วน:
- _spawn_monster ไม่สร้างเพิ่มถ้า current_monster ยัง valid
- instance id แยก signal ของตัวเก่าออกจากตัวใหม่ และกัน died/tree_exited เริ่มนับซ้ำ

## ปรับ WildMonster ให้เดินรอบจุดเกิด

เพิ่ม export ใน wild_monster.gd:

```gdscript
@export var home_anchor: Node2D
```

แทนบรรทัดจำตำแหน่งบ้านใน _ready:

```gdscript
_home = home_anchor.global_position if is_instance_valid(home_anchor) else global_position
```

Spawner จะส่ง home_anchor = self และ wander_radius = spawn_radius ให้ก่อน add_child
ทำให้สุ่มเดินรอบศูนย์กลาง Spawner ไม่ใช่รอบจุดสุ่มแรก ซึ่งอาจทำให้วงเดินขยายเกินรัศมีที่กำหนด
รัศมีนี้ใช้กับ Spawn และ Wander; การไล่คู่หูใน Battle ยังใช้ leash_distance ของศัตรู

## Signal ความตายที่ใช้กับ Spawner

WildMonster รุ่นเดิมมี:

```gdscript
signal died(enemy: WildMonster)

# ใน take_damage หลัง hp เหลือ 0 และสร้าง Damage Popup แล้ว
if hp == 0:
    ring.hide()
    collision_layer = 0
    died.emit(self)
    queue_free()
```

ต้องส่ง self ตาม signature นี้ และ emit เมื่อมอนสเตอร์ตายจริง
ไม่ต้องแก้คำสั่งโจมตีของ Partner

## ต่อกับระบบอื่น

```gdscript
# ใน _ready ของ World หรือระบบภายนอก
$Spawners/SpawnerA.monster_spawned.connect(_on_monster_spawned)

func _on_monster_spawned(monster: WildMonster) -> void:
    print("เกิดมอนสเตอร์ใหม่: ", monster.name)
```

current_monster ใช้อ่านตัวที่จุดนี้กำลังดูแลได้; เป็น null ขณะรอ Respawn
get_respawn_time_left() คืนวินาทีที่เหลือสำหรับต่อยอด UI และคืน 0 เมื่อไม่ได้รอ
อย่าเรียก _spawn_monster ทุก frame ระบบใช้ signal และ Timer อยู่แล้ว

## Pause และการเก็บกวาด

Timer อยู่ใน Spawner และใช้ process mode ที่สืบทอดจาก World
SceneTree.paused = true จะหยุดการนับในฉากตัวอย่าง และนับต่อเมื่อ Resume
เมื่อ Spawner ออกจาก SceneTree จะหยุด Timer และ queue_free มอนสเตอร์ที่ดูแล
จึงไม่เหลือศัตรูใน Actors แม้ monster_parent เป็น Node แยก
การเปลี่ยนแผนที่ไม่มี await Respawn ที่ลอยค้างอยู่นอก Scene

## ขอบเขตตัวอย่าง

การสุ่มตำแหน่งเป็นวงในพิกัดโลก ยังไม่มีการตรวจว่าจุดนั้นอยู่ในกำแพงหรือน้ำ
สำหรับแผนที่จริง วางรัศมีในพื้นที่เดินได้ หรือเพิ่มตัวกรอง physics/navigation ก่อนยืนยันจุดเกิด
ศัตรูเดโม Wander/ไล่เป้าหมายเป็นเส้นตรงในลานโล่ง หากมีเขาวงกตให้เพิ่ม NavigationAgent2D
หนึ่ง Spawner เกิดหนึ่งตัว; ใช้หลายจุดเพื่อเพิ่มจำนวนในแผนที่

## ตรวจสอบ

```bash
godot --headless --editor --import --quit
godot --headless res://tests/spawner_test.tscn
godot --headless res://tests/smoke_test.tscn
godot --headless res://tests/damage_popup_test.tscn
```

ทดสอบเกิดเริ่มต้น, รัศมีและบ้าน, กันเกิดซ้อน, died/tree_exited ไม่รีเซ็ตเวลา,
Respawn หลายรอบ, หลายจุดอิสระ, การลบโดยตรง, parent transform, radius=0,
Pause/Resume, standalone และออกจาก World ขณะรอเกิด
พร้อมตรวจ AI/DS/Digivolve/สกิลและ Damage Popup เดิม
ทดสอบด้วย Godot 4.4.1 headless ยังไม่ได้ทดสอบบนมือถือจริง

เอกสาร:
- https://docs.godotengine.org/en/4.4/classes/class_timer.html
- https://docs.godotengine.org/en/4.4/classes/class_node.html
