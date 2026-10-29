"""Benchmark the current load path against a copied save, without player writes.

Example: python3 scripts/benchmark_offline_load.py --godot /path/to/godot \
  --save /path/to/profile_local.json --gaps 0,3600,55800 --repeats 3
"""
import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import statistics
import subprocess
import tempfile
import time
from pathlib import Path


def stage_project(root, stage):
    stage.mkdir()
    for source in root.iterdir():
        if source.name in {".git", ".godot", "project.godot", "output", "docs", "debug_saves"}:
            continue
        (stage / source.name).symlink_to(source, target_is_directory=source.is_dir())
    settings = (root / "project.godot").read_text(encoding="utf-8")
    settings = re.sub(r'^MCPRuntimeServer=.*\n', '', settings, flags=re.MULTILINE)
    (stage / "project.godot").write_text(settings, encoding="utf-8")
    cache = stage / ".godot"
    cache.mkdir()
    for name in ["global_script_class_cache.cfg", "uid_cache.bin"]:
        source = root / ".godot" / name
        if source.exists():
            shutil.copy2(source, cache / name)
    imported = root / ".godot" / "imported"
    if not imported.is_dir():
        raise RuntimeError("Import the project in Godot before running the benchmark")
    (cache / "imported").symlink_to(imported, target_is_directory=True)


def stage_reference_models(root, stage):
    """Use uncached scene algorithms as a same-timeline parity reference."""
    (stage / "components").unlink()
    shutil.copytree(root / "components", stage / "components")
    def original_function(path, name, following):
        source = subprocess.check_output(["git", "show", "HEAD:" + path], cwd=root, text=True)
        start = source.index("func " + name + "(")
        end = source.index("func " + following + "(", start)
        return source[start:end]
    path = "components/bees/apiary_system.gd"
    source = (stage / path).read_text()
    for name, following in [("_flowers", "_nearby_crops"), ("_assign", "advance")]:
        start = source.index("func " + name + "(")
        end = source.index("func " + following + "(", start)
        old_next = "effective_radius" if name == "_flowers" else "advance"
        source = source[:start] + original_function(path, name, old_next) + source[end:]
    start = source.index("func _nearby_crops(")
    end = source.index("func effective_radius(", start)
    source = source[:start] + """func _nearby_crops(_radius_squared: float) -> Array[Crop]:
	var result: Array[Crop] = []
	_crop_points.clear()
	for cell: Vector2i in farming.crop_cells():
		var crop: Crop = farming.get_crop(cell)
		if crop != null:
			result.append(crop)
			_crop_points[crop] = farming.farmland.to_global(farming.farmland.map_to_local(cell))
	return result

""" + source[end:]
    (stage / path).write_text(source)
    path = "components/trees/tree_plantation.gd"
    source = (stage / path).read_text()
    start = source.index("func advance(")
    end = source.index("func capture(", start)
    source = source[:start] + original_function(path, "advance", "capture") + source[end:]
    (stage / path).write_text(source)


def production_fingerprint(root):
    paths = set(subprocess.check_output(["git", "diff", "--name-only", "--", "components", "persistence", "world", "project.godot", "localization"], cwd=root, text=True).splitlines())
    paths.update(subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "--", "components", "persistence", "world", "project.godot", "localization"], cwd=root, text=True).splitlines())
    hashes = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in sorted(paths) if (root / path).is_file()}
    return {"production_files_sha256": hashes, "production_files_fingerprint": hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--save", type=Path, required=True)
    parser.add_argument("--gaps", default="0,3600,55800")
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--reference-models", action="store_true", help="Disable flower/spatial/tree caches using the original scene algorithms; retain the corrected timeline")
    parser.add_argument("--budget", type=int, default=32000, help="0 = synchronous reference; positive = async chunk budget in usec")
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--output", type=Path, default=Path("output/offline-load-benchmark"))
    args = parser.parse_args()
    gaps = [float(value) for value in args.gaps.split(",")]
    if args.repeats < 1 or any(not 0 <= value <= 315360000 for value in gaps):
        parser.error("Use positive repeats and finite gaps from 0 to 10 years")
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_bytes = args.save.read_bytes()
    envelope = json.loads(source_bytes)
    payload = json.loads(envelope["payload"])
    profile = payload["profile_id"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", profile):
        parser.error("Invalid profile identifier")
    source_hash = hashlib.sha256(source_bytes).hexdigest()
    code_diff = subprocess.check_output(["git", "diff", "--", "components", "persistence", "world", "project.godot"], cwd=root)
    manifest = {
        **production_fingerprint(root),
        "reference_models": args.reference_models,
        "fixture_sha256": source_hash, "fixture_bytes": len(source_bytes),
        "fixture_name": args.save.name, "platform": platform.platform(),
        "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "production_diff_sha256": hashlib.sha256(code_diff).hexdigest(),
        "engine": subprocess.check_output([args.godot, "--headless", "--version"], text=True).strip(),
        "cache_policy": "Fresh process; existing imported assets and OS cache reused; not a cold import benchmark",
        "measurement_scope": "load_game plus separately measured catalog and world setup; no native rendering; no save writes",
        "runs": [],
    }
    with tempfile.TemporaryDirectory(prefix="offline-load-benchmark-") as temporary:
        work = Path(temporary)
        stage = work / "project"
        stage_project(root, stage)
        if args.reference_models:
            stage_reference_models(root, stage)
        saves = work / "saves"
        saves.mkdir()
        source = saves / f"profile_{profile}.json"
        source.write_bytes(source_bytes)
        environment = {**os.environ, "XDG_DATA_HOME": str(work / "userdata")}
        for gap in gaps:
            for repeat in range(args.repeats):
                name = f"gap-{gap:g}-run-{repeat + 1}"
                result_path = output / f"{name}.json"
                # Never accept an old result left by a timed-out previous run.
                result_path.unlink(missing_ok=True)
                command = [args.godot, "--headless", "--path", str(stage),
                           "--script", "res://tests/support/offline_load_benchmark.gd", "--",
                           "--source", str(source), "--gap", str(gap), "--budget", str(args.budget), "--result", str(result_path)]
                began = time.monotonic()
                try:
                    run = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=args.timeout)
                    log = run.stdout + run.stderr
                    result = json.loads(result_path.read_text()) if result_path.exists() else {"ok": False, "error": "No result"}
                    result["exit_code"] = run.returncode
                    result["ok"] = bool(result.get("ok")) and run.returncode == 0 and "SCRIPT ERROR:" not in log and "\nERROR:" not in log
                except subprocess.TimeoutExpired as error:
                    log = (error.stdout or b"") + (error.stderr or b"")
                    log = log.decode("utf-8", errors="replace") if isinstance(log, bytes) else log
                    result = {"ok": False, "exit_code": 124, "error": "timeout", "gap_seconds": gap}
                result["process_wall_ms"] = (time.monotonic() - began) * 1000
                (output / f"{name}.log").write_text(log, encoding="utf-8")
                result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
                manifest["runs"].append({"file": result_path.name, **result})
                print(json.dumps({"run": name, "ok": result["ok"], "load_game_ms": result.get("load_game_ms"), "error": result.get("error")}), flush=True)
        manifest["copied_fixture_unchanged"] = hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
    manifest["original_fixture_unchanged"] = hashlib.sha256(args.save.read_bytes()).hexdigest() == source_hash
    manifest["summary"] = []
    for gap in gaps:
        samples = [run["load_game_ms"] for run in manifest["runs"] if run.get("ok") and run.get("gap_seconds") == gap]
        manifest["summary"].append({"gap_seconds": gap, "successful_runs": len(samples), "attempted_runs": args.repeats,
                                   "median_load_game_ms": statistics.median(samples) if samples else None,
                                   "min_load_game_ms": min(samples) if samples else None,
                                   "max_load_game_ms": max(samples) if samples else None,
                                   "p95_load_game_ms": None, "p95_note": "Not estimated; use an adequate native sample set for acceptance"})
    manifest["ok"] = all(run["ok"] for run in manifest["runs"]) and manifest["copied_fixture_unchanged"] and manifest["original_fixture_unchanged"]
    (output / "summary.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return 0 if manifest["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
