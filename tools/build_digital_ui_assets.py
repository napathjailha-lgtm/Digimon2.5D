"""สร้าง PNG พิกเซลที่กำหนดตำแหน่งแน่นอนสำหรับ Nine Patch โดยไม่ยืม UI จากเกมอื่น"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'assets/ui/digital'
OUT.mkdir(parents=True, exist_ok=True)
W, H = 64, 24

def stepped(x0, y0, x1, y1, cut=3):
    return [(x0+cut,y0),(x1-cut,y0),(x1-cut,y0+1),(x1-1,y0+1),
            (x1-1,y0+cut),(x1,y0+cut),(x1,y1-cut),(x1-1,y1-cut),
            (x1-1,y1-1),(x1-cut,y1-1),(x1-cut,y1),(x0+cut,y1),
            (x0+cut,y1-1),(x0+1,y1-1),(x0+1,y1-cut),(x0,y1-cut),
            (x0,y0+cut),(x0+1,y0+cut),(x0+1,y0+1),(x0+cut,y0+1)]

# ฐานมืดช่วยให้หลอดสว่างอ่านได้แม้ยืนบนพื้นหญ้าสีสด
under = Image.new('RGBA', (W,H))
d = ImageDraw.Draw(under)
d.polygon(stepped(0,0,63,23), fill='#050c18')
d.polygon(stepped(3,3,60,20,2), fill='#101c2d')
d.line((7,5,56,5),fill='#1c3048')
under.save(OUT/'bar_under.png')

# Fill สีขาวมีแถบเงาสามระดับ; tint_progress เป็นคนเลือกสี HP/MP/DS
fill = Image.new('RGBA',(W,H))
d = ImageDraw.Draw(fill)
d.rectangle((6,5,57,18),fill='#b9bacb')
d.rectangle((6,5,57,7),fill='#f5fcff')
d.rectangle((6,8,57,13),fill='#dce8f4')
d.line((6,17,57,17),fill='#8d9daf')
fill.save(OUT/'bar_fill.png')

# กรอบกลางโปร่งใส: โลหะเงินบน/ล่าง, จุด cyan และสกรูเล็กอยู่ในส่วนที่ไม่ยืด
frame = Image.new('RGBA',(W,H))
d = ImageDraw.Draw(frame)
d.polygon(stepped(0,0,63,23),fill='#37526a')
d.polygon(stepped(2,2,61,21,2),fill='#111d30')
d.rectangle((5,4,58,19),fill=(0,0,0,0))
d.line((8,1,55,1),fill='#90abc0')
d.line((8,3,55,3),fill='#44cddc')
d.line((8,22,55,22),fill='#0b1726')
for x in [2,60]:
    d.rectangle((x,9,x+1,14),fill='#50e4ef')
for x in [4,59]:
    d.point((x,3),fill='#ccedff')
    d.point((x,20),fill='#738aa6')
frame.save(OUT/'bar_frame.png')

# แสงพิกเซลใช้ขนาด 4px เพื่อยังเห็นเป็นสี่เหลี่ยมตอนขยาย
particle=Image.new('RGBA',(4,4),(255,255,255,255))
ImageDraw.Draw(particle).rectangle((1,1,2,2),fill='#c9f7ff')
particle.save(OUT/'pixel_dust.png')

# ปุ่มวงแปดเหลี่ยม สองกรอบรองรับทั้งปุ่มสกิลและช่อง item
for name,round_shape in [('command_frame',True),('slot_frame',False)]:
    im=Image.new('RGBA',(80,80))
    d=ImageDraw.Draw(im)
    points=[(22,2),(57,2),(77,22),(77,57),(57,77),(22,77),(2,57),(2,22)] if round_shape else stepped(1,1,78,78,7)
    d.polygon(points,fill='#071527',outline='#2d6a84',width=2)
    if round_shape:
        d.line([(24,6),(55,6),(73,24)],fill='#86e1f4',width=2)
        d.line([(6,56),(24,73),(55,73)],fill='#102e48',width=3)
        d.rectangle((34,3,45,4),fill='#cde8bd')
    else:
        d.line((12,4,67,4),fill='#5ccbdd',width=2)
        d.line((12,75,67,75),fill='#17314b',width=2)
        for x,y in [(6,6),(72,6),(6,72),(72,72)]:
            d.rectangle((x,y,x+1,y+1),fill='#a5c8d7')
    im.save(OUT/(name+'.png'))

print('Created 6 pixel textures:', OUT)
