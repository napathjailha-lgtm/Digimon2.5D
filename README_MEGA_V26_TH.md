# v26 — Agumon / Gabumon ถึงร่าง Mega

แตก ZIP เป็นโฟลเดอร์ใหม่ แล้ว Import `mobile_mega_lines_v26/project.godot` ด้วย Godot 4.4.1 Standard
รอ Import ภาพให้เสร็จแล้วกด F5 เข้าเกมตามปกติ

| สาย | Rookie | Champion | Ultimate | Mega |
| --- | --- | --- | --- | --- |
| Agumon | Agumon | Greymon | MetalGreymon | **WarGreymon** |
| Gabumon | Gabumon | Garurumon | WereGarurumon | **MetalGarurumon** |

## วิธีพัฒนาเป็น Mega

ทำเควสต์ตามลำดับจนจบ **ปกป้องซากโบราณตะวันออก** (q07_myotismon) โดยปราบ Myotismon
เควสต์นี้ปลดล็อก Mega ของทั้งสองสาย จากนั้นอยู่ในร่าง Ultimate แล้วกด Evolve
ใช้ DS ของ Tamer 25 หน่วยในการเปลี่ยนร่าง และรักษาร่างด้วย DS 6 หน่วยต่อวินาทีตามค่าฐาน Mega เดิม
ต้องมี HP Tamer ตามเงื่อนไขต่อสู้เดิม และคู่หูต้องไม่เป็นไข่

WarGreymon ใช้ภาพเดิน/โจมตี/ร่ายจากชุดภาพเดิมที่มีอยู่แล้ว ส่วน MetalGarurumon มีภาพ PNG ใหม่ 18 ท่า
ใช้ AtlasTexture และ SpriteFrames สำหรับเดิน โจมตี และร่าย 4 ทิศ โดยด้านซ้ายกลับภาพจากด้านขวา
สกิลปล่อยพลังที่เฟรม 2 เพื่อให้ภาพโจมตีตรงจังหวะดาเมจ

| ร่าง | สกิล | MP | คูลดาวน์ |
| --- | --- | ---: | ---: |
| WarGreymon | Terra Force | 18 | 8 วินาที |
| WarGreymon | Great Tornado | 16 | 6 วินาที |
| MetalGarurumon | Cocytus Breath | 14 | 6 วินาที |
| MetalGarurumon | Garuru Tomahawk | 18 | 8 วินาที |
| MetalGarurumon | Grace Cross Freezer | 22 | 12 วินาที |

สกิลใช้ภาพไอคอนและเอฟเฟกต์ธาตุจาก v24: ไฟ ลม น้ำแข็ง และมิสไซล์
ค่าโจมตีและขอบเขตสกิลในโปรเจกต์นี้เป็นค่าทดสอบเกม ไม่ใช่ค่าจากเกม Digimon ภาคอื่น

## เซฟเดิมและการทดสอบ

เพิ่มร่างต่อท้ายสายเดิมโดยคง ID Rookie/Champion/Ultimate และชื่อ application เดิม
ใช้บัญชี/Server/ช่องตัวละครเดิมได้ ไม่ต้องล้างเซฟหรือสร้างตัวละครใหม่
การสลับสมาชิกจำร่าง HP MP เลเวลและคูลดาวน์แยกกัน และเลือด Tamer ต่ำกว่า 20% ยังบังคับกลับ Rookie ตามระบบเดิม

เปิด `tools/mega_preview.tscn` แล้วกด F6 เพื่อดู Mega ทั้งสองตัวและบันทึกภาพไว้ใน `preview/mega_v26/`
ฉากนี้ใช้เซฟสาธิตแยก ปลดล็อกเควสต์เพื่อพรีวิว แล้วปิดตัวเองเมื่อถ่ายภาพครบ
ผลทดสอบรอบนี้อยู่ `MEGA_TEST_RESULTS_V26.json` และ `docs/test_logs/mega_lines_v26/`
ยังไม่ได้วัด FPS หรือทดสอบการสัมผัสบนโทรศัพท์จริง

## ไฟล์สำคัญ

- `data/pregame/agumon.tres`, `gabumon.tres`: รายการสายร่างสี่ขั้น
- `data/pregame/agumon_3.tres`, `gabumon_3.tres`: ค่าพลังและชุดสกิลของ Mega
- `data/pregame/*_3_*.tres`: สกิลใหม่และ SpriteFrames ของ MetalGarurumon
- `assets/anime_v26/metalgarurumon_atlas.png`: ภาพใหม่จาก built-in image_gen
- `MEGA_IMAGE_PROMPTS_V26.json`: คำสั่งสร้างภาพ
- `tools/build_mega_resources.py`: สร้างข้อมูล AtlasTexture โดยไม่แก้พิกเซล PNG

อ้างอิงชื่อร่างและท่าจาก Digimon Encyclopedia:
- https://digimon.net/reference_en/detail.php?directory_name=wargreymon
- https://digimon.net/reference/detail.php?directory_name=metalgarurumon

แมพเดียวขนาดใหญ่และหน้าสถานะดิจิมอนจาก v25 อยู่ในโปรเจกต์นี้ครบ Android preset เพิ่มเลขรุ่นเป็น 26 แล้ว
ไม่มี APK ในรอบนี้ สามารถ Export ด้วย SDK/Java และกุญแจเซ็นบนเครื่องของคุณได้ตามเดิม

ผลทดสอบรอบสุดท้าย: **4 ชุด รวม 239 ข้อ ผ่านทั้งหมด** และตรวจภาพจาก Godot Compatibility จริงครบทั้งสองร่าง
