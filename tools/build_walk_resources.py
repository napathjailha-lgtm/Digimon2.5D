"""อ่าน alpha เพื่อสร้าง AtlasTexture/SpriteFrames โดยไม่แก้พิกเซล PNG.
รันจาก root โปรเจกต์: python tools/build_walk_resources.py
ต้องมี Pillow, numpy, scipy เฉพาะตอนเตรียม Resource ไม่ใช้บนมือถือ.
"""
from pathlib import Path
import json
import re
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ["down", "right", "up", "left"]
HEIGHTS = {"tamer": 76.0, "rookie": 52.0, "champion": 112.0,
           "ultimate": 144.0, "mega": 160.0}
CANVAS = 512
report = {}

for actor, world_height in HEIGHTS.items():
    image_path = ROOT / "assets" / "walk" / f"{actor}_walk_v12.png"
    alpha = np.array(Image.open(image_path).getchannel("A"))
    labels, _ = ndimage.label(alpha > 24)
    slices = ndimage.find_objects(labels)
    counts = np.bincount(labels.ravel())
    # sprite ที่ติดกันเป็นชิ้นหลัก 16 ตัว; ส่วนเล็กแยก เช่นปลายผ้าพันคอ
    # จะรวมกับตัวใกล้ที่สุดในขั้นถัดไป เพื่อไม่ตัดทิ้งรายละเอียด
    main = []
    for index, region in enumerate(slices, 1):
        if counts[index] > 5000:
            ys, xs = np.where(labels[region] == index)
            main.append((xs.mean() + region[1].start,
                         ys.mean() + region[0].start, index))
    assert len(main) == 16, (actor, "ต้องมี sprite แยกกันครบ16ตัว", len(main))
    main.sort(key=lambda item: item[1])
    ordered = []
    for row in range(4):
        ordered.extend(sorted(main[row * 4:row * 4 + 4], key=lambda item: item[0]))
    centers = np.array([(x, y) for x, y, _ in ordered])
    grouped = [[] for _ in ordered]
    for index, region in enumerate(slices, 1):
        if counts[index] < 4:
            continue
        center = np.array([(region[1].start + region[1].stop) / 2,
                           (region[0].start + region[0].stop) / 2])
        slot = int(np.argmin(((centers - center) ** 2).sum(axis=1)))
        grouped[slot].append(region)
    rectangles = []
    head_centers = []
    for slot, regions in enumerate(grouped):
        left = min(s[1].start for s in regions)
        right = max(s[1].stop for s in regions)
        top = min(s[0].start for s in regions)
        bottom = max(s[0].stop for s in regions)
        rectangles.append((left, top, right - left, bottom - top))
        main_id = ordered[slot][2]
        head_bottom = top + int((bottom - top) * 0.36)
        ys, xs = np.where(labels[top:head_bottom] == main_id)
        head_centers.append(float(np.median(xs)))
    scale = world_height / max(rect[3] for rect in rectangles)
    actor_dir = ROOT / "assets" / "walk" / actor
    actor_dir.mkdir(exist_ok=True)
    paths = []
    for slot, rect in enumerate(rectangles):
        row, column = divmod(slot, 4)
        left, top, width, height = rect
        # ปักเท้าที่ y=0 ของ Node; วางหัวให้อยู่แกนเดียวกันระหว่างเฟรม
        margin_x = CANVAS / 2 - (head_centers[slot] - left)
        margin_y = CANVAS - height
        path = f"assets/walk/{actor}/{DIRECTIONS[row]}_{column}.tres"
        paths.append(path)
        (ROOT / path).write_text(
            '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n'
            f'[ext_resource type="Texture2D" path="res://assets/walk/{actor}_walk_v12.png" id="1"]\n'
            '[resource]\natlas = ExtResource("1")\n'
            f'region = Rect2({left}, {top}, {width}, {height})\n'
            f'margin = Rect2({margin_x}, {margin_y}, {CANVAS-width}, {CANVAS-height})\n'
            'filter_clip = true\n')
    entries = []
    for row, direction in enumerate(DIRECTIONS):
        indices = [row * 4 + col for col in range(4)]
        for prefix in ["idle", "walk", "attack"]:
            selected = indices if prefix == "walk" else indices[:1]
            frames = ", ".join('{"duration": 1.0, "texture": ExtResource("f%d")}' % i for i in selected)
            entries.append('{"frames": [%s], "loop": %s, "name": &"%s_%s", "speed": %s}'
                           % (frames, "false" if prefix == "attack" else "true",
                              prefix, direction, "12.0" if prefix == "walk" else "6.0"))
    # alias ใช้กับโค้ดเก่า/คัตซีน ร่างใหม่ยังเลือกชื่อ4ทิศเป็นหลัก
    for prefix in ["idle", "walk", "attack"]:
        selected = range(4) if prefix == "walk" else [0]
        frames = ", ".join('{"duration": 1.0, "texture": ExtResource("f%d")}' % i for i in selected)
        entries.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'
                       % (frames, "false" if prefix == "attack" else "true", prefix,
                          "12.0" if prefix == "walk" else "6.0"))
    resource = '[gd_resource type="SpriteFrames" load_steps=17 format=3]\n'
    resource += "\n".join('[ext_resource type="Texture2D" path="res://%s" id="f%d"]' % (path, i)
                          for i, path in enumerate(paths))
    resource += '\n[resource]\nanimations = [\n' + ",\n".join(entries) + '\n]\n'
    (ROOT / "data" / f"{actor}_frames.tres").write_text(resource)
    if actor == "tamer":
        path = ROOT / "scenes" / "tamer.tscn"
        text = path.read_text()
        for old, direction in [("front", "down"), ("right", "right"), ("back", "up"), ("left", "left")]:
            text = text.replace(f"res://assets/art/tamer_{old}.tres", f"res://assets/walk/tamer/{direction}_0.tres")
        text = re.sub(r"scale = Vector2\([^\n]*\)", f"scale = Vector2({scale}, {scale})", text, count=1)
        text = re.sub(r"offset = Vector2\([^\n]*\)", "offset = Vector2(0, -256)", text, count=1)
        path.write_text(text)
    else:
        path = ROOT / "data" / f"{actor}.tres"
        text = re.sub(r"sprite_scale = Vector2\([^\n]*\)", f"sprite_scale = Vector2({scale}, {scale})", path.read_text())
        if "require_directional_animations = true" not in text:
            text += 'require_directional_animations = true\nidle_animation = &"idle_down"\nwalk_animation = &"walk_down"\nattack_animation = &"attack_down"\n'
        path.write_text(text)
    report[actor] = {"sheet": str(image_path.relative_to(ROOT)), "scale": scale,
                     "world_height": world_height, "regions": rectangles,
                     "directions": DIRECTIONS, "frames_per_direction": 4}
    print(actor, "4ทิศ x 4เฟรม", "world height", world_height, "scale", scale)
(ROOT / "WALK_ATLAS_METADATA.json").write_text(json.dumps(report, indent=2) + "\n")

# v13: รันต่อเพื่อรักษาท่าโจมตีเมื่อ rebuild ภาพเดิน
action_builder = ROOT / "tools" / "build_action_resources.py"
if action_builder.is_file():
    import runpy
    runpy.run_path(str(action_builder), run_name="__main__")
