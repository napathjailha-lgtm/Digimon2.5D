extends Node2D
@export var zone_id: StringName = &"lumen_isle"
@export var background_texture: Texture2D
@export var world_extent: Vector2 = Vector2(1280, 720)
@export var open_world_enabled: bool = false

func _ready() -> void:
    if GameManager.gameplay_active:
        GameManager.scene_entered()
        GameManager.set_menu_input(false)
    # ภาพพื้นหลังเป็น Texture จริง ย่อให้พอดีกับพื้นที่เกม 1280x720
    # ไม่มีการเพิ่ม collision จากภาพ พื้นที่เดินจึงยังใช้ NavigationPolygon เดิม
    if background_texture != null and not open_world_enabled:
        var background := Sprite2D.new()
        background.name = "WorldArtwork"
        background.texture = background_texture
        background.position = Vector2(640.0, 360.0)
        background.scale = Vector2(1280.0, 720.0) / background_texture.get_size()
        background.z_index = -100
        add_child(background)
    # ป้องกันเปิด Scene โซนที่ยังล็อกโดยตรง
    if not QuestManager.is_zone_unlocked(zone_id):
        _return_to_lumen_isle.call_deferred()
        return
    QuestManager.set_current_zone(zone_id)
    # เริ่ม BGM หลังผ่านการตรวจโซนแล้ว
    AudioManager.play_bgm()
    var state: Dictionary = QuestManager.party_snapshot if not QuestManager.party_snapshot.is_empty() else QuestManager.party_profile
    var tamer: Tamer = $Actors/Tamer
    var partner: PartnerMonster = $Actors/Partner
    # คืนข้อมูล Economy/Incubator ก่อนเปิด UI บนแผนที่
    GameManager.bits = maxi(0, int(state.get("bits", GameManager.DEFAULT_BITS)))
    GameManager.incubator_state = state.get("incubator", {}).duplicate(true) if state.get("incubator", {}) is Dictionary else {}
    GameManager.bits_changed.emit(GameManager.bits)
    if not state.is_empty():
        if state.get("tamer_progress", {}) is Dictionary:
            tamer.progress.restore_data(state.get("tamer_progress", {}))
        if state.get("equipment") is Dictionary:
            tamer.equipment.restore_data(state["equipment"])
        tamer.apply_progress_stats()
        tamer.hp = clampi(int(state.get("tamer_hp", tamer.max_hp)), 0, tamer.max_hp)
        tamer.ds = clampf(float(state.get("ds", tamer.ds)), 0.0, tamer.max_ds)
        if state.get("partner_progress", {}) is Dictionary:
            partner.progress.restore_data(state.get("partner_progress", {}))
        var selected: MonsterData = partner.forms[0]
        for data: MonsterData in partner.forms:
            if String(data.id) == str(state.get("form_id", "")) and QuestManager.can_use_form(data):
                selected = data
                break
        # โหลดร่างเซฟภายในก่อน เพื่อคืนสัดส่วน HP ถูกต้อง แล้วค่อยบังคับ Rookie ถ้า Tamer ล้ม
        partner._internal_load = true
        partner.load_monster_data(selected, false)
        partner._internal_load = false
        partner.hp = clampi(int(state.get("hp", partner.hp)), 0, partner.max_hp)
        if bool(state.get("egg", false)) or partner.hp == 0:
            partner.enter_fainted(false)
        var mp: Variant = state.get("digimon_mp",partner.digimon_max_mp)
        partner.digimon_mp = clampf(float(mp),0,partner.digimon_max_mp) if (mp is int or mp is float) and is_finite(float(mp)) else partner.digimon_max_mp
        partner.mp_changed.emit(partner.digimon_mp,partner.digimon_max_mp)
        var survival: Variant = state.get("survival",{})
        tamer.survival.restore_data(survival if survival is Dictionary else {})
        partner.hp_changed.emit(partner.hp, partner.max_hp)
        tamer.hp_changed.emit(tamer.hp, tamer.max_hp)
        tamer.ds_changed.emit(tamer.ds, tamer.max_ds)
    # คืนทีมหลังระบบ HP/เลเวลเดิมพร้อม แต่ก่อนกระเป๋า emit changed และเซฟ snapshot
    if is_instance_valid(tamer.party_roster):
        var roster_data: Variant = state.get("partner_roster", {})
        tamer.party_roster.initialize(roster_data if roster_data is Dictionary else {})
    # คืนกระเป๋าหลัง HP/ร่างพร้อมแล้ว changed จึงบันทึก snapshot ที่ครบทุกระบบ
    var saved_inventory: Variant = state.get("inventory", {})
    InventoryManager.bind_player(tamer, saved_inventory if saved_inventory is Dictionary else {})
    # state อาจเป็น Dictionary เดียวกับ snapshot ต้องอ่าน inventory ก่อน clear
    QuestManager.party_snapshot.clear()
    tamer.save_party_progress()

func _return_to_lumen_isle() -> void:
    get_tree().change_scene_to_file("res://scenes/world.tscn")

func _draw() -> void:
    if background_texture != null or open_world_enabled:
        return
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.18, 0.17))
    for x: int in range(0, 1281, 64):
        draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.2, 0.3, 0.27), 1.0)
    for y: int in range(0, 721, 64):
        draw_line(Vector2(0, y), Vector2(1280, y), Color(0.2, 0.3, 0.27), 1.0)
