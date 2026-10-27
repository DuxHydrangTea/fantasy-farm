"""Integrate the user's thirty PixelLab-unzoomed flowers without redrawing sprites."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/flowers_unzoom_2026-10-27'
BACKUP = ROOT / 'output/flower_integration_30_backup'
ASSETS = ROOT / 'assets/Flowers/Unzoom30'
VI = ['Hoa hồng', 'Cẩm chướng', 'Hoa lan', 'Oải hương', 'Hoa chuông xanh', 'Cẩm tú cầu', 'Vạn thọ', 'Hướng dương', 'Linh lan', 'Sen xanh', 'Tulip', 'Thủy tiên vàng', 'Anh đào', 'Tử đằng', 'Mẫu đơn', 'Trà mi', 'Diên vĩ', 'Dâm bụt', 'Anh túc', 'Hoa sen', 'Hoa cúc', 'Bìm bìm', 'Hoa sứ', 'Hoa giấy', 'Cúc trắng', 'Lưu ly', 'Păng-xê', 'Cúc ngũ sắc', 'Sao nhái', 'Dành dành']

def write(path, content):
    target = ROOT / path
    backup = BACKUP / path
    if target.exists() and not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(target.read_bytes())
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')

def header(text, kind, script_class=None):
    uid = re.search(r'^\[gd_resource[^\n]*\buid="[^"]+"', text)
    attr = re.search(r'uid="[^"]+"', uid.group(0)).group(0) if uid else ''
    cls = f' script_class="{script_class}"' if script_class else ''
    return f'[gd_resource type="{kind}"{cls} format=3 {attr}]'.replace(' ]', ']')

def extend_catalog(path, declarations, blocks, array_key, references):
    text = (ROOT / path).read_text(encoding='utf-8')
    # Idempotence: an existing integration is left intact.
    if 'id="flower_pack_11"' in text:
        return
    pos = text.index('[sub_resource')
    text = text[:pos] + declarations + '\n' + text[pos:]
    pos = text.index('[resource]')
    text = text[:pos] + blocks + '\n' + text[pos:]
    pattern = rf'^({array_key} = Array\[[^\n]+?\]\()\[([^\n]*)\](\))'
    text, count = re.subn(pattern, lambda m: m[1] + '[' + m[2] + ', ' + ', '.join(references) + ']' + m[3], text, flags=re.MULTILINE)
    assert count == 1, path
    write(path, text)

def main():
    entries = json.loads((SOURCE / 'manifest.json').read_text())['items']
    assert len(entries) == 30
    ASSETS.mkdir(parents=True, exist_ok=True)
    templates = [(ROOT / f'flowers/definitions/flower_{i:02}.tres').read_text() for i in range(1, 11)]
    stock = (ROOT / 'resources/shops/farm_supply.tres').read_text()
    prices = (ROOT / 'resources/shops/produce_prices.tres').read_text()
    stock_prices = [int(re.search(rf'\[sub_resource type="Resource" id="Offer_{i+8}"\][\s\S]*?\nprice = (\d+)', stock).group(1)) for i in range(1, 11)]
    sell_prices = []
    for i in range(1, 11):
        ext_id = re.search(rf'path="res://items/flowers/flower_{i:02}\.tres" id="([^"]+)"', prices).group(1)
        sell_prices.append(int(re.search(rf'item = ExtResource\("{ext_id}"\)\nprice = (\d+)', prices).group(1)))
    stock_decl, stock_blocks, stock_refs = '', '', []
    sell_decl, sell_blocks, sell_refs = '', '', []
    for row in entries:
        i, name, filename = row['index'], row['name'], row['file']
        # Byte-for-byte copies of the approved transparent sprites.
        (ASSETS / filename).write_bytes((SOURCE / 'sprites32' / filename).read_bytes())
        image_path = f'res://assets/Flowers/Unzoom30/{filename}'
        for stage in (4, 5):
            path = f'flowers/frames/flower_{i:02}_stage_{stage}.tres'
            old = (ROOT / path).read_text() if (ROOT / path).exists() else ''
            frames = ', '.join(['{"duration": 1.0, "texture": ExtResource("art")}'] * 6)
            write(path, f'{header(old, "SpriteFrames")}\n\n[ext_resource type="Texture2D" path="{image_path}" id="art"]\n\n[resource]\nanimations = [{{"frames": [{frames}], "loop": true, "name": &"grow", "speed": 8.0}}]\n')
        path = f'items/flowers/flower_{i:02}.tres'
        old = (ROOT / path).read_text() if (ROOT / path).exists() else ''
        write(path, f'{header(old, "Resource", "ItemDefinition")}\n\n[ext_resource type="Script" path="res://scripts/item_definition.gd" id="script"]\n[ext_resource type="Texture2D" path="{image_path}" id="art"]\n\n[resource]\nscript = ExtResource("script")\nitem_id = &"flower_{i:02}"\ndisplay_name = "{name}"\nicon = ExtResource("art")\nitem_type = 2\nmax_stack = 32000\n')
        if i > 10:
            tier = (i - 1) % 10
            template = templates[tier]
            seconds = float(re.search(r'growth_seconds = ([\d.]+)', template).group(1))
            amount = int(re.search(r'harvest_amount = (\d+)', template).group(1))
            ext = '[ext_resource type="Script" path="res://scripts/flower_definition.gd" id="script"]\n'
            ext += f'[ext_resource type="Resource" path="res://items/flowers/flower_{i:02}.tres" id="produce"]\n'
            for stage in range(1, 6):
                source_index = 1 if stage <= 3 else i
                ext += f'[ext_resource type="SpriteFrames" path="res://flowers/frames/flower_{source_index:02}_stage_{stage}.tres" id="stage_{stage}"]\n'
            stages = ', '.join(f'ExtResource("stage_{s}")' for s in range(1, 6))
            write(f'flowers/definitions/flower_{i:02}.tres', f'[gd_resource type="Resource" script_class="FlowerDefinition" format=3]\n\n{ext}\n[resource]\nscript = ExtResource("script")\nflower_id = &"flower_{i:02}"\ndisplay_name = "{name}"\nstage_frames = Array[SpriteFrames]([{stages}])\ngrowth_seconds = {seconds}\nharvest_item = ExtResource("produce")\nharvest_amount = {amount}\n')
            stock_decl += f'[ext_resource type="Resource" path="res://items/seeds/flower_{i:02}_seed.tres" id="flower_pack_{i:02}"]\n'
            stock_blocks += f'[sub_resource type="Resource" id="flower_pack_offer_{i:02}"]\nscript = ExtResource("2_offer")\nitem = ExtResource("flower_pack_{i:02}")\nprice = {stock_prices[tier]}\ncategory = 2\n\n'
            stock_refs.append(f'SubResource("flower_pack_offer_{i:02}")')
            sell_decl += f'[ext_resource type="Resource" path="res://items/flowers/flower_{i:02}.tres" id="flower_pack_{i:02}"]\n'
            sell_blocks += f'[sub_resource type="Resource" id="flower_pack_price_{i:02}"]\nscript = ExtResource("1_k2k64")\nitem = ExtResource("flower_pack_{i:02}")\nprice = {sell_prices[tier]}\n\n'
            sell_refs.append(f'SubResource("flower_pack_price_{i:02}")')
        path = f'items/seeds/flower_{i:02}_seed.tres'
        old = (ROOT / path).read_text() if (ROOT / path).exists() else ''
        icons = list((ROOT / 'assets/Icons/seeds/flowers48').glob(f'flower_{i:02}_*_seed.png'))
        assert len(icons) == 1
        icon_path = 'res://' + icons[0].relative_to(ROOT).as_posix()
        write(path, f'{header(old, "Resource", "ItemDefinition")}\n\n[ext_resource type="Script" path="res://scripts/item_definition.gd" id="script"]\n[ext_resource type="Resource" path="res://flowers/definitions/flower_{i:02}.tres" id="flower"]\n[ext_resource type="Texture2D" path="{icon_path}" id="icon"]\n\n[resource]\nscript = ExtResource("script")\nitem_id = &"flower_{i:02}_seed"\ndisplay_name = "{name} Seed"\nicon = ExtResource("icon")\nitem_type = 1\ncrop = ExtResource("flower")\nmax_stack = 999\n')
    extend_catalog('resources/shops/farm_supply.tres', stock_decl, stock_blocks, 'offers', stock_refs)
    extend_catalog('resources/shops/produce_prices.tres', sell_decl, sell_blocks, 'entries', sell_refs)
    for locale in ('en', 'vi'):
        path = f'localization/{locale}.po'
        text = (ROOT / path).read_text(encoding='utf-8')
        for row, vi in zip(entries, VI):
            for key, translated in ((row['name'], vi), (row['name'] + ' Seed', 'Hạt giống ' + vi.lower())):
                if f'msgid "{key}"\n' not in text:
                    text += f'\nmsgid "{key}"\nmsgstr "{translated if locale == "vi" else key}"\n'
        write(path, text)
    print('Integrated thirty exact source sprites, thirty flower/seed pairs, sixty bloom resources, twenty new shop offers and sell prices. Existing first-ten IDs, growth/economy and early stages retained; new species reuse those ten tiers.')

if __name__ == '__main__':
    main()
