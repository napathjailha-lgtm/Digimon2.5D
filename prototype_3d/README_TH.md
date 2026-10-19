# Prism Tamer 3D — Prototype (Godot 4)

โฟลเดอร์นี้เป็นโปรเจกต์ทดลอง 3D แยกจากเกมเดิม Digimon2.5D เพื่อไม่ทำให้โปรเจกต์ 2D/2.5D เดิมเสียหาย

## เปิดโปรเจกต์
1. ติดตั้ง Godot 4.x รุ่นเสถียร (แนะนำ Godot 4.4 ขึ้นไป)
2. ใน Project Manager เลือก Import แล้วเลือกไฟล์ prototype_3d/project.godot
3. กด F5 เพื่อรัน

## Controls
- WASD: เดิน
- เมาส์: หมุนกล้อง (Esc ปล่อยเมาส์)
- Space: สั่งคู่หูโจมตีเป้าหมายที่อยู่ใกล้ที่สุด
- E: วิวัฒนาการต้นแบบ

## Multiplayer LAN (ทดลอง)
- เปิดเกมหน้าต่างแรก กด Host LAN
- เปิดเกมอีกหน้าต่างบนเครื่องเดียวกัน แล้วกด Join 127.0.0.1
- เครื่องอื่นใน LAN ต้องแก้ IP ในปุ่ม Join ให้ตรงกับ IP เครื่อง Host และเปิด UDP port 8910 ใน firewall
- ระบบนี้เป็น proof-of-concept สำหรับส่งตำแหน่งผู้เล่นเท่านั้น ยังไม่ใช่เซิร์ฟเวอร์ MMORPG production

## ข้อจำกัด
- โมเดลเป็น placeholder จาก primitive meshes ยังไม่ใช่โมเดล anime คุณภาพสูง
- Network ยังไม่มี authoritative server, account/login, persistence, anti-cheat หรือ replication ของ combat/companions/enemies
- ยังไม่ได้รัน Godot headless หรือทดสอบ runtime ในสภาพแวดล้อมนี้ จึงยังยืนยันว่า prototype ผ่านการทดสอบไม่ได้
- ยังไม่มีการ Deploy หรือแก้ไข branch main
