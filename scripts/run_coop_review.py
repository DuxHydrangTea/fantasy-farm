"""Capture authored livestock yards in an isolated project without touching real saves."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', default='review')
    parser.add_argument('--area', choices=['coop', 'barn', 'riverside', 'east'], default='coop')
    parser.add_argument('--godot', default='C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe')
    parser.add_argument('--batch', help='Apply a Godot scene_batch JSON file to the real project before capture.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = root / '.godot/coop-review-stage'
    stage.mkdir(exist_ok=True)
    for entry in root.iterdir():
        if entry.name.startswith('.') or entry.name == 'project.godot':
            continue
        target = stage / entry.name
        if entry.is_dir() and not target.exists():
            if os.name == 'nt':
                import _winapi
                _winapi.CreateJunction(str(entry), str(target))
            else:
                target.symlink_to(entry, target_is_directory=True)
        elif entry.is_file():
            shutil.copyfile(entry, target)
    settings = (root / 'project.godot').read_text(encoding='utf-8')
    settings = '\n'.join('TimeManager="*res://components/time_manager.gd"' if line.startswith('TimeManager=') else
                         'enabled=PackedStringArray()' if line.startswith('enabled=PackedStringArray') else line
                         for line in settings.splitlines() if not line.startswith('MCPRuntimeServer='))
    settings = settings.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="fantasy-farm-coop-review"')
    (stage / 'project.godot').write_text(settings, encoding='utf-8')
    cache = stage / '.godot'
    cache.mkdir(exist_ok=True)
    imported = cache / 'imported'
    if not imported.exists():
        if os.name == 'nt':
            import _winapi
            _winapi.CreateJunction(str(root / '.godot/imported'), str(imported))
        else:
            imported.symlink_to(root / '.godot/imported', target_is_directory=True)
    for entry in (root / '.godot').iterdir():
        if entry.name in {'global_script_class_cache.cfg', 'uid_cache.bin'}:
            shutil.copyfile(entry, cache / entry.name)
    output = root / '.godot/decor-review' / args.area / args.label
    output.mkdir(parents=True, exist_ok=True)
    startup = None
    if os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    if args.batch:
        # Windows limits command lines to 32 KB; tile batches are often larger.
        # Read the structured batch from disk in Godot instead of inlining JSON.
        runner = root / '.godot/scene_batch_file_runner.gd'
        runner.write_text('''extends SceneTree
func _initialize() -> void:
    call_deferred("run_batch")
func run_batch() -> void:
    var arguments: PackedStringArray = OS.get_cmdline_user_args()
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
    if not data is Dictionary:
        push_error("Invalid scene batch JSON")
        quit(1)
        return
    var operation: RefCounted = load(arguments[1]).new()
    await operation.execute(data)
    var utilities: Script = load(arguments[2])
    quit(1 if utilities.had_errors else 0)
''', encoding='utf-8')
        result = subprocess.run([args.godot, '--headless', '--path', str(stage), '--script',
                                 str(runner), '--', str(Path(args.batch).resolve()),
                                 str(root / '.agents/skills/godot/scripts/scene/scene_batch.gd'),
                                 str(root / '.agents/skills/godot/scripts/core/utils.gd')], capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=90, startupinfo=startup)
        (output / 'batch.log').write_text(result.stdout + result.stderr, encoding='utf-8')
        if result.returncode or 'ERROR:' in result.stdout + result.stderr:
            print((result.stdout + result.stderr)[-5000:])
            return 1
    result = subprocess.run([args.godot, '--path', str(stage), '--rendering-method', 'gl_compatibility',
                             '--resolution', '1536x1024', '--script', 'res://tests/support/coop_decor_capture.gd',
                             '--', '--output=' + str(output), '--area=' + args.area], capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=90, startupinfo=startup)
    log = result.stdout + result.stderr
    (output / 'engine.log').write_text(log, encoding='utf-8')
    print(log[-2500:])
    return result.returncode or int('SCRIPT ERROR:' in log or '\nERROR:' in log)


if __name__ == '__main__':
    raise SystemExit(main())
