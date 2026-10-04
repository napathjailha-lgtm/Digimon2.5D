class_name DamagePopup
extends Node2D
## หนึ่ง instance ต่อหนึ่ง hit: Pop + ลอยขึ้น + จางหาย แล้วลบตัวเอง
## กำหนด damage_amount และ position ก่อน add_child เพื่อให้ _ready ใช้ค่าถูกต้อง

@export var damage_amount: int = 0
@export_range(0.3, 2.0) var lifetime: float = 0.8
@export var float_distance: float = 70.0
@export var horizontal_spread: float = 35.0
@export var spawn_spread: float = 10.0
@export var text_color: Color = Color(1.0, 0.85, 0.25)
@onready var label: Label = $Label

func _ready() -> void:
    add_to_group("damage_popups")
    label.text = str(damage_amount)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    modulate = text_color
    modulate.a = 1.0

    # กระจายจุดเริ่มและปลายทางแยกกัน ลดการซ้อนเมื่อโดนหลาย hit
    position.x += randf_range(-absf(spawn_spread), absf(spawn_spread))
    var destination: Vector2 = position + Vector2(
        randf_range(-absf(horizontal_spread), absf(horizontal_spread)),
        -absf(float_distance)
    )
    var duration: float = maxf(0.3, lifetime)
    scale = Vector2.ONE * 0.8

    # Tween แรกทำงานตามลำดับ: ขยายแล้วกลับขนาดปกติ
    # Node.create_tween() ผูก Tween กับ Popup นี้โดยอัตโนมัติ
    var pop_tween: Tween = create_tween()
    pop_tween.tween_property(
        self, "scale", Vector2.ONE * 1.25, minf(0.1, duration * 0.25)
    ).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop_tween.tween_property(
        self, "scale", Vector2.ONE, minf(0.16, duration * 0.25)
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    # Tween ที่สอง: ลอยและจางทำงานขนานกัน โดย Fade เริ่มช่วงท้าย
    # แต่ละ Tween เปลี่ยนคนละ property จึงไม่แย่งค่า scale กัน
    var float_tween: Tween = create_tween().set_parallel(true)
    float_tween.tween_property(
        self, "position", destination, duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    float_tween.tween_property(
        self, "modulate:a", 0.0, duration * 0.45
    ).set_delay(duration * 0.55)

    # chain() รอทั้งการลอยและ Fade จบก่อนลบ Node
    float_tween.chain().tween_callback(queue_free)
