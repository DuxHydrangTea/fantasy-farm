"""Build Web with a standard Godot editor, without editor plugins or real saves.

Usage: python scripts/build_web.py --godot /path/to/standard/godot
The source project settings are never rewritten. Output defaults to .dist/.
"""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess


def link_directory(source: Path, target: Path) -> None:
    if target.exists():
        if target.resolve() != source.resolve():
            raise RuntimeError(f"Staging path belongs to another source: {target}")
        return
    if os.name == "nt":
        import _winapi
        _winapi.CreateJunction(str(source), str(target))
    else:
        target.symlink_to(source, target_is_directory=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Standard Godot 4.x executable (not Mono/.NET)")
    parser.add_argument("--output", default=".dist", help="Build directory, relative to project or absolute")
    parser.add_argument("--debug", action="store_true", help="Debug export; default is release")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = root / ".godot/web-stage"
    stage.mkdir(parents=True, exist_ok=True)
    output = Path(args.output)
    if not output.is_absolute():
        output = root / output
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if "mono" in version.lower():
        parser.error("Web needs the standard Godot editor, not the Mono/.NET editor.")

    # Preserve all runtime resources, including catalogs loaded by directory scans.
    for entry in root.iterdir():
        if entry.name.startswith(".") or entry.name in {"docs", "export_templates", "feature_profiles", "script_templates"}:
            continue
        if entry.is_dir():
            link_directory(entry, stage / entry.name)
        elif entry.name not in {"project.godot", "export_presets.cfg"}:
            shutil.copyfile(entry, stage / entry.name)
    settings = (root / "project.godot").read_text(encoding="utf-8")
    settings = "\n".join(line for line in settings.splitlines() if not line.startswith("MCPRuntimeServer="))
    settings = re.sub(r"(?m)^TimeManager=.*$", 'TimeManager="*res://components/time_manager.gd"', settings)
    settings = re.sub(r"(?m)^enabled=PackedStringArray\(.*\)$", "enabled=PackedStringArray()", settings)
    settings = re.sub(r"(?m)^window/stretch/aspect=.*\n?", "", settings)
    settings = settings.replace('[display]', '[display]\nwindow/stretch/aspect="expand"', 1)
    # Avoid renderer fallback warnings in the browser; desktop settings stay intact.
    if "[rendering]" not in settings:
        settings += "\n[rendering]\n"
    settings = re.sub(r'(?m)^renderer/rendering_method(?:\.mobile)?=.*\n?', '', settings)
    settings = settings.replace("[rendering]", '[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"', 1)
    # Native staging previews must never bind the user's desktop save directory.
    settings = settings.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="fantasy-farm-web-preview"', 1)
    (stage / "project.godot").write_text(settings + "\n", encoding="utf-8")
    shutil.copyfile(root / "export_presets.cfg", stage / "export_presets.cfg")

    cache = stage / ".godot"
    cache.mkdir(exist_ok=True)
    imported = root / ".godot/imported"
    if imported.exists():
        link_directory(imported, cache / "imported")
    for entry in (root / ".godot").iterdir():
        if entry.is_file():
            shutil.copyfile(entry, cache / entry.name)

    log_path = root / ".godot/web-build.log"
    command = [args.godot, "--headless", "--path", str(stage), "--export-debug" if args.debug else "--export-release", "Web", str(output / "index.html")]
    print("Building", version, "->", output, flush=True)
    with log_path.open("w", encoding="utf-8") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600)
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    failures = [line for line in log_text.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
    files = {name: (output / name).stat().st_size for name in ["index.html", "index.js", "index.wasm", "index.pck"] if (output / name).exists()}
    ok = result.returncode == 0 and not failures and len(files) == 4
    report = {"ok": ok, "engine": version, "output": str(output), "log": str(log_path), "files": files, "errors": failures}
    (output / "build-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2), flush=True)
    if not ok:
        print(log_text[-8000:])
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
