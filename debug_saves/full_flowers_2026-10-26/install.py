import datetime,hashlib,json,os
from pathlib import Path

out=Path(__file__).resolve().parent
info=json.loads((out/'source.json').read_text())
assert json.loads((out/'verification.json').read_text())['world_restore_verified']
source=Path(info['source'])
assert source.resolve().parent==Path('C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves').resolve()
raw=source.read_bytes();assert hashlib.sha256(raw).hexdigest()==info['sha256'],'Save changed; do not overwrite.'
candidate=(out/'profile_local.json').read_bytes();envelope=json.loads(candidate)
assert hashlib.sha256(envelope['payload'].encode()).hexdigest()==envelope['sha256']
before=json.loads(json.loads(raw)['payload']);after=json.loads(envelope['payload'])
assert all(before[k]==after[k] for k in before if k not in ('flower_gardens','revision'))
stamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=7))).strftime('%Y%m%d_%H%M%S')
backup=source.with_name(source.name+'.before_full_flowers_'+stamp+'.bak')
with backup.open('xb') as file:file.write(raw)
temp=source.with_name(source.name+'.full_flowers.tmp')
with temp.open('xb') as file:file.write(candidate);file.flush();os.fsync(file.fileno())
os.replace(temp,source);assert source.read_bytes()==candidate
report={'installed':str(source),'backup':str(backup),'flowers':177,'species':10,'other_fields_preserved':True,'revision':after['revision']}
(out/'installation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
