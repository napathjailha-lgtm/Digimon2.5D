# Prism Tamer Online Server

Phase 1 รองรับ:
- Online presence
- Sync ตำแหน่ง/ทิศทาง
- Join/Leave
- Chat ตาม zone

ยังไม่ sync combat, loot, Bits, inventory หรือ save

## ติดตั้งบน aaPanel

1. ติดตั้ง Node.js 20+ และสร้าง Node Project ที่โฟลเดอร์นี้
2. รัน:
   npm install
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
