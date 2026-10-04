# v12 — เดินต่อเนื่องและมีเฟรมก้าวจริง

เปิด `project.godot` ในโฟลเดอร์ mobile_smooth_walk_v12 ด้วย Godot 4.4.1 แล้วกด F5
ควรเปิดรุ่นนี้เป็นโปรเจกต์แยก เพื่อไม่สับสนกับ v11 ที่มีเฟรมเดินเดียว
ชื่อแอปเดิมยังเหมือนเดิมเพื่อให้ใช้ user:// และ Save เดิมได้

## สิ่งที่แก้

- Tamer ใช้ acceleration/braking ตาม delta แทนกระโดดเป็นความเร็วเต็ม และยังรักษาน้ำหนักการลาก Joystick
- คู่หูรักษา velocity ระหว่างเฟรม ตามความเร็ว Tamer และลดความเร็วเมื่อใกล้จุดหยุด จึงไม่วิ่ง–หยุดเป็นช่วง ๆ ในทางโล่ง
- CharacterBody2D ใช้ MOTION_MODE_FLOATING สำหรับ top-down ทั้งสองตัว
- เปิด physics interpolation สำหรับการวาดระหว่าง physics ticks; ฟิสิกส์ยังทำงาน 60 ครั้งต่อวินาที
- Tamer และ Rookie/Champion/Ultimate/Mega มีภาพเดินใหม่ตัวละ 4 ทิศ × 4 เฟรม พร้อม idle ตามทิศล่าสุด
- AtlasTexture ใช้ margin ขนาดเฟรมคงที่และจุดเท้าเดียวกัน; DirectionalAnimator รักษาจังหวะก้าวเมื่อเปลี่ยนทิศ และปรับ speed_scale จากความเร็วที่เดินได้จริงหลังชน
- Portrait, nameplate และภาพคัตซีนอ่านเฉพาะบริเวณภาพที่มองเห็น เพื่อไม่ให้ padding ของเฟรมเดินทำให้ตัวละครเล็กเกินไป

## ดูความต่างทันที

1. F5 เล่นเกม ใช้ Joystick ลากเบา/เต็ม ปล่อยนิ้ว และเลี้ยวกลับ
2. เปิด `tools/movement_preview.tscn` แล้ว F6: ดู Tamer เดินรอบสี่เหลี่ยมและคู่หูตามในสนามจริง ใช้ Save แยกของพรีวิว
3. เปิด `tools/walk_preview.tscn` แล้ว F6: ดูภาพทุกตัววน 4 ทิศพร้อมกัน ฉากนี้ตรวจแอนิเมชัน ไม่ใช่การจำลอง AI
4. เปิดคลิปใน `preview/` ดูภาพจาก renderer ของ Godot

## ปรับความรู้สึกใน Inspector

Tamer: acceleration 1600 px/s², braking 2800 px/s², move_speed 190 px/s
ใช้เวลาประมาณ 0.12 วินาทีถึงความเร็วเต็ม และประมาณ 0.07 วินาทีหยุดจากความเร็วเต็ม
Partner: acceleration 2000, braking 3000; follow_start_distance 100 และ follow_stop_distance 58
เพิ่ม acceleration หากต้องการตอบสนองไวขึ้น เพิ่ม braking หากต้องการหยุดไวขึ้น
SpriteFrames ตั้ง walk 12 FPS ที่ความเร็วอ้างอิงของตัวนั้น; ไม่ต้องตั้ง sprite.speed_scale เองทุกเฟรม

## ไฟล์สำคัญ

`scripts/smooth_motion.gd` คำนวณการเร่ง/เบรกและระยะหยุด
`scripts/tamer.gd` / `scripts/partner_monster.gd` เชื่อมการเดินกับระบบเดิม
`scripts/directional_animator.gd` จัดการทิศ จังหวะก้าว และความเร็วแอนิเมชัน
`data/*_frames.tres` และ `assets/walk/` คือ SpriteFrames/AtlasTexture/ภาพเดินใหม่
`tools/build_walk_resources.py` อ่าน alpha แล้วสร้าง Resource ใหม่ โดยไม่แก้พิกเซลต้นฉบับ
ตัวสร้าง Resource ใช้ Pillow/numpy/scipy เฉพาะตอนเตรียมภาพ; เปิดเกมใน Godot ไม่ต้องติดตั้ง Python
`PROMPTS_WALK_V12.md` อธิบายที่มาภาพและข้อกำหนดที่ใช้สร้าง
`CHANGED_FILES_V12.json` เทียบ SHA-256 กับไฟล์ v11 ฉบับล่าสุด

## ผลตรวจ

Godot 4.4.1: 9 ฉากทดสอบ รวม 300 ข้อ ผ่านทั้งหมด ดู `SMOOTH_WALK_TEST_RESULTS.json`
คู่หูเดินตามต่อเนื่อง 2 วินาที ในทางโล่ง: หลังช่วงเร่งไม่มีเฟรมหยุด ระยะห่างประมาณ 55–76px
ตรวจภาพจริงด้วย Compatibility renderer ทั้งในสนามและฉากพรีวิวแอนิเมชัน
ผลนี้ไม่ใช่ผลวัด FPS บน Android; ควรลองบนมือถือเป้าหมายเพื่อประเมินความรู้สึกของนิ้วและอัตราเฟรม
ภาพใหม่เป็นชุดต้นแบบ 4 เฟรมต่อทิศ สามารถเปลี่ยนเป็นชุดวาดละเอียด 6–8 เฟรมได้โดยใช้ระบบเดิม
เอกสาร README และผลทดสอบของ v11 ที่ยังอยู่ในแพ็กเป็นประวัติของระบบก่อนหน้านี้
