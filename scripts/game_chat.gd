extends Node
## Autoload GameChat ไม่มี class_name ซ้ำชื่อ Singleton
## ตัวอย่างเป็นแชตภายในเครื่อง: outgoing_message คือจุดเชื่อมเซิร์ฟเวอร์ในอนาคต
signal messages_changed
signal outgoing_message(channel: StringName, text: String)
signal local_message_submitted(text: String)
const MAX_MESSAGES: int = 100
var messages: Array[Dictionary] = []

func _ready() -> void:
    add_system("ยินดีต้อนรับสู่ Digital Adventure")
    add_system("แชตจะเชื่อม Online Server อัตโนมัติเมื่อเปิดใช้งาน")
    QuestManager.quest_completed.connect(_on_quest_completed)

func add_system(text: String) -> void:
    # ข้อความระบบอยู่ต่อเมื่อเปลี่ยนโซน เพราะเก็บใน Autoload
    _append(&"system", "ระบบ", text)

func add_remote(sender: String, text: String) -> void:
    var clean_sender: String = sender.strip_edges().substr(0, 24)
    var clean_text: String = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").substr(0, 160)
    if clean_sender.is_empty() or clean_text.is_empty():
        return
    _append(&"general", clean_sender, clean_text)

func submit_local(text: String) -> bool:
    # จำกัดความยาวและข้ามข้อความว่าง ไม่ส่งออกเครือข่ายอัตโนมัติ
    var clean: String = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").substr(0, 160)
    if clean.is_empty():
        return false
    _append(&"general", "คุณ", clean)
    local_message_submitted.emit(clean)
    outgoing_message.emit(&"general", clean)
    return true

func _append(channel: StringName, sender: String, body: String) -> void:
    # เก็บข้อความธรรมดา ไม่ตีความ BBCode จากผู้เล่น
    messages.append({"channel": channel, "sender": sender, "body": body})
    while messages.size() > MAX_MESSAGES:
        messages.pop_front()
    messages_changed.emit()

func _on_quest_completed(quest_id: StringName) -> void:
    add_system("สำเร็จเควสต์: " + String(quest_id))
