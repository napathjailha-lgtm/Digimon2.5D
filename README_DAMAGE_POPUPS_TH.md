> เวอร์ชันนี้เป็น v8 อ่าน README_RECOVERY_LEVEL_CUTSCENE_TH.md สำหรับระบบคู่หูเป็นไข่ เลเวล และคัตซีนล่าสุด

> โปรเจกต์นี้เป็น v7 พร้อมภาพเกม อ่าน README_ART_TH.md สำหรับภาพและการเปิดเล่นล่าสุด

> คู่มือระบบก่อนหน้า: โปรเจกต์ v6 เพิ่ม Story Quest อ่าน README_STORY_QUESTS_TH.md สำหรับขั้นตอนเปิดและใช้งานล่าสุด

# Damage Popups — Godot 4

เพิ่มจาก MonsterData รุ่น v3 โดยใช้ Tween แบบ Godot 4

## เปิดทดสอบ

แตก ZIP เป็นโฟลเดอร์ใหม่ → Import project.godot → กด F5
แตะมอนสเตอร์หรือกด Attack/Skill เพื่อให้คู่หูโจมตี ตัวเลขสีเหลืองจะ Pop ลอยและจางหาย
โค้ดคู่หูเดิมเรียก target.take_damage(amount, self) ได้ต่อ
และเรียก enemy.take_damage(30) แบบ argument เดียวได้ด้วย

## ไฟล์และ Node

| ไฟล์ | หน้าที่ |
|---|---|
| scripts/damage_popup.gd | Tween ตัวเลขและ queue_free ตัวเอง |
| scenes/damage_popup.tscn | Node2D ชื่อ DamagePopup + Label |
| scripts/wild_monster.gd | หัก HP และสร้าง Popup ที่ DamageOrigin |
| scenes/wild_monster.tscn | เพิ่ม Marker2D ชื่อ DamageOrigin |
| scenes/world.tscn | เพิ่ม DamagePopups เป็น Node2D แยกจาก Actors |

| Parent | Node ลูก | ชนิด |
|---|---|---|
| DamagePopup | Label | Label |
| WildMonster | DamageOrigin | Marker2D |
| World | DamagePopups | Node2D |

DamagePopups ต้องอยู่ในโลกเดียวกับศัตรู ไม่ใช้ CanvasLayer ของ HUD
จึงติดตาม Camera2D และ zoom ของแผนที่ตามปกติ
แยกจาก Actors ที่เปิด Y Sort และตั้ง z_index = 200 ให้แสดงเหนือมอนสเตอร์
DamagePopup มี z_index = 100 เพิ่มจาก parent และยังอยู่ใต้ CanvasLayer ของ HUD

## สร้าง Scene ตัวเลขเอง

1. สร้าง Scene ใหม่ Root Node2D ชื่อ DamagePopup
2. เพิ่ม Label ชื่อ Label เป็นลูก
3. ตั้ง Label position = (-80, -24), size = (160, 48)
4. Horizontal Alignment = Center, Vertical Alignment = Center
5. Font Size = 28, Font Outline Color สีดำ, Outline Size = 6
6. ตั้ง Mouse Filter = Ignore เพื่อไม่บล็อก Touch Target
7. ติด damage_popup.gd ที่ Root และบันทึก scenes/damage_popup.tscn

Label อยู่กึ่งกลางรอบจุดกำเนิดของ Node2D จึงขยายจากกลางตัวเลขได้
ไม่จำเป็นต้องคำนวณ pivot_offset ของ Label เพราะ Tween scale ที่ Node2D root
Popup เป็น child ของ Node2D ปกติ ไม่วางใน Container ที่อาจจัดตำแหน่งใหม่

## ตั้งค่าศัตรู

1. เพิ่ม Marker2D ชื่อ DamageOrigin เป็นลูกของ WildMonster
2. วางตรงหัว เช่น (0, -38) สำหรับ placeholder ชุดนี้
3. ปรับ Marker ใน Editor ตามความสูง Sprite ของคุณ
4. เพิ่ม Node2D ชื่อ DamagePopups เป็นลูก World
5. ที่ศัตรูแต่ละตัว ลาก World/DamagePopups ลง export property popup_layer
6. ผสาน take_damage และ _spawn_damage_popup จาก wild_monster.gd กับโค้ดศัตรูเดิม

ถ้าไม่ได้กำหนด popup_layer โค้ดจะใช้ current_scene ที่เป็น Node2D หรือ parent Node2D เป็น fallback
แนะนำกำหนด layer แยกเสมอเพื่อให้ลำดับการวาดชัดเจน

## ลำดับการสร้างที่สำคัญ

```gdscript
var popup: DamagePopup = DAMAGE_POPUP_SCENE.instantiate() as DamagePopup
popup.damage_amount = amount
popup.position = layer.to_local(damage_origin.global_position)
layer.add_child(popup)
```

ต้องกำหนด amount และ position ก่อน add_child เพราะ _ready ของ Popup เริ่ม Tween ทันที
หาก add_child ก่อน แล้วค่อยตั้งตำแหน่ง Tween อาจจำปลายทางจากจุดกำเนิดเดิม
ใช้ layer.to_local() เพื่อแปลงพิกัด Marker ในโลกเป็น local ของ parent ใหม่
Popup เป็นลูกของ layer ไม่ใช่ศัตรู จึงไม่ถูกลบเมื่อศัตรู queue_free และไม่วิ่งตามศัตรู

## Tween

ใช้ Node.create_tween() ซึ่ง bind กับ Popup นี้
เมื่อ Popup หรือ Scene ถูกลบ Tween จะถูกหยุดตามไปด้วย

| ช่วงเวลาเริ่มต้น | สิ่งที่เกิด |
|---|---|
| 0–0.10 วินาที | ขยายจาก 0.8 เป็น 1.25 ด้วย TRANS_BACK / EASE_OUT |
| 0.10–0.26 วินาที | กลับขนาด 1.0 |
| 0–0.80 วินาที | ลอยขึ้น 70 px และสุ่มซ้าย/ขวา |
| 0.44–0.80 วินาที | จาง alpha จาก 1 เป็น 0 |
| เมื่อทั้งลอยและจางจบ | queue_free() |

Tween แรกเปลี่ยน scale แบบ sequential
Tween ที่สองใช้ set_parallel(true) เปลี่ยน position และ modulate:a พร้อมกัน
Fade ใช้ set_delay() ให้เริ่มท้ายช่วง
chain().tween_callback(queue_free) รอให้ parallel group จบก่อนลบ
สอง Tween เปลี่ยนคนละ property จึงไม่มีการแย่งค่ากัน

## ลดการซ้อนของตัวเลข

- spawn_spread = 10: สุ่มจุดเริ่มแกน X ภายใน -10 ถึง +10
- horizontal_spread = 35: สุ่มระยะลอยซ้าย/ขวาภายใน -35 ถึง +35
- float_distance = 70: ระยะลอยขึ้น
- lifetime = 0.8: เวลาก่อนลบ
- text_color: สีตัวเลข

ค่าระยะเป็น local ของ layer ควรใช้ DamagePopups scale = (1,1) ในเกมปกติ
การสุ่มช่วยลดการซ้อน แต่ตัวเลขจาก hit พร้อมกันจำนวนมากยังอาจทับกันได้
ถ้าต้องการแยกแน่นอน สามารถต่อยอดระบบช่อง/เลนสลับกันหรือรวม damage ตามช่วงเวลา

## กติกาความเสียหาย

- amount <= 0 ไม่หัก HP และไม่สร้าง Popup
- ศัตรูตายแล้วไม่รับ hit เพิ่ม
- Popup แสดงค่าดาเมจของ hit เช่น 9999 แม้ศัตรูเหลือ HP 10
- คำนวณ HP ให้ไม่ต่ำกว่า 0
- เรียก _spawn_damage_popup ก่อน queue_free ศัตรู
- attacker เป็น optional เพื่อรองรับคำสั่งเดิมจาก Partner และรักษาระบบตีโต้

หากมี Defense/Critical ให้นำ final_damage หลังคำนวณส่งเข้า take_damage
หากต้องการตัวเลข HP ที่เสียจริง ให้ใช้ mini(amount, hp) ก่อนหัก HP เป็นค่าที่แสดงแทน

## การทดสอบ

```bash
godot --headless --editor --import --quit
godot --headless res://tests/damage_popup_test.tscn
godot --headless res://tests/smoke_test.tscn
```

ทดสอบ HP, ค่า Label, พิกัดใต้ parent transform, การ Pop/Float/Fade,
ศัตรูเดินแล้วตัวเลขไม่ตาม, hit สุดท้าย, burst หลาย hit, queue_free และไม่มี Tween ค้าง
smoke_test เดิมตรวจ AI/DS/Digivolve/Touch และสกิล
ทดสอบด้วย Godot 4.4.1 headless ยังไม่ได้ทดสอบอุปกรณ์มือถือจริง

เอกสาร:
- https://docs.godotengine.org/en/4.4/classes/class_node.html#class-node-method-create-tween
- https://docs.godotengine.org/en/stable/classes/class_tween.html
