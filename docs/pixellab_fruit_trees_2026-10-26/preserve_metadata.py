"""Keep original UID metadata and verify that edits only affect mature visuals."""
from pathlib import Path
import re
import subprocess

for id in ['apple','peach','pear','cherry']:
    path=Path(f'trees/definitions/{id}.tres')
    original=subprocess.check_output(['git','show','HEAD:'+path.as_posix()],text=True)
    metadata={re.sub(r' uid="[^"]+"','',line):line for line in original.splitlines() if line.startswith(('[gd_resource','[ext_resource'))}
    current=path.read_text()
    updated='\n'.join(metadata.get(line,line) for line in current.splitlines())+'\n'
    def fields(text):
        return dict(line.split(' = ',1) for line in text.split('[resource]',1)[1].splitlines() if ' = ' in line and not line.startswith(('stage_textures = ','ready_texture = ')))
    assert fields(original)==fields(updated),id
    path.write_text(updated)
print('Preserved fruit-tree data and UID metadata; mature/ready visual bindings are the only changes.')
