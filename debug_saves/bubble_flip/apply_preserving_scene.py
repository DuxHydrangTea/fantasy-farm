from pathlib import Path

root = Path(__file__).resolve().parents[2]
paths = [
    'scenes/ui/merchant_interaction.tscn',
    'scenes/characters/shop_merchant.tscn',
    'scenes/characters/produce_buyer.tscn',
    'scenes/characters/seed_flower_merchant.tscn',
    'scenes/characters/pet_merchant.tscn',
    'scenes/characters/flower_merchant.tscn',
    'scenes/characters/blacksmith_merchant.tscn',
]
for relative in paths:
    destination = root / relative
    original = (root / 'debug_saves/bubble_flip/original' / destination.name).read_bytes()
    newline = b'\r\n' if b'\r\n' in original else b'\n'
    assert original.count(b'[node name="Bubble" type="PanelContainer"') == 1
    assert b'id="bubble_flip_material"' not in original
    header_end = original.index(newline) + len(newline)
    extra = newline + b'[ext_resource type="Material" path="res://resources/ui/bubble_flip_material.tres" id="bubble_flip_material"]' + newline
    updated = original[:header_end] + extra + original[header_end:]
    node_start = updated.index(b'[node name="Bubble" type="PanelContainer"')
    node_end = updated.index(newline, node_start) + len(newline)
    updated = updated[:node_end] + b'material = ExtResource("bubble_flip_material")' + newline + updated[node_end:]
    destination.write_bytes(updated)
    print(relative)
