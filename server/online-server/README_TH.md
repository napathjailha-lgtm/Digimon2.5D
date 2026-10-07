# Prism Tamer Online Server

Phase 1 รองรับ:
- Online presence
- Sync ตำแหน่ง/ทิศทาง
- Join/Leave
- Chat ตาม zone

ยังไม่ sync combat, loot, Bits, inventory หรือ save

## ติดตั้งบน aaPanel

1. ติดตั้ง Node.js 22+ และสร้าง Node Project ที่โฟลเดอร์นี้
2. รัน:
   npm ci --ignore-scripts
3. Startup file:
   server.js
4. PORT:
   8787
5. เปิด Reverse Proxy จากโดเมน HTTPS ไปที่:
   http://127.0.0.1:8787
6. เปิด WebSocket support ใน Nginx/aaPanel
7. ตั้งค่า Godot:
   online/server_url="wss://online.example.com"
   online/auto_connect=true

GitHub Pages ใช้ HTTPS ดังนั้น Production ต้องใช้ wss:// เท่านั้น


## ความปลอดภัยของ Online (2026-10-07)

- Trade ปิดชั่วคราวทั้ง client และ server รวมถึงคำสั่งจาก client รุ่นเก่า
  เพราะไอเทม/Bits และเซฟยังอยู่บนเครื่องผู้เล่น ไม่มี ledger ที่เซิร์ฟเวอร์ตรวจสอบได้
  ห้ามเปิดการโอนใหม่จนกว่าจะมีบัญชีทรัพย์สินฝั่งเซิร์ฟเวอร์และธุรกรรมถาวรที่ทำซ้ำได้อย่างปลอดภัย
  การเพิ่ม ACK อย่างเดียวไม่ทำให้การโอน local save ปลอดภัย
- Online เฉพาะตอนอยู่ใน world; ออกจาก world/logout จะส่ง leave และปิด socket
- ตัวละครเดียวเปิดได้ session เดียว: session ใหม่แทนที่อันเก่า อันเก่าไม่ reconnect อัตโนมัติ
  UID แบบสุ่มยังเป็น identity ของ local/demo ไม่ใช่ระบบบัญชีที่ยืนยันเจ้าของบนเซิร์ฟเวอร์
  ควรรันเพียงหนึ่ง instance จนกว่าจะมี shared session registry
- Server ping ทุก 30 วินาที และลบ socket ที่ไม่ตอบรอบถัดไป
- `npm test` ทดสอบ Trade ที่ปลอมขึ้น, identity ซ้ำ, leave/reconnect, guild isolation และ heartbeat
- `/health` แสดง `release`, `commit` (จาก Railway), และ `capabilities.trade: false`

## Deploy และตรวจเวอร์ชัน

GitHub Pages deploy ตัวเกมเมื่อ merge เข้า main ส่วน Railway ต้อง deploy service
จาก root directory `server/online-server` ใน commit เดียวกัน (Auto Deploy หรือ Redeploy)
ตรวจ `/health` ว่า `release` เป็น `online-safety-2026-10-07` และ commit ตรงกับ main
ก่อนถือว่าปิดช่องโหว่ฝั่ง server แล้ว การ deploy Pages อย่างเดียวไม่อัปเดต server
