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


## Encrypted JSON Storage

Production ใช้ JSON บน Railway Volume `/data` เป็น storage ชั่วคราวก่อนย้าย PostgreSQL:

- `accounts.json`
- `characters.json`
- `inventories.json`
- `partners.json`
- `guilds.json`
- `transactions.json`

ทุกไฟล์เขียนเป็น encrypted envelope ด้วย **AES-256-GCM** ไม่เก็บข้อมูลผู้เล่นเป็น plaintext
และใช้ authentication tag เพื่อตรวจว่าข้อมูลถูกแก้ไขหรือเสียหายหรือไม่

ต้องตั้ง Environment Variable บน Railway:

```
DATA_ENCRYPTION_KEY=<32-byte secret>
```

รองรับค่าแบบ 64 hex characters หรือ base64 ที่ decode แล้วได้ 32 bytes
ห้าม commit key ลง GitHub และห้ามส่ง key ไปที่ Godot client

เมื่อ server รุ่นนี้เจอ `guilds.json` แบบ plaintext รุ่นเดิม จะอ่านข้อมูลเดิมและเขียนกลับ
เป็น AES-256-GCM โดยอัตโนมัติในครั้งแรก เพื่อรักษาข้อมูลกิลด์เดิมไว้

หาก key หายหรือเปลี่ยนโดยไม่มี migration key เดิม ข้อมูลเดิมจะถอดรหัสไม่ได้
server จึง fail closed และไม่ reset ข้อมูลทิ้งอัตโนมัติ

ขณะนี้ server เริ่มสร้าง secure character shell และพื้นที่สำหรับ inventory/partner/transaction แล้ว
แต่ economy จาก local save ยังถือว่ายังไม่ได้ migrate (`migrated: false`) ดังนั้น Trade ยังคงปิดอยู่
จนกว่า Bits/Item/Equipment/Partner ทั้งหมดจะถูกย้ายมาเป็น server-authoritative จริง


## Server Economy Migration

รุ่น `online-economy-json-2026-10-07` เพิ่ม profile ต่อ Character ที่
`/data/profiles/<online_uid>.json` และเข้ารหัส AES-256-GCM เหมือน store อื่น

ลำดับการทำงาน:
1. Character เชื่อม Online และได้รับ `economy_snapshot`
2. ถ้ายังไม่เคย migrate, client ส่ง local snapshot เดิมขึ้น Server **ครั้งเดียว**
3. Server sanitize ข้อมูลและบันทึก revision 1
4. หลังจากนั้นทุก update ต้องระบุ revision ปัจจุบัน
5. packet เก่าหรือ revision ไม่ตรงจะถูกปฏิเสธและ Server ส่ง snapshot ล่าสุดกลับ
6. เวลาเข้าเกมครั้งถัดไป Server snapshot เป็น source of truth สำหรับ Bits, Inventory,
   Equipment, Incubator และ Partner roster/progression

Server จำกัด schema/จำนวน stack/จำนวน item/slot/Partner roster และ clamp ค่าตัวเลข
ก่อนเขียนไฟล์ ไม่เขียน JSON ที่ client ส่งมาตรง ๆ

ข้อจำกัดด้าน Anti-Cheat:
- การ migrate ครั้งแรกจำเป็นต้องเชื่อ legacy local save เพื่อรักษาของผู้เล่นเดิม
- หลัง migration Server เป็น source of truth ด้าน persistence และ revision ordering
- แต่ Combat, Loot drop, Quest reward และ Shop action ยังเกิดจาก client gameplay
  ดังนั้น client ที่ถูกดัดแปลงยังอาจสร้าง mutation ปลอมได้
- **Trade ยังคงปิด** จนกว่า reward/spend/item mutation จะถูกเปลี่ยนเป็น server-validated events
  และ transaction ledger สามารถ commit สองผู้เล่นแบบ atomic/idempotent ได้
