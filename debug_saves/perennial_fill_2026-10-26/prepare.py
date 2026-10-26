import collections
import copy
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/profile_local.json')
raw = SOURCE.read_bytes()
envelope = json.loads(raw)
assert hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['sha256']
old = json.loads(envelope['payload'])
data = copy.deepcopy(old)
definitions = {}
for path in (ROOT/'trees/definitions').glob('*.tres'):
    text = path.read_text()
    definitions[path.stem] = {'kind':int(re.search(r'^kind = (\d+)', text, re.M)[1]) if re.search(r'^kind = (\d+)', text, re.M) else 0,
        'growth':float(re.search(r'^growth_seconds = ([\d.]+)',text,re.M)[1]),
        'cycle':float(re.search(r'^fruit_cycle_seconds = ([\d.]+)',text,re.M)[1]) if re.search(r'^fruit_cycle_seconds = ([\d.]+)',text,re.M) else 90.0}
now = data['saved_at']
rows = []
counts = {}
for kind, origin_x in ((0,10),(1,66)):
    ids = sorted(n for n,d in definitions.items() if d['kind'] == kind)
    assert len(ids) == (4 if kind == 0 else 17)
    for y in range(9):
        for x in range(17):
            # Rotating rows distribute every species across the whole region.
            name = ids[(x + y*5) % len(ids)]
            definition = definitions[name]
            mature = now - (definition['cycle'] if kind == 0 else 1.0)
            planted = mature - definition['growth']
            row = {'tree':name,'cell':[origin_x+2+x*3,61+y*3], 'planted_at':planted,
                   'growth_started_at':planted,'matures_at':mature,'last_at':now}
            if kind == 0:
                row.update(fruit_work=definition['cycle'],active_graft=0,pending_graft=0,graft_revision=0)
            else:
                row.update(stump=False,hits=0,root_hits=0,regrow_at=0.0)
            rows.append(row)
    counts[str(kind)] = dict(collections.Counter(r['tree'] for r in rows if definitions[r['tree']]['kind'] == kind))
data['trees'] = rows
data['tree_plot_upgrades'] = {'fruit':17,'timber':17}
data['revision'] = int(old['revision'])+1
assert len(rows) == 306 and len({tuple(r['cell']) for r in rows}) == 306
assert set(counts['1'].values()) == {9}
assert max(counts['0'].values())-min(counts['0'].values()) <= 1
changed = [k for k in data if old[k] != data[k]]
assert set(changed) == {'trees','tree_plot_upgrades','revision'}
(OUT/'before_profile_local.json').write_bytes(raw)
payload = json.dumps(data,separators=(',',':'),ensure_ascii=False)
candidate = {'format':'fantasy_farm_save','payload':payload,'sha256':hashlib.sha256(payload.encode()).hexdigest()}
(OUT/'profile_local.json').write_text(json.dumps(candidate,indent=2,ensure_ascii=False),encoding='utf-8')
report = {'source':str(SOURCE),'source_sha256':hashlib.sha256(raw).hexdigest(),'revision_before':old['revision'],'revision_after':data['revision'],'tree_count':len(rows),'counts':counts,'changed_fields':changed,'mature':True,'plots':data['tree_plot_upgrades']}
(OUT/'plan.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
