"""Compose the approved pot with all flower stages; sink plant roots three pixels."""
from pathlib import Path
import json
import re
import subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/Flowers/Unzoom30'
OUT = ROOT / 'output/clay_pot_unzoom_2026-10-27'
PLANT_Y = 3
POT_Y = 24

def save_frames(path, texture_name, strip=False):
    original = path.read_text()
    uid = re.search(r'^\[gd_resource[^\n]*uid="([^"]+)"', original)
    uid_attr = f' uid="{uid.group(1)}"' if uid else ''
    subs = ''
    if strip:
        for frame in range(6):
            subs += f'[sub_resource type="AtlasTexture" id="frame_{frame}"]\natlas = ExtResource("art")\nregion = Rect2({frame*32}, 0, 32, 48)\nfilter_clip = true\n\n'
        frames = ', '.join(f'{{"duration": 1.0, "texture": SubResource("frame_{frame}")}}' for frame in range(6))
    else:
        frames = ', '.join(['{"duration": 1.0, "texture": ExtResource("art")}'] * 6)
    path.write_text(f'[gd_resource type="SpriteFrames" format=3{uid_attr}]\n\n[ext_resource type="Texture2D" path="res://assets/Flowers/Unzoom30/{texture_name}" id="art"]\n\n{subs}[resource]\nanimations = [{{"frames": [{frames}], "loop": true, "name": &"grow", "speed": 8.0}}]\n')

def main():
    pot = Image.open(OUT / 'clay_pot_for_flowers_32x24.png').convert('RGBA')
    (DEST / 'clay_pot_32x24.png').write_bytes((OUT / 'clay_pot_for_flowers_32x24.png').read_bytes())
    entries = json.loads((ROOT / 'output/flowers_unzoom_2026-10-27/manifest.json').read_text())['items']
    for entry in entries:
        i = entry['index']
        flower = Image.open(DEST / entry['file']).convert('RGBA')
        composite = Image.new('RGBA', (32, 48))
        composite.alpha_composite(pot, (0, POT_Y))
        composite.alpha_composite(flower, (0, PLANT_Y))
        name = f'flower_{i:02}_potted.png'
        composite.save(DEST / name)
        for stage in (4, 5):
            save_frames(ROOT / f'flowers/frames/flower_{i:02}_stage_{stage}.tres', name)
    for i in range(1, 11):
        for stage in range(1, 4):
            path = ROOT / f'flowers/frames/flower_{i:02}_stage_{stage}.tres'
            # Original committed clips remain the source on repeat runs.
            text = subprocess.check_output(['git', 'show', f'HEAD:flowers/frames/flower_{i:02}_stage_{stage}.tres'], cwd=ROOT, text=True)
            source_path = re.search(r'path="res://([^\"]+\.png)"', text).group(1)
            source = Image.open(ROOT / source_path).convert('RGBA')
            rects = re.findall(r'region = Rect2\((\d+), (\d+), (\d+), (\d+)\)', text)
            strip = Image.new('RGBA', (192, 48))
            for frame, (x, y, w, h) in enumerate(rects):
                x, y = int(x), int(y)
                composite = Image.new('RGBA', (32, 48))
                composite.alpha_composite(pot, (0, POT_Y))
                # Crop off the old baked-in pot; root y=33 matches the lowered blooms.
                composite.alpha_composite(source.crop((x, y, x+16, y+11)), (8, 23))
                strip.alpha_composite(composite, (frame*32, 0))
            name = f'flower_{i:02}_stage_{stage}_potted.png'
            strip.save(DEST / name)
            save_frames(path, name, strip=True)
    preview = Image.new('RGB', (768, 352), '#283138')
    draw = ImageDraw.Draw(preview)
    samples = [None, 1, 4, 30]
    for index, sample in enumerate(samples):
        tile = Image.new('RGBA', (32, 48), '#56616b')
        grid = ImageDraw.Draw(tile)
        for y in range(0, 48, 4):
            for x in range(0, 32, 4):
                if (x//4 + y//4) % 2 == 0:
                    grid.rectangle((x, y, x+3, y+3), fill='#69747e')
        if sample is None:
            tile.alpha_composite(pot, (0, POT_Y))
        else:
            tile.alpha_composite(Image.open(DEST / f'flower_{sample:02}_potted.png').convert('RGBA'))
        preview.paste(tile.resize((160, 240), Image.Resampling.NEAREST), (index*192+16, 12))
        draw.text((index*192+16, 270), ['Empty pot', 'Rose - lowered 3px', 'Lavender - lowered 3px', 'Gardenia - lowered 3px'][index], fill='#f5e9d0')
    preview.save(OUT / 'preview_lowered_3px.png')
    (OUT / 'integration.json').write_text(json.dumps({'pot': 'res://assets/Flowers/Unzoom30/clay_pot_32x24.png', 'pot_position': [0, POT_Y], 'plant_position': [0, PLANT_Y], 'root_y': 33, 'planted_canvas': [32, 48], 'empty_canvas': [32, 24], 'species': 30, 'early_growth': 'Original six plant frames cropped above the old pot, root aligned at y=33.', 'game_layout': 'unchanged'}, indent=2))
    print('Integrated approved clay pot for empty pots and every growth stage of all 30 species; plants lowered 3px.')

if __name__ == '__main__':
    main()
