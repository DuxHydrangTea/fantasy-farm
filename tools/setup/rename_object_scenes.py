"""Migrate indexed scene names without regenerating or losing scene edits.

Run from any directory: python3 tools/setup/rename_object_scenes.py
Naming authority: data/object_scene_names.json. Atlas paths remain unchanged.
"""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "tools/setup/data/object_scene_names.json"
INDEX = ROOT / "docs/object_scenes_index.json"


def scene_path(relative):
    group, local = relative.split('/', 1)
    roots = {
        'characters': 'entities/npcs',
        'crops': 'features/farming/crops',
        'items': 'features/inventory/items',
        'house_decor': 'world/decorations/house',
        'outdoor_decor': 'world/decorations/outdoor',
    }
    return f'res://{roots[group]}/{local}.tscn'


def main():
    names = json.loads(CATALOG.read_text())
    index = json.loads(INDEX.read_text())
    changes = {}
    for old, name in names["crops"].items():
        for folder, suffix in [("crops/field", ""), ("crops/signs", "_sign"),
                               ("items/seeds", "_seed"), ("items/harvest", "_harvest")]:
            changes[f"{folder}/{old}{suffix}"] = f"{folder}/{name}{suffix}"
    for style in ("outline", "no_outline"):
        for category, mapping in names["icons"].items():
            for old, name in mapping.items():
                changes[f"items/{style}/{category}/{old}"] = f"items/{style}/{category}/{name}"
    for old, name in names["outdoor_decor"].items():
        changes[f"outdoor_decor/{old}"] = f"outdoor_decor/{name}"
    changes = {scene_path(old): scene_path(new)
               for old, new in changes.items()}
    assert len(set(changes.values())) == len(changes), "Duplicate target paths"
    def normalized(text):
        text = re.sub(r' uid="uid://[^"]+"', '', text)
        text = re.sub(r'(?m)^metadata/object_id = .*\n', '', text)
        return re.sub(r'(?m)^\[node name="[^"]+"', '[node name="ROOT"', text, count=1)

    planned = []
    for old, new in changes.items():
        source, target = ROOT / old[6:], ROOT / new[6:]
        if source.exists():
            if target.exists():
                source_text, target_text = source.read_text(), target.read_text()
                source_uid = re.search(r' uid="(uid://[^"]+)"', source_text)
                target_uid = re.search(r' uid="(uid://[^"]+)"', target_text)
                if normalized(source_text) != normalized(target_text):
                    raise RuntimeError(f"Scene contents differ; refusing to overwrite: {old}, {new}")
                if source_uid and target_uid and source_uid[1] != target_uid[1]:
                    raise RuntimeError(f"Scene UIDs differ; refusing to overwrite: {old}, {new}")
            planned.append((source, target))
        elif not target.exists():
            raise RuntimeError(f"Missing scene: {old} / {new}")
    # Complete preflight before the first rename.
    for source, target in planned:
        text = source.read_text()
        name = "".join(part.capitalize() for part in target.stem.split("_"))
        text, count = re.subn(r'(?m)^\[node name="[^"]+"([^\n]*)$',
                             lambda match: f'[node name="{name}"{match[1]}', text, count=1)
        assert count == 1, source
        target.write_text(text)
        source.unlink()
    references = 0
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in (".godot", ".git") for part in path.parts):
            continue
        if path.suffix not in (".tscn", ".tres", ".gd", ".godot", ".json", ".md"):
            continue
        before = path.read_text()
        after = before
        for old, new in changes.items():
            if old in after:
                after = after.replace(old, new)
        if after != before:
            path.write_text(after)
            references += 1
    # Attach stable identities to semantic scenes, including already-named fruit.
    for entry in index["scenes"]:
        entry["scene"] = changes.get(entry["scene"], entry["scene"])
        entry["object_id"] = Path(entry["scene"]).stem
        if entry["category"] == "outdoor_decor":
            entry["kind"] = names["outdoor_decor"].get(entry["kind"], entry["kind"])
        if entry["category"] not in ("crops", "items", "outdoor_decor"):
            continue
        path = ROOT / entry["scene"][6:]
        text = path.read_text()
        if entry["category"] == "outdoor_decor":
            text = re.sub(r'(?m)^metadata/object_kind = .*',
                          f'metadata/object_kind = "{entry["kind"]}"', text)
        identity = f'metadata/object_id = "{entry["object_id"]}"'
        if "metadata/object_id =" in text:
            text = re.sub(r'(?m)^metadata/object_id = .*$', identity, text)
        else:
            text = text.replace("metadata/object_kind =", identity + "\nmetadata/object_kind =", 1)
        if text != path.read_text():
            path.write_text(text)
    INDEX.write_text(json.dumps(index, ensure_ascii=False, indent="\t") + "\n")
    print(f"Renamed {len(planned)} scenes; updated references in {references} files.")


if __name__ == "__main__":
    main()
