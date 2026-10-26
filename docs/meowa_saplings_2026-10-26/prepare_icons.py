"""Normalize reviewed Meowa results into native transparent inventory icons."""
import hashlib
import json
from PIL import Image, ImageDraw
from batch import ROOT, OUT, SPECIES

target = ROOT / 'assets/Icons/tree_saplings'
target.mkdir(parents=True, exist_ok=True)
report = []
board = Image.new('RGBA', (7*144,2*184), (49,52,58,255))
draw = ImageDraw.Draw(board)
for i, name in enumerate(SPECIES):
    source = OUT / (name + '_raw128.png')
    image = Image.open(source).convert('RGBA')
    assert image.size == (128,128), (name, image.size)
    image = image.resize((32,32), Image.Resampling.NEAREST)
    image.putalpha(image.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    bbox = image.getbbox()
    assert bbox is not None, name
    image = image.crop(bbox)
    scale = min(24 / image.width, 22 / image.height)
    size = (max(1,round(image.width*scale)),max(1,round(image.height*scale)))
    image = image.resize(size, Image.Resampling.NEAREST)
    icon = Image.new('RGBA', (32,32))
    icon.alpha_composite(image, ((32-image.width)//2, 27-image.height))
    path = target / (name + '_sapling.png')
    icon.save(path)
    alpha = set(icon.getchannel('A').get_flattened_data())
    assert alpha == {0,255}, (name, alpha)
    assert 0 < len(set(icon.get_flattened_data())) < 1024
    report.append({'tree_id':name, 'path':str(path.relative_to(ROOT)), 'size':[32,32], 'bbox':icon.getbbox(), 'opaque_pixels':sum(a>0 for a in icon.getchannel('A').get_flattened_data()), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    x,y = (i%7)*144,(i//7)*184
    board.alpha_composite(icon.resize((128,128),Image.Resampling.NEAREST),(x+8,y+4))
    draw.text((x+8,y+143),name,fill='white')
    board.alpha_composite(icon,(x+112,y+148))
assert len({r['sha256'] for r in report}) == 14
(OUT/'image_checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
board.save(OUT/'final_icons_preview.png')
print('Prepared 14 unique transparent 32x32 icons; validation saved to image_checks.json.')
