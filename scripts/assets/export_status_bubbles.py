"""Export the approved 2026-10-30 concept to game textures, without regenerating art."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/status_bubble_concepts_2026-10-30'
OUTPUT = ROOT / 'assets/Ui/status_bubbles'
OUTPUT.mkdir(parents=True, exist_ok=True)

for name in ['weeds', 'worm', 'sick', 'hungry', 'thirsty']:
    icon = Image.open(SOURCE / 'raw' / f'{name}_16.png').convert('RGBA')
    assert icon.size == (16, 16) and icon.getchannel('A').getextrema()[0] == 0
    icon.save(OUTPUT / f'{name}.png')
    exported = Image.open(OUTPUT / f'{name}.png').convert('RGBA')
    assert exported.tobytes() == icon.tobytes(), 'Approved sprite pixels must be preserved'

for count in range(1, 6):
    width = 12 + count * 16 + (count - 1) * 4
    panel = Image.new('RGBA', (width, 27))
    d = ImageDraw.Draw(panel)
    edge, cream = '#55392E', '#FFF1CF'
    mid = width // 2
    d.rounded_rectangle((0, 0, width - 1, 22), radius=4, fill=edge)
    d.polygon([(mid - 4, 20), (mid + 4, 20), (mid, 26)], fill=edge)
    d.rounded_rectangle((1, 1, width - 2, 21), radius=3, fill=cream)
    d.line((4, 1, width - 5, 1), fill='#FFFBEB')
    d.line((4, 21, width - 5, 21), fill='#DEC397')
    d.polygon([(mid - 2, 21), (mid + 2, 21), (mid, 24)], fill=cream)
    panel.save(OUTPUT / f'bubble_{count}.png')

metadata = json.loads((SOURCE / 'manifest.json').read_text())
metadata['status'] = 'approved_and_integrated'
metadata['additional_generations_used'] = 0
metadata['source_concept'] = str(SOURCE.relative_to(ROOT))
(OUTPUT / 'manifest.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
print(f'Exported 5 approved 16x16 icons and 5 bubble widths to {OUTPUT}')
