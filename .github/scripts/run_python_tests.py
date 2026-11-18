#!/usr/bin/env python3
"""Run tests/test_*.py, split by the repo flake list (tests/FLAKY.md).

blocking: every collected Python test except listed Python ids (required job).
flaky: only the listed Python ids (visible non-blocking job).

Godot suite names (tests/<name>.gd) in the list are ignored here; the
Godot runner handles them. Removing an entry from the list makes that
test blocking again. Nothing is skipped or deleted.
"""
from __future__ import annotations

import argparse
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLAKE_LIST = ROOT / "tests" / "FLAKY.md"


def listed_ids() -> list[str]:
    if not FLAKE_LIST.is_file():
        return []
    ids: list[str] = []
    for raw in FLAKE_LIST.read_text(encoding="utf-8").splitlines():
        line = raw.strip().lstrip("- ").strip().strip("`")
        if not line or line.startswith("#"):
            continue
        if "test_" in line and " " not in line:
            ids.append(line)
    return ids


def classify(entry: str) -> str:
    if (ROOT / "tests" / f"{entry}.gd").is_file():
        return "godot"
    if "." in entry:
        return "python"
    return "unknown"


def walk(suite: unittest.TestSuite):
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from walk(item)
        else:
            yield item


def matches(test_id: str, entry: str) -> bool:
    return test_id == entry or test_id.endswith("." + entry)


def classified_ids() -> tuple[list[str], list[str], list[str]]:
    python_ids: list[str] = []
    godot_ids: list[str] = []
    unknown: list[str] = []
    for entry in listed_ids():
        kind = classify(entry)
        if kind == "godot":
            godot_ids.append(entry)
        elif kind == "python":
            python_ids.append(entry)
        else:
            unknown.append(entry)
    return python_ids, godot_ids, unknown


def main() -> int:
    os.chdir(ROOT)
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("blocking", "flaky"), default="blocking")
    parser.add_argument("--list", action="store_true", help="print selected Python ids and exit")
    parser.add_argument("--list-godot", action="store_true", help="print listed Godot suite names and exit")
    args = parser.parse_args()

    python_ids, godot_ids, unknown = classified_ids()
    if unknown:
        sys.stderr.write("ERROR: flake list entries are neither a tests/<name>.gd suite nor a Python id: %s\n" % unknown)
        return 2

    if args.list_godot:
        for name in godot_ids:
            print(name)
        return 0

    collected = list(walk(unittest.TestLoader().discover("tests", pattern="test_*.py")))
    unmatched = [entry for entry in python_ids if not any(matches(test.id(), entry) for test in collected)]
    if unmatched:
        sys.stderr.write("ERROR: flake list Python entries matched no collected test: %s\n" % unmatched)
        sys.stderr.write("collected: %s\n" % [test.id() for test in collected])
        return 2

    want_flaky = args.mode == "flaky"
    selected = [test for test in collected if any(matches(test.id(), entry) for entry in python_ids) == want_flaky]
    print("MODE=%s selected=%d collected=%d flake_python=%d flake_godot=%d" % (
        args.mode, len(selected), len(collected), len(python_ids), len(godot_ids)))
    if args.list:
        for test in selected:
            print(test.id())
        return 0
    if not selected:
        print("No tests in this mode; OK")
        return 0
    suite = unittest.TestSuite()
    suite.addTests(selected)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
