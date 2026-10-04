# เริ่มใช้ v16 — ระบบก่อนเข้าเกม

## เริ่มเล่น

1. แตก ZIP ลงโฟลเดอร์ใหม่ `mobile_pregame_v16`
2. Godot Project Manager → Import → เลือก `project.godot` ของ v16
3. ใช้ Godot Standard 4.4.1 ขึ้นไป และรอ Import SVG/Texture ให้เสร็จ
4. กด F5 เกมเริ่มที่ `scenes/pregame/loading_screen.tscn`
5. Login จำลอง เช่น Username `demo`, Password `demo` เลือก File Island Server 1 หรือ 2
6. เลือกช่องว่าง → เลือกโมเดล Tamer → กรอกชื่อ 2–16 ตัวอักษร → สร้างตัวละคร
7. เลือก Starter 1 ใน 5 ตัว ดู Evolution Path/HP/ATK/SPD/สกิล → ยืนยัน
8. Loading เข้าแผนที่จริง พร้อม Tamer/Partner ที่เลือกและอุปกรณ์เริ่มต้นในกระเป๋า

ตัวละครเก่าที่มีในช่องจะมีปุ่ม **เข้าสู่โลกดิจิตอล** และข้ามหน้า Starter
ในสนามมีปุ่ม **เลือกตัวละคร** ตรงกลางด้านบนเพื่อกลับออกมา เซฟ Progress ก่อนเปลี่ยน Scene
กด **ย้อนกลับ** บนหน้า Character เพื่อ Logout ไป Login; ย้อนกลับจาก Starter ไม่ใช้ช่องและเก็บ draft ชื่อ/โมเดลให้แก้ต่อ
Esc / Android Back ใช้ย้อนกลับในหน้าที่รองรับ ไม่กดออกเกมขณะกำลังพิมพ์

## ข้อมูลที่มีให้

- Tamer: ไทจิ, ยามาโตะ, โซระ, โคจิโร่, มีมี่ — มีภาพต้นแบบ/ชุดเดินแยก และฐาน HP/DS/ความเร็วต่างกัน
- Starter: Agumon, Gabumon, Piyomon, Tentomon, Palmon — แต่ละตัวมี Rookie → Champion → Ultimate, สกิล และค่าต่อสู้ของตนเอง
- แต่ละบัญชีและ Server มี 5 ช่องตัวละคร ช่องตัวละครต่างจาก 5 โมเดลต้นแบบ
- Champion ใช้ DS เปลี่ยนร่างตามระบบเดิม; Ultimate ต้องปลดล็อกเควสต์เนื้อเรื่องเดิม
- ภาพโมเดลใหม่เป็น SVG ต้นแบบ ท่าเดิน/ท่าตี/ร่ายเป็นตัวอย่างสำหรับทดสอบ Flow เปลี่ยน `portrait`, `sprite_frames` และ `sprite_scale` ใน Resource เพื่อใส่งานจริง
- Archetype เป็นค่าตั้งต้นของสเตตัส ไม่บังคับคลาส และยังไม่เพิ่มสกิลโจมตี/ฮีลให้ Tamer

## เซฟและผู้เล่น v15

Application name เดิมยังเป็น Digital Adventure Form Skills เพื่ออ่าน `user://` เดิมได้
เซฟใหม่แยกเป็น `user://profiles/<hash บัญชี+Server>/roster.json` และ `slot_1_story.json` ถึง `slot_5_story.json`
ข้อมูล Quest/HP/DS/เลเวล/ร่าง/อุปกรณ์ยังใช้ party profile ของ QuestManager เดิม
ถ้ามีเซฟเดิม `user://story_progress.json` จะมีปุ่ม **นำเข้าเซฟ v15** เมื่อเลือกช่องว่าง
ปุ่มนี้คัดลอกข้อมูลไป slot ใหม่และเก็บต้นฉบับไว้ ผู้เล่นนำเข้าจะใช้ฐานสเตตัสและภาพ/สายร่างเดิมครบ
เพียง Login username เดิมและ Server เดิมก็จะได้รายชื่อตัวละครเดิมกลับมา
โมเดล Tamer ใหม่ทั้ง 5 แบบมีชุดเดินต้นแบบแยก และถูกส่งเข้า gameplay ตามที่เลือกจริง
Password เป็นการจำลอง ไม่ได้ตรวจยืนยันบัญชีจริงและไม่บันทึกลงไฟล์

## ขอบเขตการทดสอบ

ใช้ Godot 4.4.1 บน Linux ทดสอบแบบ headless และใช้ X11 Compatibility เรนเดอร์ UI Native
ทดสอบ ScreenTouch จริงใน pipeline input จำลอง รวมถึงการเปลี่ยน Scene และ disk save/load
ไม่ได้ทดสอบ APK บนโทรศัพท์จริง และ Login/Server เป็นข้อมูล local สำหรับต้นแบบเท่านั้น
ผลทดสอบอยู่ใน `PREGAME_TEST_RESULTS.json` และ logs ที่ `docs/test_logs/`

ทดสอบระบบเดิมตรง ๆ ด้วย F6 ที่ `scenes/world.tscn` ได้; F5 ใช้ Flow ใหม่ครบทุกขั้น
