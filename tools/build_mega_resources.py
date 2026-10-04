"""อ่าน alpha แล้วสร้าง AtlasTexture; ไม่แก้พิกเซล PNG ต้นฉบับ"""
import json
import numpy as np
from PIL import Image
import build_anime_resources as atlas

atlas.ART = atlas.ROOT / "assets/anime_v26"
# ภาพแนวตั้ง 3 คอลัมน์ × 6 แถว ทำให้ท่าหมาป่าด้านข้างมีพื้นที่หาง/ปากครบ
source = atlas.ART / "metalgarurumon_atlas.png"
image = Image.open(source)
assert image.mode == "RGBA" and image.height > image.width, "ต้องใช้ภาพแนวตั้ง RGBA"
alpha = np.array(image.getchannel("A"))
assert (alpha == 0).mean() > .2, "พื้นหลังต้องโปร่งใส"
cuts = atlas.row_cuts(alpha, 6)
grid = []
for row in range(6):
    cells = []
    y0, y1 = cuts[row:row + 2]
    for col in range(3):
        x0, x1 = round(col * image.width / 3), round((col + 1) * image.width / 3)
        ys, xs = np.where(alpha[y0:y1, x0:x1] > 40)
        assert len(xs) > 80, f"ช่องภาพว่าง {row}/{col}"
        left, top = max(x0, x0 + int(xs.min()) - 1), max(y0, y0 + int(ys.min()) - 1)
        right, bottom = min(x1, x0 + int(xs.max()) + 2), min(y1, y0 + int(ys.max()) + 2)
        cells.append([left, top, right - left, bottom - top])
    grid.append(cells)
# รวมสองแถวของทิศเดียวกันเป็น idle/walk/walk/wind-up/strike/cast ให้ builder เดิม
regions = [grid[i] + grid[i + 1] for i in range(0, 6, 2)]
atlas.REPORT["metalgarurumon"] = {"source":str(source.relative_to(atlas.ROOT)),
    "image_size":list(image.size), "rows":6, "columns":3, "row_cuts":cuts,
    "regions":regions, "transparent_fraction":float((alpha == 0).mean())}
path = atlas.ROOT / "data/pregame/gabumon_3_frames.tres"
scale = atlas.write_frames("metalgarurumon", regions, path, "partner", 88)
# builder รุ่นเดิมใช้พาธ anime_v22; เปลี่ยนเฉพาะ reference ไปยังภาพใหม่
path.write_text(path.read_text().replace("assets/anime_v22/metalgarurumon", "assets/anime_v26/metalgarurumon"))
atlas.replace_scale(atlas.ROOT / "data/pregame/gabumon_3.tres", scale, True)
atlas.REPORT["metalgarurumon"]["sprite_scale"] = scale
(atlas.ROOT / "MEGA_ATLAS_METADATA_V26.json").write_text(json.dumps(atlas.REPORT,indent=2))
print("Created 16 directional animations from 18 poses; scale", scale)
