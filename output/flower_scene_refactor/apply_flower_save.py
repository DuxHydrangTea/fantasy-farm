from pathlib import Path
import datetime
import hashlib
import json
import os

folder = Path(__file__).resolve().parent
target = Path('C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/profile_local.json')
expected = (folder / 'flower-save-source.sha256').read_text(encoding='ascii').strip()
original = target.read_bytes()
if hashlib.sha256(original).hexdigest() != expected:
    raise SystemExit('Save changed since preparation; no files were changed.')
candidate = (folder / 'flower-save-candidate.json').read_bytes()
envelope = json.loads(candidate)
assert hashlib.sha256(envelope['payload'].encode('utf-8')).hexdigest() == envelope['sha256']
stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
backup = target.with_name(target.name + '.before_flower_fill_' + stamp + '.bak')
with backup.open('xb') as f:
    f.write(original)
    f.flush()
    os.fsync(f.fileno())
temp = target.with_name(target.name + '.flower_fill_' + stamp + '.tmp')
with temp.open('xb') as f:
    f.write(candidate)
    f.flush()
    os.fsync(f.fileno())
if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
    raise SystemExit('Save changed while preparing the write; backup kept; target untouched.')
os.replace(temp, target)
assert target.read_bytes() == candidate
print('SAVE_UPDATED:', target)
print('BACKUP:', backup)
print('REVISION:', json.loads(envelope['payload'])['revision'])
