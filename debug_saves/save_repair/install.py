import hashlib
import json
import os
from pathlib import Path
from datetime import datetime

target = Path(r'C:\Users\faker\AppData\Roaming\Godot\app_userdata\fantasy-farm\saves\profile_local.json')
candidate = Path(r'C:\projects\fantasy-farm\debug_saves\save_repair\repaired.json')
expected = 'ef5031b9351f2bbae90266378c9023819df9b0f13fc9afd75ed6fc0875aeace7'
original = target.read_bytes()
if hashlib.sha256(original).hexdigest() != expected:
    raise RuntimeError('Save changed since validation; refusing to overwrite.')
replacement = candidate.read_bytes()
envelope = json.loads(replacement)
if hashlib.sha256(envelope['payload'].encode()).hexdigest() != envelope['sha256']:
    raise RuntimeError('Candidate checksum mismatch.')
backup = target.with_name(target.name + '.before_worker_position_' + datetime.now().strftime('%Y%m%d_%H%M%S') + '.bak')
with backup.open('xb') as f:
    f.write(original)
temporary = target.with_name(target.name + '.worker_repair.tmp')
with temporary.open('xb') as f:
    f.write(replacement)
if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
    temporary.unlink()
    raise RuntimeError('Save changed during repair; backup retained.')
os.replace(temporary, target)
print('Updated:', target)
print('Backup:', backup)
