"""Rebuild Adventure partner resources from the checked-in, unmodified imagegen atlases.

Pillow is used only to measure alpha bounds, never to edit the source images.
Godot AtlasTexture regions and margins keep each pose centered and feet aligned.
"""
from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/adventure_partners"
DATA = ROOT / "data/pregame"

LINES = {
    "tailmon": (["Tailmon", "Angewomon", "Holydramon"], [1, 2, 3],
                ["Cat Punch", "Holy Arrow", "Holy Flame", "Apocalypse"],
                [0, 342, 735, 1086], [138, 405, 640], [21, 59, 77], [252, 265, 280]),
    "patamon": (["Patamon", "Angemon", "HolyAngemon", "Seraphimon"], [0, 1, 2, 3],
                ["Air Shot", "Heaven's Knuckle", "Heaven's Gate", "Seven Heavens", "Testament"],
                [0, 314, 624, 930, 1254], [125, 260, 410, 650], [17, 39, 60, 78], [245, 250, 265, 275]),
    "gomamon": (["Gomamon", "Ikkakumon", "Zudomon", "Vikemon"], [0, 1, 2, 3],
                ["Marching Fishes", "Harpoon Torpedo", "Hammer Spark", "Arctic Blizzard", "Viking Axe"],
                [0, 280, 580, 897, 1254], [150, 290, 450, 720], [18, 38, 59, 76], [235, 235, 245, 250]),
}


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def poses(atlas, rows, row):
    im = Image.open(ART / atlas)
    alpha = im.getchannel("A").point(lambda a: 255 if a > 96 else 0)
    boxes = []
    for col in range(4):
        left, right = round(col * im.width / 4), round((col + 1) * im.width / 4)
        top, bottom = rows[row:row + 2]
        box = alpha.crop((left, top, right, bottom)).getbbox()
        assert box, (atlas, row, col)
        x, y, x2, y2 = box
        boxes.append((left + x, top + y, x2 - x, y2 - y))
    width = max(b[2] for b in boxes)
    height = max(b[3] for b in boxes)
    resources = []
    for n, (x, y, w, h) in enumerate(boxes):
        resources.append(f'''[sub_resource type="AtlasTexture" id="p{n}"]
atlas = ExtResource("tex")
region = Rect2({x}, {y}, {w}, {h})
margin = Rect2({(width-w)/2}, {height-h}, {width-w}, {height-h})
filter_clip = true
''')
    return "\n".join(resources), boxes[0], height


def make_frames(key, atlas, rows, row, tamer=False):
    resources, box, height = poses(atlas, rows, row)
    animations = []
    for direction in ["down", "right", "up", "left"]:
        mapping = {"idle": [0], "walk": [0, 1, 0, 1], "attack": [0, 2, 3, 0], "cast": [0, 2, 3, 0]}
        if tamer:
            mapping = {"idle": [3] if direction == "up" else [0], "walk": [3, 3] if direction == "up" else [0, 1, 0, 2]}
        for action, indexes in mapping.items():
            frames = ", ".join('{"duration":1.0,"texture":SubResource("p%d")}' % i for i in indexes)
            loop = str(action in ["idle", "walk"]).lower()
            speed = 1.0 if action == "idle" else 8.0 if action == "walk" else 10.0
            animations.append(f'{{"frames":[{frames}],"loop":{loop},"name":&"{action}_{direction}","speed":{speed}}}')
    write(DATA / f"{key}_frames.tres", f'''[gd_resource type="SpriteFrames" load_steps=6 format=3]
[ext_resource type="Texture2D" path="res://assets/adventure_partners/{atlas}" id="tex"]
{resources}
[resource]
animations = [{",\n".join(animations)}]
metadata/mirror_left = true
''')
    x, y, w, h = box
    portrait_path = f"res://assets/adventure_partners/{key}_portrait.tres"
    write(ROOT / portrait_path.removeprefix("res://"), f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://assets/adventure_partners/{atlas}" id="tex"]
[resource]
atlas = ExtResource("tex")
region = Rect2({x}, {y}, {w}, {h})
filter_clip = true
''')
    return portrait_path, height


def build():
    for family, (names, stages, skills, rows, hp, atk, speeds) in LINES.items():
        for i, name in enumerate(names):
            key = f"{family}_{i}"
            portrait, height = make_frames(key, f"{family}.png", rows, i)
            mega = stages[i] == 3
            skill_ids = [f"{key}_skill"] + ([f"{key}_skill_2"] if mega else [])
            for slot, skill_id in enumerate(skill_ids):
                skill_name = skills[i + slot]
                style = "ice" if family == "gomamon" else "astral"
                if family == "patamon" and i == 0: style = "wind"
                if family == "tailmon" and i == 0: style = "claw"
                melee = slot == 1 or (family == "tailmon" and i == 0)
                write(DATA / f"{skill_id}.tres", f'''[gd_resource type="Resource" script_class="MonsterSkill" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/skill_data.gd" id="s"]
[ext_resource type="Texture2D" path="{portrait}" id="icon"]
[resource]
script = ExtResource("s")
id = &"{skill_id}"
display_name = "{skill_name}"
icon = ExtResource("icon")
vfx_style = "{style}"
animation_prefix = &"{'attack' if melee else 'cast'}"
release_frame = 2
multiplier = {1.25 + stages[i]*0.2 + slot*0.3:.2f}
cast_range = {130.0 if melee else 290.0 + stages[i]*20}
cooldown = {3.2 + stages[i]*0.6 + slot*1.5:.1f}
mp_cost = {6.0 + stages[i]*3 + slot*4}
impact_radius = {90.0 + slot*35 if mega else 45.0 if i > 0 else 0.0}
projectile_speed = {0.0 if melee else 540.0}
effect_color = Color({'0.4, 0.8, 1.0' if family == 'gomamon' else '1.0, 0.85, 0.5'}, 1.0)
effect_size = {13.0 + stages[i]*4}
''')
            scale = ([105, 148, 175, 195][stages[i]] if i > 0 else 108) / height
            ext_skills = "\n".join(f'[ext_resource type="Resource" path="res://data/pregame/{s}.tres" id="k{n}"]' for n, s in enumerate(skill_ids))
            skill_refs = ", ".join(f'ExtResource("k{n}")' for n in range(len(skill_ids)))
            write(DATA / f"{key}.tres", f'''[gd_resource type="Resource" script_class="MonsterData" load_steps={6+len(skill_ids)-1} format=3]
[ext_resource type="Script" path="res://scripts/monster_data.gd" id="s"]
[ext_resource type="SpriteFrames" path="res://data/pregame/{key}_frames.tres" id="f"]
{ext_skills}
[ext_resource type="Script" path="res://scripts/skill_data.gd" id="kt"]
[ext_resource type="Texture2D" path="{portrait}" id="p"]
[resource]
script = ExtResource("s")
id = &"{key}"
monster_name = "{name}"
evolution_stage = {stages[i]}
max_hp = {hp[i]}
attack = {atk[i]}
move_speed = {speeds[i]}.0
attack_range = {62.0 + stages[i]*7}
attack_interval = 0.8
defense = {stages[i]*3 if family == 'gomamon' else 0}
portrait_texture = ExtResource("p")
sprite_frames = ExtResource("f")
sprite_scale = Vector2({scale:.6f}, {scale:.6f})
attack_sprite_scale = Vector2({scale:.6f}, {scale:.6f})
cast_sprite_scale = Vector2({scale:.6f}, {scale:.6f})
idle_animation = &"idle_down"
walk_animation = &"walk_down"
attack_animation = &"attack_down"
cast_animation = &"cast_down"
attack_hit_frame = 2
animation_reference_speed = {speeds[i]}.0
require_directional_animations = true
require_action_animations = true
evolution_cost = {0.0 if i == 0 else 25.0 if mega else stages[i]*25.0}
ds_drain_per_second = {0.0 if i == 0 else 6.0 if mega else stages[i]*5.0}
skills = Array[ExtResource("kt")]([{skill_refs}])
''')
        starter = DATA / f"{family}.tres"
        text = starter.read_text()
        text = re.sub(r'^\[ext_resource[^\n]+id="f[1-9]"\]\n', '', text, flags=re.MULTILINE)
        text = re.sub(r"load_steps=\d+", f"load_steps={4+len(names)}", text)
        text = text.replace(f'res://assets/pregame/{family}.svg', f'res://assets/adventure_partners/{family}_0_portrait.tres')
        extra = "\n".join(f'[ext_resource type="Resource" path="res://data/pregame/{family}_{i}.tres" id="f{i}"]' for i in range(1, len(names)))
        text = text.replace("[resource]", extra + "\n[resource]")
        text = re.sub(r'forms = .*', 'forms = Array[ExtResource("mt")]([' + ', '.join(f'ExtResource("f{i}")' for i in range(len(names))) + '])', text)
        text = re.sub(r'description = ".*"', f'description = "คู่หูของ{dict(tailmon="ฮิคาริ", patamon="ทาเครุ", gomamon="โจ")[family]} • พัฒนาได้จนถึง {names[-1]}"', text)
        write(starter, text)

    for row, tamer in enumerate(["hikari", "takeru", "joe"]):
        portrait, height = make_frames(tamer, "tamers.png", [0, 354, 714, 1086], row, True)
        path = DATA / f"{tamer}.tres"
        text = path.read_text().replace(f"res://assets/pregame/{tamer}.svg", portrait)
        scale = 115 / height
        text = re.sub(r'sprite_scale = Vector2\([^\n]+', f'sprite_scale = Vector2({scale:.6f}, {scale:.6f})', text)
        write(path, text)


if __name__ == "__main__":
    build()
