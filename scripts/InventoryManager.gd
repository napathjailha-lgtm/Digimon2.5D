extends Node
## Autoload ชื่อ InventoryManager ไม่ประกาศ class_name ซ้ำกับ Singleton
## เก็บสถานะกระเป๋าของตัวละครที่กำลังเล่น Resource เป็นข้อมูลอ่านอย่างเดียว
signal changed
signal feedback(message: String)
signal item_used(item: ItemData, restored_hp: int)
signal heal_requested(amount: int)
signal item_picked_up(item: ItemData, quantity: int)
const CATALOG_PATH: String = "res://data/items/catalog.tres"
const LOOT_SCENE_PATH: String = "res://scenes/loot_item.tscn"
@export_range(1, 24) var max_slots: int = 24
@export_range(1, 999) var max_stack: int = 999
var catalog: ItemCatalog
var _items: Array[Dictionary] = []
var _player: WeakRef
var _busy: bool = false

func _ready() -> void:
    # โหลดฐานข้อมูลครั้งเดียว ข้อมูลสามชนิดมีขนาดเล็กและไม่มี Scene โลกเป็น dependency
    catalog = load(CATALOG_PATH) as ItemCatalog

func bind_player(player: Node, saved_data: Dictionary = {}) -> void:
    # เรียกหลัง World คืนเซฟ ห้ามใช้กระเป๋าของตัวละครก่อนหน้าเป็นค่าเริ่มต้น
    var previous: Node = player_node()
    if is_instance_valid(previous) and changed.is_connected(previous.save_party_progress):
        changed.disconnect(previous.save_party_progress)
    if is_instance_valid(previous) and is_instance_valid(previous.partner) and heal_requested.is_connected(previous.partner.restore_hp):
        heal_requested.disconnect(previous.partner.restore_hp)
    _player = weakref(player)
    restore_data(saved_data)
    changed.connect(player.save_party_progress)
    heal_requested.connect(player.partner.restore_hp)
    changed.emit()

func player_node() -> Node:
    # WeakRef ไม่ยื้อ Node ของ Scene เก่า และไม่เรียกสมาชิกบน Object ที่ถูก free แล้ว
    return _player.get_ref() if _player != null else null

func items() -> Array[Dictionary]:
    # UI ได้สำเนารายการ เพื่อไม่แก้ quantity ของจริงโดยข้ามฟังก์ชันตรวจเงื่อนไข
    return _items.duplicate(true)

func item_at(index: int) -> ItemData:
    # ปฏิเสธ index เก่า/นอกขอบ เพราะลบ stack แล้วลำดับ Array เปลี่ยนได้
    return _items[index].item if index >= 0 and index < _items.size() else null

func index_of(id: String) -> int:
    # UI จำ ID แล้วค้น index ใหม่ทุกครั้ง ไม่ผูกปุ่ม Use กับเลข index ค้างไว้
    for index: int in range(_items.size()):
        if _items[index].item.item_id == id:
            return index
    return -1

func count(id: String) -> int:
    # รวมจำนวนจาก stack ของ ID เดียว รุ่นนี้หนึ่ง ID ใช้หนึ่งช่องและเพดาน max_stack
    var index: int = index_of(id)
    return int(_items[index].quantity) if index >= 0 else 0

func _fail(message: String) -> bool:
    feedback.emit(message)
    return false

func add_item(item: ItemData, quantity: int = 1) -> bool:
    # รับครบจำนวนหรือไม่รับเลย เพื่อให้ Loot บนพื้นไม่หายเมื่อ stack/กระเป๋าเต็ม
    if _busy or item == null or quantity <= 0 or catalog == null:
        return false
    var canonical: ItemData = catalog.find_item(item.item_id)
    if canonical == null:
        return _fail("ไอเทมนี้ไม่อยู่ในฐานข้อมูล")
    var index: int = index_of(canonical.item_id)
    if quantity > max_stack - count(canonical.item_id):
        return _fail("จำนวนไอเทมเกินเพดานซ้อน เก็บเพิ่มไม่ได้")
    if index < 0 and _items.size() >= max_slots:
        return _fail("กระเป๋าเต็ม ไอเทมยังอยู่บนพื้น")
    if index < 0:
        _items.append({"item":canonical, "quantity":quantity})
    else:
        _items[index].quantity += quantity
    changed.emit()
    return true

func is_tradeable(item: ItemData) -> bool:
    # ไอเทมเควสต์ผูกกับความคืบหน้าตัวละคร ห้ามส่งต่อ
    return item != null and item.item_type != ItemData.ItemType.QUEST_ITEM


func validate_trade(outgoing: Array, incoming: Array, outgoing_bits: int = 0, incoming_bits: int = 0) -> String:
    if _busy or catalog == null:
        return "กระเป๋ากำลังถูกใช้งาน"
    if outgoing_bits < 0 or incoming_bits < 0:
        return "จำนวน Bits ไม่ถูกต้อง"
    if not GameManager.can_apply_trade_bits(outgoing_bits, incoming_bits):
        return "Bits ไม่เพียงพอหรือเกินเพดาน"

    var simulated: Dictionary = {}
    for entry: Dictionary in _items:
        var current: ItemData = entry.item
        simulated[current.item_id] = int(entry.quantity)

    for value: Variant in outgoing:
        if not (value is Dictionary):
            return "ข้อมูลไอเทมที่เสนอไม่ถูกต้อง"
        var entry := value as Dictionary
        var item_id: String = str(entry.get("id", ""))
        var quantity: int = int(entry.get("quantity", 0))
        var item: ItemData = catalog.find_item(item_id)
        if item == null or not is_tradeable(item) or quantity <= 0:
            return "มีไอเทมที่ไม่สามารถแลกเปลี่ยนได้"
        var owned: int = int(simulated.get(item_id, 0))
        if owned < quantity:
            return "%s มีไม่ครบตามจำนวนที่เสนอ" % item.item_name
        simulated[item_id] = owned - quantity

    for value: Variant in incoming:
        if not (value is Dictionary):
            return "ข้อมูลไอเทมที่จะรับไม่ถูกต้อง"
        var entry := value as Dictionary
        var item_id: String = str(entry.get("id", ""))
        var quantity: int = int(entry.get("quantity", 0))
        var item: ItemData = catalog.find_item(item_id)
        if item == null or not is_tradeable(item) or quantity <= 0:
            return "มีไอเทมฝั่งคู่ค้าไม่ถูกต้อง"
        var next_quantity: int = int(simulated.get(item_id, 0)) + quantity
        if next_quantity > max_stack:
            return "%s จะเกินจำนวนซ้อนสูงสุด" % item.item_name
        simulated[item_id] = next_quantity

    var used_slots: int = 0
    for amount: Variant in simulated.values():
        if int(amount) > 0:
            used_slots += 1
    if used_slots > max_slots:
        return "กระเป๋าไม่พอรับของจากการแลกเปลี่ยน"
    return ""


func apply_trade(outgoing: Array, incoming: Array, outgoing_bits: int = 0, incoming_bits: int = 0) -> bool:
    var error: String = validate_trade(outgoing, incoming, outgoing_bits, incoming_bits)
    if not error.is_empty():
        feedback.emit(error)
        return false

    _busy = true
    for value: Variant in outgoing:
        var entry := value as Dictionary
        var item_id: String = str(entry.get("id", ""))
        var quantity: int = int(entry.get("quantity", 0))
        var index: int = index_of(item_id)
        if index >= 0:
            _remove(index, quantity)

    for value: Variant in incoming:
        var entry := value as Dictionary
        var item_id: String = str(entry.get("id", ""))
        var quantity: int = int(entry.get("quantity", 0))
        var item: ItemData = catalog.find_item(item_id)
        var index: int = index_of(item_id)
        if index < 0:
            _items.append({"item": item, "quantity": quantity})
        else:
            _items[index].quantity += quantity

    var bits_ok: bool = GameManager.apply_trade_bits(outgoing_bits, incoming_bits)
    _busy = false
    if not bits_ok:
        push_error("InventoryManager: validated trade failed Bits commit")
        return false
    changed.emit()
    feedback.emit("แลกเปลี่ยนสำเร็จ")
    return true


func can_use_item(item: ItemData) -> bool:
    # ใช้ guard เดียวกันทั้ง UI และคำสั่งจริง ไม่ปิดอาหารเพราะ HP คู่หูเต็ม/ยังเป็นไข่
    return _use_error(item,player_node()).is_empty()

func _use_error(item: ItemData, player: Node) -> String:
    if item == null or not is_instance_valid(player):
        return "ไม่พบไอเทมหรือ Tamer"
    if item.item_type == ItemData.ItemType.EGG:
        return "ต้องนำ Digitama ไปใช้ที่ Digital Incubator กลางหมู่บ้าน"
    if item.item_type != ItemData.ItemType.CONSUMABLE:
        return "ไข่เก็บไว้สำหรับระบบฟัก ส่วนชิปข้อมูลใช้เป็นไอเทมเควสต์"
    if not is_instance_valid(player.partner) or player.partner.evolution_busy:
        return "รอคัตซีนเปลี่ยนร่างจบก่อน"
    match item.effect_type:
        ItemData.EffectType.TAMER_FOOD:
            if not player.can_eat_food(item.effect_value,item.tamer_hp_restore,item.tamer_stamina_restore):
                return "ค่าที่อาหารนี้ฟื้นได้เต็มแล้ว"
        ItemData.EffectType.PARTNER_HP:
            if not player.partner.is_alive(): return "คู่หูสลบ ใช้ Recover ก่อนใช้เนื้อ"
            if item.effect_value <= 0 or player.partner.hp >= player.partner.max_hp: return "HP เต็มแล้ว ไอเทมยังอยู่ในกระเป๋า"
        ItemData.EffectType.PARTNER_MP:
            if not player.partner.is_alive(): return "คู่หูสลบ ใช้ Recover ก่อนฟื้น MP"
            if item.effect_value <= 0 or player.partner.digimon_mp >= player.partner.digimon_max_mp: return "MP เต็มแล้ว ไอเทมยังอยู่ในกระเป๋า"
        ItemData.EffectType.TAMER_HP:
            if item.effect_value <= 0 or player.hp >= player.max_hp: return "HP Tamer เต็มแล้ว ไอเทมยังอยู่ในกระเป๋า"
        ItemData.EffectType.TAMER_MP:
            if item.effect_value <= 0 or player.tamer_mp >= player.max_tamer_mp: return "MP Tamer เต็มแล้ว ไอเทมยังอยู่ในกระเป๋า"
        ItemData.EffectType.TAMER_MP_REGEN:
            if item.tamer_mp_regen_per_second <= 0.0 or item.tamer_mp_regen_duration <= 0.0:
                return "ไอเทม Regen MP ตั้งค่าไม่ถูกต้อง"
            if player.tamer_mp >= player.max_tamer_mp:
                return "MP Tamer เต็มแล้ว ไอเทมยังอยู่ในกระเป๋า"
        _: return "ไม่รู้จักผลของไอเทม"
    return ""

func use_item(item_index: int) -> bool:
    # ตรวจครบก่อนเริ่ม; commit ผลและจำนวนของหนึ่งครั้ง จึงค่อย emit changed เพื่อเซฟ
    var item: ItemData = item_at(item_index)
    var player: Node = player_node()
    if _busy:
        return false
    var error: String = _use_error(item,player)
    if not error.is_empty():
        return _fail(error)
    _busy = true
    var healed: int = 0
    var applied: bool = false
    var message: String = ""
    if item.item_type == ItemData.ItemType.EGG:
        _busy = false
        return _fail("Digitama ฟักได้เฉพาะที่ Digital Incubator")
    match item.effect_type:
        ItemData.EffectType.TAMER_FOOD:
            var previous_hp: int = player.hp
            applied = player.eat_food(item.effect_value,item.tamer_hp_restore,item.tamer_stamina_restore)
            healed = player.hp-previous_hp
            message = "Tamer อิ่ม +%d / HP +%d" % [item.effect_value,healed]
        ItemData.EffectType.PARTNER_HP:
            var previous_hp: int = player.partner.hp
            heal_requested.emit(item.effect_value)
            healed = maxi(0,int(player.partner.hp)-previous_hp)
            applied = healed > 0
            message = "คู่หู HP +%d" % healed
        ItemData.EffectType.PARTNER_MP:
            var restored: float = player.partner.restore_mp(item.effect_value)
            applied = restored > 0
            message = "คู่หู MP +%.0f" % restored
        ItemData.EffectType.TAMER_HP:
            var previous_hp: int = player.hp
            player.restore_hp(item.effect_value)
            healed = maxi(0, int(player.hp) - previous_hp)
            applied = healed > 0
            message = "Tamer HP +%d" % healed
        ItemData.EffectType.TAMER_MP:
            var previous_mp: float = player.tamer_mp
            player.restore_mp(float(item.effect_value))
            var restored_mp: float = maxf(0.0, player.tamer_mp - previous_mp)
            applied = restored_mp > 0.0
            message = "Tamer MP +%.0f" % restored_mp
        ItemData.EffectType.TAMER_MP_REGEN:
            applied = player.start_mp_regen(item.tamer_mp_regen_per_second, item.tamer_mp_regen_duration)
            message = "Tamer MP Regen +%.1f/วิ • %.0f วิ" % [item.tamer_mp_regen_per_second, item.tamer_mp_regen_duration]
    if not applied:
        _busy = false
        return false
    _remove(item_index,1)
    _busy = false
    changed.emit() # รวม HP/MP/Hunger/Stamina และจำนวนใหม่ใน snapshot เดียว
    item_used.emit(item,healed)
    feedback.emit("ใช้ %s — %s" % [item.item_name,message])
    return true

func use_item_by_id(item_id: String) -> bool:
    var index: int = index_of(item_id)
    if index < 0:
        return _fail("ไม่มีไอเทมนี้ในกระเป๋า")
    return use_item(index)

func remove_item(item_id: String, quantity: int = 1) -> bool:
    # API กลางสำหรับร้านค้าและ Incubator ตัดของผ่านจุดเดียว
    if _busy or quantity <= 0:
        return false
    var index: int = index_of(item_id)
    if index < 0 or int(_items[index].quantity) < quantity:
        return false
    _remove(index, quantity)
    changed.emit()
    return true

func _remove(index: int, quantity: int) -> void:
    # ฟังก์ชันภายใน เรียกหลัง validation แล้ว จำนวนเป็นศูนย์จึงลบ stack
    _items[index].quantity -= quantity
    if _items[index].quantity <= 0:
        _items.remove_at(index)

func drop_item(item_index: int, quantity: int = 1) -> bool:
    # ทิ้งเป็น Loot จริง มีช่วงหน่วงก่อนดูดกลับ ไม่ลบของทิ้งถ้าไม่มี World รองรับ
    var item: ItemData = item_at(item_index)
    var player: Node2D = player_node() as Node2D
    if _busy or item == null or quantity <= 0 or quantity > int(_items[item_index].quantity) or not is_instance_valid(player):
        return false
    if player.partner.evolution_busy:
        return _fail("รอคัตซีนเปลี่ยนร่างจบก่อน")
    var parent: Node2D = player.get_parent() as Node2D
    if parent == null:
        return false
    var loot: Node2D = create_loot(item, quantity, parent, player.global_position + Vector2(55, 12), 1.0)
    if loot == null:
        return false
    _remove(item_index, quantity)
    changed.emit()
    feedback.emit("วาง %s x%d บนพื้น" % [item.item_name, quantity])
    return true

func create_loot(item: ItemData, quantity: int, parent: Node2D, at: Vector2, pickup_delay: float = 0.15) -> Node2D:
    # ใช้ร่วมกันทั้ง Drop จาก UI และมอนสเตอร์ ตั้งข้อมูล/พิกัดก่อน add_child
    if item == null or quantity <= 0 or not is_instance_valid(parent) or catalog.find_item(item.item_id) == null:
        return null
    var scene: PackedScene = load(LOOT_SCENE_PATH) as PackedScene
    if scene == null:
        return null
    var loot: Node2D = scene.instantiate() as Node2D
    loot.set("item", item)
    loot.set("quantity", quantity)
    loot.set("pickup_delay", maxf(0.0, pickup_delay))
    loot.position = parent.to_local(at)
    parent.add_child(loot)
    return loot

func get_save_data() -> Dictionary:
    # JSON มีแต่ ID/quantity ไม่เก็บ Resource, Node หรือ Texture ลงไฟล์
    var stacks: Array[Dictionary] = []
    for entry: Dictionary in _items:
        stacks.append({"id":entry.item.item_id, "quantity":int(entry.quantity)})
    return {"version":1, "stacks":stacks}

func restore_data(data: Dictionary) -> void:
    # เซฟเก่าที่ไม่มี inventory ได้กระเป๋าว่าง; เซฟว่างไม่แจกของซ้ำเมื่อเข้า Scene ใหม่
    _items.clear()
    var stacks: Variant = data.get("stacks", [])
    if not stacks is Array or catalog == null:
        return
    for entry: Variant in stacks:
        if not entry is Dictionary:
            continue
        var item: ItemData = catalog.find_item(str(entry.get("id", "")))
        var number: Variant = entry.get("quantity", 0)
        if item == null or not (number is int or number is float):
            continue
        if not is_finite(float(number)) or float(number) <= 0 or floorf(float(number)) != float(number):
            continue
        var quantity: int = int(minf(float(number), float(max_stack)))
        var index: int = index_of(item.item_id)
        if index >= 0:
            _items[index].quantity = mini(max_stack, int(_items[index].quantity) + quantity)
        elif _items.size() < max_slots:
            _items.append({"item":item, "quantity":quantity})
