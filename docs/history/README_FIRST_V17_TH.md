# เริ่มเล่น v17

1. แตก ZIP ลงโฟลเดอร์ใหม่ mobile_inventory_v17
2. Import project.godot ด้วย Godot Standard 4.4.1 แล้วรอ Import Assets
3. F5 เข้า Flow เดิม Username demo / Password demo เป็น Login จำลอง
4. ใช้บัญชีและ Server เดิม เลือกตัวละครเดิม หรือสร้าง Tamer/Starter ใหม่
5. ฆ่ามอนสเตอร์ป่า → เดินใกล้ Loot → แตะกระเป๋าใต้ปุ่มอุปกรณ์ด้านบนขวา
6. เลือกเนื้อ → ใช้: ฟื้น HP คู่หูสูงสุด 80 และลดหนึ่งชิ้น; HP เต็ม/สลบ/คัตซีนไม่กินไอเทม
7. เลือกไอเทม → ทิ้ง: วาง Loot หนึ่งชิ้นข้าง Tamer เก็บกลับได้หลังปิดหน้าต่าง
8. Scene สาธิต tools/inventory_preview.tscn → F6 ใช้เซฟแยกและ guaranteed loot

คู่มือผัง Node + Script ฉบับเต็ม: README_INVENTORY_LOOT_TH.md
เซฟ v15/v16 ใช้ได้ต่อ: ระบบอุปกรณ์เดิมยังใช้ equipment; inventory เก็บเนื้อ/ชิปเควสต์/ไข่แยกตามตัวละคร
รอบนี้ทำระบบถือครองไข่และชิป ไม่เพิ่มระบบฟักไข่หรือเควสต์ใช้ชิปอัตโนมัติ
ทดสอบ Linux headless ทั้งระบบเดิมและใหม่ ยังไม่ได้ทดสอบ APK บนมือถือจริง
