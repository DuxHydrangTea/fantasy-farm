"""Keep existing item identities/UID metadata while retaining the new icon bindings."""
from pathlib import Path
import re
import subprocess

for index in range(1,11):
    path=Path(f'items/seeds/flower_{index:02d}_seed.tres')
    original=subprocess.check_output(['git','show','HEAD:'+path.as_posix()],text=True)
    normalized={re.sub(r' uid="[^"]+"','',line):line for line in original.splitlines() if line.startswith(('[ext_resource','[gd_resource'))}
    current=path.read_text()
    updated='\n'.join(normalized.get(line,line) for line in current.splitlines())+'\n'
    def properties(text):
        return {line.split(' = ',1)[0]:line.split(' = ',1)[1] for line in text.split('[resource]',1)[1].splitlines() if ' = ' in line and not line.startswith('icon = ')}
    assert properties(original)==properties(updated),path
    path.write_text(updated)
print('Existing item metadata preserved for all 10 flower seed resources; only icon bindings changed.')
