from pathlib import Path
import tempfile,subprocess,os,shutil
root=Path(__file__).resolve().parents[2];out=root/'docs/flower_seed_icons_2026-10-26';binary='/home/dungnguyen/Downloads/Godot_v4.7.2-stable_linux.x86_64'
with tempfile.TemporaryDirectory(prefix='flower-icons-ui-') as tmp:
 stage=Path(tmp)
 for p in root.iterdir():
  if p.name.startswith('.') or p.name=='project.godot':continue
  (stage/p.name).symlink_to(p,target_is_directory=p.is_dir())
 settings=(root/'project.godot').read_text();settings='\n'.join('enabled=PackedStringArray()' if line.startswith('enabled=PackedStringArray') else line for line in settings.splitlines() if not line.startswith('MCPRuntimeServer='))
 settings=settings.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+stage.name+'"')
 (stage/'project.godot').write_text(settings)
 cache=stage/'.godot';cache.mkdir();(cache/'imported').symlink_to(root/'.godot/imported',target_is_directory=True)
 for p in (root/'.godot').iterdir():
  if p.is_file():shutil.copyfile(p,cache/p.name)
 env=os.environ.copy();env['XDG_DATA_HOME']='/tmp/codex-flower-icons-validation'
 imported=subprocess.run([binary,'--headless','--editor','--path',str(stage),'--import'],env=env,capture_output=True,text=True,timeout=180)
 (out/'ui-import.log').write_text(imported.stdout+imported.stderr)
 assert imported.returncode==0
 result=subprocess.run([binary,'--path',str(stage),'--rendering-method','gl_compatibility','res://docs/flower_seed_icons_2026-10-26/ui_probe.tscn'],env=env,capture_output=True,text=True,timeout=90)
 (out/'ui.log').write_text(result.stdout+result.stderr);print('UI EXIT',result.returncode);print(result.stdout[-300:]);print(result.stderr[-1000:]);raise SystemExit(result.returncode)
