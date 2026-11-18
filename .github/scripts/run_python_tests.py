#!/usr/bin/env python3
"""Run tests/test_*.py, split by the repo flake list (tests/FLAKY.md).

blocking: every collected test except listed ids (required job).
flaky: only the listed ids (visible non-blocking job).

Removing an entry from the list makes that test blocking again.
Nothing is skipped or deleted.
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


def walk(suite: unittest.TestSuite):
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from walk(item)
        else:
            yield item


def matches(test_id: str, entry: str) -> bool:
    return test_id == entry or test_id.endswith("." + entry)


def main() -> int:
    os.chdir(ROOT)
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("blocking", "flaky"), default="blocking")
    parser.add_argument("--list", action="store_true", help="print selected ids and exit")
    args = parser.parse_args()

    flake_ids = listed_ids()
    collected = list(walk(unittest.TestLoader().discover("tests", pattern="test_*.py")))
    unmatched = [entry for entry in flake_ids if not any(matches(test.id(), entry) for test in collected)]
    if unmatched:
        sys.stderr.write("ERROR: flake list entries matched no collected test: %s\n" % unmatched)
        sys.stderr.write("collected: %s\n" % [test.id() for test in collected])
        return 2

    want_flaky = args.mode == "flaky"
    selected = [test for test in collected if any(matches(test.id(), entry) for entry in flake_ids) == want_flaky]
    print("MODE=%s selected=%d collected=%d flake_list=%d" % (
        args.mode, len(selected), len(collected), len(flake_ids)))
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
