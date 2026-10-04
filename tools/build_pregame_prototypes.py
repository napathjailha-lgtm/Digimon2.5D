"""สร้าง SVG ต้นแบบ + Resources: แทนที่ไฟล์ภาพด้วยงานจริงได้ภายหลัง ไม่แก้ v15 assets"""
from pathlib import Path
import math,json
R=Path(__file__).resolve().parents[1];A=R/'assets/pregame';D=R/'data/pregame'
A.mkdir(exist_ok=True,parents=True);D.mkdir(exist_ok=True,parents=True)
tamers=[('taichi','ไทจิ','ชาย','สายลุย','#714133','#3584c7',230,90,190),('yamato','ยามาโตะ','ชาย','สายบาลานซ์','#f5cf6e','#529379',200,100,195),('sora','โซระ','หญิง','สายซัพพอร์ต','#d8804c','#dd7b98',180,130,200),('koushiro','โคจิโร่','ชาย','สายเทคนิค','#8d343d','#855ca8',160,150,185),('mimi','มีมี่','หญิง','ป้องกัน / ฟื้นฟู','#9a583d','#da849f',250,110,180)]
def svg(body,w=256,h=320):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 256 320"><g stroke="#172d48" stroke-width="4" stroke-linejoin="round">{body}</g></svg>'
for id,name,gender,role,hair,shirt,hp,ds,speed in tamers:
 long=gender=='หญิง'
 back=f'<path d="M55 105Q37 235 74 242L91 132h72l16 110q39-18 22-136Z" fill="{hair}"/>' if long else ''
 head=f'<path d="M60 116l-8-37 31 1 6-29 24 16 19-31 18 34 38-19-3 39 20 17-13 28z" fill="{hair}"/>'
 if id=='yamato':head=f'<path d="M53 115q-7-84 81-78 81 3 68 77l-20-28-21 21-26-35-35 26-30-8z" fill="{hair}"/>'
 if id=='mimi':head+='<path d="M64 70q-2-46 63-46 62 0 64 46l19 12H45z" fill="#f4acbd"/><path d="M80 54h94v12H80z" fill="#e67ba7"/>'
 if id=='sora':head+='<path d="M57 72Q63 28 130 32q70 0 70 46l-41-15-78 12z" fill="#72a8d6"/>'
 goggles='<path d="M80 70h38v22H80zM138 70h38v22h-38z" fill="#ccefff"/><path d="M118 80h20"/>' if id=='taichi' else ''
 eye='<ellipse cx="97" cy="120" rx="9" ry="13" fill="#eaf8ff"/><ellipse cx="158" cy="120" rx="9" ry="13" fill="#eaf8ff"/><ellipse cx="99" cy="123" rx="4" ry="7" fill="#315579"/><ellipse cx="157" cy="123" rx="4" ry="7" fill="#315579"/>'
 if id=='koushiro':eye+='<path d="M81 109h32v27H81zM141 109h32v27h-32zM113 119h28" fill="none" stroke="#5c9fbf"/>'
 body=f'{back}<path d="M86 176L66 218l16 18 17-26h58l18 26 16-18-19-42z" fill="{shirt}"/><path d="M99 224l-4 60h25l10-38 8 38h25l-6-60z" fill="'+('#ead2a0' if long else '#42556b')+'"/><path d="M95 279h27l3 26H84zM137 279h28l13 26h-42z" fill="'+shirt+'"/><ellipse cx="126" cy="121" rx="68" ry="65" fill="#ffd5b3"/>'+head+eye+'<path d="M117 147q11 8 23 0" fill="none" stroke-width="3"/>'+goggles
 if long:body+=f'<path d="M92 208h69l15 44H80z" fill="{shirt}"/>'
 (A/(id+'.svg')).write_text(svg(body))
 # ภาพเดินต้นแบบของ Tamer แต่ละโมเดล: idle/walk 4 ทิศ ปรับ frame ใน Inspector ได้
 folder=A/'sprites'/id;folder.mkdir(parents=True,exist_ok=True);frame_names=[];animations=[]
 for action in ['idle','walk']:
  for direction in ['down','right','up','left']:
   entries=[]
   for frame in range(4):
    lift=[0,5,0,-5][frame] if action=='walk' else 0
    content=body.replace('<path d="M95 279h27l3 26H84zM137 279h28l13 26h-42z"', '<path transform="translate(0,'+str(lift)+')" d="M95 279h27l3 26H84zM137 279h28l13 26h-42z"')
    if direction=='up':content=content.replace(eye,'').replace('<path d="M117 147q11 8 23 0" fill="none" stroke-width="3"/>','')
    if direction=='left':content='<g transform="translate(256,0) scale(-1,1)">'+content+'</g>'
    if direction=='right':content='<g transform="translate(10,0) scale(0.94,1)">'+content+'</g>'
    content='<g transform="translate(0,'+str(-abs(lift)*0.4)+')">'+content+'</g>'
    key=action+'_'+direction+'_'+str(frame);index=len(frame_names);frame_names.append(key)
    (folder/(key+'.svg')).write_text(svg(content,128,154).replace('0 0 256 320','0 0 256 308'))
    entries.append('{"duration":1.0,"texture":ExtResource("f'+str(index)+'")}')
   animations.append('{"frames":['+', '.join(entries)+'],"loop":true,"name":&"'+action+'_'+direction+'","speed":'+('3.0' if action=='idle' else '10.0')+'}')
 frames_text='[gd_resource type="SpriteFrames" load_steps='+str(len(frame_names)+1)+' format=3]\n'
 for i,key in enumerate(frame_names):frames_text+='[ext_resource type="Texture2D" path="res://assets/pregame/sprites/'+id+'/'+key+'.svg" id="f'+str(i)+'"]\n'
 frames_text+='[resource]\nanimations = ['+',\n'.join(animations)+']\n';(D/(id+'_frames.tres')).write_text(frames_text)
 text='[gd_resource type="Resource" script_class="TamerModelData" load_steps=4 format=3]\n[ext_resource type="Script" path="res://scripts/pregame/tamer_model_data.gd" id="s"]\n[ext_resource type="Texture2D" path="res://assets/pregame/'+id+'.svg" id="p"]\n[ext_resource type="SpriteFrames" path="res://data/pregame/'+id+'_frames.tres" id="f"]\n[resource]\nscript = ExtResource("s")\n'
 text+=f'id = &"{id}"\ndisplay_name = "{name}"\ngender = "{gender}"\nplay_style = "{role}"\ndescription = "เด็กผู้ถูกเลือก • {role} เป็นค่าพื้นฐานเริ่มต้น ปรับแต่งอุปกรณ์และสกิลต่อได้"\nportrait = ExtResource("p")\nsprite_frames = ExtResource("f")\nbase_hp = {hp}\nbase_ds = {float(ds)}\nmove_speed = {float(speed)}\n'
 text=text.replace('base_hp = ', 'sprite_scale = Vector2(0.64, 0.64)\nbase_hp = ', 1)
 (D/(id+'.tres')).write_text(text)
starters=[('agumon','Agumon','วัคซีน','ไฟ',['Agumon','Greymon','MetalGreymon'],['dino','horn_dino','cyber_dino'],'#e9a451',120,18,240,'Baby Flame','Mega Flame','Giga Destroyer','#ff9945'),('gabumon','Gabumon','ข้อมูล','น้ำแข็ง',['Gabumon','Garurumon','WereGarurumon'],['horn_fur','wolf','werewolf'],'#81c7e8',145,16,250,'Blue Blaster','Howling Blaster','Wolf Claw','#87e5ff'),('piyomon','Piyomon','วัคซีน','ลม',['Piyomon','Birdramon','Garudamon'],['bird','firebird','warbird'],'#e39abd',105,20,265,'Spiral Twister','Meteor Wing','Shadow Wing','#a4e9bf'),('tentomon','Tentomon','วัคซีน','สายฟ้า',['Tentomon','Kabuterimon','MegaKabuterimon'],['beetle','bluebeetle','redbeetle'],'#e5686d',160,17,220,'Super Shocker','Electro Shocker','Horn Buster','#ffe86e'),('palmon','Palmon','ข้อมูล','พืช',['Palmon','Togemon','Lillymon'],['plant','cactus','fairy'],'#8cc57c',150,16,230,'Poison Ivy','Needle Spray','Flower Cannon','#e9aaff')]
def monster_body(kind,col,frame=0,action='idle',direction='down'):
 bob=[0,-2,0,2][frame];step=[0,6,0,-6][frame] if action=='walk' else 0
 arms= [0,-12,17,4][frame] if action=='attack' else [0,-14,-25,0][frame] if action=='cast' else step*.5
 outline=f'<path d="M89 {253-step}L70 294h47l10-28 15 28h48l-17-{41-step}z" fill="{col}"/>'
 # ขาแยกยกทีละข้าง ไม่ใช้ path ที่มี operand ลบกำกวม
 outline=f'<ellipse cx="94" cy="280" rx="27" ry="{15+step*.2}" fill="{col}"/><ellipse cx="161" cy="{280-step}" rx="27" ry="15" fill="{col}"/><ellipse cx="128" cy="208" rx="61" ry="73" fill="{col}"/>'
 outline+=f'<ellipse cx="67" cy="{197+arms}" rx="25" ry="20" fill="{col}"/><ellipse cx="188" cy="{193-arms}" rx="25" ry="20" fill="{col}"/>'
 if 'bird' in kind:outline+=f'<path d="M83 163L14 {205+arms}l54-9-13 24 40-27M173 162l66 {44-arms}-54-9 13 24-40-27z" fill="{col}"/>'
 if kind in ['horn_fur','wolf','werewolf']:outline+='<path d="M72 90L55 41l51 24M150 63l52-27-18 59z" fill="#d6f0f7"/><path d="M84 173l43 34 48-34-13 62-33-18-30 17z" fill="#edf3d6"/>'
 if kind in ['horn_dino','cyber_dino']:outline+='<path d="M64 82l-15-33 42 15 39-34 40 34 40-15-18 42z" fill="#8d6850"/>'
 if kind=='cyber_dino':outline+='<path d="M39 190l-27-91 68 58M189 154l55-55-19 93" fill="#997cb3"/><path d="M152 183h49v71h-49z" fill="#bad2d8"/><circle cx="174" cy="209" r="16" fill="#4b7991"/>'
 if kind in ['firebird','warbird']:outline+='<path d="M44 211L12 121l48 44-14-62 53 62M190 163l47-60-14 62 20-15-23 65" fill="#ecad50"/>'
 if 'beetle' in kind:outline+='<ellipse cx="128" cy="190" rx="62" ry="58" fill="#912f48"/><path d="M128 137v105M107 87l16-52 16 52" fill="none" stroke="#4b5e79" stroke-width="13"/>'
 if kind=='cactus':outline+='<path d="M86 226l-37-31v-60h30v36l26 13M163 220l45-34v-57h-29v42l-32 18" fill="#669c66"/><path d="M69 241l-13 7M171 237l14 5M97 165l-9-8M159 167l10-10" fill="none" stroke="#fce79e"/>'
 if kind=='fairy':outline+='<path d="M99 158l-64-32 12 66 48-15M158 155l61-30-6 64-50-12" fill="#c3edf0"/><path d="M92 231l36-37 38 39-36 39z" fill="#da76a6"/>'
 outline+=f'<ellipse cx="128" cy="105" rx="{65 if kind not in ["beetle","bluebeetle","redbeetle"] else 52}" ry="57" fill="{col}"/>'
 if kind=='horn_fur':outline+='<path d="M105 62l21-48 19 48" fill="#f0d587"/><path d="M78 117l22 12M170 116l-19 12M92 153l22-14M158 153l-19-14" stroke="#437ca1"/>'
 if kind in ['plant','fairy']:outline+='<path d="M95 63l-24-37 46 14 14-29 23 27 32-14-23 39z" fill="#e991bf"/><circle cx="132" cy="44" r="15" fill="#f8da76"/>'
 if direction!='up':
  sx=8 if direction=='right' else -8 if direction=='left' else 0
  outline+=f'<ellipse cx="{102+sx}" cy="103" rx="9" ry="15" fill="#f4fcff"/><ellipse cx="{155+sx}" cy="103" rx="9" ry="15" fill="#f4fcff"/><ellipse cx="{104+sx}" cy="105" rx="5" ry="9" fill="#29475f"/><ellipse cx="{157+sx}" cy="105" rx="5" ry="9" fill="#29475f"/><path d="M108 132q19 14 40 0" fill="none" stroke-width="3"/>'
  if 'bird' in kind:outline+='<path d="M116 122l14-13 17 13-17 21z" fill="#edc966"/>'
 if action=='cast' and frame==2:outline+='<circle cx="203" cy="137" r="24" fill="#d7f8ff" stroke="#75d9f4"/>'
 return f'<g transform="translate(0,{bob})">{outline}</g>'
allids=[]
for sid,name,attribute,element,names,kinds,col,hp,atk,speed,s0,s1,s2,effect in starters:
 for stage,(fname,kind,sname) in enumerate(zip(names,kinds,[s0,s1,s2])):
  fid=sid+'_'+str(stage);allids.append(fid);folder=A/'sprites'/fid;folder.mkdir(parents=True,exist_ok=True)
  stagecol=col if stage==0 else '#d99043' if kind=='horn_dino' else '#83abb7' if kind=='cyber_dino' else '#eb9952' if kind=='firebird' else '#d7986a' if kind=='warbird' else '#73a6d8' if kind=='bluebeetle' else '#d95864' if kind=='redbeetle' else '#75ad74' if kind=='cactus' else col
  (A/(fid+'.svg')).write_text(svg(monster_body(kind,stagecol)))
  frames=[];anim=[]
  for action in ['idle','walk','attack','cast']:
   for dr in ['down','right','up','left']:
    keys=[]
    for f in range(4):
     fn=f'{action}_{dr}_{f}';(folder/(fn+'.svg')).write_text(svg(monster_body(kind,stagecol,f,action,dr),128,150).replace("0 0 256 320", "0 0 256 300"));idx=len(frames);frames.append(fn);keys.append('{"duration": 1.0, "texture": ExtResource("f'+str(idx)+'")}')
    anim.append('{"frames": ['+', '.join(keys)+'], "loop": '+('true' if action in ['idle','walk'] else 'false')+', "name": &"'+action+'_'+dr+'", "speed": '+('3.0' if action=='idle' else '10.0')+'}')
  text=f'[gd_resource type="SpriteFrames" load_steps={len(frames)+1} format=3]\n'
  for i,fn in enumerate(frames):text+=f'[ext_resource type="Texture2D" path="res://assets/pregame/sprites/{fid}/{fn}.svg" id="f{i}"]\n'
  text+='[resource]\nanimations = ['+',\n'.join(anim)+']\n';(D/(fid+'_frames.tres')).write_text(text)
  # ลูกไฟสี/ชื่อแยกตาม starter ใช้ resolver/projectile/touch ของระบบเดิม
  mult=[1.2,2.5,3.2][stage];cd=[3.0,6.0,8.0][stage]
  skill='[gd_resource type="Resource" script_class="MonsterSkill" load_steps=3 format=3]\n[ext_resource type="Script" path="res://scripts/skill_data.gd" id="s"]\n[ext_resource type="Texture2D" path="res://assets/equipment/power_chip.svg" id="icon"]\n[resource]\nscript = ExtResource("s")\n'
  skill+=f'id = &"{fid}_skill"\ndisplay_name = "{sname}"\nicon = ExtResource("icon")\nmultiplier = {mult}\ncooldown = {cd}\ncast_range = 200.0\nds_cost = {float(5+stage*5)}\nimpact_radius = {float(stage*35)}\nprojectile_speed = 480.0\neffect_color = Color({int(effect[1:3],16)/255}, {int(effect[3:5],16)/255}, {int(effect[5:7],16)/255}, 1)\neffect_size = {float(12+stage*8)}\n';(D/(fid+'_skill.tres')).write_text(skill)
  scale=[0.64,0.76,0.84][stage]
  form='[gd_resource type="Resource" script_class="MonsterData" load_steps=5 format=3]\n[ext_resource type="Script" path="res://scripts/monster_data.gd" id="s"]\n[ext_resource type="SpriteFrames" path="res://data/pregame/'+fid+'_frames.tres" id="f"]\n[ext_resource type="Resource" path="res://data/pregame/'+fid+'_skill.tres" id="k"]\n[ext_resource type="Script" path="res://scripts/skill_data.gd" id="kt"]\n[resource]\nscript = ExtResource("s")\n'
  form+=f'id = &"{fid}"\nmonster_name = "{fname}"\nevolution_stage = {stage}\nmax_hp = {hp+stage*140}\nattack = {atk+stage*20}\nmove_speed = {float(speed+stage*10)}\nsprite_frames = ExtResource("f")\nsprite_scale = Vector2({scale}, {scale})\nattack_sprite_scale = Vector2({scale}, {scale})\ncast_sprite_scale = Vector2({scale}, {scale})\nanimation_reference_speed = {float(speed+stage*10)}\nidle_animation = &"idle_down"\nwalk_animation = &"walk_down"\nattack_animation = &"attack_down"\ncast_animation = &"cast_down"\nrequire_directional_animations = true\nrequire_action_animations = true\nattack_hit_frame = 2\nevolution_cost = {float(stage*25)}\nds_drain_per_second = {float(stage*5)}\nskills = Array[ExtResource("kt")]([ExtResource("k")])\n';(D/(fid+'.tres')).write_text(form)
 text='[gd_resource type="Resource" script_class="StarterPartnerData" load_steps=7 format=3]\n[ext_resource type="Script" path="res://scripts/pregame/starter_partner_data.gd" id="s"]\n[ext_resource type="Texture2D" path="res://assets/pregame/'+sid+'_0.svg" id="p"]\n[ext_resource type="Script" path="res://scripts/monster_data.gd" id="mt"]\n'
 for j in range(3):text+=f'[ext_resource type="Resource" path="res://data/pregame/{sid}_{j}.tres" id="f{j}"]\n'
 text+='[resource]\nscript = ExtResource("s")\n'+f'id = &"{sid}"\ndisplay_name = "{name}"\nattribute_name = "{attribute}"\nelement_name = "{element}"\ndescription = "คู่หูธาตุ{element} • ข้อมูลสเตตัสและชุดสกิลแยกตามแต่ละร่าง"\nportrait = ExtResource("p")\nforms = Array[ExtResource("mt")]([ExtResource("f0"), ExtResource("f1"), ExtResource("f2")])\n';(D/(sid+'.tres')).write_text(text)
cat='[gd_resource type="Resource" script_class="PregameCatalog" load_steps=14 format=3]\n[ext_resource type="Script" path="res://scripts/pregame/pregame_catalog.gd" id="s"]\n[ext_resource type="Script" path="res://scripts/pregame/tamer_model_data.gd" id="tt"]\n[ext_resource type="Script" path="res://scripts/pregame/starter_partner_data.gd" id="pt"]\n'
for i,item in enumerate(tamers):cat+=f'[ext_resource type="Resource" path="res://data/pregame/{item[0]}.tres" id="t{i}"]\n'
for i,item in enumerate(starters):cat+=f'[ext_resource type="Resource" path="res://data/pregame/{item[0]}.tres" id="p{i}"]\n'
cat+='[resource]\nscript = ExtResource("s")\ntamers = Array[ExtResource("tt")](['+', '.join(f'ExtResource("t{i}")' for i in range(5))+'])\nstarters = Array[ExtResource("pt")](['+', '.join(f'ExtResource("p{i}")' for i in range(5))+'])\n';(D/'catalog.tres').write_text(cat)
print('5 tamer portraits / 5 starter lines / 15 forms with directional SVG prototype animations')
