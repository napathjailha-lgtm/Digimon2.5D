# v10 — Mobile HUD แนว MMO ตามภาพอ้างอิง

ต่อยอดจาก v9 โดยใช้กรอบน้ำเงินเข้ม ขอบทอง และหลอด HP สีแดง/DS สีน้ำเงินแบบภาพอ้างอิง จัดวางใหม่สำหรับจอมือถือแนวนอน 1280×720 และจอที่กว้างขึ้น

## เปิดใช้งาน

แตก ZIP ไปโฟลเดอร์ใหม่ → Godot Project Manager → Import `project.godot` → กด F5 ใช้ Godot 4.4+

ชื่อแอปใน project.godot คงเป็น Digital Adventure Form Skills เหมือน v9 เพื่ออ่าน user:// และความคืบหน้าเดิมต่อได้ ปุ่ม/Resource เดิมของการต่อสู้ เลเวล คู่หูสลบเป็นไข่ Recover คัตซีน และเควสต์ยังใช้ระบบเดิม

## ส่วนที่เพิ่มและปรับ

| ส่วน | การทำงาน |
|---|---|
| กรอบ Tamer / คู่หู มุมซ้ายบน | รูปในกรอบ, ชื่อ, Lv, HP แดง, DS น้ำเงิน และ EXP ทอง อ่านข้อมูลจริง |
| Portrait คู่หู | เปลี่ยนตามร่างและเปลี่ยนเป็น Digitama เมื่อแพ้ |
| แถว Partners 4 ช่อง | ช่องแรกแสดงคู่หูจริงและเปิด Status; 3 ช่องอื่นยังว่าง ไม่ได้เพิ่มระบบ roster/switch ใหม่ |
| Quest Tracker | แผงเล็กใต้กรอบสถานะ แตะเพื่อเดินนำทางเหมือนเดิม |
| Target Status | แสดงชื่อและ HP ของศัตรูที่เลือกไว้ ปิดเมื่อศัตรูตายหรือเลิกเลือก |
| หลอดบนหัว | ชื่อและ HP ของ Tamer/คู่หู/ศัตรู ยกตำแหน่งตามความสูงภาพแต่ละร่าง |
| Minimap | ภาพแผนที่ปัจจุบัน จุด Tamer สีเขียว คู่หูทอง ศัตรูแดง อัปเดตจากพิกัดโลกจริง |
| Chat Panel | พิมพ์ได้, ส่งด้วยปุ่ม/Enter, เลื่อนย้อนหลัง, กรองทั้งหมด/ทั่วไป/ระบบ และพับเก็บ |
| ปุ่ม Status / Digivolve / Auto | กรอบสี่เหลี่ยมโทนน้ำเงินและทอง ไม่ทับแผนที่ย่อ |
| Mobile Controls | Joystick กับปุ่มต่อสู้ยังรองรับหลาย finger ตามเดิม แชตวางข้าง Joystick |

## ขอบเขตแชตในรุ่นนี้

**แชตทั่วไปเป็นแชตภายในเครื่อง ไม่มีการส่งหาเพื่อนหรือผู้เล่นคนอื่นผ่านเครือข่าย** มีป้าย LOCAL บนกรอบแชต ระบบแจ้งเควสต์สำเร็จ, Level Up, เปลี่ยนร่าง และ Recover ลงแท็บระบบได้

GameChat เก็บข้อความระหว่างเปลี่ยนโซน สูงสุด 100 ข้อความต่อการเปิดเกมหนึ่งครั้ง ปิดเกมแล้วไม่เก็บประวัติถาวร ช่องพิมพ์จำกัด 160 ตัวอักษรและข้ามข้อความว่าง แสดงเนื้อหาผู้เล่นเป็นข้อความธรรมดา ไม่ตีความ BBCode

เมื่อเริ่มพิมพ์ จะปล่อยนิ้ว Joystick, ยกเลิก Auto-Navigation และหยุดรับคำสั่งสกิลชั่วคราว โลกและ AI ยังทำงานอยู่ ส่งข้อความ/พับแชต/แตะออกนอกแชตแล้วคืนการควบคุม

LineEdit เปิด virtual_keyboard_enabled และ Chat Panel ยกขึ้นตาม DisplayServer.virtual_keyboard_get_height() เมื่อแพลตฟอร์มรายงานความสูง คำนวณสเกลจากขนาด Window กับ viewport เพื่อรองรับ stretch ตรวจ logic และ focus บนเดสก์ท็อปแล้ว การแสดง/ขนาดคีย์บอร์ดจริงยังต้องลองบน Android/iOS ที่จะใช้

## Script และ Node สำคัญ

| Script | Node / บทบาท |
|---|---|
| scripts/classic_ui_style.gd | RefCounted: สีและ StyleBox ของกรอบต่าง ๆ |
| scripts/classic_command.gd | ClassicCommand: ปุ่มสี่เหลี่ยมที่สืบทอด TouchCommand |
| scripts/vitals_card.gd | VitalsCard: portrait และหลอด HP/DS/EXP |
| scripts/mobile_chat_panel.gd | MobileChatPanel: แชต, focus, แท็บ, พับ, ปรับตำแหน่งเหนือคีย์บอร์ด |
| scripts/game_chat.gd | Autoload GameChat: เก็บข้อความและ outgoing_message สำหรับต่อเซิร์ฟเวอร์ |
| scripts/mobile_minimap.gd | MobileMinimap: วาด map texture และ marker ของตัวละคร |
| scripts/actor_nameplate.gd | Node2D ลูกของตัวละคร: ชื่อ/เลือดบนหัว |
| scripts/mobile_hud.gd | เชื่อม HP/DS/EXP/ร่าง/เป้าหมาย กับ Component ต่าง ๆ |
| scripts/touch_command.gd | เปลี่ยน locked แล้ววาดสีปุ่มใหม่ทันที |
| scenes/mobile_hud.tscn | จัด Joystick, Attack, SkillPanel, Digivolve และ Auto |

ส่วนที่สร้างใน runtime จะปรากฏใน Remote Scene Tree ใต้ MobileHUD/Root: ChatPanel, Minimap, TargetStatus, PartnerSlot0–3 และกรอบสถานะสองตัว ยังใช้ Root/SkillPanel ของ v9 สำหรับปุ่มสกิลตามร่าง

HP/EXP เชื่อม Signal ของเจ้าของ ส่วนกรอบเป้าหมายและ Minimap อ่านพิกัด/HP ประมาณ 7–10 ครั้งต่อวินาที เพื่อลดการวาดซ้ำ เลือดคู่หูใช้ DS ของ Tamer ตามกติกาเกมนี้ จึงมีข้อความ "DS ร่วมกับ Tamer" ระบุไว้

Minimap ตั้ง world_extent = Vector2(1280, 720) ตามแผนที่ตัวอย่าง หากขยายแผนที่จริงต้องเปลี่ยน extent ให้ตรงขนาดโลกด้วย มิฉะนั้น marker จะคลาดเคลื่อน แผนที่ย่อในรุ่นนี้ใช้แสดงตำแหน่ง ไม่ได้เพิ่มการคลิกเดินบนแผนที่

## เชื่อมแชตกับเซิร์ฟเวอร์ภายหลัง

GameChat.outgoing_message(channel, text) ส่ง signal หลังยอมรับข้อความทดสอบ จุดนี้ใช้เชื่อม transport ที่เลือก เช่น WebSocket ขณะนี้ยังไม่มี transport, login, channel membership, chat moderation หรือข้อความจากผู้เล่นคนอื่น

```gdscript
# ตัวอย่างจุดเชื่อม เมื่อคุณเพิ่ม network client จริงเข้ามาแล้ว
GameChat.outgoing_message.connect(_on_outgoing_chat)

func _on_outgoing_chat(channel: StringName, text: String) -> void:
    # เรียก network client ของคุณจากจุดนี้
    # เซิร์ฟเวอร์ต้องตรวจผู้ส่ง/ช่อง/ความยาว ก่อนส่งกลับให้สมาชิก
    pass
```

## ปรับหน้าตา

- แก้ NAVY/BLUE/GOLD/TEXT ที่ classic_ui_style.gd เพื่อเปลี่ยนสีกรอบทั้งชุด
- ขนาดและตำแหน่งกรอบเลือดอยู่ใน mobile_hud.gd `_build_progress_ui()` และ vitals_card.gd
- Portrait เป็น AtlasTexture ครอปส่วนบนของ texture ต้นฉบับในหน่วยความจำ ไม่ได้แก้ภาพตัวละคร ถ้าใส่ภาพใบหน้าเฉพาะ ให้เปลี่ยนการกำหนด portrait.texture ที่ vitals_card.gd
- ตำแหน่งแชตอยู่ใน `_build_classic_extras()` ยึดขอบล่าง ส่วน Minimap ยึดมุมขวาบน
- ปิด Nameplate ได้โดยซ่อน/ลบ Node Nameplate ใน Scene ตัวละคร กรณีศัตรูแบบ inherited scene ให้แก้ใน wild_monster.tscn ตัวฐาน ไม่ต้องสร้าง Nameplate ซ้ำใน wild_monster_crab.tscn
- รูปเดินยังมีข้อจำกัดเหมือน v9: ยังต้องใส่เฟรมขาก้าวจริงใน SpriteFrames หากต้องการแอนิเมชันเดินสมบูรณ์

## ภาพตัวอย่างและการทดสอบ

`preview/hud_preview_v10.png` เป็นภาพจาก Godot ที่รันโปรเจกต์จริง ใช้ Scene tests/hud_capture.tscn ตั้งค่าตัวอย่าง Lv/HP เพื่อแสดงองค์ประกอบ HUD ไม่ใช่ภาพวาดจำลอง

`tests/classic_hud_test.tscn` ตรวจ portrait, HP/DS/EXP, เปลี่ยนร่าง/ไข่/Recover, HP เป้าหมาย, touch ไม่ทะลุ UI, focus, ยกช่องพิมพ์ตามความสูงคีย์บอร์ด, ส่งแชต, literal BBCode, filter, fold, ข้อความว่าง/ความยาว/ประวัติ, ข้อความเควสต์ 8 ชุดและ layout 1280×720 กับ 1600×720

ตรวจร่วมกับ smoke_test, story_quest_test, recovery_progress_cutscene_test, form_skills_animation_test, art_integration_test, spawner_test และ damage_popup_test บน Godot 4.4.1 แบบ headless ภาพตรวจด้วย Compatibility renderer

รัน scene ทดสอบทีละตัว เช่น:

```bash
godot --headless --path <project-folder> res://tests/classic_hud_test.tscn
```

ผลสุดท้ายต้องเป็น RESULT: 0 failure(s) การทดสอบ Popup จับจังหวะ Tween สั้น ให้รันด้วย --fixed-fps 60 เพื่อให้ช่วงเวลาจำลองคงที่ เช่น godot --headless --fixed-fps 60 --path <project-folder> res://tests/damage_popup_test.tscn

เอกสาร API ทางการ:

- https://docs.godotengine.org/en/4.4/classes/class_lineedit.html
- https://docs.godotengine.org/en/4.4/classes/class_displayserver.html
- https://docs.godotengine.org/en/4.4/classes/class_richtextlabel.html
