"""อ่าน alpha ของภาพจริงและสร้าง AtlasTexture/SpriteFrames โดยไม่แก้พิกเซล PNG.
รันจากโฟลเดอร์โปรเจกต์: python tools/build_action_resources.py
Pillow/numpy/scipy ใช้เฉพาะตอนเตรียม Resource ไม่ใช่ dependency ของเกม.
"""
from pathlib import Path
import json,re
import numpy as np
from scipy import ndimage
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DIRECTIONS=['down','right','up','left']
HEIGHTS={'rookie':52.,'champion':112.,'ultimate':144.,'mega':160.}
metadata={}
for actor,world_height in HEIGHTS.items():
    scales={}
    new_resources=[]
    animations=[]
    for action in ['attack','cast']:
        sheet=ROOT/'assets/actions'/f'{actor}_{action}_v13.png'
        alpha=np.asarray(Image.open(sheet).getchannel('A'))
        assert alpha.min()==0 and alpha.max()>240, sheet
        labels,_=ndimage.label(alpha>24)
        slices=ndimage.find_objects(labels)
        counts=np.bincount(labels.ravel())
        main_ids=sorted(range(1,len(counts)),key=lambda i:counts[i],reverse=True)[:16]
        assert len(main_ids)==16 and min(counts[i] for i in main_ids)>2000,(sheet,'ต้องมีตัวหลัก 16 ตัว')
        main=[]
        for i in main_ids:
            region=slices[i-1]
            ys,xs=np.where(labels[region]==i)
            main.append((xs.mean()+region[1].start,ys.mean()+region[0].start,i))
        main.sort(key=lambda x:x[1])
        ordered=[]
        for row in range(4): ordered+=sorted(main[row*4:row*4+4],key=lambda x:x[0])
        centers=np.array([(x,y) for x,y,_ in ordered])
        grouped=[[] for _ in ordered]
        for i,region in enumerate(slices,1):
            if counts[i]<4: continue
            center=np.array([(region[1].start+region[1].stop)/2,(region[0].start+region[0].stop)/2])
            slot=int(np.argmin(((centers-center)**2).sum(axis=1)))
            grouped[slot].append(region)
        rectangles=[]
        feet=[]
        for slot,regions in enumerate(grouped):
            x=min(s[1].start for s in regions); y=min(s[0].start for s in regions)
            right=max(s[1].stop for s in regions); bottom=max(s[0].stop for s in regions)
            w,h=right-x,bottom-y
            rectangles.append((x,y,w,h))
            # ยึดศูนย์กลางเท้า ไม่ยึดหัว เพราะหัวต้องเอียง/พุ่งตามการโจมตี
            _,xs=np.where(labels[bottom-max(4,int(h*.12)):bottom]==ordered[slot][2])
            feet.append(float(np.median(xs)))
        scales[action]=world_height/max(r[3] for r in rectangles)
        folder=ROOT/'assets/actions'/actor/action
        folder.mkdir(parents=True,exist_ok=True)
        for slot,(x,y,w,h) in enumerate(rectangles):
            assert w<512 and h<512,(actor,action,slot,w,h)
            row,col=divmod(slot,4); key=f'{action}_{DIRECTIONS[row]}_{col}'
            resource=f'assets/actions/{actor}/{action}/{DIRECTIONS[row]}_{col}.tres'
            (ROOT/resource).write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n'
                f'[ext_resource type="Texture2D" path="res://assets/actions/{actor}_{action}_v13.png" id="1"]\n'
                '[resource]\natlas = ExtResource("1")\n'
                f'region = Rect2({x}, {y}, {w}, {h})\n'
                f'margin = Rect2({256-(feet[slot]-x)}, {512-h}, {512-w}, {512-h})\nfilter_clip = true\n')
            new_resources.append(f'[ext_resource type="Texture2D" path="res://{resource}" id="{key}"]')
        for direction in DIRECTIONS:
            frames=', '.join('{"duration": 1.0, "texture": ExtResource("%s_%s_%d")}'%(action,direction,i) for i in range(4))
            animations.append('{"frames": [%s], "loop": false, "name": &"%s_%s", "speed": %s}'%(frames,action,direction,'10.0' if action=='attack' else '8.0'))
        metadata[actor+'_'+action]={'sheet':str(sheet.relative_to(ROOT)),'regions':rectangles,'scale':scales[action],'frames':16}
    p=ROOT/'data'/f'{actor}_frames.tres'; s=p.read_text()
    # ลบเฉพาะท่า action เก่า/รอบก่อน เพื่อให้ builder รันซ้ำได้
    lines=[line for line in s.splitlines() if not ('"name": &"attack' in line or '"name": &"cast' in line)
           and not (line.startswith('[ext_resource') and 'res://assets/actions/' in line)]
    s='\n'.join(lines)
    s=re.sub(r'load_steps=\d+','load_steps=49',s,count=1)
    s=s.replace('[resource]','\n'.join(new_resources)+'\n[resource]',1)
    s=s.rstrip().removesuffix(']').rstrip().rstrip(',')+',\n'+',\n'.join(animations)+'\n]\n'
    p.write_text(s)
    p=ROOT/'data'/f'{actor}.tres'; s=p.read_text()
    for key,value in {'attack_sprite_scale':f'Vector2({scales["attack"]}, {scales["attack"]})',
                      'cast_sprite_scale':f'Vector2({scales["cast"]}, {scales["cast"]})',
                      'require_action_animations':'true','cast_animation':'&"cast_down"','attack_hit_frame':'2'}.items():
        s=re.sub(r'^'+key+r' = .*\n','',s,flags=re.M)
        s+=f'{key} = {value}\n'
    p.write_text(s)
    print(actor,'32 real action frames generated')
(ROOT/'ACTION_ATLAS_METADATA.json').write_text(json.dumps(metadata,indent=2)+'\n')
