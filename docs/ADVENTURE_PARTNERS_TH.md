# ฮิคาริ ทาเครุ และโจ: คู่หูถึง Mega

ต่อยอดตัวเลือกสามคู่บน main โดยคง ID ตัวละครและร่างเริ่มต้นเดิม เซฟที่มี Tailmon, Patamon หรือ Gomamon จึงได้รับสายวิวัฒนาการเพิ่มโดยไม่ต้องสร้างตัวละครใหม่

| เทมเมอร์ | สายวิวัฒนาการ | เลเวลปลดล็อก |
| --- | --- | --- |
| ฮิคาริ | Tailmon → Angewomon → Holydramon (Magnadramon) | 1 / 60 / 90 |
| ทาเครุ | Patamon → Angemon → HolyAngemon (MagnaAngemon) → Seraphimon | 1 / 15 / 60 / 90 |
| โจ | Gomamon → Ikkakumon → Zudomon → Vikemon | 1 / 15 / 60 / 90 |

Tailmon เป็น Champion ตั้งแต่ต้น จึงใช้สามร่างและไม่ใส่ร่าง Baby เพิ่ม ระบบตรวจเลเวลตาม `evolution_stage` ของร่างปลายทาง ทั้งปุ่มวิวัฒนาการ การโหลดร่างตรง และการคืนสมาชิกจากเซฟ ส่วนร่างเริ่มต้นเปิดให้ใช้ตั้งแต่ Lv.1 สาย Agumon/Gabumon ยังคงเกณฑ์เดิม

ทุกร่างมีสกิลประจำตัว Mega มีสองสกิล ใช้ระบบ MP, cooldown, projectile/AOE และปล่อยความเสียหายเมื่อถึงเฟรม 2 เหมือนคู่หูเดิม การเปลี่ยนร่างใช้ MP ของเทมเมอร์ แก้การวาด polygon ของเอฟเฟกต์ที่หดจนมีขนาดเป็นศูนย์ด้วย

เพิ่ม Digitama ของทั้งสามสายลงฐานข้อมูลและตารางดรอป ฟักแล้วได้สายที่ระบุแน่นอนและส่งเข้าคลังแม้ปาร์ตี้เต็ม อัตรารวมของไข่ยังเป็น 10% แบ่งแปดสายเท่ากันสายละ 1.25% และยังออกได้ไม่เกินหนึ่งใบต่อการดรอปหนึ่งครั้ง

## ภาพและข้อจำกัด

ภาพสร้างด้วย built-in imagegen และเก็บ PNG ต้นฉบับที่ `assets/adventure_partners/{tailmon,patamon,gomamon,tamers}.png` พร้อม portrait แบบ AtlasTexture สคริปต์ `tools/build_adventure_partners.py` อ่าน alpha เพื่อกำหนดกรอบ ไม่แก้ไขพิกเซลต้นฉบับ

ชุด prompt ใช้แนวทาง production sprite atlas สำหรับเกม Godot 2.5D: พื้นหลังโปร่งใส ไม่มีข้อความ/เส้นตาราง ภาพ chibi anime cel-shaded เต็มตัว สี่คอลัมน์เป็น idle, walk, windup, release; แถวเรียงตามชื่อร่างในตารางด้านบน ชุดเทมเมอร์ใช้ Hikari/Takeru/Joe ของ Adventure และสี่คอลัมน์เป็น idle, ก้าวขวา, ก้าวซ้าย, มองจากด้านหลัง

คู่หูใช้สี่ key poses ต่อร่าง โดย attack/cast เรียง idle → windup → release → idle เป็นการเคลื่อนไหวแบบสั้น ภาพมุมเฉียงใช้ร่วมกับทิศขึ้น/ลงและกลับด้านเมื่อหันซ้าย ยังไม่ใช่ชุดภาพมุมหน้า/หลังแยกทุกทิศ เทมเมอร์มีภาพด้านหลังสำหรับทิศขึ้น แต่ยังไม่มีวงจรเดินด้านหลังแยก

รัน `godot --path . res://tools/adventure_preview.tscn` เพื่อตรวจภาพที่เกมใช้จริง เพิ่ม `-- --capture` เพื่อจับภาพ idle/attack ลง `user://`

## การตรวจสอบ

- Godot 4.4.1: นำเข้า resource ใหม่และโหลดฉากหลักด้วย `tests/resource_load_smoke.gd`
- `tests/adventure_partners_test.tscn`: ทดสอบการล็อกก่อนเลเวล/ปลดล็อกตรงเลเวล การจองและจบวิวัฒนาการ สกิลทำดาเมจตรงจังหวะภาพ ใช้ MP ครั้งเดียว cooldown คืน Mega จากเซฟ ลดร่างที่ยังไม่ปลดล็อก และฟักไข่เข้าคลัง
- ตรวจภาพ idle และ attack ด้วย Godot OpenGL Compatibility / Mesa llvmpipe
- เพิ่ม regression ชุดใหม่ใน GitHub Actions เดิม

ข้อจำกัดของ baseline ที่ตรวจพบ: ไฟล์ splash JPG สองไฟล์และ `assets/original_monsters/prismforge_fusion.png` บน main อ่านภาพไม่ได้ และชุดทดสอบ pregame เก่ามี assertion เรื่องฐานสเตตัส/legacy ที่ไม่ผ่านอยู่เดิม รายละเอียดการเทียบ baseline ระบุใน PR ไม่ได้รวมการเปลี่ยน splash หรือร่าง fusion ในงานสามคู่ครั้งนี้
