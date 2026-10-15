"""Remove colliders from visual-only scenes, preserving other scene edits."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY = json.loads((ROOT / 'tools/setup/data/object_collision_policy.json').read_text())
INDEX = ROOT / 'docs/object_scenes_index.json'


def needs_collision(entry):
    category, kind = entry['category'], entry['kind']
    if category in POLICY['categories_without_collision']:
        return False
    key = {'crops': 'crop_kinds_without_collision',
           'house_decor_static': 'house_decor_kinds_without_collision',
           'house_decor_animated': 'animated_kinds_without_collision',
           'outdoor_decor': 'animated_kinds_without_collision'}.get(category)
    return not (key and kind in POLICY[key])


def main():
    index = json.loads(INDEX.read_text())
    planned = []
    for entry in index['scenes']:
        entry['has_collision'] = needs_collision(entry)
        if entry['has_collision']:
            continue
        path = ROOT / entry['scene'][6:]
        original = path.read_text()
        blocks = re.split(r'(?m)(?=^\[)', original)
        removed = [b for b in blocks if b.startswith('[node ') and 'type="CollisionShape2D"' in b.split('\n', 1)[0]]
        remaining = ''.join(b for b in blocks if b not in removed)
        for block in removed:
            name = re.search(r'name="([^"]+)"', block)[1]
            if re.search(r'parent="' + re.escape(name) + r'(?:/|\")', remaining):
                raise RuntimeError(f'Collision node has children; review before removing: {path}')
        shape_ids = {m for b in removed for m in re.findall(r'shape = SubResource\("([^"]+)"\)', b)}
        deleted_shapes = 0
        for shape_id in shape_ids:
            if f'SubResource("{shape_id}")' in remaining:
                continue
            for block in blocks:
                if block.startswith('[sub_resource ') and f'id="{shape_id}"' in block.split('\n', 1)[0]:
                    remaining = remaining.replace(block, '')
                    deleted_shapes += 1
        remaining = re.sub(r'load_steps=(\d+)', lambda m: f'load_steps={int(m[1]) - deleted_shapes}', remaining, count=1)
        if remaining != original:
            planned.append((path, remaining))
    for path, text in planned:
        path.write_text(text)
    INDEX.write_text(json.dumps(index, ensure_ascii=False, indent='\t') + '\n')
    print(f'Removed collision from {len(planned)} scenes; {sum(not e["has_collision"] for e in index["scenes"])} scenes use no collision.')


if __name__ == '__main__':
    main()
