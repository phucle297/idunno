"""Public profiler CLI produces actual two-client traces, not a synthetic roster."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from tools.profile_multiplayer import authoritative_movement_summary, summarize

ROOT = Path(__file__).resolve().parents[1]
# Driver dependency for the staged test selector: tools/profile_multiplayer_peer.gd


class MultiplayerProfileContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = os.environ.get("GODOT_BIN") or shutil.which("godot")
        if not cls.engine:
            raise RuntimeError("Godot4.7.2 is required for the real-client contract")
        # Either integration test may run first in a fresh staged checkout.
        if not (ROOT / ".godot/global_script_class_cache.cfg").exists():
            imported = subprocess.run([cls.engine, "--headless", "--editor", "--path", str(ROOT), "--quit"],
                                      capture_output=True, text=True, timeout=120)
            output = imported.stdout + imported.stderr
            if imported.returncode or any(line.startswith(("SCRIPT ERROR:", "ERROR:")) for line in output.splitlines()):
                raise RuntimeError(output)

    def test_summary_keeps_temporal_order_and_uses_elapsed_time(self):
        rows = [dict(frame_ms=value, physics_ticks=1, match_sequence=index,
                     ack_sequence=index * 2) for index, value in enumerate([10, 50, 20, 100])]
        summary = summarize({"samples": rows})
        self.assertEqual([row["frame_ms"] for row in rows], [10, 50, 20, 100])
        self.assertEqual((summary["p50_ms"], summary["p95_ms"], summary["p99_ms"]), (20, 100, 100))
        self.assertAlmostEqual(summary["physics_ticks_per_s"], 4 / .18)
        self.assertEqual(summary["observed_ack_sequence_delta"], 6)
        self.assertEqual(summary["hitches_over_50ms"], 1)

    def test_authoritative_movement_summary_uses_server_positions(self):
        trace = {"samples": [
            {"authoritative_player_positions": {"2": [0, 0, 0]}},
            {"authoritative_player_positions": {"2": [1, 0, 0]}},
            {"authoritative_player_positions": {"2": [1, 0, 2]}},
        ]}
        movement = authoritative_movement_summary(trace, 2)
        self.assertEqual(movement["peer_id"], 2)
        self.assertEqual(movement["authoritative_travel_m"], 3)
        self.assertEqual(movement["authoritative_max_displacement_m"], 5 ** .5)

    def test_two_real_clients_repeat_without_stale_results(self):
        engine = self.engine
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "results"
            completed = subprocess.run([sys.executable, "tools/profile_multiplayer.py", "--engine", engine,
                "--renderers", "0", "--output", str(output), "--warmup", "2", "--samples", "24",
                "--repeats", "2", "--fps", "60", "--timeout", "30"], cwd=ROOT, capture_output=True, text=True, timeout=120)
            diagnostics = completed.stdout + completed.stderr
            for log in output.glob("*.log"):
                diagnostics += log.read_text()
            self.assertEqual(completed.returncode, 0, diagnostics)
            self.assertIn("MULTIPLAYER_PROFILE_OK", completed.stdout)
            summaries = json.loads((output / "summary.json").read_text())
            self.assertEqual(len(summaries), 6)
            for repeat in range(2):
                for peer in ["client-0", "client-1", "server"]:
                    trace = json.loads((output / f"{repeat}-{peer}.json").read_text())
                    rows = trace["samples"]
                    self.assertEqual(len(rows), 24)
                    self.assertEqual(trace["fps_cap"], 0 if peer == "server" else 60)
                    self.assertFalse(trace["moving_client_input"])
                    self.assertTrue(all(row["state"] == 1 and row["players"] == 2 for row in rows))
                    self.assertTrue(all(a["time_usec"] < b["time_usec"] for a, b in zip(rows, rows[1:])))
                    self.assertGreater(rows[-1]["match_sequence"], rows[0]["match_sequence"])
                    if peer != "server":
                        self.assertGreater(rows[-1]["ack_sequence"], rows[0]["ack_sequence"])

    def test_two_real_clients_moving_client_changes_authoritative_position(self):
        engine = self.engine
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "results"
            completed = subprocess.run([sys.executable, "tools/profile_multiplayer.py", "--engine", engine,
                "--renderers", "0", "--output", str(output), "--warmup", "2", "--samples", "90",
                "--repeats", "1", "--fps", "60", "--timeout", "30", "--moving-client"],
                cwd=ROOT, capture_output=True, text=True, timeout=120)
            diagnostics = completed.stdout + completed.stderr
            for log in output.glob("*.log"):
                diagnostics += log.read_text()
            self.assertEqual(completed.returncode, 0, diagnostics)
            summaries = json.loads((output / "summary.json").read_text())
            movement = summaries[-1]["moving_client_authoritative"]
            self.assertGreater(movement["authoritative_max_displacement_m"], .5)
            client = json.loads((output / "0-client-0.json").read_text())
            self.assertTrue(client["moving_client_input"])
            self.assertTrue(all(row["observed_pending_input_count"] >= 0 for row in client["samples"]))


if __name__ == "__main__":
    unittest.main()
