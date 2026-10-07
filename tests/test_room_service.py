"""Contract and actual Godot/ENet checks; no public network or Docker claims."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from tools.room_service import RoomService, Server, Rejected, normalize_id

ROOT = Path(__file__).resolve().parents[1]


def settings(**overrides):
    values = dict(godot=os.environ.get("GODOT_BIN", shutil.which("godot")), project=str(ROOT),
                  build="development", public_address="127.0.0.1", port_start=29820,
                  port_end=29823, rooms=4, players=2, token_ttl=20,
                  startup_timeout=12, heartbeat_timeout=10, empty_timeout=60)
    values.update(overrides)
    return SimpleNamespace(**values)


class Contract(unittest.TestCase):
    def setUp(self):
        self.service = RoomService(settings())
        self.addCleanup(self.service.close)
        self.room = {"id": "ALPHA", "key": "server-key", "port": 29820, "tokens": {},
                     "peers": {}, "joinable": True, "heartbeat": time.monotonic(),
                     "empty_since": time.monotonic(), "ready": threading.Event()}
        self.service.rooms["ALPHA"] = self.room
        # Pure admission fixtures have no child to stop.
        self.addCleanup(self.service.rooms.clear)

    def consume(self, token, **overrides):
        data = dict(room_id="ALPHA", key="server-key", peer=90, token=token)
        data.update(overrides)
        return self.service.internal("consume", data)

    def rejects(self, code, call):
        with self.assertRaises(Rejected) as error:
            call()
        self.assertEqual(error.exception.code, code)

    def test_normalization_and_version(self):
        self.assertEqual(normalize_id("  My-room42 "), "MY-ROOM42")
        for bad in ("ab", "a" * 25, "../evil", "abc;echo", "a b", [], 42):
            self.rejects("invalid_room_id", lambda: normalize_id(bad))
        for wrong in ({"protocol": 2, "build": "development"}, {"protocol": 1, "build": "old"}):
            self.rejects("incompatible_version", lambda: self.service.compatible(wrong))

    def test_bad_expired_replayed_and_wrong_room(self):
        token = self.service.issue(self.room)["token"]
        self.rejects("invalid_admission", lambda: self.consume("invalid"))
        other = dict(self.room, id="BRAVO", key="other-key", tokens={}, peers={})
        self.service.rooms["BRAVO"] = other
        self.rejects("invalid_admission", lambda: self.consume(token, room_id="BRAVO", key="other-key"))
        self.assertEqual(self.consume(token), {"ok": True})
        self.rejects("invalid_admission", lambda: self.consume(token, peer=8))
        token = self.service.issue(self.room)["token"]
        self.room["tokens"][hashlib.sha256(token.encode()).hexdigest()] = time.monotonic() - 0.001
        self.rejects("invalid_admission", lambda: self.consume(token, peer=8))
        self.rejects("invalid_server", lambda: self.consume(token, key="wrong"))

    def test_concurrent_reservations_and_stale_heartbeat(self):
        def issue(_):
            with self.service.lock:
                try:
                    return self.service.issue(self.room)
                except Rejected as error:
                    return error.code
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(issue, range(8)))
        issued = [result for result in results if isinstance(result, dict)]
        self.assertEqual(len(issued), 2)
        self.assertEqual(results.count("room_full"), 6)
        self.consume(issued[0]["token"])
        heartbeat = dict(room_id="ALPHA", key="server-key", peers=[], joinable=True)
        self.service.internal("heartbeat", heartbeat)
        self.assertIn(90, self.room["peers"], "Stale heartbeat must not release an in-flight admission")
        self.rejects("room_full", lambda: self.service.issue(self.room))
        heartbeat["peers"] = [90]
        self.service.internal("heartbeat", heartbeat)
        heartbeat["peers"] = []
        self.service.internal("heartbeat", heartbeat)
        self.assertNotIn(90, self.room["peers"])
        self.assertIn("token", self.service.issue(self.room))

    def test_expiry_match_state_and_rate_limit(self):
        token = self.service.issue(self.room)["token"]
        self.room["joinable"] = False
        self.rejects("invalid_admission", lambda: self.consume(token))
        for _ in range(30):
            self.service.rate_limit("127.0.0.1")
        self.rejects("rate_limited", lambda: self.service.rate_limit("127.0.0.1"))
        self.assertNotIn(token, repr(self.room))


class RealProcesses(unittest.TestCase):
    def setUp(self):
        self.service = RoomService(settings())
        self.server = Server(("127.0.0.1", 0), self.service)
        self.service.internal_url = f"http://127.0.0.1:{self.server.server_port}/internal/"
        self.worker = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.worker.start()
        self.addCleanup(self.stop)
        self.data = dict(protocol=1, build="development", room_id="Alpha", password="sample-password")

    def stop(self):
        self.server.shutdown()
        self.service.close()
        self.server.server_close()
        self.worker.join()

    def post(self, path, data, status=200):
        request = Request(f"http://127.0.0.1:{self.server.server_port}{path}",
                          data=json.dumps(data).encode(), headers={"Content-Type": "application/json"})
        try:
            response = urlopen(request, timeout=20)
        except HTTPError as error:
            response = error
        with response:
            self.assertEqual(response.status, status)
            return json.load(response)

    def peer(self, ticket, accepted=True, token=None):
        options = dict(ticket, accepted=accepted)
        if token is not None:
            options["token"] = token
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ticket.json"
            path.write_text(json.dumps(options))
            result = subprocess.run([self.service.args.godot, "--headless", "--path", str(ROOT),
                                     "--script", "res://tests/room_admission_peer.gd", "--",
                                     f"--admission-file={path}"], capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("ROOM_ADMISSION_PEER_OK", output)
        if "retry_token" in options:
            self.assertIn("ROOM_ADMISSION_RETRY_OK", output)
        if options.get("start"):
            self.assertIn("ROOM_ADMISSION_ACTIVE_OK", output)
        self.assertNotIn("SCRIPT ERROR", output)
        errors = [line for line in output.splitlines() if line.startswith("ERROR:") and "resources still in use at exit" not in line]
        self.assertEqual(errors, [], output)

    def test_http_and_real_enet_security(self):
        ticket = self.post("/v1/rooms/create", self.data)
        self.assertEqual(ticket["room_id"], "ALPHA")
        self.assertEqual((ticket["build"], ticket["protocol"]), ("development", 1))
        room = self.service.rooms["ALPHA"]
        self.assertEqual(room["config"].stat().st_mode & 0o777, 0o600)
        self.assertNotIn("sample-password", repr(room))
        self.assertEqual(self.post("/v1/rooms/create", self.data, 409)["error"], "duplicate_room_id")
        self.assertEqual(self.post("/v1/rooms/join", dict(self.data, password="bad"), 403)["error"], "bad_password")
        self.assertEqual(self.post("/v1/rooms/join", dict(self.data, build="old"), 409)["error"], "incompatible_version")
        self.assertEqual(self.post("/v1/rooms/join", dict(self.data, room_id="UNKNOWN"), 404)["error"], "unknown_room")
        self.post("/internal/consume", dict(room_id="ALPHA", key="wrong", peer=2, token=ticket["token"]), 403)
        self.peer(ticket, accepted=False, token="")  # Unrestricted direct-UDP bypass.
        self.peer(ticket, accepted=False, token="bad-token")
        self.peer(ticket)
        self.peer(ticket, accepted=False)  # Same token in a different actual ENet process.
        deadline = time.monotonic() + 4
        while room["peers"] and time.monotonic() < deadline:
            time.sleep(0.1)
        self.assertFalse(room["peers"], "Disconnect heartbeat must reclaim player capacity")
        expired = self.post("/v1/rooms/join", self.data)
        with self.service.lock:
            room["tokens"][hashlib.sha256(expired["token"].encode()).hexdigest()] = time.monotonic() - 1
        self.peer(expired, accepted=False)
        bravo = self.post("/v1/rooms/create", dict(self.data, room_id="BRAVO"))
        new = self.post("/v1/rooms/join", self.data)
        self.peer(dict(bravo, token=new["token"]), accepted=False)
        self.peer(new)  # Wrong-room rejection must not consume the valid ALPHA token.
        retry = self.post("/v1/rooms/join", self.data)
        self.peer(dict(retry, retry_token=retry["token"]), accepted=False, token="bad-token")

    def test_atomic_creation_capacity_crash_empty_and_shutdown(self):
        def create(_):
            try:
                return self.service.create(self.data)
            except Rejected as error:
                return error.code
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(create, range(4)))
        self.assertEqual(sum(isinstance(r, dict) for r in results), 1)
        self.assertEqual(results.count("duplicate_room_id"), 3)
        first = next(r for r in results if isinstance(r, dict))
        self.post("/v1/rooms/join", self.data)
        self.assertEqual(self.post("/v1/rooms/join", self.data, 409)["error"], "room_full")
        for name in ("BRAVO", "CHARLIE", "DELTA"):
            self.post("/v1/rooms/create", dict(self.data, room_id=name))
        self.assertEqual(self.post("/v1/rooms/create", dict(self.data, room_id="ECHO"), 503)["error"], "service_full")
        old = self.service.rooms["ALPHA"]
        old["process"].kill()
        old["process"].wait()
        self.service.reap()
        self.assertNotIn("ALPHA", self.service.rooms)
        self.assertFalse(old["config"].exists())
        replacement = self.post("/v1/rooms/create", self.data)
        self.assertEqual(replacement["port"], first["port"])
        self.peer(dict(replacement, token=first["token"]), accepted=False)
        room = self.service.rooms["ALPHA"]
        with self.service.lock:
            room["tokens"].clear()
            room["empty_since"] = time.monotonic() - 61
            self.service.reap()
        self.assertNotIn("ALPHA", self.service.rooms)
        self.assertIsNotNone(room["process"].poll())
        processes = [r["process"] for r in self.service.rooms.values()]
        self.service.close()
        self.assertTrue(all(p.poll() is not None for p in processes))
        self.assertFalse(self.service.rooms)

    def test_startup_failure_deadline_and_port_reclaim(self):
        self.service.args.godot = "/not/a/godot"
        self.assertEqual(self.post("/v1/rooms/create", self.data, 503)["error"], "server_start_failed")
        self.assertFalse(self.service.rooms)
        self.service.args.godot = shutil.which("godot")
        self.service.args.startup_timeout = 0.001
        self.assertEqual(self.post("/v1/rooms/create", self.data, 503)["error"], "server_start_timeout")
        self.assertFalse(self.service.rooms)
        self.service.args.startup_timeout = 12
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as occupied:
            occupied.bind(("0.0.0.0", self.service.args.port_start))
            self.service.args.startup_timeout = 0.8
            self.post("/v1/rooms/create", self.data, 503)
        self.assertFalse(self.service.rooms)
        self.service.args.startup_timeout = 12
        ticket = self.post("/v1/rooms/create", dict(self.data, room_id=""))
        self.assertRegex(ticket["room_id"], r"^[A-F0-9]{8}$")
        self.assertEqual(ticket["port"], self.service.args.port_start)

    def test_malformed_http_and_heartbeat_loss(self):
        self.post("/v1/rooms/create", [], 400)
        self.assertEqual(self.post("/v1/rooms/create", dict(self.data, room_id=[]), 400)["error"], "invalid_room_id")
        self.post("/internal/consume", {"room_id": []}, 403)
        ticket = self.post("/v1/rooms/create", self.data)
        room = self.service.rooms[ticket["room_id"]]
        with self.service.lock:
            room["heartbeat"] = time.monotonic() - 11
            self.service.reap()
        self.assertIsNotNone(room["process"].poll())
        self.assertFalse(self.service.rooms)

    def test_active_match_rejects_lookup_and_reserved_token(self):
        self.service.args.players = 3
        owner = self.post("/v1/rooms/create", self.data)
        guest = self.post("/v1/rooms/join", self.data)
        late = self.post("/v1/rooms/join", self.data)
        room = self.service.rooms["ALPHA"]
        with ThreadPoolExecutor(max_workers=2) as pool:
            playing = pool.submit(self.peer, dict(owner, start=True))
            deadline = time.monotonic() + 6
            while not room["peers"] and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue(room["peers"], "Owner must admit before guest")
            ready_guest = pool.submit(self.peer, dict(guest, hold=6))
            deadline = time.monotonic() + 8
            while room["joinable"] and time.monotonic() < deadline:
                time.sleep(0.05)
            if room["joinable"]:
                playing.result(timeout=12)  # Surface fixture failure before state failure.
            self.assertFalse(room["joinable"], "Authoritative active state must reach service")
            self.assertEqual(self.post("/v1/rooms/join", self.data, 409)["error"], "match_in_progress")
            self.peer(late, accepted=False)
            playing.result(timeout=12)
            ready_guest.result(timeout=12)

    def test_ui_discovery_ready_start_and_crash_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            processes = []
            logs = []
            try:
                for role in ("owner", "guest"):
                    log = Path(directory) / f"{role}.log"
                    logs.append(log)
                    with log.open("w") as output:
                        processes.append(subprocess.Popen([
                            self.service.args.godot, "--headless", "--path", str(ROOT),
                            "--script", "res://tests/room_ui_peer.gd", "--", f"--role={role}",
                            f"--room-service-url=http://127.0.0.1:{self.server.server_port}",
                        ], stdout=output, stderr=subprocess.STDOUT))
                    if role == "owner":
                        deadline = time.monotonic() + 12
                        while "ROOM_UI_CONNECTED" not in log.read_text() and time.monotonic() < deadline:
                            time.sleep(0.05)
                        self.assertIn("ROOM_UI_CONNECTED", log.read_text())
                deadline = time.monotonic() + 12
                while not all("ROOM_UI_ACTIVE" in log.read_text() for log in logs) and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertTrue(all("ROOM_UI_ACTIVE" in log.read_text() for log in logs), [log.read_text() for log in logs])
                room = self.service.rooms["UI-FRIENDS"]
                room["process"].kill()
                room["process"].wait(timeout=3)
                self.service.reap()
                for process, log in zip(processes, logs):
                    self.assertEqual(process.wait(timeout=28), 0, log.read_text())
                    output = log.read_text()
                    self.assertIn("ROOM_UI_PEER_OK", output)
                    self.assertNotIn("SCRIPT ERROR", output)
                    self.assertEqual([line for line in output.splitlines() if line.startswith("ERROR:") and "resources still in use at exit" not in line], [], output)
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=3)

    def test_registry_restart_server_fails_closed(self):
        ticket = self.post("/v1/rooms/create", self.data)
        room = self.service.rooms[ticket["room_id"]]
        # Simulate lost in-memory registry while the old game process still runs.
        with self.service.lock:
            self.service.rooms.clear()
        try:
            self.assertEqual(room["process"].wait(timeout=11), 1)
            self.assertEqual(self.post("/v1/rooms/join", self.data, 404)["error"], "unknown_room")
            room["config"].unlink()
            fresh = self.post("/v1/rooms/create", self.data)
            self.assertEqual(fresh["port"], ticket["port"])
            self.peer(dict(fresh, token=ticket["token"]), accepted=False)
        finally:
            if room["process"].poll() is None:
                room["process"].terminate()
                room["process"].wait(timeout=3)
            if "ALPHA" not in self.service.rooms:
                room["config"].unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
