import datetime
import hashlib
import json
import os
from pathlib import Path

out = Path(__file__).resolve().parent
plan = json.loads((out/'plan.json').read_text())
source = Path(plan['source'])
assert source.resolve().parent == Path('C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves').resolve()
original = source.read_bytes()
assert hashlib.sha256(original).hexdigest() == plan['source_sha256'], 'Save changed since preparation; do not overwrite.'
assert 'PERENNIAL_FILL_VALIDATED' in (out/'validate.log').read_text()
candidate = (out/'profile_local.json').read_bytes()
envelope = json.loads(candidate)
assert hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['sha256']
before = json.loads(json.loads(original)['payload'])
after = json.loads(envelope['payload'])
assert [k for k in before if before[k] != after[k]] == ['revision','tree_plot_upgrades','trees']
stamp = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=7))).strftime('%Y%m%d_%H%M%S')
backup = source.with_name(source.name+'.before_all_perennials_'+stamp+'.bak')
with backup.open('xb') as handle:
    handle.write(original)
temp = source.with_name(source.name+'.perennial_fill.tmp')
with temp.open('xb') as handle:
    handle.write(candidate)
    handle.flush()
    os.fsync(handle.fileno())
os.replace(temp,source)
assert source.read_bytes() == candidate
report = {'installed':str(source),'backup':str(backup),'trees':306,'species':21,'revision':after['revision'],'preserved_other_fields':True,'sha256':hashlib.sha256(candidate).hexdigest()}
(out/'installation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
