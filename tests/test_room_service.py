"""Contract and actual Godot/ENet checks; no public network or Docker claims."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import Mock
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from tools.room_service import RoomService, Server, Handler, Rejected, normalize_id

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

    def test_rate_limit_global_cap_does_not_poison_registry(self):
        # Reaching the 1024-address cap must reject the next address without
        # leaving an empty entry that crashes the following prune (IndexError).
        for index in range(1024):
            self.service.rates[f"10.{index // 256}.{index % 256}.1"] = [time.monotonic()]
        self.rejects("rate_limited", lambda: self.service.rate_limit("10.255.255.255"))
        self.service.rate_limit("10.0.0.1")  # A subsequent request must not raise.

    def test_response_cancellation_is_not_an_application_failure(self):
        for stage in ("headers", "body"):
            for error in (BrokenPipeError, ConnectionResetError, OSError):
                with self.subTest(stage=stage, error=error):
                    handler = object.__new__(Handler)
                    body = b'{"protocol":1,"build":"development","room_id":"UNKNOWN"}'
                    handler.headers = {"Content-Length": str(len(body))}
                    handler.rfile = io.BytesIO(body)
                    handler.path = "/v1/rooms/join"
                    handler.client_address = ("127.0.0.1", 1)
                    handler.server = SimpleNamespace(service=self.service)
                    handler.send_response = Mock()
                    handler.send_header = Mock()
                    handler.end_headers = Mock(side_effect=error() if stage == "headers" else None)
                    handler.wfile = SimpleNamespace(write=Mock(side_effect=error() if stage == "body" else None))
                    if error is OSError:
                        with self.assertRaises(OSError):
                            handler.do_POST()
                    else:
                        handler.do_POST()
                    handler.send_response.assert_called_once_with(404)


class Profiles(unittest.TestCase):
    """Public HTTP contract against a real service process and persistent file."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.store = Path(self.directory.name) / "profiles.sqlite3"
        self.process = None
        self.log = Path(self.directory.name) / "service.log"
        self.addCleanup(self.stop)
        self.data = {"protocol": 1, "build": "development"}
        self.start()

    def start(self, enabled=True, port=None):
        if port is None:
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
        self.port = port
        command = [sys.executable, str(ROOT / "tools/room_service.py"), "--listen-port", str(self.port)]
        if enabled:
            command += ["--profile-store", str(self.store)]
        with self.log.open("w") as output:
            self.process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 5
        while "ROOM_SERVICE_READY" not in self.log.read_text() and self.process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertIsNone(self.process.poll(), self.log.read_text())
        self.assertIn("ROOM_SERVICE_READY", self.log.read_text())

    def stop(self):
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            self.assertEqual(self.process.wait(timeout=5), 0, self.log.read_text())
        self.process = None

    def post(self, action, data=None, credential=None, status=200):
        headers = {"Content-Type": "application/json"}
        if credential is not None:
            headers["Authorization"] = "Bearer " + credential
        request = Request(f"http://127.0.0.1:{self.port}/v1/profiles/{action}",
                          data=json.dumps(self.data if data is None else data).encode(), headers=headers)
        try:
            response = urlopen(request, timeout=5)
        except HTTPError as error:
            response = error
        with response:
            self.assertEqual(response.status, status)
            self.assertEqual(response.headers["Cache-Control"], "no-store")
            return json.load(response)

    def test_profile_restart_isolation_and_no_plaintext_credentials(self):
        first = self.post("create")
        second = self.post("create")
        self.assertRegex(first["profile_id"], r"^[0-9a-f]{32}$")
        self.assertRegex(first["credential"], r"^[A-Za-z0-9_-]{43}$")
        self.assertNotEqual(first["profile_id"], second["profile_id"])
        self.assertNotEqual(first["credential"], second["credential"])
        self.assertEqual(set(first["owned"]), {"plain", "cap", "hard_hat", "backpack"})
        self.assertEqual((first["equipped"], first["pending"]), ("plain", []))
        query = dict(self.data, profile_id=first["profile_id"])
        for bad in (None, "x" * 43, second["credential"]):
            self.assertEqual(self.post("fetch", query, bad, 403)["error"], "invalid_profile_credentials")
        self.assertEqual(self.post("fetch", dict(query, profile_id="0" * 32), first["credential"], 403)["error"],
                         "invalid_profile_credentials")
        self.stop()
        # Non-default persisted equipment fixture, not an implemented equip API.
        with sqlite3.connect(self.store) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 1)
            self.assertEqual(db.execute("SELECT credential_hash FROM profiles WHERE id=?", (first["profile_id"],)).fetchone()[0],
                             hashlib.sha256(first["credential"].encode()).hexdigest())
            db.execute("UPDATE profiles SET equipped='cap' WHERE id=?", (first["profile_id"],))
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o600)
        for profile in (first, second):
            self.assertNotIn(profile["credential"].encode(), self.store.read_bytes())
            self.assertNotIn(profile["credential"], self.log.read_text())
        self.start()
        restored = self.post("fetch", query, first["credential"])
        self.assertEqual(restored, dict(query, owned=sorted(first["owned"]), equipped="cap", pending=[]))
        other = self.post("fetch", dict(self.data, profile_id=second["profile_id"]), second["credential"])
        self.assertEqual(other["equipped"], "plain")
        self.assertNotIn("credential", restored)
        self.assertNotIn("credential_hash", restored)

    def test_godot_client_restart_preserves_credentials_and_rejects_reset(self):
        path = Path(self.directory.name) / "client-profile.json"
        url = f"http://127.0.0.1:{self.port}"

        def peer(expected_failure=False, service_url=url):
            command = [settings().godot, "--headless", "--path", str(ROOT),
                       "--script", "res://tests/profile_client_peer.gd", "--",
                       f"--profile-service-url={service_url}", f"--profile-file={path}"]
            if expected_failure:
                command.append("--expect-failure")
            result = subprocess.run(command, capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("PROFILE_CLIENT_REJECTED_OK" if expected_failure else "PROFILE_CLIENT_PEER_OK", output)
            self.assertNotIn("SCRIPT ERROR", output)
            self.assertNotIn("ERROR:", output)
            return output

        output = peer()
        saved = path.read_bytes()
        identity = json.loads(saved)
        self.assertEqual(set(identity), {"service_url", "profile_id", "credential"})
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertIn(identity["profile_id"], output)
        self.assertNotIn(identity["credential"], output)
        peer()  # New Godot process restores the same identity, without a second create.
        self.assertEqual(path.read_bytes(), saved)
        path.write_text(json.dumps(dict(identity, owned=["forged"], equipped="forged")))
        self.assertIn("equipped=plain", peer(), "Local cached ownership must not override the service")
        path.write_bytes(saved)
        port = self.port
        self.stop()
        self.start(port=port)
        output = peer()
        self.assertIn(identity["profile_id"], output)
        self.assertEqual(path.read_bytes(), saved)
        peer(True, service_url="http://rooms.invalid:29800")  # No remote plaintext credentials.
        peer(True, service_url=f"http://127.0.0.1:{port + 1}")  # Never forward to another service.
        self.assertEqual(path.read_bytes(), saved)
        path.write_text(json.dumps(dict(identity, credential="x" * 43)))
        rejected = path.read_bytes()
        peer(True)  # Credential rejection must not auto-create a replacement identity.
        self.assertEqual(path.read_bytes(), rejected)
        path.write_text("{broken-json")
        peer(True)
        self.assertEqual(path.read_text(), "{broken-json")
        with sqlite3.connect(self.store) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM profiles").fetchone()[0], 1)

    def test_input_authority_concurrent_creation_and_rate_limit(self):
        for extra in ({"owned": ["forged"]}, {"equipped": "forged"}, {"profile_id": "chosen"},
                      {"credential": "chosen"}, {"pending": ["forged"]}):
            self.assertEqual(self.post("create", dict(self.data, **extra), status=400)["error"], "invalid_body")
        self.post("create", dict(self.data, build="old"), status=409)
        self.post("create", [], status=400)
        with ThreadPoolExecutor(max_workers=8) as pool:
            profiles = list(pool.map(lambda _: self.post("create"), range(8)))
        self.assertEqual(len({p["profile_id"] for p in profiles}), 8)
        for profile in profiles:
            fetched = self.post("fetch", dict(self.data, profile_id=profile["profile_id"]), profile["credential"])
            self.assertEqual(set(fetched["owned"]), {"plain", "cap", "hard_hat", "backpack"})
        # 6 valid JSON invalid requests + 8 creates + 8 fetches = 22 counted.
        for _ in range(8):
            self.post("create")
        self.assertEqual(self.post("create", status=429)["error"], "rate_limited")
        with sqlite3.connect(self.store) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM profiles").fetchone()[0], 16)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM owned").fetchone()[0], 64)

    def test_store_failure_does_not_reset_and_opt_in_is_required(self):
        profile = self.post("create")
        self.store.rename(self.store.with_suffix(".backup"))
        self.assertEqual(self.post("fetch", dict(self.data, profile_id=profile["profile_id"]),
                                   profile["credential"], 503)["error"], "profile_store_unavailable")
        self.post("create", status=503)
        self.assertFalse(self.store.exists(), "A missing live store must not recreate an empty DB")
        self.stop()
        self.start(enabled=False)
        self.assertEqual(self.post("create", status=503)["error"], "profiles_unavailable")
        self.assertFalse(self.store.exists())

    def test_startup_rejects_corrupt_unsupported_and_unwritable_store(self):
        self.stop()
        for kind in ("corrupt", "future_schema", "missing_schema", "read_only", "missing_parent", "directory"):
            with self.subTest(kind=kind):
                path = Path(self.directory.name) / kind
                if kind == "corrupt":
                    path.write_bytes(b"not a SQLite database")
                elif kind in ("future_schema", "missing_schema"):
                    with sqlite3.connect(path) as db:
                        db.execute("PRAGMA user_version = " + ("99" if kind == "future_schema" else "1"))
                elif kind == "read_only":
                    shutil.copyfile(self.store, path)
                    path.chmod(0o400)
                elif kind == "missing_parent":
                    path = path / "profiles.sqlite3"
                else:
                    path.mkdir()
                before = path.read_bytes() if path.is_file() else None
                result = subprocess.run([sys.executable, str(ROOT / "tools/room_service.py"),
                                         "--profile-store", str(path)], capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 1)
                self.assertIn("PROFILE_STORE_STARTUP_FAILED", result.stderr)
                self.assertNotIn("ROOM_SERVICE_READY", result.stderr)
                if before is not None:
                    self.assertEqual(path.read_bytes(), before, "Existing evidence must not be rewritten")
                if kind == "read_only":
                    self.assertEqual(path.stat().st_mode & 0o777, 0o400)


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
            retry_ready = Path(directory) / "retry-ready"
            try:
                for role in ("owner", "guest"):
                    log = Path(directory) / f"{role}.log"
                    logs.append(log)
                    with log.open("w") as output:
                        processes.append(subprocess.Popen([
                            self.service.args.godot, "--headless", "--path", str(ROOT),
                            "--script", "res://tests/room_ui_peer.gd", "--", f"--role={role}",
                            f"--room-service-url=http://127.0.0.1:{self.server.server_port}",
                            f"--retry-ready-file={retry_ready}",
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
                deadline = time.monotonic() + 12
                while "ROOM_UI_RETRY_ADMITTED role=owner" not in logs[0].read_text() and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertIn("ROOM_UI_RETRY_ADMITTED role=owner", logs[0].read_text())
                retry_ready.touch()
                for process, log in zip(processes, logs):
                    self.assertEqual(process.wait(timeout=28), 0, {path.name: path.read_text() for path in logs})
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
