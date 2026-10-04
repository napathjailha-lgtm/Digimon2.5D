# v13 — แอคชั่นตีธรรมดาและใช้สกิลของคู่หู

เปิด `project.godot` จากโฟลเดอร์ mobile_combat_actions_v13 ด้วย Godot 4.4.1 แล้ว F5
ในสนาม: แตะศัตรู หรือเลือกเป้าหมายแล้วกด Attack เพื่อสั่งคู่หูเข้าตี
กดปุ่มสกิลทางขวาเพื่อให้คู่หูเดินเข้าระยะและใช้สกิลนั้น

## ภาพใหม่ที่เพิ่มจริง

Rookie, Champion, Ultimate, Mega มี Attack และ Cast แยกกัน
แต่ละท่ามี down/right/up/left และท่าละ 4 เฟรม รวม 128 เฟรมใหม่
Attack: เตรียม → ง้าง → ฟัน → คืนท่า (10 FPS)
Cast: เตรียม → ชาร์จ → ปล่อยพลัง → คืนท่า (8 FPS)
เฟรมเริ่มนับจาก 0; เฟรม 2 เป็นจังหวะ Strike/Release
ตีธรรมดาใช้ Attack; สกิลกัด/กรงเล็บใช้ Attack; สกิลพลัง/ลูกไฟใช้ Cast
รูปไม่ได้ใช้ภาพเดินมาสวมเป็นภาพตี; PNG ใหม่อยู่ใน assets/actions/
ระบบเดินลื่นและเฟรมเดินจาก v12 ยังอยู่ครบ

## จังหวะต่อสู้

- ระหว่างออกท่า คู่หูหยุดเคลื่อนที่และไม่เริ่มอีกท่าทับ
- กดสกิลระหว่างท่าเดิม: เก็บคำสั่งช่องล่าสุดไว้ แล้วทำหลังคืนท่าเมื่อยังใช้ได้
- การตีธรรมดาไม่หัก HP ตอนเริ่มง้าง แต่หักที่ Strike frame
- Baby Flame/Mega Flame ปล่อยลูกไฟที่ Release frame และค่อยลงดาเมจตอนลูกไฟชน
- สกิลที่ projectile_speed=0 ลงดาเมจ/ระเบิดที่ Release frame โดยไม่มีช่วงบิน
- หัก DS และตั้ง CD ครั้งเดียวตอนเริ่มใช้สกิล; จดจำ ATK/ดาเมจในขณะนั้น
- หากศัตรูหนีออกจากระยะหรือมีผนังขวางก่อนออกท่า ท่านั้นพลาดและไม่คืน DS/CD
- เปลี่ยนเป้าหมาย เปลี่ยนร่าง สลบ หรือเริ่มคัตซีน จะยกเลิกท่าที่ยังเตรียมอยู่
- ลูกไฟที่ออกไปแล้วรักษาดาเมจเดิมเมื่อเปลี่ยนร่าง และยังหยุดเมื่อผู้ยิงสลบตามระบบเดิม
- แอคชั่น เอฟเฟกต์ และลูกไฟ pause พร้อมสนาม

## เอฟเฟกต์

ตีธรรมดา/สกิลประชิดมีกรงเล็บสามเส้นที่หันตามเป้าหมาย
ท่า Cast มีวงพลังและประกายชาร์จ แล้ววาบตอน Release
ภาพลูกไฟเริ่มจากจุดปากคู่หู แล้วเคลื่อนไปหาตัวศัตรู ส่วน Raycast ยังคงอยู่บนระนาบฟิสิกส์ที่เท้า
เอฟเฟกต์วาดด้วย Node2D และลบตัวเอง ไม่เพิ่ม shader หนักหรืออนุภาคจำนวนมาก

## Node และ Script

Partner (CharacterBody2D)
ใช้ AnimatedSprite2D, DirectionalAnimator, NavigationAgent2D, Progress เดิม
เพิ่ม CombatAction (Node) พร้อม scripts/partner_combat_action.gd
Component ส่ง signal impact/finished/canceled ให้ Partner ตัดสินใจดาเมจและสถานะ
ใช้ frame_changed และ animation_finished ของ AnimatedSprite2D จริง ไม่มี await ที่ถือเป้าหมายเก่า
ทั้ง Attack/Cast ปิด Loop เพื่อให้คืนท่าได้

`scripts/partner_monster.gd`: รับคำสั่ง สร้าง snapshot ตรวจระยะ/เป้าหมายที่ Impact และสร้างเอฟเฟกต์
`scripts/partner_combat_action.gd`: ล็อกแอคชั่น ตรวจ Impact frame ครั้งเดียว และยกเลิกได้
`scripts/combat_action_effect.gd`: วงชาร์จ วาบปล่อยพลัง และกรงเล็บ
`scripts/directional_animator.gd`: เลือกทิศและสเกลแยก Walk/Attack/Cast
`scripts/skill_projectile.gd`: จุดวาดลูกไฟแยกจากเส้นฟิสิกส์

## ปรับใน Inspector

MonsterData: attack_hit_frame, attack_sprite_scale, cast_sprite_scale, require_action_animations
MonsterSkill: animation_prefix = attack/cast, release_frame = 2
หากเพิ่มจำนวนเฟรม ให้ปรับ hit/release ให้ตรงท่าที่โดน และปิด Loop
ปรับ FPS/duration ใน SpriteFrames ได้โดยไม่ต้องตั้ง Timer ของดาเมจใหม่
ท่ายังคงใช้ sprite.speed_scale=1 แยกจากความเร็วเดิน

## ลองและดูคลิป

F5 เล่นตามปกติ หรือเปิด tools/combat_preview.tscn แล้ว F6
พรีวิวในสนามจริงจะสาธิตตีธรรมดา → สกิลแรก → สกิลที่สอง ครบ 4 ร่าง
พรีวิวใช้ Save แยกและปลดร่างเฉพาะการสาธิต ไม่ข้ามเงื่อนไขเควสต์ใน F5
คลิปอยู่ใน preview/Partner_CombatActions_v13.mp4

## ภาพและ Resource

สร้างภาพด้วย built-in imagegen จากภาพอ้างอิงตัวละครเดิม
ACTION_IMAGE_PROMPTS.json เก็บพรอมป์ต์ครบและการแก้ภาพหันหลังของ Rookie
PNG ต้นฉบับไม่ได้แก้พิกเซลด้วย Python; tools/build_action_resources.py อ่าน alpha เพื่อสร้าง AtlasTexture
AtlasTexture ใช้ region/margin ปักเท้าให้ตรง origin; สเกลภาพ action ปรับแยกเพื่อคงขนาดแต่ละร่าง
เมื่อ rebuild ภาพเดินด้วย tools/build_walk_resources.py จะเรียกตัวสร้าง action ต่ออัตโนมัติ
Python/Pillow/numpy/scipy ใช้เฉพาะตอนเตรียม Resource; เล่นเกมไม่ต้องติดตั้ง Python

## ผลทดสอบ

Godot 4.4.1: 10 ฉากทดสอบ รวม 367 ข้อ ผ่านทั้งหมด ดู COMBAT_ACTION_TEST_RESULTS.json
ครอบคลุมเฟรมลงดาเมจครั้งเดียว, การคืนท่า, การปล่อยลูกไฟ, ค่า DS/CD, pause, เปลี่ยนเป้า/ร่าง, สลบ, หนีระยะ และเป้าหมายถูก free
รวมทดสอบเดิมของ HUD เควสต์ การฟื้นฟู EXP การเดิน และลูกไฟด้วย
ตรวจภาพจริงใน Compatibility renderer; คลิปเป็นการจับภาพที่ 20 FPS ไม่ใช่ผล benchmark ของเกมบน Android
ภาพ action เป็นชุดต้นแบบ 4 เฟรม สามารถเปลี่ยนเป็นชุดละเอียดขึ้นผ่าน Resource เดิม
CHANGED_FILES_V13.json เทียบกับ ZIP v12 ที่ใช้เป็นต้นทาง; README รุ่นก่อนหน้าเก็บเป็นประวัติ
