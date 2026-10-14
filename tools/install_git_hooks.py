#!/usr/bin/env python3
"""Install repo-local hooks while preserving other configured hook stages."""
from pathlib import Path
import shutil
import subprocess


def install():
    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    common = subprocess.check_output(["git", "rev-parse", "--git-common-dir"], text=True).strip()
    hooks = Path(common).resolve() / "hooks"
    configured = subprocess.run(["git", "config", "--get", "core.hooksPath"], capture_output=True, text=True).stdout.strip()
    previous = Path(configured).expanduser().resolve() if configured else hooks
    source = root / ".githooks/pre-commit"
    destination = hooks / "pre-commit"
    for candidate in {previous / "pre-commit", destination}:
        if candidate.exists() and "# Disaster Party staged-test gate" not in candidate.read_text():
            raise SystemExit(f"Existing pre-commit hook at {candidate}; integrate it explicitly before installation.")
    hooks.mkdir(parents=True, exist_ok=True)
    if previous != hooks and previous.is_dir():
        for hook in previous.iterdir():
            target = hooks / hook.name
            if hook.is_file() and not target.exists() and not target.is_symlink():
                shutil.copy2(hook, target)
    shutil.copy2(source, destination)
    subprocess.run(["git", "config", "--local", "core.hooksPath", str(hooks)], check=True)
    print(f"GIT_HOOKS_INSTALLED pre-commit={source}")


if __name__ == "__main__":
    install()
