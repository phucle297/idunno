"""T25 AC3: every shipped wav is listed in assets/manifest.json.

Each assets/audio/**/*.wav must appear in exactly one audio_bundle whose
export_path is the wav's folder. Files the generators write must all ship.
EXCLUDED names a shipped wav deliberately left out of the manifest, with the
reason; it is empty today (all 17 are listed: 15 generated + 2 music).
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "manifest.json"
AUDIO = ROOT / "assets" / "audio"
GENERATOR = ROOT / "tools" / "audio_generation" / "generate_audio.gd"
MUSIC_GENERATOR = ROOT / "tools" / "audio_generation" / "generate_music.py"

# "assets/audio/<dir>/<name>.wav": "why it is not in the manifest"
EXCLUDED: dict[str, str] = {}


def _listed() -> dict[str, list[str]]:
    listed: dict[str, list[str]] = {}
    for asset in json.loads(MANIFEST.read_text())["assets"]:
        if asset.get("category") != "audio_bundle":
            continue
        folder = str(asset.get("export_path", "")).rstrip("/")
        for entry in asset.get("files", []):
            name = entry["name"] if isinstance(entry, dict) else entry
            listed.setdefault(f"{folder}/{name}", []).append(asset["asset_id"])
    return listed


class AudioManifestContract(unittest.TestCase):
    def test_every_shipped_wav_is_listed_or_explained(self):
        shipped = sorted(p.relative_to(ROOT).as_posix() for p in AUDIO.rglob("*.wav"))
        self.assertEqual(len(shipped), 17, shipped)
        listed = _listed()
        for path in shipped:
            with self.subTest(wav=path):
                if path in EXCLUDED:
                    self.assertTrue(EXCLUDED[path].strip(), f"{path}: exclusion needs a reason")
                    self.assertNotIn(path, listed)
                    continue
                self.assertEqual(len(listed.get(path, [])), 1, f"{path} must be listed in exactly one audio_bundle, got {listed.get(path)}")
        for path in listed:
            with self.subTest(listed=path):
                self.assertIn(path, shipped, f"manifest lists {path} but it does not ship")

    def test_generator_outputs_all_ship(self):
        body = GENERATOR.read_text().split("const SOUNDS := {", 1)[1].split("}", 1)[0]
        generated = {f"assets/audio/generated/{name}.wav" for name in re.findall(r'"([a-z_]+)"\s*:', body)}
        self.assertEqual(len(generated), 15)
        music = {f"assets/audio/music/{name}.wav" for name in re.findall(r'"name":\s*"([a-z_]+)"', MUSIC_GENERATOR.read_text())}
        self.assertEqual(len(music), 2, music)
        shipped = {p.relative_to(ROOT).as_posix() for p in AUDIO.rglob("*.wav")}
        self.assertEqual(generated | music, shipped)


if __name__ == "__main__":
    unittest.main()
