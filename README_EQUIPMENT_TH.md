# โครงสร้างและการต่อยอดระบบอุปกรณ์ v15

## ไฟล์หลัก

| ไฟล์ | หน้าที่ |
|---|---|
| `scripts/equipment_item_data.gd` | Custom Resource ต้นแบบของแต่ละไอเทม |
| `scripts/equipment_catalog.gd` | Resource รายการไอเทมทั้งหมดและค้นด้วย ID |
| `data/equipment/catalog.tres` | Catalog ที่ใช้จริง มีตัวอย่าง 18 ไอเทม |
| `scripts/equipment_inventory.gd` | จำนวนใน bag, ช่อง equipped, ใส่/ถอด/รางวัล/เซฟ |
| `scripts/equipment_screen.gd` | CanvasLayer หน้าต่างอุปกรณ์, tabs, เปรียบเทียบ และ pause ownership |
| `scripts/equipment_button.gd` | ปุ่มไอคอนใช้ finger index รองรับ touch หลายนิ้ว |
| `scripts/equipment_stage.gd` | พื้นโฮโลแกรมและเส้นกริดวาดด้วย Canvas2D |
| `scripts/tamer.gd` | รวมโบนัส Tamer, Defense, บันทึก equipment ใน party |
| `scripts/partner_monster.gd` | รวมโบนัสคู่หูกับฐานร่าง/เลเวล |
| `scripts/story_world.gd` | คืนอุปกรณ์ก่อนคืน HP/DS/ร่างจากเซฟ |
| `scripts/mobile_hud.gd` | ปุ่มเปิดอุปกรณ์และล้าง touch ก่อน pause |

## โครงสร้าง Node ขณะเกมทำงาน

- World (Node2D): แผนที่/Navigation/แสงเงาเดิม
- Actors/Tamer (CharacterBody2D): มี `equipment: EquipmentInventory` เป็น RefCounted ต่อผู้เล่น ไม่ใช่ Autoload
- Actors/Partner (CharacterBody2D): อ่านโบนัสจาก Tamer แล้วรวมเมื่อโหลดร่าง/Level Up/gear เปลี่ยน
- MobileHUD (CanvasLayer): ปุ่ม Equipment อยู่ใน Root เดิม
- MobileHUD/EquipmentScreen (CanvasLayer, layer 80, Process Mode Always): สร้าง Control/Panel/TextureRect/EquipmentButton ใน `_build()`

Resource เก็บข้อมูลต้นแบบร่วมกัน แต่ bag/equipped เป็น Dictionary ต่อผู้เล่น
ไม่มีการเปลี่ยน `MonsterData.attack` หรือตัวเลขโบนัสใน `.tres` เพื่อเก็บสถานะสวมใส่

## เพิ่มไอเทมใหม่ใน Inspector

1. FileSystem → New Resource → `EquipmentItemData` แล้ว Save As เช่น `data/equipment/new_boots.tres`
2. ตั้ง `id` ที่ไม่ซ้ำ, `item_name`, `slot`, `required_level`, `rarity`, `icon` และค่าตัวเลขโบนัส
3. เปิด `data/equipment/catalog.tres` แล้วเพิ่ม Resource นี้ใน `items`
4. UI จะมีช่องไอเทมตามลำดับ catalog; layout รุ่นนี้ออกแบบสำหรับตัวอย่าง 18 ไอเทม (6×3) หากต้องการมากกว่านั้นให้เพิ่ม pagination/ScrollContainer ของกระเป๋า
5. เซฟผู้เล่นเดิมจะไม่รับไอเทมที่เพิ่มใหม่โดยอัตโนมัติ ให้แจกด้วย `grant_item()` จากเควสต์/ดรอป/ร้านค้า

`slot` ที่ใช้ได้: `head`, `face`, `chest`, `legs`, `gloves`, `boots`, `back`, `neck`, `ring`, `bracelet`, `belt`, `charm`, `device`, `chip`
ชนิด `chip` ใส่ในช่อง `chip_a` หรือ `chip_b` ได้
ช่อง UI สร้างจากตำแหน่งสองคอลัมน์ใน `_build()` และปรับสเกลตาม viewport โดย `_layout()`

## เรียกใช้จากระบบอื่น

```gdscript
# รางวัลเควสต์หรือดรอปไอเทม: ตรวจ ID กับ catalog ก่อนเพิ่ม
if tamer.equipment.grant_item(&"power_chip", 1):
    GameChat.add_system("ได้รับ Power Chip")

# สวมลงช่องปกติ: ของเดิมคืน bag โดยอัตโนมัติ
var success: bool = tamer.equipment.put_on(&"field_jacket")

# ระบุช่องชิป: ไม่พึ่งการเลือกช่องอัตโนมัติ
success = tamer.equipment.put_on(&"power_chip", &"chip_a")

# ถอดและคืนกระเป๋า
success = tamer.equipment.take_off(&"chip_a")

# เปิดหน้าจอ ต้องไม่อยู่ในคัตซีนหรือ pause โดยระบบอื่น
var hud: MobileHUD = get_tree().current_scene.get_node("MobileHUD")
hud.equipment_screen.open_screen()
```

`put_on()` ตรวจเจ้าของ, ID, จำนวน, Lv และช่องให้ครบก่อนแก้ Dictionary
`changed` ส่งหลังธุรกรรมเสร็จ → Tamer คำนวณ stats, Partner คำนวณ stats, HUD อัปเดตจาก HP/DS signals และหน้าต่าง refresh
อย่าแก้ `bag` / `equipped` โดยตรงในระบบ gameplay ให้ผ่าน API เพื่อให้ stats/UI/save เปลี่ยนครบ

## สูตรและ HP

Tamer MaxHP = CharacterProgress MaxHP + ผลรวม `hp_bonus`
Tamer MaxDS = ค่าเริ่มต้น MaxDS ของ Scene + ผลรวม `ds_bonus`
Tamer Speed = CharacterProgress Speed + ผลรวม `speed_bonus`
Tamer Defense = ผลรวม `defense_bonus`
Tamer take_damage = max(1, amount - Defense) เมื่อ amount > 0

Partner ATK = ฐานร่าง + โบนัสเลเวล + ผลรวม `partner_attack_bonus`
Partner MaxHP = ฐานร่าง + โบนัสเลเวล + ผลรวม `partner_hp_bonus`
Partner Speed = ฐานร่าง + โบนัสเลเวล + ผลรวม `partner_speed_bonus`
สกิลเดิมเรียก `roll_damage(partner.attack_power, rng)` จึงใช้ ATK หลัง gear และแกว่ง ±5% ตามเดิม

เมื่อ gear เปลี่ยน จะ clamp HP/DS เฉพาะส่วนที่เกินเพดาน ไม่เพิ่มค่าปัจจุบัน
Digivolve ใช้นโยบายรักษาสัดส่วน HP เดิมของโปรเจกต์; Level Up เพิ่ม HP ตามส่วนต่างเลเวลเดิม; Recover กลับ Rookie HP เต็มตามเดิม
gear ไม่เปลี่ยนกฎเปลี่ยนร่าง, ข้อจำกัดเควสต์, สกิล หรือการฟื้นฟูเหล่านี้
ระหว่างคัตซีน `evolution_busy` จะปฏิเสธการแก้ gear

## Save และการย้ายโซน

`capture_party_state()` เพิ่ม `equipment: { version:1, bag:{id:quantity}, equipped:{slot:id} }`
`QuestManager` เซฟข้อมูลนี้ไปไฟล์เดิมทั้งตอนไอเทมเปลี่ยนและ Portal ย้าย Scene
`story_world._ready()` คืน CharacterProgress → คืน equipment → คำนวณ Tamer → คืน HP/DS → โหลดร่าง Partner พร้อมโบนัส → คืน HP/สถานะไข่
เซฟไม่มี equipment = migration จาก v14; เซฟมี equipment แต่ bag ว่าง = ไม่แจก starter
ID ไม่รู้จัก/ช่องผิดจะถูกกรองตอนโหลด จำนวนจำกัด 0..999 ของระดับสูงเกินจะถูกคืน bag

## Input และ pause

หน้าต่างถือครอง pause เมื่อเปิดสำเร็จเท่านั้น ปฏิเสธการเปิดเมื่อ Tree paused อยู่ก่อน
CanvasLayer ตั้ง Process Mode Always ส่วนโลกยังใช้ Pauseable/Inherited เดิม
ก่อน pause: คืนแชต/คีย์บอร์ด, ล้าง joystick, skill fingers และปุ่ม HUD ทั้งหมด
ปิด X/Esc/Android Back หรือออก Scene → คืน pause และ `quit_on_go_back` เดิม
ตัวปุ่มใช้ `InputEventScreenTouch` เดิมของโปรเจกต์ เพราะตั้ง `emulate_mouse_from_touch=false`; บนคอมเมาส์จำลอง touch ผ่าน setting เดิม

## ทดสอบ

เปิด `tests/equipment_test.tscn` → F6 หรือ CLI:

```bash
godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tests/equipment_test.tscn
```

ทดสอบธุรกรรม, requirement, bonus, ไม่มี stack/heal/resurrection, DF, เปลี่ยนร่าง, level, JSON/disk save, ย้าย Scene/migrate, touch, chip ช่องเฉพาะ, responsive layout, pause และ Esc
พรีวิว `tools/equipment_preview.tscn` ใช้เซฟแยกจากผู้เล่นเพื่อไม่ใส่ชุดสาธิตทับเซฟจริง

เอกสาร Godot: https://docs.godotengine.org/en/4.4/tutorials/scripting/resources.html และ https://docs.godotengine.org/en/4.4/tutorials/scripting/pausing_games.html
