class_name LootItem
extends Node2D
## Loot เป็นลูก Actors/World แยกจากศัตรู จึงยังอยู่หลังศัตรู queue_free
@export var item: ItemData
@export_range(1, 999) var quantity: int = 1
@export var pickup_delay: float = 0.15
@export var lifetime: float = 120.0
@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var quantity_label: Label = $Quantity
var _claimed: bool = false
var _age: float = 0.0
var _retry_left: float = 0.0
var _start: Vector2
var _collector: WeakRef
var _notice_left: float = 0.0

func _ready() -> void:
    # Sprite แสดงไอคอนจาก Resource ขนาดประมาณ 32px ไม่ใช่ภาพเต็ม Character
    add_to_group("ground_loot")
    if item == null or item.item_texture == null or quantity <= 0:
        queue_free()
        return
    sprite.texture = item.item_texture
    sprite.scale = Vector2.ONE * (32.0 / maxf(1.0, maxf(sprite.texture.get_width(), sprite.texture.get_height())))
    quantity_label.text = "x%d" % quantity
    area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    # Retry เมื่อกระเป๋าเต็มแล้วผู้เล่นเคลียร์ช่องโดยยังยืนอยู่ใน Area ไม่ต้องเดินออกเข้าใหม่
    _age += delta
    _notice_left = maxf(0.0, _notice_left - delta)
    if _claimed:
        return
    if lifetime > 0.0 and _age >= lifetime:
        queue_free()
        return
    if _age < pickup_delay:
        return
    _retry_left -= delta
    if _retry_left <= 0.0:
        _retry_left = 0.5
        for body: Node2D in area.get_overlapping_bodies():
            _on_body_entered(body)
            if _claimed:
                break

func _on_body_entered(body: Node2D) -> void:
    # รับเฉพาะ Tamer ปัจจุบัน คู่หู/ศัตรูไม่เก็บของ; flag กัน callback ซ้ำแจกไอเทมหลายครั้ง
    if _claimed or _age < pickup_delay or not body is Tamer or body != InventoryManager.player_node():
        return
    if _notice_left > 0.0:
        return
    _claimed = true
    if not InventoryManager.add_item(item, quantity):
        _claimed = false
        _notice_left = 2.0
        return
    # Commit ของเข้ากระเป๋าก่อน Tween ป้องกัน Scene เปลี่ยน/ผู้เก็บหายระหว่างเอฟเฟกต์แล้วของสูญหาย
    InventoryManager.item_picked_up.emit(item, quantity)
    _collector = weakref(body)
    _start = global_position
    area.set_deferred("monitoring", false)
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_method(_float_to_collector, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.0, 0.35)
    tween.chain().tween_callback(queue_free)

func _float_to_collector(weight: float) -> void:
    # อ่านตำแหน่ง Tamer ทุกเฟรม จึงดูดตามตัวที่กำลังเดินโดยไม่ dereference Object ถูก free
    var collector: Node2D = _collector.get_ref() as Node2D
    if is_instance_valid(collector):
        global_position = _start.lerp(collector.global_position + Vector2(0, -35), weight)
        global_position.y -= sin(weight * PI) * 24.0
