"""Run native grass checks in the isolated Web staging project, never personal saves.

Prepare staging with scripts/build_web.py first. Probes use real GPU rendering;
headless mode cannot verify these pixels. Windows child windows remain hidden.
"""
from pathlib import Path
import argparse
import json
import os
import subprocess


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--phase", choices=["g1", "g2", "g3", "g4"], default="g1")
    parser.add_argument("--checks-only", action="store_true")
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument("--output", default=".godot/grass-g1-results")
    args = parser.parse_args()
    if args.checks_only and args.baseline_only:
        parser.error("Choose at most one of --checks-only / --baseline-only")
    if args.phase != "g1" and (args.checks_only or args.baseline_only):
        parser.error("G2-G4 run combined checks and benchmark; these flags apply to G1")
    root = Path(__file__).resolve().parents[2]
    stage = root / ".godot/web-stage"
    settings_file = stage / "project.godot"
    if not settings_file.exists():
        parser.error("Run scripts/build_web.py --godot ENGINE first to prepare isolated staging")
    settings = settings_file.read_text(encoding="utf-8")
    if ('config/use_custom_user_dir=true' not in settings or
            'config/custom_user_dir_name="fantasy-farm-web-preview"' not in settings or
            'MCPRuntimeServer=' in settings):
        parser.error("Staging isolation differs from build_web.py; refusing to run")
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    results = []
    for backend, folder in [("gl_compatibility", "compatibility"), ("forward_plus", "forward-plus")]:
        target = output / folder
        target.mkdir(parents=True, exist_ok=True)
        cases = ["probe"] if args.checks_only else ["baseline"] if args.baseline_only else ["probe", "baseline"]
        if args.phase == "g2":
            cases = ["chunks_probe"]
        elif args.phase == "g3":
            cases = ["interactions_probe"]
        elif args.phase == "g4":
            cases = ["farm_probe"]
        for case in cases:
            command = [args.godot, "--path", str(stage), "--rendering-method", backend,
                       "--log-file", str(target / (case + "-engine.log")),
                       "res://tests/support/grass_gpu_" + case + ".tscn", "--", str(target)]
            try:
                result = subprocess.run(command, startupinfo=startup, timeout=120, capture_output=True,
                                        text=True, encoding="utf-8", errors="replace", check=False)
                log = result.stdout + result.stderr
                status = result.returncode
                if status == 0 and ("SCRIPT ERROR:" in log or "\nERROR:" in log):
                    status = 1
            except subprocess.TimeoutExpired as error:
                log = "Timed out: " + str(error)
                status = 124
            (target / (case + "-stdout.log")).write_text(log, encoding="utf-8")
            record = {"renderer": backend, "case": case, "exit_code": status}
            results.append(record)
            print(json.dumps(record), flush=True)
            if status:
                print(log[-4000:], flush=True)
    (output / "run-summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    return int(any(record["exit_code"] for record in results))


if __name__ == "__main__":
    raise SystemExit(main())
