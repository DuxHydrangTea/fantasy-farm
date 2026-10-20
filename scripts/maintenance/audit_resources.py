"""Report resource references conservatively; never delete asset libraries.

All gameplay/setup/test scripts and catalog directories are roots. Literal paths,
UID references, and resources under dynamic directory prefixes are considered.
Unreferenced candidates require review: an editor asset library is valid content.
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[2]
SKIP = {'.git', '.godot', '.agents', '.codex', 'addons', 'bin', 'obj'}
TEXT = {'.gd', '.tscn', '.tres', '.godot', '.py'}
CATALOGS = ('items/', 'crops/', 'animals/', 'flowers/', 'sprite_frames/', 'icons/')

def audit():
    files = {p.relative_to(ROOT).as_posix(): p for p in ROOT.rglob('*')
             if p.is_file() and not SKIP.intersection(p.relative_to(ROOT).parts)}
    sources = {name: p.read_text(encoding='utf-8', errors='replace') for name, p in files.items() if p.suffix in TEXT}
    uid_paths = {p.read_text().strip(): name[:-4] for name, p in files.items() if name.endswith('.uid')}
    for name, source in sources.items():
        match = re.match(r'\[(?:gd_scene|gd_resource)[^\n]*uid="([^"]+)"', source)
        if match: uid_paths[match[1]] = name
    edges = {}
    missing = []
    for name, source in sources.items():
        targets = set()
        for path in re.findall(r'["\']res://([^"\'\n]+)["\']', source):
            if '%' in path or '{' in path or path.endswith('/'):
                prefix = path.split('%')[0].split('{')[0]
                targets.update(f for f in files if f.startswith(prefix))
            elif path in files:
                targets.add(path)
            elif (ROOT / path).is_dir():
                targets.update(f for f in files if f.startswith(path.rstrip('/') + '/'))
            elif not name.endswith('.py') and not path.startswith(('.godot/', 'addons/')):
                missing.append({'source': name, 'path': path})
        targets.update(uid_paths[uid] for uid in re.findall(r'uid://[a-z0-9]+', source) if uid in uid_paths)
        edges[name] = targets
    reached = {name for name in files if name.endswith(('.gd', '.py')) or name == 'project.godot' or name.startswith(CATALOGS)}
    todo = list(reached)
    while todo:
        for target in edges.get(todo.pop(), ()):
            if target not in reached:
                reached.add(target); todo.append(target)
    return {'files_scanned': len(files), 'reachable': len(reached),
            'review_candidates': sorted(name for name in files if name.endswith(('.tscn', '.tres')) and name not in reached),
            'missing_literal_references': missing,
            'policy': 'Candidates are review hints, not permission to delete setup/editor libraries.'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = audit()
    encoded = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output: args.output.write_text(encoded, encoding='utf-8')
    print(json.dumps({k: len(v) if isinstance(v, list) else v for k, v in result.items()}, ensure_ascii=False))
