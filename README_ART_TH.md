> เวอร์ชันนี้เป็น v8 อ่าน README_RECOVERY_LEVEL_CUTSCENE_TH.md สำหรับระบบคู่หูเป็นไข่ เลเวล และคัตซีนล่าสุด

# Story Quest พร้อมภาพเกม — v7

## เปิดเล่น

แตก ZIP ลงโฟลเดอร์ใหม่ Import project.godot ใน Godot 4 แล้วกด F5
ฉากหลัก story_boot.tscn จะเปิดโซนตาม Save หากไม่มี Save จะเริ่มจาก File Island
เควสต์ การนำทาง Joystick การต่อสู้ เปลี่ยนร่าง Respawn และ Damage Popups ทำงานต่อจาก v6
อ่าน README_STORY_QUESTS_TH.md สำหรับระบบเควสต์และการเชื่อมต่อกับเกมเดิม

## ภาพที่เพิ่ม

- assets/art/file_island.png — ป่าเกาะเขตร้อน
- assets/art/server_continent.png — ลานทะเลทรายกับซากโบราณ
- assets/art/odaiba.png — พลาซาเมืองริมอ่าวยามเย็น
- assets/art/spiral_mountain.png — ลานภูเขาหินและคริสตัลสีม่วง
- assets/art/characters.png — Atlas พื้นหลังโปร่งใส 16 สไปรต์

ภาพทั้งหมดเป็นงานใหม่ที่สร้างด้วย imagegen แบบ built-in ไม่ใช่ภาพที่นำมาจากไฟล์เกม DMO หรืออนิเมะ ภาพตัวละครเป็นต้นฉบับธีมโลกดิจิทัล ส่วนระบบเควสต์ยังใช้ ID/ชื่อจากตัวอย่างเนื้อเรื่องก่อนหน้า

Atlas ประกอบด้วย Tamer 4 ทิศ, คู่หู 4 ร่าง, บอส 4 แบบ, มอนสเตอร์ป่า 2 แบบ และ NPC 2 แบบ ดู PROMPTS_ART.md สำหรับชุด prompt ที่ใช้สร้างภาพ

Godot อ่านแต่ละตัวผ่าน AtlasTexture (.tres) ใน assets/art โดยแชร์ PNG เดียวกัน ไม่ต้องตัด PNG เอง พิกัด region กำหนดตามขอบเขต alpha ของแต่ละภาพ แยกได้ครบ 16 ตัว และจัด Origin ให้อยู่ใต้เท้า

MonsterData ของ Rookie, Champion, Ultimate และ Mega ใช้ SpriteFrames ต่างกันจริง ร่าง Ultimate/Mega มีภาพเฉพาะของตัวเอง ไม่ใช้ภาพ Champion ขยายแทน

Tamer เปลี่ยนภาพหน้า/ขวา/หลัง/ซ้ายตาม velocity ส่วนศัตรูและคู่หูพลิกภาพตามแนวนอน มีเงาใต้เท้าช่วยอ่านตำแหน่ง

## สิ่งที่ยังต้องต่อยอด

ตัวละครเป็นสไปรต์นิ่งต่อ state ยังไม่ใช่แอนิเมชันเดินหรือโจมตีหลายเฟรม ชื่อ idle/walk/attack ใน SpriteFrames ใช้เชื่อมระบบเดิม แต่แต่ละ state มีหนึ่งเฟรม

ฉากเป็น Texture พื้นหลังหนึ่งภาพต่อลาน ไม่ใช่ TileMap แยกชิ้น พื้นที่เดินใช้ NavigationPolygon เดิม รายละเอียดต้นไม้ อาคาร และขอบหน้าผาในภาพเป็นของตกแต่ง ถ้าขยายเป็นแผนที่จริงให้วาง Collider และ bake Navigation ตามพื้นที่ที่ต้องการกั้น

TouchTarget ของศัตรูครอบภาพทั้งตัว แยกจาก Collider ฟิสิกส์ใต้เท้า ทำให้แตะส่วนหัวหรือลำตัวเลือกเป้าหมายได้ NPC ใช้ขอบเขตแตะตามขนาดภาพเช่นกัน

ไม่รวมคัตซีนหรือเอฟเฟกต์สกิลแบบภาพหลายเฟรม ยังใช้ UI เดิมของระบบตัวอย่าง

## ตรวจสอบ

ทดสอบด้วย Godot 4.4.1 stable แบบ headless เปิด Import จากโปรเจกต์ใหม่ และทดสอบ story_quest_test, smoke_test, damage_popup_test, spawner_test กับ art_integration_test

```sh
godot --headless --editor --import --quit
godot --headless res://tests/art_integration_test.tscn
godot --headless res://tests/story_quest_test.tscn
godot --headless res://tests/smoke_test.tscn
godot --headless res://tests/damage_popup_test.tscn
godot --headless res://tests/spawner_test.tscn
```

ยังไม่ได้ทดสอบการแสดงผลและประสิทธิภาพบนมือถือจริง
