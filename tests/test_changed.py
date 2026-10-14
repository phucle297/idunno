"""Changed-test selection and actual staged-commit gate contract."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tools.test_changed import select_tests


class ChangedTestContract(unittest.TestCase):
    def setUp(self):
        self.files = {
            "game/leaf.gd": "class_name Leaf\nextends Node\n",
            "game/shared.gd": 'extends Leaf\n',
            "scenes/shared.tscn": '[ext_resource path="res://game/shared.gd"]',
            "tests/test_leaf.gd": "var leaf: Leaf",
            "tests/test_scene.gd": 'load("res://scenes/shared.tscn")',
            "tests/test_other.gd": "extends SceneTree",
            "tests/network_authority_peer.gd": 'load("res://scenes/shared.tscn")',
            "tests/run_network_authority_test.sh": 'godot --script res://tests/network_authority_peer.gd',
            "tools/backend.py": "",
            "tests/test_backend.py": "from tools.backend import Server",
        }

    def test_transitive_resources_global_types_and_network_driver(self):
        selected, full = select_tests(self.files, ["game/leaf.gd"])
        self.assertFalse(full)
        self.assertEqual(set(selected), {"tests/test_leaf.gd", "tests/test_scene.gd", "tests/run_network_authority_test.sh"})

    def test_test_only_change_and_python_import(self):
        self.assertEqual(select_tests(self.files, ["tests/test_other.gd"]), (["tests/test_other.gd"], False))
        self.assertEqual(select_tests(self.files, ["tools/backend.py"]), (["tests/test_backend.py"], False))

    def test_docs_and_progress_skip(self):
        self.assertEqual(select_tests(self.files, ["README.md", "progress.json", "docs/plan.md"]), ([], False))

    def test_unknown_runtime_and_project_fall_back_even_with_known_change(self):
        for paths in [["game/dynamic.gd"], ["project.godot"], ["game/leaf.gd", "assets/new.glb"]]:
            selected, full = select_tests(self.files, paths)
            self.assertTrue(full)
            self.assertIn("tests/test_other.gd", selected)

    def test_real_hook_checks_index_not_unstaged_fix(self):
        source = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")

            def command(*args, check=True):
                return subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, check=check)

            command("git", "init", "-q")
            command("git", "config", "user.name", "Hook test")
            command("git", "config", "user.email", "hook@example.invalid")
            for name in [".githooks/pre-commit", "tools/install_git_hooks.py", "tools/test_changed.py"]:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / name, target)
            command("git", "add", ".")
            command("git", "commit", "-qm", "test: bootstrap")
            command("python3", "tools/install_git_hooks.py")
            command("python3", "tools/install_git_hooks.py")
            before = command("git", "rev-parse", "HEAD").stdout
            test = root / "tests/test_gate.py"
            test.parent.mkdir()
            failing = "import unittest\nclass Gate(unittest.TestCase):\n    def test_gate(self): self.assertTrue(False)\n"
            test.write_text(failing)
            command("git", "add", "tests/test_gate.py")
            test.write_text(failing.replace("False", "True"))
            blocked = command("git", "commit", "-qm", "test: must fail", check=False)
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn("PRE_COMMIT_FAILED", blocked.stdout + blocked.stderr)
            self.assertEqual(command("git", "rev-parse", "HEAD").stdout, before)
            command("git", "add", "tests/test_gate.py")
            accepted = command("git", "commit", "-qm", "test: passes")
            self.assertIn("PRE_COMMIT_OK", accepted.stdout + accepted.stderr)
            self.assertNotEqual(command("git", "rev-parse", "HEAD").stdout, before)


if __name__ == "__main__":
    unittest.main()
