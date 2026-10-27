from pathlib import Path
from PIL import Image
import json

OUT = Path(__file__).resolve().parent
(OUT / 'inputs').mkdir(exist_ok=True)
entries = []
for sheet in range(1, 4):
    source = Path(f'C:/Users/faker/Downloads/hoa{sheet}.jpg')
    im = Image.open(source).convert('RGB')
    for row in range(2):
        for col in range(5):
            index = (sheet - 1) * 10 + row * 5 + col + 1
            rect = (round(col * im.width / 5), row * (im.height // 2), round((col + 1) * im.width / 5), (row + 1) * (im.height // 2))
            filename = f'flower_{index:02}.png'
            im.crop(rect).save(OUT / 'inputs' / filename)
            entries.append({'index': index, 'sheet': sheet, 'row': row, 'column': col, 'source': str(source), 'rect': rect, 'input': filename})
(OUT / 'inputs.json').write_text(json.dumps(entries, indent=2))
print('Prepared 30 original-resolution flower crops, 5 columns x 2 rows per source.')
