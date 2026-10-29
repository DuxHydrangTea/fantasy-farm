"""Run the real boot/loading/save flow using an isolated copy of a player save."""
import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from benchmark_offline_load import stage_project


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--save', required=True, type=Path)
    parser.add_argument('--gap', type=float, default=55800)
    parser.add_argument('--always-on-top', action='store_true', help='Keep the QA window visible; record this separately from ordinary native runs')
    parser.add_argument('--resolution', default='960x540')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    original = args.save.read_bytes()
    data = json.loads(json.loads(original)['payload'])
    profile = data['profile_id']
    if not re.fullmatch(r'[A-Za-z0-9_-]+', profile):
        parser.error('Invalid profile identifier')
    with tempfile.TemporaryDirectory(prefix='offline-startup-') as temporary:
        work = Path(temporary)
        stage = work / 'project'
        stage_project(root, stage)
        settings = (stage / 'project.godot').read_text()
        settings = settings.replace('Language="*res://components/language_settings.gd"', 'Language="*res://components/language_settings.gd"\nStartupProbe="*res://tests/support/startup_load_probe.gd"')
        (stage / 'project.godot').write_text(settings)
        saves = work / 'userdata/godot/app_userdata/fantasy-farm/saves'
        saves.mkdir(parents=True)
        copy = saves / f'profile_{profile}.json'
        copy.write_bytes(original)
        result_file = output / 'startup.json'
        result_file.unlink(missing_ok=True)
        command = [args.godot, '--path', str(stage), '--audio-driver', 'Dummy', '--resolution', args.resolution]
        if args.always_on_top:
            command.append('--always-on-top')
        if args.headless:
            command.append('--headless')
        command += ['--', '--target', str(float(data['saved_at']) + args.gap), '--result', str(result_file)]
        result = subprocess.run(command, env={**os.environ, 'XDG_DATA_HOME': str(work / 'userdata')}, capture_output=True, text=True, timeout=600)
        log = result.stdout + result.stderr
        (output / 'startup.log').write_text(log)
        report = json.loads(result_file.read_text()) if result_file.exists() else {'ok': False, 'error': 'No startup result'}
        report.update(topmost_requested=args.always_on_top, gap_seconds=args.gap, exit_code=result.returncode, source_sha256=hashlib.sha256(original).hexdigest(),
                      original_unchanged=args.save.read_bytes() == original, isolated_copy_unchanged=copy.read_bytes() == original)
        report['ok'] = bool(report.get('ok')) and result.returncode == 0 and 'SCRIPT ERROR:' not in log and '\nERROR:' not in log and report['original_unchanged'] and report['isolated_copy_unchanged']
        result_file.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(report, ensure_ascii=False))
        return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
