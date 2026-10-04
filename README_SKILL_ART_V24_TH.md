# v24 — Painted Skill Icons & Elemental Combat Effects

ต่อยอดจากโปรเจกต์ v23 โดยแทนภาพไอคอนและปรับภาพตอนต่อสู้ รองรับ Godot 4.4.1 / Compatibility

## เปิดใช้งาน

1. แตก ZIP แล้ว Import ไฟล์ `mobile_skill_art_v24/project.godot` ใน Godot
2. รอ Import ภาพครั้งแรก แล้วกด F5 ใช้หน้า Login/เลือกตัวละครเดิม
3. ล็อกศัตรูแล้วกดสกิลเพื่อดูเอฟเฟกต์จริง ปุ่มชุดสกิลยังสลับหน้าตามร่างเดิม
4. สำหรับภาพตัวอย่าง เปิด `tools/skill_art_preview.tscn` แล้วกด F6: สคริปต์สาธิตจะจับภาพลง `preview/skill_art/` และปิดตัวเองเมื่อเสร็จ ใช้ไฟล์เซฟสำหรับพรีวิวแยกจากผู้เล่น

รอบนี้ไม่มี APK ใหม่ ใช้ Export Preset Android ที่แนบเพื่อ export เองบนเครื่องได้เหมือนเดิม ตั้งค่า Java/SDK และคีย์เซ็นในเครื่องของคุณก่อน export

## สิ่งที่เปลี่ยน

- ภาพไอคอนวาดใหม่ 10 แบบ (PNG) ใส่ในสกิลเดิมทั้งหมด 29 Resource รวมถึงปุ่มโจมตีและ Evolve
- ไอคอนแสดงเต็มพื้นที่วงกลมด้วย UV polygon ขอบบาง มีชื่อสกิลตัดบรรทัดและคูลดาวน์ทับภาพ
- ช่องที่ยังไม่มีสกิลเป็นจุดวงกลมจาง ๆ ลดการบดบังฉาก แต่ยังคงตำแหน่งสัมผัสเดิม
- เอฟเฟกต์ชาร์จ/ปล่อยพลัง, หางพลังโค้งตามเส้นทางจริง, ระเบิดธาตุ, เกล็ดน้ำแข็ง, ใบไม้, ขนนก, สายฟ้าและประกายดาว
- ภาพระเบิดไฟกับสายฟ้าเพิ่มอีก 2 PNG มี alpha โปร่งใสจริง ขยายและจางตามอายุเอฟเฟกต์
- ตัวเลือก Settings → เอฟเฟกต์น้อย ลดจำนวนเศษและจำกัดเอฟเฟกต์กระทบพร้อมกัน 12 ชุด (ปกติ 32)

จำนวนสกิลของแต่ละร่างยังอิง Resource เดิม: ร่างเริ่มต้นแต่ละสายมี 1 สกิล จึงยังมีช่องสำรองว่าง 3 ช่อง การเปลี่ยนภาพไม่เพิ่มสกิลหรือปลดล็อกเควสต์ให้โดยอัตโนมัติ

## ภาพกับสกิลที่ใช้

| ไฟล์ใน assets/skills_painted | ตัวอย่างสกิล |
|---|---|
| fire.png | Baby Flame, Mega Flame, Flame Burst |
| ice.png | Blue Blaster, Howling Blaster, Solar Wave |
| wind.png | Spiral Twister |
| lightning.png | Super Shocker, Electro Shocker, Horn Buster, Solar Lance |
| nature.png | Poison Ivy, Needle Spray, Flower Cannon |
| claw.png | Wolf Claw, Quick Bite, Heavy Claw, Nova Fang และปุ่มโจมตี |
| missile.png | Giga Destroyer |
| wing.png | Meteor Wing, Shadow Wing |
| astral.png | Solar Nova, Astral Cannon/Wave/Nova |
| evolve.png | ปุ่ม Evolve |

บางสกิลใช้ภาพร่วมในกลุ่มเดียวกัน แต่ยังมี ID, MP, cooldown และค่าความแรงของตนเอง

## โค้ดที่เกี่ยวข้อง

| ไฟล์ | หน้าที่ |
|---|---|
| scripts/skill_data.gd | เพิ่ม `vfx_style` เลือกรูปแบบภาพต่อสกิล |
| scripts/hud/hybrid_command.gd | วาดภาพวงกลมด้วย UV, ชื่อ 2 บรรทัด, cooldown |
| scripts/form_skill_panel.gd | ผูกภาพกับปุ่มที่สร้างใหม่เมื่อสลับหน้า/เปลี่ยนร่าง |
| scripts/skill_vfx_paint.gd | ตัวช่วยวาดแสงนุ่ม สายฟ้า ใบไม้ ประกาย ใช้ texture แสงร่วมกัน |
| scripts/combat_action_effect.gd | รวมพลัง ปล่อยพลัง กรงเล็บ |
| scripts/skill_projectile.gd | ภาพหัวพลังและหางสูงสุด 10 จุด (โหมดน้อย 4) |
| scripts/skill_hit_resolver.gd | ลงดาเมจครั้งเดียวและสร้างเอฟเฟกต์ตามงบภาพ |
| scripts/skill_impact.gd | วงกระทบพื้น + ภาพระเบิด + เศษธาตุ ลบตัวเองเมื่อจบ |
| scripts/partner_monster.gd | ส่ง style ของสกิลไปตามเส้นทางโจมตีเดิม |

ตัวอย่างในสกิล `.tres`:

```ini
[ext_resource type="Texture2D" path="res://assets/skills_painted/lightning.png" id="icon"]

[resource]
icon = ExtResource("icon")
vfx_style = "lightning"
```

`vfx_style` มีค่า fire / ice / wind / lightning / nature / claw / missile / wing / astral เป็นชนิดภาพเท่านั้น ยังไม่ได้เพิ่มระบบแพ้ชนะธาตุหรือสถานะพิษ/แช่แข็ง

## ประสิทธิภาพและกลไก

- PNG ต้นฉบับเก็บครบสำหรับแก้ไข แต่ Import ตั้ง Size Limit 256 และ Mipmaps เพื่อให้ใช้หน่วยความจำภาพน้อยลงบนมือถือ
- ไม่สร้าง ImageTexture หรือโหลด PNG จากดิสก์ในแต่ละเฟรม
- ใช้ CanvasItemMaterial แบบ Unshaded จึงเห็นพลังในฉากกลางวัน/กลางคืนโดยไม่เพิ่ม PointLight2D จำนวนมาก
- ค่าดาเมจ, MP, cooldown, AoE, raycast กันกำแพง และจังหวะ hit เดิมยังอยู่ในเส้นทางต่อสู้เดิม
- การเกินงบเอฟเฟกต์งดเฉพาะภาพใหม่ ดาเมจยังครบทุก hit
- เอฟเฟกต์ pause พร้อมสนาม และ queue_free เฉพาะ Node ภาพ/ลูกพลัง ไม่ลบคู่หู
- ไม่มี screen shake หรือ flash เต็มจอเพิ่ม

## การตรวจสอบ

Godot 4.4.1: 5 ชุดทดสอบ รวม 231 assertions ผ่าน — skill_art_vfx 38, combat_actions 66, hybrid_hud 43, form_skills_animation 69, target_freed 15
ผลและ log อยู่ที่ `SKILL_ART_TEST_RESULTS_V24.json` กับ `docs/test_logs/skill_art_v24/`

ตรวจภาพจาก Godot OpenGL Compatibility จริงที่ 1280×720 ทั้ง HUD, 5 สายคู่หู และแกลเลอรีภาพ ภาพเอฟเฟกต์สาธิตหยุดไว้ที่อายุ 0.14 วินาทีเพื่อจับภาพนิ่ง; ระหว่างเล่นจริงเอฟเฟกต์เคลื่อนไหวและลบตัวเองตามเวลา ไม่ได้หยุดเกม

ยังไม่ได้วัด FPS หรือสัมผัสหลายจุดบนโทรศัพท์จริงสำหรับ v24 นี้

## แหล่งภาพ

ภาพใหม่ 12 PNG สร้างด้วยเครื่องมือสร้างภาพในตัว (built-in image generation) และนำไฟล์จริงเข้าโปรเจกต์ ไม่ใช่ placeholder จาก SVG ข้อความ prompt เก็บใน `PROMPTS_SKILL_ART_V24.md`
