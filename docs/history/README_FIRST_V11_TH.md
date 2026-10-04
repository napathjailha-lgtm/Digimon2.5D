# v11.1 — ลูกไฟเดินทางและแก้ Target ที่ถูกลบ

Hotfix 0.11.1: แก้ freed reference ที่ส่งเข้า MobileHUD._refresh_target และคำสั่งโจมตี/สกิล อ่าน README_TARGET_FREED_FIX_TH.md เพิ่มเติม

แพ็กนี้แก้โค้ดจาก Godot4_ClassicMobileHUD_Chat_v10.zip จริง ไม่ใช่การเปลี่ยนชื่อ ZIP หรือเพิ่มเฉพาะคู่มือ

## สิ่งที่เปลี่ยนจาก v10

| ระบบ | v10 | v11 |
|---|---|---|
| Baby Flame / Mega Flame | หัก HP ทันทีตอน cast | ลูกไฟเดินทาง และลงดาเมจเมื่อชนครั้งเดียว |
| รูปแบบลูกไฟ | ไม่มี projectile | Rookie ขนาด 12px / 460px ต่อวินาที; Champion ขนาด 26px / 360px ต่อวินาที |
| ระเบิดวงกว้าง | เกิดตอน cast | Mega Flame ระเบิดรอบตัวที่ชน รัศมี 90px |
| เปลี่ยนร่างกลางวิถี | ไม่มีลูกไฟค้างระหว่างเดินทาง | ลูกไฟเก็บดาเมจของร่าง ณ ตอนยิง ไม่คำนวณใหม่ตอนชน |
| กำแพงระหว่างบิน | ตรวจเฉพาะตอน cast | ตรวจช่วงที่ลูกไฟเดินทางทุก physics frame ไม่ทะลุกำแพงบาง |
| สลับภาพเดินต่างจำนวนเฟรม | คัดลอกเลขเฟรมเดิม | รักษาสัดส่วนรอบเดิน รวม duration ของแต่ละเฟรม |
| คำสั่งปุ่มเก่า | ตรวจ ID ของสกิล | ตรวจทั้ง ID และ revision ของแผง แม้กลับมาร่างเดิมก็ไม่รับ callback เก่า |
| ข้ามช่องสกิลว่าง | ตำแหน่งปุ่มอาจคลาดกับ slot | ผูก slot จริงไว้ใน metadata ใช้อ่าน CD และส่งคำสั่ง |

## เปิดและทดลอง

1. แตก ZIP ลงโฟลเดอร์ใหม่ แล้ว Import `mobile_form_combat_v11/project.godot` ใน Godot 4.4.1 ขึ้นไป
2. กด F5 แตะศัตรู แล้วกด Baby Flame จะเห็นลูกไฟสีส้มบินไปก่อนตัวเลขดาเมจปรากฏ
3. กด Digivolve ผ่านคัตซีน แล้วลอง Mega Flame ลูกไฟจะใหญ่ขึ้นและระเบิดเป็นวง
4. แต่ละร่างยังใช้สกิล ไอคอน ATK และค่า DS จาก Resource ของตัวเอง
5. config/version เป็น 0.11.0 แต่ config/name คงเดิมเพื่อให้เส้นทาง user:// และ Save เดิมยังใช้ได้ หาก Save เดิมอยู่ Champion หรือสูงกว่า อาจไม่ได้เริ่มที่ Rookie

ไม่มีเงื่อนไขเลเวลขั้นต่ำที่เพิ่มใหม่ใน v11: การปลดล็อก Ultimate/Mega ยังคงอิงเควสต์ และ Digivolve ยังคงตรวจ DS ผ่านระบบเดิม

## ไฟล์ใหม่และจุดเชื่อม

- `scripts/skill_projectile.gd`: SkillProjectile / Node2D จัดการเดินทาง ตรวจชน หมดอายุ และลบลูกไฟหลัง hit
- `scripts/skill_hit_resolver.gd`: SkillHitResolver รวมการลงดาเมจและ AoE เพื่อไม่ให้ลงซ้ำทั้งตอน cast และตอนชน
- `scripts/partner_monster.gd`: หลังตรวจระยะ/DS/CD เรียก _apply_skill_hit ซึ่งเลือกยิง projectile หรือ hit ทันทีตามข้อมูลสกิล
- `scripts/skill_data.gd`: เพิ่ม projectile_speed และ projectile_lifetime พร้อม validation
- `scripts/directional_animator.gd`: เพิ่มการแปลง frame/frame_progress เป็นสัดส่วน cycle แล้วคืนให้ภาพทิศใหม่
- `scripts/form_skill_panel.gd`: เพิ่ม revision และ metadata slot/id ป้องกันคำสั่งตกค้าง
- `data/rookie_strike.tres`: Baby Flame ตั้ง projectile_speed = 460.0
- `data/champion_claw.tres`: Mega Flame ตั้ง projectile_speed = 360.0 และ effect_size = 26.0

ไม่ต้องวาง SkillProjectile ลงแผนที่ด้วยมือ Partner สร้าง Node นี้เป็นลูกของ Actors ขณะใช้สกิล ทำให้เปลี่ยนฉากแล้วลูกไฟถูกลบตามสนาม

## เพิ่มสกิลลูกไฟของร่างอื่น

เปิด Resource MonsterSkill ใน Inspector:

- `projectile_speed = 0.0`: ใช้สกิลลงดาเมจทันที เช่นกัดหรือกรงเล็บ
- `projectile_speed > 0.0`: ยิงลูกไฟที่วิ่งด้วยความเร็วพิกเซลต่อวินาที
- `projectile_lifetime`: อายุสูงสุดเป็นวินาที นับเฉพาะเวลาที่สนามทำงาน
- `effect_size`: รัศมีภาพลูกไฟ ไม่ใช่รัศมี collider
- `impact_radius = 0.0`: โจมตีตัวที่ชนตัวเดียว
- `impact_radius > 0.0`: กระจายดาเมจรอบศูนย์กลางตัวที่ชน ทุกตัวในวงได้ดาเมจเดียวกัน ยกเว้นมีกำแพงขวาง

DS และ CD ถูกหักตอนยิงครั้งเดียว หากลูกไฟถูกขวาง/หมดอายุจะไม่คืนค่าเหล่านี้ ลูกไฟจะยกเลิกเมื่อเป้าหมายตายหรือคู่หูผู้ยิงสลบ มอนสเตอร์ตัวอื่นที่ขวางวิถีสามารถรับลูกไฟแทนเป้าหมายได้

สูตรดาเมจยังเป็น ATK ปัจจุบัน * multiplier * สุ่ม(0.95, 1.05) แล้วปัดเป็น int เก็บผลตั้งแต่ยิง จึงไม่เพิ่มโบนัสเลเวลซ้ำหรือเปลี่ยนดาเมจตามร่างใหม่ระหว่างบิน

## Collision และคัตซีน

Partner.enemy_layer = 4 และ world_layer = 1 ตาม Scene เดิม หากโปรเจกต์ของคุณใช้ layer อื่น ให้ปรับสองช่องใน Inspector

ลูกไฟตรวจ Physics Body และไม่ชน Area2D ที่ครอบรูปเพื่อรับ Touch ศูนย์ฟิสิกส์อิงจุดเท้า ภาพลูกไฟยกขึ้น 18px ตัววงระเบิดยังใช้จุดเท้าเป็นศูนย์กลาง

Projectile ใช้ process mode แบบ inherited จึงหยุดและเล่นต่อพร้อม SceneTree.paused ของระบบคัตซีนเดิม

## แอนิเมชัน 4 ทิศ

โครงสร้าง Tamer/Partner ยังเป็น CharacterBody2D + AnimatedSprite2D + DirectionalAnimator ใช้ get_real_velocity() หลัง move_and_slide() และ sprite.speed_scale = actual_speed / animation_reference_speed ตามเดิม

เพิ่มใน v11: เมื่อ walk_right มี 4 เฟรม แต่ walk_up มี 8 เฟรม และอยู่ที่ 62.5% ของวงเดิน ระบบจะย้ายไปเฟรม 5 ของ walk_up แทนการคัดลอกเลขเฟรม 2 แบบเดิม ทั้งนี้ศิลปินต้องจัดทุกทิศให้เริ่มวงด้วยจังหวะก้าวเดียวกัน

ชื่อภาพคือ idle_right/left/up/down และ walk_right/left/up/down เปิด Loop สำหรับ Idle/Walk และปิด Loop สำหรับ Attack

ภาพตัวละครในแพ็กยังเป็นชุดเดิม บางแอนิเมชันมีเฟรมเดียว ยังไม่ได้วาดภาพขาก้าวใหม่ การรักษา cycle และความเร็วแอนิเมชันจะเห็นประโยชน์เมื่อใส่ SpriteFrames ที่มีเฟรมเดินจริง

## ตรวจไฟล์และทดสอบ

`CHANGED_FILES_V11.json` แสดงไฟล์เพิ่ม/แก้ พร้อม SHA-256 ของ v10 และ v11 ส่วน `UPGRADE_TEST_RESULTS.json` แสดงผลทดสอบที่รันจริง

รัน Scene ใหม่เพื่อทดสอบลูกไฟและการสลับภาพ:

```bash
godot --headless --audio-driver Dummy --fixed-fps 60 --path mobile_form_combat_v11 res://tests/projectile_upgrade_test.tscn
```

ทดสอบอัตโนมัติด้วย Godot 4.4.1 แบบ headless การผ่านทดสอบ Logic ยังไม่ใช่ผลวัด FPS หรือการทดสอบบน Android จริง
