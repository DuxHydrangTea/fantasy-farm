import datetime
import hashlib
import json
import os
from pathlib import Path

out=Path(__file__).resolve().parent
info=json.loads((out/'source.json').read_text())
verified=json.loads((out/'verification.json').read_text())
assert verified['ok'] and verified['world_restore_verified'] and verified['animal_count']==90
source=Path(info['source'])
assert source.resolve().parent==Path('C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves').resolve()
original=source.read_bytes()
assert hashlib.sha256(original).hexdigest()==info['sha256'],'Save changed since preparation; refusing to overwrite.'
candidate=(out/'profile_local.json').read_bytes()
envelope=json.loads(candidate)
assert hashlib.sha256(envelope['payload'].encode()).hexdigest()==envelope['sha256']
before=json.loads(json.loads(original)['payload'])
after=json.loads(envelope['payload'])
allowed={'animals','pen_upgrades','troughs','trees','tree_plot_upgrades','revision'}
assert all(before[key]==after[key] for key in before if key not in allowed)
assert before['soil']==after['soil'] and before['crops']==after['crops']
assert [t for t in before['trees'] if t['cell'][0]>=66]==[t for t in after['trees'] if t['cell'][0]>=66]
assert len(after['animals'])==90 and all(v==6 for v in after['pen_upgrades'].values())
stamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=7))).strftime('%Y%m%d_%H%M%S')
backup=source.with_name(source.name+'.before_full_ranch_'+stamp+'.bak')
with backup.open('xb') as file:file.write(original)
temp=source.with_name(source.name+'.full_ranch.tmp')
with temp.open('xb') as file:
    file.write(candidate);file.flush();os.fsync(file.fileno())
os.replace(temp,source)
assert source.read_bytes()==candidate
report={'installed':str(source),'backup':str(backup),'revision':after['revision'],'animals':90,'fruit_trees':153,'soil_preserved':True,'crops_preserved':True,'timber_trees_preserved':True,'other_fields_preserved':True,'sha256':hashlib.sha256(candidate).hexdigest()}
(out/'installation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
