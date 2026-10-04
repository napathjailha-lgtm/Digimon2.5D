class_name PartyStatusHUD
extends PanelContainer
## กรอบเดียวแสดงคู่หูและ Tamer; HP ทั้งสองยังเห็น แต่ DS ของ Tamer / MP คู่หูแยกกัน ไม่มี EXP ในกรอบ
@onready var tamer_portrait: TextureRect = $Margin/Rows/Portraits/TamerFrame/TamerIcon
@onready var partner_portrait: TextureRect = $Margin/Rows/Portraits/PartnerFrame/PartnerIcon
@onready var names: Label = $Margin/Rows/Portraits/Names
@onready var partner_hp: SmoothTextureBar = $Margin/Rows/PartnerHP
@onready var tamer_hp: SmoothTextureBar = $Margin/Rows/TamerHP
@onready var ds_bar: SmoothTextureBar = $Margin/Rows/Energy/DS
@onready var mp_bar: SmoothTextureBar = $Margin/Rows/Energy/MP
@onready var hunger_bar: SmoothTextureBar = $Margin/Rows/Needs/Hunger
@onready var stamina_bar: SmoothTextureBar = $Margin/Rows/Needs/Stamina
@onready var condition: Label = $Margin/Rows/Condition
var _tamer_texture: Texture2D
var _partner_texture: Texture2D

func _ready() -> void:
    # กรอบน้ำเงินเข้ม + เส้น cyan บาง ๆ ช่วยแยก HUD จากฉาก โดยไม่ใช้พื้นทึบสีสด
    add_theme_stylebox_override("panel", ClassicUIStyle.frame(Color("428b9f"), Color("071321f5")))
    ($Margin/Rows/Portraits/TamerFrame as PanelContainer).add_theme_stylebox_override("panel",ClassicUIStyle.frame(Color("bd9b63"),Color("172336")))
    ($Margin/Rows/Portraits/PartnerFrame as PanelContainer).add_theme_stylebox_override("panel",ClassicUIStyle.frame(Color("4dabc1"),Color("13293b")))

func update_values(tamer: Node, partner: Node) -> void:
    # Signal-driven อัปเดตเมื่อค่าจริงเปลี่ยน ตัดการสร้าง Atlas ซ้ำทุกเฟรม
    if partner.current_form == null:
        return
    names.text = "%s • Lv%d\n%s • Lv%d" % [tamer.display_name, tamer.progress.level, partner.current_form.monster_name if partner.is_alive() else "DIGITAMA", partner.progress.level]
    _update_hp(partner_hp, partner.hp, partner.max_hp, "คู่หู")
    _update_hp(tamer_hp, tamer.hp, tamer.max_hp, "Tamer")
    ds_bar.set_vitals(tamer.ds, tamer.max_ds, "DS %.0f/%.0f" % [tamer.ds, tamer.max_ds])
    mp_bar.set_vitals(partner.digimon_mp, partner.digimon_max_mp, "MP %.0f/%.0f" % [partner.digimon_mp,partner.digimon_max_mp])
    hunger_bar.set_vitals(tamer.tamer_hunger, 100, "อิ่ม %.0f/100" % tamer.tamer_hunger)
    stamina_bar.set_vitals(tamer.tamer_stamina, 100, "แรง %.0f/100" % tamer.tamer_stamina)
    condition.visible = not tamer.can_battle() or tamer.survival.is_resting()
    condition.text = "พักในเมือง • ฟื้น HP / MP" if tamer.can_battle() else "ต่อสู้ไม่ได้ • กินอาหารหรือพักในเมือง"
    condition.modulate = Color("9ee8ba") if tamer.can_battle() else Color("ffbdab")
    var tamer_image: Texture2D = tamer.sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
    var partner_image: Texture2D = partner.egg_sprite.texture if not partner.is_alive() else partner.current_form.sprite_frames.get_frame_texture(partner.current_form.idle_animation, 0)
    if tamer_image != _tamer_texture:
        _tamer_texture = tamer_image
        tamer_portrait.texture = _portrait(tamer_image)
    if partner_image != _partner_texture:
        _partner_texture = partner_image
        partner_portrait.texture = _portrait(partner_image)

func _update_hp(bar: SmoothTextureBar, hp: int, maximum: int, title: String) -> void:
    # สีกรอบเตือนเปลี่ยนทันทีเมื่อเลือดต่ำ แต่ไม่เริ่ม Tween เดิมซ้ำตาม Signal MP/อาหาร
    bar.set_vitals(hp, maximum, "%s HP  %d / %d" % [title, hp, maximum])
    bar.tint_over = Color("ff97a6") if float(hp) / maxi(1, maximum) <= 0.25 else Color.WHITE

func _portrait(texture: Texture2D) -> Texture2D:
    # Atlas ใช้ภาพเดิม ไม่สร้างรูปภาพใหม่; ตัดส่วนบนให้อ่านหน้าตัวละครในกรอบสี่เหลี่ยม
    var visible: Texture2D = WalkTextureTools.visible_texture(texture)
    var result := AtlasTexture.new()
    result.atlas = visible
    result.region = Rect2(0, 0, visible.get_width(), visible.get_height() * 0.5)
    return result
