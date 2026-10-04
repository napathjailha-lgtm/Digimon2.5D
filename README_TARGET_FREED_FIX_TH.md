# Hotfix สำหรับ v11: Target ถูกลบแล้ว HUD error

## การติดตั้งแพตช์

หยุดเกมใน Godot แล้วคัดลอกสองไฟล์ในโฟลเดอร์ scripts/ ของ ZIP นี้ ไปแทนไฟล์ชื่อเดียวกันใน res://scripts/ ของโปรเจกต์ v11 จากนั้นกด F5 ใหม่

- scripts/mobile_hud.gd
- scripts/tamer.gd

แพตช์นี้ไม่มีภาพหรือ Resource ชุดใหม่ ใช้กับโปรเจกต์ Godot4_FormCombat_Projectiles_v11 เดิม

## สาเหตุและสิ่งที่แก้

_refresh_target(enemy: WildMonster) ตรวจชนิดพารามิเตอร์ก่อนเข้าไปถึง is_instance_valid() เมื่อศัตรู queue_free แล้ว HUD ยังอ่าน Tamer.target เดิม จึงเกิด Invalid type ... previously freed

เปลี่ยนพารามิเตอร์เป็น Variant แล้วตรวจ is_instance_valid / class / is_queued_for_deletion / HP ก่อนแปลงเป็น WildMonster และอ่านค่าเลือด

Tamer เพิ่ม get_target() เพื่อคืนเฉพาะเป้าหมายที่ยังอยู่ในฉากและมีชีวิต ส่วน set_target() เชื่อม tree_exiting เพื่อให้ล้างเป้าก่อน Node ถูก free จริง callback ผูก instance ID เพื่อไม่เก็บ Object ไว้ และตัดการเชื่อมกับศัตรูเก่าเมื่อเลือกศัตรูใหม่

command_attack() และ command_skill() ส่งผลจาก get_target() ไม่ส่ง reference เก่าเข้าพารามิเตอร์ที่บังคับเป็น WildMonster

## ผลทดสอบ

Godot 4.4.1 / headless / fixed-fps 60:

- target_freed_test.tscn ผ่าน 15 จุด: ศัตรูตาย, callback ใช้ freed reference, queued deletion, ลบ Node ตรง, remove_child, เลือกศัตรูใหม่ก่อนตัวเก่าตาย, อัปเดตหลอด HP เป้าใหม่ และกดสกิลหลังเป้าหมายหาย
- HUD / Projectile / Smoke / Animation & Skills / Story Quest ผ่านทั้งหมด รวม 222 จุดตรวจใน 6 Scene
- ทุก Scene รายงาน RESULT: 0 failure(s) และไม่มี SCRIPT ERROR

README นี้และ regression test อยู่ในโปรเจกต์เต็มฉบับปรับปรุงด้วย
