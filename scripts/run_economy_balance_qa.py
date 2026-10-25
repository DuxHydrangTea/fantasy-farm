"""Run native economy balance UI/input QA in the save-isolated Web staging project."""
import argparse
import json
import os
import subprocess
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', default='.godot/balance-native')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = root / '.godot/web-stage'
    settings = (stage / 'project.godot').read_text(encoding='utf-8')
    if 'config/custom_user_dir_name="fantasy-farm-web-preview"' not in settings or 'MCPRuntimeServer=' in settings:
        parser.error('Prepare isolated staging with scripts/build_web.py first')
    output = Path(args.output).resolve()
    startup = None
    if os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    results = []
    for renderer, folder in [('gl_compatibility', 'compatibility'), ('forward_plus', 'forward-plus')]:
        target = output / folder
        target.mkdir(parents=True, exist_ok=True)
        command = [args.godot, '--path', str(stage), '--rendering-method', renderer, '--log-file', str(target/'engine.log'),
                   'res://tests/support/economy_balance_probe.tscn', '--', str(target)]
        try:
            run = subprocess.run(command, startupinfo=startup, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=150)
            log = run.stdout + run.stderr
            code = run.returncode or int('SCRIPT ERROR:' in log or '\nERROR:' in log)
        except subprocess.TimeoutExpired as error:
            code, log = 124, str(error)
        (target/'stdout.log').write_text(log, encoding='utf-8')
        results.append({'renderer': renderer, 'exit_code': code})
        print(json.dumps(results[-1]), flush=True)
        if code:
            print(log[-5000:], flush=True)
    (output/'run-summary.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    return int(any(item['exit_code'] for item in results))

if __name__ == '__main__':
    raise SystemExit(main())
