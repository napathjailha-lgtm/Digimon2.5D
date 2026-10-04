# Digital Adventure — Anime Characters v22

## เริ่มใช้งาน
เปิด project.godot ด้วย Godot 4.4.1 Standard แล้วรอ import จากนั้นกด F5
ไฟล์ APK v22 ใช้ package และลายเซ็นเดียวกับ v21 จึงติดตั้งอัปเดตทับได้
บัญชีทดสอบ: demo / demo; ระบบล็อกอินเป็นการจำลองแบบออฟไลน์

## ภาพใหม่
- Tamer: ไทจิ, ยามาโตะ, โซระ, โคจิโร่ และมีมี่
- คู่หูเริ่มต้น: Agumon, Gabumon, Piyomon, Tentomon และ Palmon
- ร่าง Champion / Ultimate ของทั้ง 5 สาย รวม 15 ร่าง
- WarGreymon สำหรับร่าง Mega ของสายสำรองเดิมในฉาก World/F6
- Agumon NPC, ภาพหน้าเลือกตัวละคร, รูป HUD และภาพในคัตซีนใช้ดีไซน์เดียวกับในสนาม

สร้างภาพด้วยเครื่องมือ image_gen แบบ built-in เป็น PNG ที่มี alpha โปร่งใส
ภาพทั้งหมดและ portrait อยู่ใน assets/anime_v22/
ชุดคำสั่งสร้างภาพสุดท้ายเก็บใน ANIME_IMAGE_PROMPTS_V22.json
ตำแหน่งเฟรมและสเกลเก็บใน ANIME_ATLAS_METADATA_V22.json
ภาพตัวอย่างจากการรัน Godot อยู่ใน docs/previews/anime_v22/

## การจัดแอนิเมชัน
- มี Idle / Walk 4 ทิศ; ซ้ายใช้ภาพด้านขวาร่วมกันแล้ว flip_h
- Partner มี Attack / Cast 4 ทิศ และปิด loop ของ action
- Attack และ Cast ใช้ 4 เฟรม จังหวะกระทบและปล่อยพลังยังอยู่เฟรม 2
- แต่ละเฟรม trim ตาม alpha แล้วเพิ่ม AtlasTexture.margin เพื่อปักเท้าไว้ที่ origin
- ภาพของแต่ละสายใช้ texture atlas ร่วมกัน ไม่สร้าง texture ใหม่ทุกเฟรม
- ยังใช้ระบบเดิน / Follow AI / สกิล / MP / DS / เปลี่ยนร่าง / ฟื้นฟูเดิม
- เงาและแสงในฉากยังทำงานร่วมกับภาพใหม่

## เตรียม Resource ใหม่ด้วยภาพชุดนี้
ใช้ python3 tools/build_anime_resources.py จาก root ของโปรเจกต์
ต้องติดตั้ง Pillow และ NumPy สำหรับเครื่องมือเตรียมภาพเท่านั้น เกมไม่ต้องใช้ Python
สคริปต์นี้อ่าน alpha และสร้าง .tres; ไม่วาดใหม่หรือแก้พิกเซล PNG ที่สร้างมา

## Export Android
ติดตั้ง Godot 4.4.1 export templates, Java 17 และ Android SDK แล้วตั้ง path ใน Editor Settings
ใช้ preset Android Test และเปิด Export With Debug
preset ใช้ ARM32 + ARM64 และ Compatibility renderer ไม่ต้องเปิด Gradle Build
กุญแจทดสอบอยู่ใน android_signing/ (alias androiddebugkey / password android)
กุญแจนี้เก็บไว้สำหรับอัปเดต APK ทดสอบด้วยลายเซ็นเดิม

## ผลตรวจ
ผ่าน 269 assertions จาก 5 suites: pregame, smooth walk, combat actions, survival และ pseudo3D
รันและจับภาพหน้าจอจาก Godot Compatibility ผ่าน
APK ผ่าน CRC, zipalign และตรวจลายเซ็น v1/v2/v3
ยังไม่ได้ทดสอบการเล่นบนโทรศัพท์ Android จริง
