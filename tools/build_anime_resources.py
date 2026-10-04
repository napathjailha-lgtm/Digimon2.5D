"""ตัดขอบเขตจาก alpha เพื่อสร้าง AtlasTexture โดยไม่แก้พิกเซลของภาพที่สร้าง

ใช้ภาพต้นฉบับร่วมกันต่อสาย ลดจำนวน texture; margin ปักเท้าทุกเฟรมที่ origin
รันจาก root ของโปรเจกต์: python3 tools/build_anime_resources.py
ต้องติดตั้ง pillow และ numpy เฉพาะตอนเตรียม assets ไม่ใช่ตอนเล่นเกม
"""
from pathlib import Path
import json
import re

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/anime_v22"
DIRECTIONS = {"down": 0, "right": 1, "up": 2, "left": 1}
TAMERS = ["taichi", "yamato", "sora", "koushiro", "mimi"]
FAMILIES = ["agumon", "gabumon", "piyomon", "tentomon", "palmon"]
REPORT = {}


def row_cuts(alpha: np.ndarray, count: int) -> list[int]:
    # Image generation วางแถวไม่ตรงพิกเซลเสมอ จึงหาช่องว่างใกล้เส้นแบ่งจริง
    height = alpha.shape[0]
    mass = (alpha > 40).sum(axis=1).astype(float)
    score = np.convolve(mass, np.ones(5) / 5, mode="same")
    result = [0]
    for index in range(1, count):
        wanted = height * index / count
        radius = height / count * 0.32
        start, end = int(wanted - radius), int(wanted + radius)
        result.append(start + int(np.argmin(score[start:end])))
    return result + [height]


def regions_for(key: str, rows: int):
    source = ART / f"{key}_atlas.png"
    image = Image.open(source)
    assert image.mode == "RGBA", f"{key}: ต้องมี alpha"
    alpha = np.array(image.getchannel("A"))
    assert (alpha == 0).mean() > 0.20, f"{key}: background ไม่โปร่งใส"
    cuts = row_cuts(alpha, rows)
    regions = []
    for row in range(rows):
        cells = []
        for column in range(6):
            x0, x1 = round(column * image.width / 6), round((column + 1) * image.width / 6)
            # ปรับรอยตัดตามแต่ละคอลัมน์ เพื่อไม่ตัดยอดหมวก/เขาที่สูงต่างกัน
            local_cuts = [0]
            local_mass = (alpha[:, x0:x1] > 40).sum(axis=1).astype(float)
            scores = np.convolve(local_mass, np.ones(3) / 3, mode="same")
            for boundary in cuts[1:-1]:
                start, end = max(1, boundary - 18), min(image.height - 1, boundary + 19)
                local_cuts.append(start + int(np.argmin(scores[start:end])))
            local_cuts.append(image.height)
            y0, y1 = local_cuts[row], local_cuts[row + 1]
            ys, xs = np.where(alpha[y0:y1, x0:x1] > 40)
            assert len(xs) > 80, f"{key}: cell ว่าง {row}/{column}"
            # เผื่อขอบ anti-alias 1px โดยไม่รวมภาพของเซลล์ข้างเคียง
            left, top = max(x0, x0 + int(xs.min()) - 1), max(y0, y0 + int(ys.min()) - 1)
            right = min(x1, x0 + int(xs.max()) + 2)
            bottom = min(y1, y0 + int(ys.max()) + 2)
            cells.append([left, top, right - left, bottom - top])
        regions.append(cells)
    REPORT[key] = {"source": str(source.relative_to(ROOT)), "image_size": list(image.size),
                   "rows": rows, "columns": 6, "row_cuts": cuts, "regions": regions,
                   "transparent_fraction": float((alpha == 0).mean())}
    return regions


def write_frames(key: str, regions: list, frame_path: Path, actor_type: str, target_height: float):
    # ความสูง idle เป็นหลัก; ท่าเหวี่ยงแขน/ยกมือมีพื้นที่ใหญ่ขึ้นตามรูปจริง
    idle_height = float(np.median([row[0][3] for row in regions]))
    scale = round(target_height / max(idle_height, 1), 6)
    width = max(rect[2] for row in regions for rect in row)
    height = max(rect[3] for row in regions for rect in row)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={2 + len(regions) * 6} format=3]',
             f'[ext_resource type="Texture2D" path="res://assets/anime_v22/{key.split(":")[0]}_atlas.png" id="atlas"]']
    for row_index, row in enumerate(regions):
        for column, (x, y, w, h) in enumerate(row):
            lines.extend([f'[sub_resource type="AtlasTexture" id="r{row_index}c{column}"]',
                          'atlas = ExtResource("atlas")', f'region = Rect2({x}, {y}, {w}, {h})',
                          f'margin = Rect2({(width - w) / 2:g}, {height - h}, {width - w}, {height - h})',
                          'filter_clip = true'])
    animations = []
    for direction, row in DIRECTIONS.items():
        sequences = {"idle": [0], "walk": [0, 1, 3, 5] if actor_type == "tamer" else [0, 1, 0, 2]}
        if actor_type == "partner":
            # จังหวะกระทบ/ปล่อยพลังยังอยู่เฟรม 2 เหมือนระบบต่อสู้เดิม
            sequences.update({"attack": [0, 3, 4, 0], "cast": [0, 3, 5, 0]})
        for action, columns in sequences.items():
            frames = ', '.join('{"duration":1.0,"texture":SubResource("r%dc%d")}' % (row, c) for c in columns)
            loop = "true" if action in ["idle", "walk"] else "false"
            fps = 1.0 if action == "idle" else 8.0 if action == "walk" else 10.0
            animations.append('{"frames":[%s],"loop":%s,"name":&"%s_%s","speed":%.1f}' % (frames, loop, action, direction, fps))
    lines.extend(['[resource]', 'metadata/mirror_left = true', 'animations = [' + ',\n'.join(animations) + ']'])
    frame_path.write_text('\n'.join(lines) + '\n', encoding="utf-8")
    return scale


def write_portrait(key: str, region: list[int], name: str):
    # Portrait ตัดจากภาพเดียวกับ idle จริง เพื่อไม่ให้หน้าเลือกคนละดีไซน์กับในสนาม
    x, y, w, h = region
    path = ART / f"{name}_portrait.tres"
    path.write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n'
                    f'[ext_resource type="Texture2D" path="res://assets/anime_v22/{key}_atlas.png" id="1"]\n'
                    '[resource]\natlas = ExtResource("1")\n'
                    f'region = Rect2({x}, {y}, {w}, {h})\nfilter_clip = true\n', encoding="utf-8")
    return 'res://' + str(path.relative_to(ROOT))


def replace_scale(path: Path, scale: float, actions: bool = False):
    text = path.read_text(encoding="utf-8")
    names = ["sprite_scale", "attack_sprite_scale", "cast_sprite_scale"] if actions else ["sprite_scale"]
    for name in names:
        text = re.sub(rf'^{name} = Vector2\([^\n]+\)', f'{name} = Vector2({scale}, {scale})', text, flags=re.M)
    path.write_text(text, encoding="utf-8")


def main():
    for name in TAMERS:
        regions = regions_for(name, 3)
        scale = write_frames(name, regions, ROOT / f"data/pregame/{name}_frames.tres", "tamer", 78)
        portrait = write_portrait(name, regions[0][0], name)
        data = ROOT / f"data/pregame/{name}.tres"
        text = data.read_text(encoding="utf-8").replace(f'res://assets/pregame/{name}.svg', portrait)
        data.write_text(text, encoding="utf-8")
        replace_scale(data, scale)
        REPORT[name]["sprite_scale"] = scale
    for family in FAMILIES:
        regions = regions_for(family, 9)
        for form in range(3):
            group = regions[form * 3:(form + 1) * 3]
            scale = write_frames(f"{family}:{form}", group, ROOT / f"data/pregame/{family}_{form}_frames.tres", "partner", [56, 90, 106][form])
            replace_scale(ROOT / f"data/pregame/{family}_{form}.tres", scale, True)
            REPORT[family].setdefault("form_scales", []).append(scale)
        portrait = write_portrait(family, regions[0][0], family)
        path = ROOT / f"data/pregame/{family}.tres"
        path.write_text(path.read_text(encoding="utf-8").replace(f'res://assets/pregame/{family}_0.svg', portrait), encoding="utf-8")
    # ฉาก World ที่เปิดตรง/F6 ใช้สายสำรอง 4 ร่าง จึงเปลี่ยนภาพให้ด้วย
    for index, legacy in enumerate(["rookie", "champion", "ultimate"]):
        source = ROOT / f"data/pregame/agumon_{index}_frames.tres"
        (ROOT / f"data/{legacy}_frames.tres").write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
        replace_scale(ROOT / f"data/{legacy}.tres", REPORT["agumon"]["form_scales"][index], True)
    regions = regions_for("wargreymon", 3)
    scale = write_frames("wargreymon", regions, ROOT / "data/mega_frames.tres", "partner", 116)
    replace_scale(ROOT / "data/mega.tres", scale, True)
    (ROOT / "data/tamer_frames.tres").write_text((ROOT / "data/pregame/taichi_frames.tres").read_text(encoding="utf-8"), encoding="utf-8")
    REPORT["wargreymon"]["sprite_scale"] = scale
    (ROOT / "ANIME_ATLAS_METADATA_V22.json").write_text(json.dumps(REPORT, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Built 5 tamers, 15 starter forms, legacy Mega and portraits from 11 unchanged PNG atlases")


if __name__ == "__main__":
    main()
