"""Run tree tests in an isolated cache and user-data folder, preserving real saves."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import sys
import json


def link_dir(source: Path, destination: Path) -> None:
    if os.name == "nt":
        import _winapi
        _winapi.CreateJunction(str(source), str(destination))
    else:
        destination.symlink_to(source, target_is_directory=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--suite", action="append", help="Project-relative test suite; repeat to run several.")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--offline-stress", choices=("48h", "7d", "all"),
                        help="Opt in to the large offline matrix only; retains the 240s timeout.")
    args = parser.parse_args()
    if args.offline_stress and (args.all or args.suite or args.preview or args.validate):
        parser.error("--offline-stress runs its own suite; do not combine it with other run modes")
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="farm-tree-tests-") as directory:
        scratch = Path(directory)
        for entry in root.iterdir():
            if entry.name.startswith(".") or entry.name == "project.godot":
                continue
            if entry.is_dir():
                link_dir(entry, scratch / entry.name)
            else:
                shutil.copyfile(entry, scratch / entry.name)
        settings = (root / "project.godot").read_text(encoding="utf-8")
        settings = "\n".join('TimeManager="*res://components/time_manager.gd"' if line.startswith("TimeManager=") else
                             'enabled=PackedStringArray()' if line.startswith("enabled=PackedStringArray") else line
                             for line in settings.splitlines() if not line.startswith("MCPRuntimeServer="))
        # Godot custom userdata is isolated even on Windows (XDG alone is insufficient).
        settings = settings.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + scratch.name + '"')
        (scratch / "project.godot").write_text(settings, encoding="utf-8")
        cache = scratch / ".godot"
        cache.mkdir()
        link_dir(root / ".godot/imported", cache / "imported")
        for entry in (root / ".godot").iterdir():
            if entry.is_file():
                shutil.copyfile(entry, cache / entry.name)
        command = [args.godot, "--headless", "--path", str(scratch), "--log-file", str(scratch / "godot.log")]
        imported = subprocess.run(command + ["--editor", "--import"], timeout=240, check=False, capture_output=True, text=True)
        if imported.returncode:
            print(imported.stdout, imported.stderr)
            return imported.returncode
        if args.validate:
            statuses = []
            for folder in ["components/trees", "trees"]:
                checked = subprocess.run([sys.executable, "-B", str(root / ".agents/skills/godot/scripts/debug/validate_project.py"), str(scratch), "--project-subpath", folder, "--godot-bin", args.godot], timeout=240, check=False, capture_output=True, text=True, encoding="utf-8")
                report = json.loads(checked.stdout)
                feature_diagnostics = [row for row in report["diagnostics"] if any(fragment in row.get("file", "") for fragment in ["components/trees/", "tree_definition.gd", "tree_save_schema.gd"])]
                ok = report["ok"] and not feature_diagnostics
                print(json.dumps({"scope":folder, "ok":ok, "checked":report["static"]["checked"], "counts":report["counts"], "feature_diagnostics":feature_diagnostics}))
                statuses.append(not ok)
            return int(any(statuses))
        if args.preview:
            preview = [args.godot, "--path", str(scratch), "--rendering-method", "gl_compatibility", "--resolution", "1920x1080", "res://tests/support/tree_preview.tscn"]
            startup = None
            if os.name == "nt":
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = 0
            result = subprocess.run(preview, timeout=45, check=False, startupinfo=startup)
            for name in ["tree-preview.png", "fruit-atlas-preview.png"]:
                if (cache / name).exists():
                    shutil.copyfile(cache / name, root / ".godot" / name)
            return result.returncode
        suites = args.suite or ["tests/unit/test_trees.gd", "tests/integration/test_tree_plantation.gd"]
        if args.offline_stress:
            suites = ["tests/integration/test_storage_offline_parity.gd"]
        tests = ["-gdir=res://tests/unit,res://tests/integration", "-ginclude_subdirs"] if args.all else ["-gtest=" + ",".join("res://" + p for p in suites)]
        if args.offline_stress:
            selection = {"48h": "matrix_large_48_hours", "7d": "matrix_large_7_days", "all": "matrix_large"}
            tests.append("-gunit_test_name=" + selection[args.offline_stress])
        run_env = os.environ.copy()
        # A parent shell's stress preference must not change a regression run.
        run_env["FARM_OFFLINE_STRESS"] = args.offline_stress or ""
        try:
            result = subprocess.run(command + ["--fixed-fps", "60", "-s", "addons/gut/gut_cmdln.gd", "-gconfig=", "-gexit", "-gdisable_colors"] + tests, timeout=240, check=False, env=run_env)
        except subprocess.TimeoutExpired:
            print(json.dumps({"ok": False, "timed_out": True, "timeout_seconds": 240,
                              "offline_stress": args.offline_stress,
                              "note": "No parity result. Last T02_MATRIX_PHASE identifies the active phase."}), flush=True)
            return 124
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
