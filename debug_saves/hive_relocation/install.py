import copy
import datetime
import hashlib
import json
import os
from pathlib import Path

folder = Path(__file__).resolve().parent
target = Path(os.environ['APPDATA']) / 'Godot/app_userdata/fantasy-farm/saves/profile_local.json'
original_bytes = target.read_bytes()

def decode(raw):
    envelope = json.loads(raw)
    assert hashlib.sha256(envelope['payload'].encode('utf-8')).hexdigest() == envelope['sha256']
    return json.loads(envelope['payload'])

before = decode(original_bytes)
prepared_bytes = (folder / 'profile_local.json').read_bytes()
after = decode(prepared_bytes)
expected = copy.deepcopy(before)
positions = {row['id']: row['position'] for row in after['beehives']}
assert len(positions) == 3
for hive in expected['beehives']:
    hive['position'] = positions[hive['id']]
assert expected == after, 'Save changed since preparation; refusing to overwrite progress'
stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
backup = target.with_name(target.name + '.before_hive_relocation_' + stamp + '.bak')
with backup.open('xb') as stream:
    stream.write(original_bytes)
temporary = target.with_name(target.name + '.hive_relocation.tmp')
with temporary.open('xb') as stream:
    stream.write(prepared_bytes)
    stream.flush()
    os.fsync(stream.fileno())
assert target.read_bytes() == original_bytes, 'Save changed during installation'
os.replace(temporary, target)
assert decode(target.read_bytes()) == after
report = {'ok': True, 'backup': str(backup), 'target': str(target), 'hives': len(after['beehives'])}
(folder / 'installation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
