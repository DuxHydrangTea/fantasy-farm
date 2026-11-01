"""Build a read-only-resource staging fixture with worker code from a git ref.

Never checks out or edits the working project. Used to compare rendered worker
performance with the same diagnostic harness and imported assets.
"""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = root / ".godot/worker-baseline"
    stage.mkdir(parents=True, exist_ok=True)
    for entry in root.iterdir():
        if not entry.is_dir() or entry.name.startswith(".") or entry.name in {"docs", "export_templates"}:
            continue
        target = stage / entry.name
        if entry.name in {"components", "tests"}:
            if target.is_symlink() or target.is_junction():
                raise RuntimeError(f"Expected an independent fixture directory: {target}")
            shutil.copytree(entry, target, dirs_exist_ok=True)
        elif not target.exists():
            if os.name == "nt":
                import _winapi
                _winapi.CreateJunction(str(entry), str(target))
            else:
                target.symlink_to(entry, target_is_directory=True)
    paths = [f"components/workers/{name}.gd" for name in (
        "worker_service", "worker_world_bridge", "crop_worker_policy", "worker_behaviour_component")]
    for path in paths:
        content = subprocess.check_output(["git", "show", f"{args.ref}:{path}"], cwd=root)
        (stage / path).write_bytes(content)
    source = root / ".godot/web-stage"
    shutil.copyfile(source / "project.godot", stage / "project.godot")
    shutil.copyfile(root / "icon.svg", stage / "icon.svg")
    cache = stage / ".godot"
    cache.mkdir(exist_ok=True)
    for entry in (source / ".godot").iterdir():
        if entry.is_file():
            shutil.copyfile(entry, cache / entry.name)
    imported = cache / "imported"
    if not imported.exists():
        if os.name == "nt":
            import _winapi
            _winapi.CreateJunction(str(root / ".godot/imported"), str(imported))
        else:
            imported.symlink_to(root / ".godot/imported", target_is_directory=True)
    revision = subprocess.check_output(["git", "rev-parse", args.ref], cwd=root, text=True).strip()
    report = {"stage": str(stage), "worker_revision": revision, "restored_paths": paths}
    (stage / "baseline.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
