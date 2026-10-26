from pathlib import Path
import tempfile,shutil,subprocess,os
root=Path(__file__).resolve().parents[2];out=root/'docs/pen_upgrades_2026-10-26'
with tempfile.TemporaryDirectory(prefix='pen-baseline-') as tmp:
 base=Path(tmp)
 for p in root.iterdir():
  if p.name in ['components','tests','project.godot']:continue
  (base/p.name).symlink_to(p,target_is_directory=p.is_dir())
 shutil.copytree(root/'components',base/'components')
 for name in ['components/animal_trade_service.gd','components/animals/management/pen_dashboard.gd']:
  old=subprocess.run(['git','show','HEAD:'+name],cwd=root,capture_output=True,check=True).stdout
  (base/name).write_bytes(old)
 (base/'tests').mkdir()
 for p in (root/'tests').iterdir():
  if p.name=='run_tree_tests.py':shutil.copyfile(p,base/'tests'/p.name)
  else:(base/'tests'/p.name).symlink_to(p,target_is_directory=p.is_dir())
 shutil.copyfile(root/'project.godot',base/'project.godot')
 env=os.environ.copy();env['XDG_DATA_HOME']='/tmp/codex-pen-validation'
 result=subprocess.run(['python3',str(base/'tests/run_tree_tests.py'),'--godot','/home/dungnguyen/Downloads/Godot_v4.7.2-stable_linux.x86_64','--suite','tests/unit/test_animal_trade_service.gd','--suite','tests/integration/test_pen_dashboard.gd'],env=env,capture_output=True,text=True,timeout=180)
 (out/'legacy-baseline.log').write_text(result.stdout+result.stderr);print('BASELINE',result.returncode);print(result.stdout[-330:])
