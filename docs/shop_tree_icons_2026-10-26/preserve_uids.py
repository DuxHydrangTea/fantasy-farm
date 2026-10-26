"""Preserve existing UID metadata after Godot's headless ResourceSaver update."""
from pathlib import Path
import re
import subprocess

path = Path('resources/shops/farm_supply.tres')
original = subprocess.check_output(['git','show','HEAD:resources/shops/farm_supply.tres'],text=True)
lines = {re.sub(r' uid="[^"]+"','',line):line for line in original.splitlines() if line.startswith(('[ext_resource','[gd_resource'))}
current = path.read_text()
path.write_text('\n'.join(lines.get(line,line) for line in current.splitlines())+'\n')
print('Preserved existing resource UID metadata.')
