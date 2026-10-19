#!/usr/bin/env python3
"""Run animal GUT tests in an isolated project, without starting another MCP server.

Usage: python3 tests/run_animal_tests.py --godot /path/to/godot
The source/assets are shared read-only by symlink; the test project, engine cache,
user data and logs live in a temporary directory. The editor project is untouched.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--all", action="store_true", help="Run every configured GUT suite.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="farm-animal-tests-") as scratch:
        project = Path(scratch)
        for entry in root.iterdir():
            if entry.name.startswith(".") or entry.name == "project.godot":
                continue
            (project / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
        settings = (root / "project.godot").read_text()
        settings = "\n".join(line for line in settings.splitlines() if not line.startswith("MCPRuntimeServer="))
        # Resolve the autoload independently of an editor's UID cache.
        settings = "\n".join('TimeManager="*res://components/time_manager.gd"' if line.startswith("TimeManager=") else line for line in settings.splitlines())
        (project / "project.godot").write_text(settings + "\n")
        cache = project / ".godot"
        cache.mkdir()
        for entry in (root / ".godot").iterdir():
            if entry.is_file():
                shutil.copyfile(entry, cache / entry.name)
        (cache / "imported").symlink_to(root / ".godot/imported", target_is_directory=True)
        command = [args.godot, "--headless", "--path", str(project), "--log-file", str(project / "godot.log"),
                   "--fixed-fps", "60", "-s", "addons/gut/gut_cmdln.gd", "-gconfig=", "-gexit", "-gdisable_colors"]
        if args.all:
            command += ["-gdir=res://tests/unit,res://tests/integration", "-ginclude_subdirs"]
        else:
            suites = ["unit/test_animal_needs.gd", "unit/test_animal_pen.gd", "unit/test_animal_trough.gd",
                      "unit/test_animal_growth.gd", "unit/test_animal_production.gd", "unit/test_inventory.gd",
                      "integration/test_animals.gd", "integration/test_animal_behaviour.gd", "integration/test_animal_feeding.gd",
                      "integration/test_animal_lifecycle.gd", "integration/test_item_pickup.gd",
                      "integration/test_barn_animals.gd",
                      "integration/test_waterfowl.gd",
                      "unit/test_trough_refilling.gd", "integration/test_trough_interaction.gd"]
            command += ["-gtest=" + ",".join("res://tests/" + suite for suite in suites)]
        environment = dict(os.environ, XDG_DATA_HOME=str(project / "user-data"), XDG_CONFIG_HOME=str(project / "config"))
        result = subprocess.run(command, env=environment, timeout=180, check=False)
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
