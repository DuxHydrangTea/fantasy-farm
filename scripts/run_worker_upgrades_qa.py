"""Run bounded worker upgrade regressions and optional save-isolated rendered QA."""
import argparse
import json
import os
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", default=".godot/worker-upgrades-qa")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--profile", action="store_true", help="Also benchmark a read-only copy of local primary/backup")
    parser.add_argument("--groups", help="Comma-separated regression groups; use none for rendered QA only")
    parser.add_argument("--extended", action="store_true", help="Include older general world-persistence fixtures")
    args = parser.parse_args()
    # The Windows console launcher spawns a child. Run the engine directly so a
    # timeout terminates the actual QA process and leaves no renderer behind.
    executable = Path(args.godot)
    if executable.name.endswith("_console.exe"):
        direct = executable.with_name(executable.name.removesuffix("_console.exe") + ".exe")
        if direct.exists():
            args.godot = str(direct)
    root = Path(__file__).resolve().parents[1]
    output = (root / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    groups = {
        "upgrades": ["integration/test_worker_upgrades.gd", "integration/test_worker_ui.gd"],
        "workers": [f"integration/{name}.gd" for name in (
            "test_workers", "test_crop_team", "test_crop_automation", "test_worker_care_improvements",
            "test_worker_optimization", "test_worker_warehouse", "test_worker_stroll", "test_worker_m0")],
        "crop-policy": ["integration/test_crop_team.gd", "integration/test_crop_automation.gd"],
        "stroll": ["integration/test_worker_stroll.gd"],
        "storage-persistence": [f"integration/{name}.gd" for name in (
            "test_crop_quality", "test_farm_health_world", "test_persistence_bootstrap",
            "test_supply_storage_flow", "test_farming_area")]
            + ["unit/test_worker_performance.gd", "unit/test_save_repository.gd"],
        "storage-offline": ["integration/test_storage_offline_parity.gd"],
        "legacy-persistence": ["integration/test_world_persistence.gd"],
    }
    results = []

    def run(name, command, timeout):
        log_path = output / f"{name}.log"
        try:
            with log_path.open("w", encoding="utf-8") as log:
                completed = subprocess.run([args.godot, "--path", str(root), *command],
                                           stdout=log, stderr=subprocess.STDOUT, startupinfo=startup, timeout=timeout)
            text = log_path.read_text(encoding="utf-8", errors="replace")
            failed = completed.returncode != 0 or "SCRIPT ERROR:" in text or "[Failed]" in text
            if name not in groups:
                failed |= "\nERROR:" in text
            if name in groups:
                failed |= "All tests passed" not in text
            results.append({"name": name, "exit_code": completed.returncode, "ok": not failed, "log": str(log_path)})
        except subprocess.TimeoutExpired:
            results.append({"name": name, "exit_code": 124, "ok": False, "log": str(log_path)})
        print(json.dumps(results[-1]), flush=True)
        (output / "summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")

    for name, paths in groups.items():
        if name in ["crop-policy", "stroll"] and not args.groups:
            continue  # Already covered by the workers group in a full run.
        if name == "legacy-persistence" and not args.extended and not args.groups:
            continue
        if args.groups and name not in args.groups.split(","):
            continue
        for path in paths:
            if not (root / "tests" / path).exists():
                parser.error(f"Missing test: {path}")
        command = ["--headless", "-s", "addons/gut/gut_cmdln.gd", "-gconfig=",
                   "-gtest=" + ",".join("res://tests/" + path for path in paths), "-gexit"]
        if name == "storage-offline" and not args.extended:
            command.append("-gunit_test_name=test_all_roles_48h_single_jump")
        run(name, command, 360)
        if not results[-1]["ok"] and name in ["upgrades", "workers"]:
            return 1
    if args.render:
        run("ui-preview", ["res://tests/support/worker_upgrade_preview.tscn", "--", str(output)], 90)
        run("fixture-benchmark", ["res://tests/performance/worker_upgrades_benchmark.tscn", "--",
                                  str(output / "fixture-benchmark.json")], 360)
        if args.profile:
            run("profile-benchmark", ["res://tests/performance/worker_upgrades_benchmark.tscn", "--",
                                      str(output / "profile-benchmark.json"), "profile"], 360)
    return int(not all(result["ok"] for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
