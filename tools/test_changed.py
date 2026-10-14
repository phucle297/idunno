#!/usr/bin/env python3
"""Run affected tests against a disposable snapshot of Git's staged tree."""
import argparse
from collections import deque
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

NETWORK = [
    "tests/run_network_authority_test.sh", "tests/run_four_client_match_test.sh",
    "tests/run_playable_scene_network_test.sh", "tests/run_playable_scale_test.sh",
    "tests/run_dedicated_network_test.sh", "tests/run_managed_scale_test.py",
]
FULL_TRIGGERS = {"project.godot", "tests/run_ui_regression.sh"}
RESOURCE_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".png", ".wav", ".ogg", ".glb"}


def select_tests(files, changed):
    """Conservative reverse dependencies: resources, global GDScript types, Python imports."""
    roots = sorted(p for p in files if p.startswith("tests/test_") and p.endswith((".gd", ".py")))
    roots += [p for p in NETWORK if p in files]
    classes = {}
    for path, source in files.items():
        match = re.search(r"^class_name\s+(\w+)", source, re.MULTILINE)
        if path.endswith(".gd") and match:
            classes[match[1]] = path
    reverse = {}
    for path, source in files.items():
        dependencies = set(re.findall(r'res://([^\s"\'\)]+)', source))
        # Shell/Python test drivers also use relative paths and Python modules.
        dependencies.update(candidate for candidate in files if candidate != path and candidate in source)
        for name, target in classes.items():
            if path.endswith(".gd") and re.search(r"\b" + re.escape(name) + r"\b", source):
                dependencies.add(target)
        if path.endswith(".py"):
            for module in re.findall(r"(?:from|import)\s+([\w.]+)", source):
                dependencies.add(module.replace(".", "/") + ".py")
        for dependency in dependencies:
            reverse.setdefault(dependency, set()).add(path)
    def dependents(paths):
        affected = set(paths)
        queue = deque(paths)
        while queue:
            for dependent in reverse.get(queue.popleft(), ()):
                if dependent not in affected:
                    affected.add(dependent)
                    queue.append(dependent)
        return affected

    affected = dependents(changed)
    selected = sorted(set(roots) & affected)
    if any(p.startswith(".githooks/") for p in changed) and "tests/test_changed.py" in files:
        selected = sorted(set(selected) | {"tests/test_changed.py"})
    runtime = [p for p in changed if p.startswith(("game/", "scenes/", "assets/")) or Path(p).suffix in RESOURCE_SUFFIXES and not p.startswith(("docs/", ".agents/"))]
    # Dynamic loading cannot be fully inferred. Never silently skip unrecognised
    # runtime changes or a change to a test driver shared by multiple suites.
    if set(changed) & FULL_TRIGGERS or any(p not in files or not set(roots) & dependents([p]) for p in runtime):
        return roots, True
    if any(p.startswith("tests/") and p.endswith(".sh") for p in changed):
        return roots, True
    return selected, False


def run(command, stage, env, godot=False):
    print("RUN " + " ".join(command), flush=True)
    result = subprocess.run(command, cwd=stage, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end="", flush=True)
    errors = [line for line in result.stdout.splitlines() if line.startswith(("SCRIPT ERROR:", "ERROR:"))
              and not re.fullmatch(r"ERROR: \d+ resources still in use at exit.*", line)]
    if result.returncode or godot and (errors or not re.search(r"_OK(?: |$)", result.stdout, re.MULTILINE)):
        raise SystemExit("PRE_COMMIT_FAILED: fix the staged changes before committing.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", action="store_true", help="Print selection without running tests")
    parser.add_argument("--full", action="store_true", help="Run all regression tests explicitly")
    args = parser.parse_args()
    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    changed = subprocess.check_output(["git", "diff", "--cached", "--name-only", "--no-renames", "-z"], cwd=root).decode().split("\0")
    changed = [p for p in changed if p]
    subprocess.run(["git", "diff", "--cached", "--check"], cwd=root, check=True)
    tree = subprocess.check_output(["git", "write-tree"], cwd=root, text=True).strip()
    with tempfile.TemporaryDirectory(prefix="disaster-commit-") as temporary:
        stage = Path(temporary)
        archive = stage / "index.tar"
        with archive.open("wb") as output:
            subprocess.run(["git", "archive", "--format=tar", tree], cwd=root, stdout=output, check=True)
        with tarfile.open(archive) as packed:
            packed.extractall(stage, filter="data")
        archive.unlink()
        files = {}
        for path in stage.rglob("*"):
            if path.is_file() and path.suffix in {".gd", ".tscn", ".tres", ".py", ".sh"}:
                files[path.relative_to(stage).as_posix()] = path.read_text(errors="replace")
        selected, full = select_tests(files, ["project.godot"] if args.full else changed)
        print(f"PRE_COMMIT_PLAN mode={'full' if full else 'affected'} tests={len(selected)} staged_files={len(changed)}", flush=True)
        for test in selected:
            print("  " + test, flush=True)
        if args.plan:
            return
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", PLAYER_COUNTS="4 8 20")
        # Tests may create their own Git fixtures; do not leak this commit's
        # repository/index location into those subprocesses.
        for key in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_PREFIX"]:
            env.pop(key, None)
        needs_godot = full or any(p.endswith((".gd", ".sh")) or p in {"tests/test_room_service.py", "tests/run_managed_scale_test.py"} for p in selected)
        engine = shutil.which(env.get("GODOT_BIN", "godot")) or env.get("GODOT_BIN")
        if needs_godot:
            if not engine:
                engine = str(root / ".tools/godot/Godot_v4.7.2-stable_linux.x86_64")
            if not Path(engine).is_file():
                raise SystemExit("Godot is required for affected tests. Install 4.7.2 or set GODOT_BIN.")
            engine = str(Path(engine).resolve())
            env["GODOT_BIN"] = engine
        if full:
            run(["bash", "tests/run_ui_regression.sh"], stage, env)
            run(["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], stage, env)
        else:
            if needs_godot:
                result = subprocess.run([engine, "--headless", "--editor", "--path", str(stage), "--quit"], env=env, capture_output=True, text=True)
                if result.returncode or re.search(r"^(SCRIPT ERROR|ERROR):", result.stdout + result.stderr, re.MULTILINE):
                    raise SystemExit(result.stdout + result.stderr)
            for test in selected:
                if test.endswith(".gd"):
                    run([engine, "--headless", "--path", str(stage), "--script", "res://" + test,
                         "--", "--settings-path=user://pre-commit-settings.cfg"], stage, env, godot=True)
                elif test.endswith(".sh"):
                    run(["bash", test], stage, env)
                elif Path(test).name.startswith("test_"):
                    run(["python3", "-m", "unittest", "discover", "-s", "tests", "-p", Path(test).name], stage, env)
                else:
                    run(["python3", test], stage, env)
            if "tests/test_pause_settings.gd" in selected:
                for mode in ["--save-for-restart", "--verify-restart"]:
                    run([engine, "--headless", "--path", str(stage), "--script", "res://tests/test_pause_settings.gd",
                         "--", "--settings-path=user://pre-commit-settings.cfg", mode], stage, env, godot=True)
        print("PRE_COMMIT_OK staged_tree=" + tree, flush=True)


if __name__ == "__main__":
    main()
