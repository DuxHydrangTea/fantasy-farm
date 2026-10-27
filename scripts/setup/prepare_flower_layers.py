"""Extract plant-only frames. Never writes to the shared pot texture."""
from pathlib import Path
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/Flowers/Unzoom30'

def main():
    rows = json.loads((ROOT / 'output/flowers_unzoom_2026-10-27/manifest.json').read_text())['items']
    for row in rows:
        for stage in (4, 5):
            path = ROOT / f"flowers/frames/flower_{row['index']:02}_stage_{stage}.tres"
            text = path.read_text()
            text = re.sub(r'path="res://assets/Flowers/Unzoom30/[^\"]+\.png"', f'path="res://assets/Flowers/Unzoom30/{row["file"]}"', text)
            path.write_text(text)
    for i in range(1, 11):
        for stage in range(1, 4):
            path = ROOT / f'flowers/frames/flower_{i:02}_stage_{stage}.tres'
            source_path = f'assets/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Potted/Flowers_{stage}_Potted_Anim.png'
            source = Image.open(ROOT / source_path).convert('RGBA')
            rects = [(frame*16, (i-1)*16, 16, 16) for frame in range(6)]
            strip = Image.new('RGBA', (192, 32))
            for frame, (x, y, w, h) in enumerate(rects):
                x, y = int(x), int(y)
                strip.alpha_composite(source.crop((x, y, x+16, y+11)), (frame*32+8, 20))
            name = f'flower_{i:02}_stage_{stage}_plant.png'
            strip.save(DEST / name)
            text = path.read_text()
            text = re.sub(r'path="res://assets/Flowers/Unzoom30/[^\"]+\.png"', f'path="res://assets/Flowers/Unzoom30/{name}"', text)
            text = re.sub(r'region = Rect2\((\d+), 0, 32, 48\)', r'region = Rect2(\1, 0, 32, 32)', text)
            path.write_text(text)
    print('Prepared plant-only frames; pot texture was not changed.')

if __name__ == '__main__':
    main()
