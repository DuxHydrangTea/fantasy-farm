"""Background cleanup and transparent padding of actual PixelLab Unzoom results; no redraw."""
from pathlib import Path
from collections import deque
import json
import re
import zipfile
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
DEST = OUT / 'sprites32'
NAMES = ['Rose', 'Carnation', 'Orchid', 'Lavender', 'Bluebell', 'Hydrangea', 'Marigold', 'Sunflower', 'Lily of the valley', 'Blue Lotus', 'Tulip', 'Daffodil', 'Sakura', 'Wisteria', 'Peony', 'Camellia', 'Iris', 'Hibiscus', 'Poppy', 'Lotus', 'Chrysanthemum', 'Morning glory', 'Plumeria', 'Bougainvillea', 'Daisy', 'Forget me not', 'Pansy', 'Zinnia', 'Cosmos', 'Gardenia']

def cutout(im, index):
    im = im.convert('RGBA')
    w, h = im.size
    pixels = im.load()
    # Ground shadows are neutral gray below the flower heads. Restrict removal
    # to the lower 30%, retaining gray outlines around white petals higher up.
    shadow_count = 0
    for y in range(int(h * .70), h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if max(r, g, b) - min(r, g, b) <= 14 and 75 <= min(r, g, b) and max(r, g, b) < 225:
                pixels[x, y] = (0, 0, 0, 0)
                shadow_count += 1
    def background(x, y):
        r, g, b, a = pixels[x, y]
        return a == 0 or (min(r, g, b) >= 230 and max(r, g, b) - min(r, g, b) <= 24)
    queue, seen = deque(), set()
    for y in range(h):
        for x in range(w):
            if (x in (0, w-1) or y in (0, h-1)) and background(x, y):
                queue.append((x, y)); seen.add((x, y))
    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and background(nx, ny):
                    seen.add((nx, ny)); queue.append((nx, ny))
    # Some white background islands are enclosed between stems. Keep white
    # only in observed pale-petal regions; remove the same background below them.
    pale_petals_until = {2: .66, 9: .62, 13: .79, 23: .71, 25: .68, 30: .74}
    preserve_until = int(h * pale_petals_until.get(index, 0))
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a and y >= preserve_until and min(r, g, b) >= 230 and max(r, g, b) - min(r, g, b) <= 24:
                pixels[x, y] = (0, 0, 0, 0)
    bbox = im.getbbox()
    assert bbox, 'Blank flower'
    return im.crop(bbox), bbox, shadow_count

def main():
    DEST.mkdir(exist_ok=True)
    jobs = {j['index']: j for j in json.loads((OUT / 'pixellab-jobs.json').read_text())}
    manifest = []
    atlas = Image.new('RGBA', (320, 96))
    preview = Image.new('RGB', (1080, 900), '#283138')
    draw = ImageDraw.Draw(preview)
    sheets = [Image.new('RGBA', (160, 64)) for _ in range(3)]
    for i, name in enumerate(NAMES, 1):
        raw = Image.open(OUT / 'unzoom' / f'flower_{i:02}.png')
        sprite, box, shadows = cutout(raw, i)
        native = sprite.size
        scale = min(1, 30 / sprite.width, 30 / sprite.height)
        if scale < 1:
            sprite = sprite.resize((max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))), Image.Resampling.NEAREST)
        frame = Image.new('RGBA', (32, 32))
        at = ((32 - sprite.width) // 2, 31 - sprite.height)
        frame.alpha_composite(sprite, at)
        slug = re.sub(r'[^a-z0-9]+', '_', name.lower())
        filename = f'flower_{i:02}_{slug}.png'
        frame.save(DEST / filename)
        assert frame.size == (32, 32) and set(frame.getchannel('A').get_flattened_data()) == {0, 255}
        atlas.alpha_composite(frame, (((i-1) % 10) * 32, ((i-1) // 10) * 32))
        s, n = divmod(i-1, 10)
        sheets[s].alpha_composite(frame, ((n % 5) * 32, (n // 5) * 32))
        x, y = ((i-1) % 6) * 180, ((i-1) // 6) * 180
        # A subtle checkerboard shows actual transparency, including white petals.
        tile = Image.new('RGBA', (32, 32), '#56616b')
        td = ImageDraw.Draw(tile)
        for yy in range(0, 32, 4):
            for xx in range(0, 32, 4):
                if ((xx + yy) // 4) % 2 == 0:
                    td.rectangle((xx, yy, xx+3, yy+3), fill='#69747e')
        tile.alpha_composite(frame)
        preview.paste(tile.resize((128, 128), Image.Resampling.NEAREST), (x+26, y+8))
        draw.text((x+8, y+145), f'{i:02} {name}', fill='#f4e9d0')
        manifest.append({'index': i, 'name': name, 'file': filename, 'pixellab_job_id': jobs[i]['job_id'], 'unzoom_size': list(raw.size), 'crop': box, 'native_content_size': native, 'scale': scale, 'placement': at, 'size': [32, 32], 'removed_shadow_pixels': shadows})
    atlas.save(OUT / 'flowers_30_atlas_320x96.png')
    for i, sheet in enumerate(sheets, 1):
        sheet.save(OUT / f'hoa{i}_sheet_160x64.png')
    preview.save(OUT / 'preview_30_flowers.png')
    (OUT / 'manifest.json').write_text(json.dumps({'method': 'Each source crop processed by PixelLab unzoom_image (quantize 48). Local border-connected white background removal protects enclosed white petals. Neutral ground shadows removed only in bottom 30%. Native content kept at original pixel size when possible, nearest-neighbor fit only if necessary; padded to transparent 32x32.', 'game_integration': False, 'items': manifest}, indent=2))
    (OUT / 'README.txt').write_text('30 flowers from hoa1.jpg, hoa2.jpg and hoa3.jpg.\nPixelLab Unzoom, no redraw. Transparent PNG sprites: sprites32/.\nNumbering: left to right, top row then bottom row, hoa1 then hoa2 then hoa3.\nEach sprite is 32x32 RGBA. Native pixels retained when possible.\nThree source sheets: 160x64, 5x2 cells. Full atlas: 320x96, 10x3 cells.\nBackground and neutral ground shadow removed; white petals protected with connected background removal.\nOriginal PixelLab outputs and job metadata retained separately for audit.\nNot integrated into game.\n')
    with zipfile.ZipFile(OUT / 'flowers_30_transparent_32x32.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for p in sorted(DEST.glob('*.png')):
            archive.write(p, f'sprites32/{p.name}')
        for name in ['flowers_30_atlas_320x96.png', 'hoa1_sheet_160x64.png', 'hoa2_sheet_160x64.png', 'hoa3_sheet_160x64.png', 'preview_30_flowers.png', 'README.txt', 'manifest.json']:
            archive.write(OUT / name, name)
    print('Verified 30 transparent 32x32 PNGs; exported three source sheets, atlas, preview and ZIP.')

if __name__ == '__main__':
    main()
