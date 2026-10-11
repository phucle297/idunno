"""Run the shipped integrity check with native Windows PowerShell."""
import hashlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = shutil.which("powershell.exe")


@unittest.skipUnless(POWERSHELL and shutil.which("wslpath"), "WSL with native Windows PowerShell is required")
class WindowsPackageTest(unittest.TestCase):
    def test_integrity_check_rejects_incomplete_corrupt_and_unsafe_packages(self):
        # Windows-local path: PowerShell cannot use a WSL /tmp path directly.
        windows_temp = subprocess.check_output(
            [POWERSHELL, "-NoProfile", "-Command", "$env:TEMP"], text=True
        ).strip()
        local_temp = subprocess.check_output(["wslpath", "-u", windows_temp], text=True).strip()
        with tempfile.TemporaryDirectory(prefix="disaster-package-", dir=local_temp) as temp:
            folder = Path(temp)
            for name in ("Play.cmd", "Verify-Package.ps1"):
                shutil.copyfile(ROOT / "tools/windows" / name, folder / name)
            for name in ("DisasterParty.exe", "DisasterParty.pck", "BUILD.txt", "PLAYTEST.txt"):
                (folder / name).write_text("integrity fixture, not an executable\n")
            manifest = "".join(
                f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
                for path in sorted(folder.iterdir())
            )
            (folder / "SHA256SUMS.txt").write_text(manifest)
            script = subprocess.check_output(
                ["wslpath", "-w", str(folder / "Verify-Package.ps1")], text=True
            ).strip()

            def check():
                return subprocess.run(
                    [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script],
                    capture_output=True, text=True, timeout=30,
                )

            result = check()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("PACKAGE_INTEGRITY_OK", result.stdout)
            original = (folder / "DisasterParty.pck").read_bytes()
            (folder / "DisasterParty.pck").unlink()
            result = check()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Re-extract the complete ZIP", result.stdout + result.stderr)
            (folder / "DisasterParty.pck").write_bytes(original + b"corruption")
            result = check()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Checksum mismatch", result.stdout + result.stderr)
            (folder / "DisasterParty.pck").write_bytes(original)
            for bad_manifest in (manifest + manifest.splitlines()[0] + "\n",
                                 manifest.replace("  BUILD.txt", "  ../BUILD.txt"),
                                 "\n".join(manifest.splitlines()[1:])):
                (folder / "SHA256SUMS.txt").write_text(bad_manifest)
                result = check()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            (folder / "SHA256SUMS.txt").write_text(manifest)
            self.assertEqual(check().returncode, 0, "Restored package must allow retry")


if __name__ == "__main__":
    unittest.main()
