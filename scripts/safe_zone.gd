extends Area2D
## เขตพัก: เดินเข้าแล้วหยุด Survival damage ฟื้น HP Tamer/MP คู่หู และ Recover ร่างไข่
var _visitors: Dictionary = {} # WeakRef ตาม ID ป้องกันถือ Tamer ของ Scene เก่า
func _ready() -> void:
    # mask=2 ตรวจเฉพาะ Tamer; body_exited ใช้คืนการนับเวลาความหิวเมื่อออกเมือง
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
    if not body is Tamer:
        return
    _visitors[body.get_instance_id()] = weakref(body)
    body.survival.set_safe_zone(self,true)
    if is_instance_valid(body.partner):
        body.partner.recover()

func _on_body_exited(body: Node2D) -> void:
    if body is Tamer:
        _visitors.erase(body.get_instance_id())
        body.survival.set_safe_zone(self,false)

func _exit_tree() -> void:
    # Safe Zone อาจถูกลบโดยไม่ส่ง exit; ปล่อยสถานะพักให้ทุกคนที่ยังอยู่ใน Scene
    for reference: WeakRef in _visitors.values():
        var visitor: Tamer = reference.get_ref() as Tamer
        if is_instance_valid(visitor) and is_instance_valid(visitor.survival):
            visitor.survival.set_safe_zone(self,false)
    _visitors.clear()
