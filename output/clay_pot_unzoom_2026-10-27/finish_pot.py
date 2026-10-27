from collections import deque
from pathlib import Path
import json
import zipfile
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
im = Image.open(OUT / 'pixellab-unzoom.png').convert('RGBA')
w, h = im.size
p = im.load()
def checker(x, y):
    r, g, b, a = p[x, y]
    return a == 0 or (min(r, g, b) >= 70 and max(r, g, b) <= 225 and max(r, g, b) - min(r, g, b) <= 18)
todo, seen = deque(), set()
for y in range(h):
    for x in range(w):
        if (x in (0, w-1) or y in (0, h-1)) and checker(x, y):
            todo.append((x, y)); seen.add((x, y))
while todo:
    x, y = todo.popleft()
    p[x, y] = (0, 0, 0, 0)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and checker(nx, ny):
                seen.add((nx, ny)); todo.append((nx, ny))
box = im.getbbox()
sprite = im.crop(box)
assert max(sprite.size) <= 32
native = Image.new('RGBA', (32, 32))
native_at = ((32-sprite.width)//2, 31-sprite.height)
native.alpha_composite(sprite, native_at)
native.save(OUT / 'clay_pot_native_32x32.png')
scale = min(22/sprite.width, 22/sprite.height, 1)
small = sprite.resize((round(sprite.width*scale), round(sprite.height*scale)), Image.Resampling.NEAREST)
pot = Image.new('RGBA', (32, 24))
at = ((32-small.width)//2, 23-small.height)
pot.alpha_composite(small, at)
pot.save(OUT / 'clay_pot_for_flowers_32x24.png')
for image in (native, pot):
    assert set(image.getchannel('A').get_flattened_data()) == {0, 255}
    assert image.getpixel((0, 0))[3] == 0
    assert not any(checker(x, y) and p[x, y][3] for y in range(h) for x in range(w))
preview = Image.new('RGB', (768, 352), '#283138')
draw = ImageDraw.Draw(preview)
flowers = Path('assets/Flowers/Unzoom30')
samples = [None, 'flower_01_rose.png', 'flower_04_lavender.png', 'flower_30_gardenia.png']
for i, filename in enumerate(samples):
    canvas = Image.new('RGBA', (32, 48), '#56616b')
    grid = ImageDraw.Draw(canvas)
    for y in range(0, 48, 4):
        for x in range(0, 32, 4):
            if (x//4+y//4)%2 == 0:
                grid.rectangle((x, y, x+3, y+3), fill='#69747e')
    canvas.alpha_composite(pot, (0, 24))
    if filename:
        flower = Image.open(flowers / filename).convert('RGBA')
        canvas.alpha_composite(flower, (0, 0))
        composite = Image.new('RGBA', (32, 48))
        composite.alpha_composite(pot, (0, 24))
        composite.alpha_composite(flower, (0, 0))
        composite.save(OUT / ('example_' + filename))
    preview.paste(canvas.resize((160, 240), Image.Resampling.NEAREST), (i*192+16, 12))
    draw.text((i*192+16, 270), ['Empty pot', 'Rose + pot', 'Lavender + pot', 'Gardenia + pot'][i], fill='#f5e9d0')
    draw.text((i*192+16, 290), 'Pot 32x24 | flower 32x32', fill='#f5e9d0')
preview.save(OUT / 'preview_pot_with_flowers.png')
(OUT / 'manifest.json').write_text(json.dumps({'source': 'C:/Users/faker/Downloads/Empty_clay_pot_2K_20261027210708.jpg', 'source_crop': [680, 160, 2070, 1390], 'pixellab_job_id': '2e8128ef-7b10-484f-b685-28bffa025b5a', 'unzoom_size': [w, h], 'native_content_size': sprite.size, 'native_crop': box, 'native_canvas': [32, 32], 'recommended_canvas': [32, 24], 'recommended_content_size': small.size, 'recommended_placement': at, 'suggested_root_anchor': [16, 6], 'example_composition': '32x48 canvas; pot at (0,24), existing 32x32 flower at (0,0)', 'background_removal': 'Border-connected neutral checker gray only; dark colored pot interior preserved. Binary alpha.', 'resizing': 'Native 32x32 retains every unzoomed art pixel. Recommended 32x24 uses proportional nearest-neighbor reduction.', 'integrated_into_game': False}, indent=2))
with zipfile.ZipFile(OUT / 'clay_pot_transparent.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in ['clay_pot_native_32x32.png', 'clay_pot_for_flowers_32x24.png', 'preview_pot_with_flowers.png', 'manifest.json']:
        archive.write(OUT / name, name)
print(f'PASS: native content {sprite.size}; recommended content {small.size}; checker removed, pot interior retained; PNGs and ZIP exported.')
