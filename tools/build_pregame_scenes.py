"""สร้าง .tscn ที่มี Control Nodes จริงใน Editor; ไม่ต้องรันสคริปต์นี้เพื่อเล่นเกม"""
from pathlib import Path
R=Path(__file__).resolve().parents[1];D=R/'scenes/pregame'
D.mkdir(parents=True,exist_ok=True)
# Theme ใช้ StyleBoxFlat และฟอนต์ไทยร่วมทุกเมนู
T=R/'data/pregame/menu_theme.tres'
T.write_text('''[gd_resource type="Theme" load_steps=7 format=3]
[ext_resource type="FontFile" path="res://assets/fonts/NotoSansThai.ttf" id="font"]
[sub_resource type="StyleBoxFlat" id="normal"]
bg_color = Color(0.025, 0.1, 0.18, 0.96)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.22, 0.46, 0.62, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
content_margin_left = 10.0
content_margin_right = 10.0
content_margin_top = 8.0
content_margin_bottom = 8.0
[sub_resource type="StyleBoxFlat" id="selected"]
bg_color = Color(0.09, 0.28, 0.4, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.88, 0.75, 0.45, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
content_margin_left = 10.0
content_margin_right = 10.0
content_margin_top = 8.0
content_margin_bottom = 8.0
[sub_resource type="StyleBoxFlat" id="hover"]
bg_color = Color(0.1, 0.24, 0.35, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.36, 0.77, 0.87, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
content_margin_left = 10.0
content_margin_right = 10.0
content_margin_top = 8.0
content_margin_bottom = 8.0
[sub_resource type="StyleBoxFlat" id="focus"]
bg_color = Color(0, 0, 0, 0)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.31, 0.78, 0.9, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
[sub_resource type="StyleBoxFlat" id="disabled"]
bg_color = Color(0.025, 0.08, 0.12, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.12, 0.25, 0.35, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_left = 8
corner_radius_bottom_right = 8
[resource]
default_font = ExtResource("font")
default_font_size = 17
Button/colors/font_color = Color(0.9, 0.97, 1, 1)
Button/colors/font_disabled_color = Color(0.45, 0.6, 0.68, 1)
Button/styles/normal = SubResource("normal")
Button/styles/pressed = SubResource("selected")
Button/styles/hover_pressed = SubResource("selected")
Button/styles/hover = SubResource("hover")
Button/styles/disabled = SubResource("disabled")
Button/styles/focus = SubResource("focus")
PanelContainer/styles/panel = SubResource("normal")
LineEdit/styles/normal = SubResource("normal")
LineEdit/styles/focus = SubResource("focus")
LineEdit/font_sizes/font_size = 20
OptionButton/styles/normal = SubResource("normal")
OptionButton/styles/hover = SubResource("hover")
OptionButton/styles/pressed = SubResource("selected")
Label/colors/font_color = Color(0.84, 0.93, 0.97, 1)
VBoxContainer/constants/separation = 12
HBoxContainer/constants/separation = 18
GridContainer/constants/h_separation = 10
GridContainer/constants/v_separation = 10
''')
class Scene:
 def __init__(self,script):
  self.text='[gd_scene load_steps=4 format=3]\n[ext_resource type="Script" path="res://scripts/pregame/'+script+'.gd" id="script"]\n[ext_resource type="Script" path="res://scripts/pregame/menu_background.gd" id="bg"]\n[ext_resource type="Theme" path="res://data/pregame/menu_theme.tres" id="theme"]\n'
 def node(self,name,type,parent=None,props=''):
  self.text+='[node name="'+name+'" type="'+type+'"'+(' parent="'+parent+'"' if parent is not None else '')+']\n'+props+'\n'
 def root(self,title,subtitle,back=False):
  self.node('Screen','Control',props='layout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = ExtResource("script")\ntheme = ExtResource("theme")')
  self.node('Background','Control','.', 'layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nscript = ExtResource("bg")\nmouse_filter = 2')
  self.node('Margin','MarginContainer','.', 'layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ntheme_override_constants/margin_left = 28\ntheme_override_constants/margin_right = 28\ntheme_override_constants/margin_top = 24\ntheme_override_constants/margin_bottom = 20')
  self.node('Column','VBoxContainer','Margin','layout_mode = 2\ntheme_override_constants/separation = 18')
  self.node('Header','HBoxContainer','Margin/Column','layout_mode = 2')
  self.label('Title','Margin/Column/Header',title,27,'size_flags_horizontal = 3')
  self.label('Subtitle','Margin/Column/Header',subtitle,14,'vertical_alignment = 1')
  if back:self.button('Back','Margin/Column/Header','ย้อนกลับ',112,44)
 def label(self,name,parent,text,font=17,props=''):
  text=text.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')
  self.node(name,'Label',parent,f'layout_mode = 2\ntext = "{text}"\ntheme_override_font_sizes/font_size = {font}\nmouse_filter = 2\n'+props)
 def button(self,name,parent,text,w=0,h=50):
  self.node(name,'Button',parent,f'layout_mode = 2\ncustom_minimum_size = Vector2({w}, {h})\ntext = "{text}"')
 def panel(self,name,parent,w=0):
  self.node(name,'PanelContainer',parent,f'layout_mode = 2\ncustom_minimum_size = Vector2({w}, 0)\nsize_flags_horizontal = 3')
  path=parent+'/'+name if parent!='.' else name
  self.node('Inner','MarginContainer',path,'layout_mode = 2\ntheme_override_constants/margin_left = 16\ntheme_override_constants/margin_right = 16\ntheme_override_constants/margin_top = 16\ntheme_override_constants/margin_bottom = 16')
  self.node('Stack','VBoxContainer',path+'/Inner','layout_mode = 2')
  return path+'/Inner/Stack'
 def image(self,name,parent,h=240):
  self.node(name,'TextureRect',parent,f'layout_mode = 2\ncustom_minimum_size = Vector2(0, {h})\nsize_flags_vertical = 3\nmouse_filter = 2\nexpand_mode = 1\nstretch_mode = 5')
 def footer(self):self.label('Message','Margin/Column','',15,'custom_minimum_size = Vector2(0, 28)\ntheme_override_colors/font_color = Color(0.96, 0.81, 0.5, 1)')
 def save(self,name): (D/(name+'.tscn')).write_text(self.text)
# Card: ปุ่ม root และ VBox ที่มองเห็นได้ใน Editor
s=Scene('menu_screen');s.text='[gd_scene format=3]\n'
s.node('SelectionCard','Button',props='custom_minimum_size = Vector2(126, 198)\ntoggle_mode = true\nmouse_filter = 0')
s.node('Margin','MarginContainer','.', 'layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 8.0\noffset_top = 10.0\noffset_right = -8.0\noffset_bottom = -8.0\nmouse_filter = 2')
s.node('Column','VBoxContainer','Margin','layout_mode = 2\nmouse_filter = 2\ntheme_override_constants/separation = 5')
s.image('Portrait','Margin/Column',68)
s.label('Name','Margin/Column','Name',15,'horizontal_alignment = 1')
s.label('Detail','Margin/Column','Style',12,'horizontal_alignment = 1\ntheme_override_colors/font_color = Color(0.43, 0.83, 0.93, 1)');s.save('selection_card')
# Loading TextureProgressBar มี GradientTexture2D จริง ไม่มี Tween จำลองค่าโหลด
s=Scene('loading_screen');s.root('DIGITAL ADVENTURE','01 / DIGITAL GATE')
s.node('Center','CenterContainer','Margin/Column','layout_mode = 2\nsize_flags_vertical = 3')
s.node('Panel','PanelContainer','Margin/Column/Center','layout_mode = 2\ncustom_minimum_size = Vector2(780, 320)')
s.node('Inner','MarginContainer','Margin/Column/Center/Panel','layout_mode = 2\ntheme_override_constants/margin_left = 34\ntheme_override_constants/margin_right = 34\ntheme_override_constants/margin_top = 26\ntheme_override_constants/margin_bottom = 26')
s.node('Stack','VBoxContainer','Margin/Column/Center/Panel/Inner','layout_mode = 2\ntheme_override_constants/separation = 16')
p='Margin/Column/Center/Panel/Inner/Stack';s.label('Logo',p,'DIGITAL GATE',42,'horizontal_alignment = 1');s.label('Status',p,'กำลังโหลดโลกดิจิตอล…',19,'horizontal_alignment = 1')
s.node('Progress','TextureProgressBar',p,'layout_mode = 2\ncustom_minimum_size = Vector2(700, 22)\ntexture_under = SubResource("under")\ntexture_progress = SubResource("fill")\nnine_patch_stretch = true');s.label('Percent',p,'0%',24,'horizontal_alignment = 1');s.button('Retry',p,'ลองใหม่');s.footer()
sub='''[sub_resource type="Gradient" id="ug"]
colors = PackedColorArray(0.035, 0.09, 0.14, 1, 0.035, 0.09, 0.14, 1)
[sub_resource type="GradientTexture2D" id="under"]
gradient = SubResource("ug")
width = 700
height = 22
[sub_resource type="Gradient" id="fg"]
colors = PackedColorArray(0.17, 0.55, 0.76, 1, 0.42, 0.9, 0.87, 1)
[sub_resource type="GradientTexture2D" id="fill"]
gradient = SubResource("fg")
width = 700
height = 22
''';idx=s.text.index('[node name=');s.text=s.text[:idx]+sub+s.text[idx:];s.text=s.text.replace('load_steps=4','load_steps=8');s.save('loading_screen')
# Login
s=Scene('login_screen');s.root('DIGITAL ADVENTURE','OFFLINE DEMO · LANDSCAPE')
s.node('Body','HBoxContainer','Margin/Column','layout_mode = 2\nsize_flags_vertical = 3\nalignment = 1')
s.node('Hero','VBoxContainer','Margin/Column/Body','layout_mode = 2\nsize_flags_horizontal = 3\nalignment = 1')
s.label('HeroTitle','Margin/Column/Body/Hero','DIGITAL\nADVENTURE',60,'theme_override_colors/font_color = Color(0.55, 0.88, 0.98, 1)')
s.label('HeroSubtitle','Margin/Column/Body/Hero','หนึ่งเทมเมอร์ • หนึ่งคู่หู • การผจญภัยครั้งใหม่',23)
s.label('HeroNote','Margin/Column/Body/Hero','FILE ISLAND → SERVER CONTINENT\n→ ODAIBA → SPIRAL MOUNTAIN',17,'theme_override_colors/font_color = Color(0.87, 0.72, 0.4, 1)')
p=s.panel('LoginPanel','Margin/Column/Body',448)
s.label('Name',p,'ยินดีต้อนรับ เทมเมอร์',26)
s.label('Help',p,'Login จำลอง — ใช้ demo / demo เพื่อเริ่ม',14)
s.label('UserLabel',p,'USERNAME',13)
s.node('Username','LineEdit',p,'layout_mode = 2\ncustom_minimum_size = Vector2(0, 52)\nplaceholder_text = "Username"\nmax_length = 24')
s.label('PasswordLabel',p,'PASSWORD',13)
s.node('Password','LineEdit',p,'layout_mode = 2\ncustom_minimum_size = Vector2(0, 52)\nplaceholder_text = "Password"\nmax_length = 64\nsecret = true')
s.label('ServerLabel',p,'เลือกเซิร์ฟเวอร์',14);s.node('Server','OptionButton',p,'layout_mode = 2\ncustom_minimum_size = Vector2(0, 50)');s.button('Login',p,'LOGIN  →',0,60)
s.label('Notice',p,'ระบบทดสอบภายในเครื่อง ไม่มีการส่งรหัสผ่าน',12);s.footer();s.save('login_screen')
# Character selection
s=Scene('character_selection');s.root('เลือก / สร้าง TAMER','',True);s.node('Body','HBoxContainer','Margin/Column','layout_mode = 2\nsize_flags_vertical = 3')
p=s.panel('Slots','Margin/Column/Body',198);s.label('Title',p,'ตัวละครของคุณ',19);s.node('SlotsList','VBoxContainer',p,'layout_mode = 2\nsize_flags_vertical = 3\ntheme_override_constants/separation = 8');s.button('ImportLegacy',p,'นำเข้าเซฟ v15',0,40)
p=s.panel('Preview','Margin/Column/Body',346);s.label('Name',p,'Tamer',22,'horizontal_alignment = 1');s.image('Portrait',p,276);s.label('Details',p,'Status',15,'autowrap_mode = 3')
p=s.panel('Create','Margin/Column/Body',520);s.label('Title',p,'เลือกเด็กผู้ถูกเลือก',23);s.node('Models','GridContainer',p,'layout_mode = 2\ncolumns = 5\ntheme_override_constants/h_separation = 6');s.label('ModelNote',p,'5 โมเดล • ชาย / หญิง • สไตล์เริ่มต้นต่างกัน',14);s.label('NameTitle',p,'ชื่อ Tamer',16)
s.node('TamerName','LineEdit',p,'layout_mode = 2\ncustom_minimum_size = Vector2(0, 52)\nmax_length = 16\nplaceholder_text = "กรอกชื่อ 2–16 ตัวอักษร"')
s.label('Hint',p,'ตัวละครใหม่จะเลือกคู่หูในหน้าถัดไป\nตัวละครเดิมเข้าสู่แผนที่พร้อมเซฟเดิม',14)
s.node('Spacer','Control',p,'layout_mode = 2\nsize_flags_vertical = 3\nmouse_filter = 2');s.button('Action',p,'สร้างตัวละคร → เลือกคู่หู',0,58);s.footer();s.save('character_selection')
# Starter selection
s=Scene('starter_selection');s.root('เลือกคู่หูเริ่มต้น','',True);s.node('Body','HBoxContainer','Margin/Column','layout_mode = 2\nsize_flags_vertical = 3')
p=s.panel('Preview','Margin/Column/Body',338);s.label('Name',p,'Starter',24,'horizontal_alignment = 1');s.image('Portrait',p,278);s.label('Details',p,'HP / ATK / SPD',17,'autowrap_mode = 3')
p=s.panel('Selection','Margin/Column/Body',818);s.label('Title',p,'คู่หูของคุณจะเติบโตไปด้วยกัน',24);s.node('Cards','GridContainer',p,'layout_mode = 2\ncolumns = 5\ntheme_override_constants/h_separation = 10')
s.label('PathTitle',p,'EVOLUTION PATH',13,'theme_override_colors/font_color = Color(0.92, 0.79, 0.48, 1)');s.label('EvolutionPath',p,'Rookie → Champion → Ultimate',21,'autowrap_mode = 3');s.label('Description',p,'รายละเอียด',16,'autowrap_mode = 3');s.node('Spacer','Control',p,'layout_mode = 2\nsize_flags_vertical = 3\nmouse_filter = 2');s.button('Confirm',p,'ยืนยันคู่หู → เข้าสู่โลกดิจิตอล',0,58);s.footer();s.save('starter_selection')
print('Four menu scenes + editor-visible card + Thai Theme ready')
