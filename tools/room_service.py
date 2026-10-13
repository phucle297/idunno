#!/usr/bin/env python3
"""Single-machine room allocator. Public HTTPS belongs at the reverse proxy."""
import argparse
from contextlib import closing
import hashlib
import hmac
import json
import logging
import math
import os
from pathlib import Path
import re
import secrets
import signal
import sqlite3
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROTOCOL = 1
LOG = logging.getLogger("rooms")


class Rejected(Exception):
    def __init__(self, code, status=400):
        self.code, self.status = code, status


def normalize_id(value):
    if not isinstance(value, str):
        raise Rejected("invalid_room_id")
    value = value.strip().upper()
    if not re.fullmatch(r"[A-Z0-9][A-Z0-9-]{2,23}", value):
        raise Rejected("invalid_room_id")
    return value


class ProfileStore:
    """Durable ownership, separate from the disposable room registry.

    Schema 2 adds immutable round completions and sealed reward reservations.
    Callers cannot supply ownership or choose the reserved outfit.
    """
    STARTERS = ("plain", "cap", "hard_hat", "backpack")
    EARNED = ("raincoat", "mechanic", "park_ranger", "meteor_observer")
    CATALOG_VERSION = 1

    def __init__(self, path):
        self.path = Path(path).resolve()
        # The operator chooses an existing private parent outside releases. Never
        # silently recreate a missing store during a request or reset an old one.
        created = False
        try:
            fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            if not self.path.is_file():
                raise ValueError("profile store must be a regular file")
            if not self.path.stat().st_mode & 0o222:
                raise PermissionError("profile store is read-only")
        else:
            os.close(fd)
            created = True
        os.chmod(self.path, 0o600)
        with closing(self.connect()) as db:
            with db:
                db.execute("BEGIN")
                if created:
                    db.execute("CREATE TABLE profiles (id TEXT PRIMARY KEY, credential_hash TEXT NOT NULL UNIQUE, "
                               "equipped TEXT NOT NULL)")
                    db.execute("CREATE TABLE owned (profile_id TEXT NOT NULL REFERENCES profiles(id), "
                               "cosmetic_id TEXT NOT NULL, PRIMARY KEY (profile_id, cosmetic_id))")
                    db.execute("PRAGMA user_version = 1")
                version = db.execute("PRAGMA user_version").fetchone()[0]
                if version not in (1, 2):
                    raise ValueError("unsupported profile store schema; do not reset the store")
                if db.execute("PRAGMA quick_check").fetchall() != [("ok",)] or db.execute("PRAGMA foreign_key_check").fetchall():
                    raise ValueError("invalid profile store; restore a verified backup")
                # Missing columns/tables or invalid equipped state are errors,
                # not permission to initialize another empty inventory.
                db.execute("SELECT id, credential_hash, equipped FROM profiles LIMIT 0")
                db.execute("SELECT profile_id, cosmetic_id FROM owned LIMIT 0")
                if db.execute("SELECT 1 FROM profiles p WHERE NOT EXISTS "
                              "(SELECT 1 FROM owned o WHERE o.profile_id=p.id AND o.cosmetic_id=p.equipped) LIMIT 1").fetchone():
                    raise ValueError("equipped cosmetic is not owned")
                if version == 1:
                    db.execute("CREATE TABLE rounds (id TEXT PRIMARY KEY, instance TEXT NOT NULL, "
                               "sequence INTEGER NOT NULL, roster TEXT NOT NULL, match_duration REAL NOT NULL, "
                               "completion TEXT, response TEXT, UNIQUE(instance, sequence))")
                    db.execute("CREATE TABLE receipts (round_id TEXT NOT NULL REFERENCES rounds(id), "
                               "profile_id TEXT NOT NULL REFERENCES profiles(id), box_id TEXT UNIQUE, "
                               "cosmetic_id TEXT, pool TEXT NOT NULL, catalog_version INTEGER NOT NULL, "
                               "state TEXT NOT NULL CHECK(state IN ('sealed','opened','no_drop')), reason TEXT NOT NULL, "
                               "PRIMARY KEY(round_id, profile_id), UNIQUE(profile_id, cosmetic_id))")
                    db.execute("PRAGMA user_version = 2")
                db.execute("SELECT id, instance, sequence, roster, match_duration, completion, response FROM rounds LIMIT 0")
                db.execute("SELECT round_id, profile_id, box_id, cosmetic_id, pool, catalog_version, state, reason FROM receipts LIMIT 0")

    def connect(self):
        db = sqlite3.connect(self.path.as_uri() + "?mode=rw", uri=True, timeout=2)
        db.execute("PRAGMA foreign_keys = ON")
        return db

    def create(self):
        profile_id = secrets.token_hex(16)
        credential = secrets.token_urlsafe(32)
        with closing(self.connect()) as db:
            with db:
                db.execute("INSERT INTO profiles VALUES (?, ?, ?)",
                           (profile_id, hashlib.sha256(credential.encode()).hexdigest(), "plain"))
                db.executemany("INSERT INTO owned VALUES (?, ?)",
                               [(profile_id, item) for item in self.STARTERS])
        return {"profile_id": profile_id, "credential": credential,
                "owned": list(self.STARTERS), "equipped": "plain", "pending": []}

    @staticmethod
    def authenticate(db, profile_id, authorization):
        if (not isinstance(profile_id, str) or not re.fullmatch(r"[0-9a-f]{32}", profile_id)
                or not isinstance(authorization, str)
                or not re.fullmatch(r"Bearer [A-Za-z0-9_-]{43}", authorization)):
            raise Rejected("invalid_profile_credentials", 403)
        digest = hashlib.sha256(authorization[7:].encode()).hexdigest()
        row = db.execute("SELECT credential_hash, equipped FROM profiles WHERE id=?", (profile_id,)).fetchone()
        if row is None or not hmac.compare_digest(row[0], digest):
            raise Rejected("invalid_profile_credentials", 403)
        return row

    def fetch(self, profile_id, authorization):
        with closing(self.connect()) as db:
            with db:
                db.execute("BEGIN")
                row = self.authenticate(db, profile_id, authorization)
                owned = [row[0] for row in db.execute(
                    "SELECT cosmetic_id FROM owned WHERE profile_id=? ORDER BY cosmetic_id", (profile_id,))]
                if row[1] not in owned:
                    raise sqlite3.DatabaseError("equipped cosmetic is not owned")
                pending = [self.public_box(*box) for box in db.execute(
                    "SELECT box_id, round_id, pool, catalog_version FROM receipts "
                    "WHERE profile_id=? AND state='sealed' ORDER BY rowid", (profile_id,))]
        return {"profile_id": profile_id, "owned": owned, "equipped": row[1], "pending": pending}

    def open_box(self, profile_id, authorization, box_id):
        with closing(self.connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            self.authenticate(db, profile_id, authorization)
            if not isinstance(box_id, str) or not re.fullmatch(r"[0-9a-f]{32}", box_id):
                raise Rejected("invalid_box", 404)
            row = db.execute("SELECT round_id,cosmetic_id,pool,catalog_version,state FROM receipts "
                             "WHERE box_id=? AND profile_id=?", (box_id, profile_id)).fetchone()
            if row is None:
                raise Rejected("invalid_box", 404)
            if row[4] == "sealed":
                db.execute("INSERT INTO owned VALUES (?,?)", (profile_id, row[1]))
                db.execute("UPDATE receipts SET state='opened' WHERE box_id=?", (box_id,))
            receipt = self.public_box(box_id, row[0], row[2], row[3])
            receipt.update(state="opened", cosmetic_id=row[1])
            return receipt

    @staticmethod
    def public_box(box_id, round_id, pool, version):
        pool = json.loads(pool)
        return dict(box_id=box_id, round_id=round_id, state="sealed", pool=pool,
                    catalog_version=version, odds=dict(numerator=1, denominator=len(pool)))

    def register_round(self, instance, record):
        with closing(self.connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT id,roster,match_duration FROM rounds WHERE instance=? AND sequence=?",
                             (instance, record["sequence"])).fetchone()
            if row is not None:
                if sorted(map(int, json.loads(row[1]))) != record["peers"] or row[2] != record["match_duration"]:
                    raise Rejected("conflicting_round", 409)
                return row[0]
            if "round_id" not in record:
                raise Rejected("invalid_round_sequence", 409)
            db.execute("INSERT INTO rounds(id,instance,sequence,roster,match_duration) VALUES (?,?,?,?,?)",
                       (record["round_id"], instance, record["sequence"],
                        json.dumps(record["roster"], sort_keys=True), record["match_duration"]))
            return record["round_id"]

    def finalize_round(self, instance, completion):
        if not isinstance(completion, dict) or not isinstance(completion.get("round_id"), str):
            raise Rejected("invalid_completion")
        with closing(self.connect()) as db, db:
            # Serialize pool selection as well as ownership writes across rooms.
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT instance,sequence,roster,match_duration,completion,response FROM rounds WHERE id=?",
                             (completion["round_id"],)).fetchone()
            if row is None or not hmac.compare_digest(instance, row[0]):
                raise Rejected("invalid_round", 403)
            roster = json.loads(row[2])
            normalized = self.validate_completion(completion, row[1], roster, row[3])
            frozen = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
            if row[4] is not None:
                if row[4] != frozen:
                    raise Rejected("conflicting_completion", 409)
                return json.loads(row[5])
            receipts = []
            for peer, profile_id in roster.items():
                player = normalized["participants"][peer]
                reason = "earned"
                if row[3] != 600.0:
                    reason = "nonstandard_round"
                elif len(roster) < 2:
                    reason = "not_enough_profiles"
                elif normalized["duration"] < 120.0:
                    reason = "round_too_short"
                elif player["connected_duration"] < 60.0:
                    reason = "participation_too_short"
                elif player["departed_alive"]:
                    reason = "left_alive"
                unavailable = {value[0] for value in db.execute(
                    "SELECT cosmetic_id FROM owned WHERE profile_id=? UNION "
                    "SELECT cosmetic_id FROM receipts WHERE profile_id=? AND cosmetic_id IS NOT NULL",
                    (profile_id, profile_id))}
                pool = [item for item in self.EARNED if item not in unavailable]
                if reason == "earned" and not pool:
                    reason = "all_rewards_earned"
                box_id = secrets.token_hex(16) if reason == "earned" else None
                item = pool[secrets.randbelow(len(pool))] if box_id else None
                pool_json = json.dumps(pool)
                state = "sealed" if box_id else "no_drop"
                db.execute("INSERT INTO receipts VALUES (?,?,?,?,?,?,?,?)",
                           (completion["round_id"], profile_id, box_id, item, pool_json,
                            self.CATALOG_VERSION, state, reason))
                receipt = dict(profile_id=profile_id, reason=reason, state=state)
                if box_id:
                    receipt.update(self.public_box(box_id, completion["round_id"], pool_json, self.CATALOG_VERSION))
                receipts.append(receipt)
            response = dict(ok=True, round_id=completion["round_id"], receipts=receipts)
            db.execute("UPDATE rounds SET completion=?,response=? WHERE id=?",
                       (frozen, json.dumps(response), completion["round_id"]))
            return response

    @staticmethod
    def validate_completion(value, sequence, roster, match_duration):
        if (set(value) != {"round_id", "sequence", "participants", "duration", "match_duration", "finished"}
                or type(value["sequence"]) is not int or value["sequence"] != sequence or value["finished"] is not True
                or not isinstance(value["participants"], dict) or set(value["participants"]) != set(roster)):
            raise Rejected("invalid_completion")
        def number(number, low, high):
            if type(number) not in (int, float) or not low <= number <= high or not math.isfinite(number):
                raise Rejected("invalid_completion")
            return float(number)
        duration = number(value["duration"], 0, match_duration)
        if number(value["match_duration"], 0, 3600) != match_duration:
            raise Rejected("invalid_completion")
        participants = {}
        for peer, profile_id in roster.items():
            player = value["participants"][peer]
            if (not isinstance(player, dict) or set(player) != {"profile_id", "connected_duration", "elimination_time", "departure_time", "departed_alive"}
                    or player["profile_id"] != profile_id or type(player["departed_alive"]) is not bool):
                raise Rejected("invalid_completion")
            death = number(player["elimination_time"], -1, duration)
            departure = number(player["departure_time"], -1, duration)
            connected = number(player["connected_duration"], 0, duration)
            if (death < 0 and death != -1 or departure < 0 and departure != -1
                    or death >= 0 and departure >= 0 and departure < death
                    or player["departed_alive"] != (departure >= 0 and death < 0)
                    or connected != min(duration, death if death >= 0 else duration, departure if departure >= 0 else duration)):
                raise Rejected("invalid_completion")
            participants[peer] = dict(profile_id=profile_id, connected_duration=connected,
                                      elimination_time=death, departure_time=departure, departed_alive=player["departed_alive"])
        return dict(round_id=value["round_id"], sequence=sequence, finished=True,
                    match_duration=match_duration, duration=duration, participants=participants)


class RoomService:
    def __init__(self, args):
        self.args = args
        self.profiles = ProfileStore(args.profile_store) if getattr(args, "profile_store", None) else None
        self.lock = threading.RLock()
        self.rooms = {}
        self.rates = {}
        self.closed = False
        self.directory = tempfile.TemporaryDirectory(prefix="disaster-rooms-")
        self.internal_url = ""

    def rate_limit(self, address):
        with self.lock:
            now = time.monotonic()
            self.rates = {ip: times for ip, times in self.rates.items() if times and times[-1] > now - 60}
            times = self.rates.get(address)
            if times is None:
                if len(self.rates) >= 1024:
                    raise Rejected("rate_limited", 429)
                times = []
                self.rates[address] = times
            if len(times) >= 30:
                raise Rejected("rate_limited", 429)
            times.append(now)

    def compatible(self, data):
        if data.get("protocol") != PROTOCOL or data.get("build") != self.args.build:
            raise Rejected("incompatible_version", 409)

    def profile(self, action, data, authorization):
        self.compatible(data)
        expected = {"protocol", "build"} if action == "create" else {"protocol", "build", "profile_id"}
        if action == "open":
            expected.add("box_id")
        if set(data) != expected:
            raise Rejected("invalid_body")
        with self.lock:
            if self.closed:
                raise Rejected("service_stopping", 503)
            if self.profiles is None:
                raise Rejected("profiles_unavailable", 503)
        # SQLite transactions serialize ownership writes. Do not hold the room
        # registry lock during disk I/O: admission/heartbeats must remain live.
        if action == "open":
            result = self.profiles.open_box(data["profile_id"], authorization, data["box_id"])
        else:
            result = self.profiles.create() if action == "create" else self.profiles.fetch(data["profile_id"], authorization)
        return dict(result, protocol=PROTOCOL, build=self.args.build)

    def password(self, data):
        value = data.get("password", "")
        if not isinstance(value, str) or len(value.encode()) > 128:
            raise Rejected("invalid_password")
        return value

    def admission_profile(self, data, authorization):
        if self.profiles is None:
            return ""
        if "profile_id" not in data:
            raise Rejected("profile_required", 403)
        # Authenticate outside the registry lock; never trust a client identity.
        return self.profiles.fetch(data["profile_id"], authorization)["profile_id"]

    def issue(self, room, profile_id=""):
        now = time.monotonic()
        for candidate in self.rooms.values():
            candidate["tokens"] = {key: value for key, value in candidate["tokens"].items() if value["expiry"] > now}
            candidate["peers"] = {key: value for key, value in candidate["peers"].items()
                                  if value["deadline"] == 0 or value["deadline"] > now}
            if profile_id and any(value["profile_id"] == profile_id
                                  for value in (*candidate["tokens"].values(), *candidate["peers"].values())):
                raise Rejected("profile_in_use", 409)
        if len(room["peers"]) + len(room["tokens"]) >= self.args.players:
            raise Rejected("room_full", 409)
        token = secrets.token_urlsafe(32)
        room["tokens"][hashlib.sha256(token.encode()).hexdigest()] = {
            "expiry": now + self.args.token_ttl + (0 if room["ready"].is_set() else self.args.startup_timeout),
            "profile_id": profile_id}
        return {"protocol": PROTOCOL, "build": self.args.build, "room_id": room["id"],
                "address": self.args.public_address, "port": room["port"],
                "token": token, "expires_in": self.args.token_ttl}

    def create(self, data, authorization=""):
        self.compatible(data)
        password = self.password(data)
        profile_id = self.admission_profile(data, authorization)
        custom = data.get("room_id", "")
        if not isinstance(custom, str):
            raise Rejected("invalid_room_id")
        with self.lock:
            if self.closed:
                raise Rejected("service_stopping", 503)
            room_id = normalize_id(custom) if custom else secrets.token_hex(4).upper()
            while not custom and room_id in self.rooms:
                room_id = secrets.token_hex(4).upper()
            if room_id in self.rooms:
                raise Rejected("duplicate_room_id", 409)
            used = {room["port"] for room in self.rooms.values()}
            port = next((p for p in range(self.args.port_start, self.args.port_end + 1) if p not in used), None)
            if len(self.rooms) >= self.args.rooms or port is None:
                raise Rejected("service_full", 503)
            salt = secrets.token_bytes(16)
            room = {"id": room_id, "port": port, "key": secrets.token_urlsafe(32),
                    "salt": salt, "password": hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1),
                    "tokens": {}, "peers": {}, "round": {}, "ready": threading.Event(),
                    "heartbeat": time.monotonic(), "empty_since": time.monotonic(),
                    "joinable": True, "process": None}
            self.rooms[room_id] = room
            config = Path(self.directory.name) / (room_id + ".json")
            room["config"] = config
            try:
                # Reserve before releasing the lock for process startup, so two
                # simultaneous creates cannot reserve the same profile twice.
                ticket = self.issue(room, profile_id)
                with open(config, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as output:
                    json.dump({"room_id": room_id, "key": room["key"], "url": self.internal_url,
                               "build": self.args.build, "capacity": self.args.players,
                               "profiles_enabled": self.profiles is not None}, output)
                # No shell; executable/project are operator configuration, not request input.
                # Official release templates reject --path; cwd also works for source editors.
                room["process"] = subprocess.Popen(
                    [self.args.godot, "--headless", "--",
                     f"--server-port={port}", f"--room-config={config}"], cwd=self.args.project)
            except Rejected:
                self.remove(room)
                raise
            except OSError:
                self.remove(room)
                raise Rejected("server_start_failed", 503)
        if not room["ready"].wait(self.args.startup_timeout):
            with self.lock:
                self.remove(room)
            raise Rejected("server_start_timeout", 503)
        with self.lock:
            if self.rooms.get(room_id) is not room or room["process"].poll() is not None:
                raise Rejected("server_start_failed", 503)
            LOG.info("ready room=%s port=%d build=%s", room_id, port, self.args.build)
            # Give the caller the full TTL after startup, not before it.
            room["tokens"][hashlib.sha256(ticket["token"].encode()).hexdigest()]["expiry"] = time.monotonic() + self.args.token_ttl
            return ticket

    def join(self, data, authorization=""):
        self.compatible(data)
        room_id = normalize_id(data.get("room_id"))
        password = self.password(data)
        profile_id = self.admission_profile(data, authorization)
        with self.lock:
            room = self.rooms.get(room_id)
            if room is None or not room["ready"].is_set():
                raise Rejected("unknown_room", 404)
            supplied = hashlib.scrypt(password.encode(), salt=room["salt"], n=16384, r=8, p=1)
            if not hmac.compare_digest(supplied, room["password"]):
                raise Rejected("bad_password", 403)
            if not room["joinable"]:
                raise Rejected("match_in_progress", 409)
            return self.issue(room, profile_id)

    def internal(self, action, data):
        if action in ("round/start", "round/finish"):
            return self.round_request(action, data)
        with self.lock:
            room_id = data.get("room_id")
            if not isinstance(room_id, str):
                raise Rejected("invalid_server", 403)
            room = self.rooms.get(room_id)
            key = data.get("key", "")
            if room is None or not isinstance(key, str) or not hmac.compare_digest(key, room["key"]):
                raise Rejected("invalid_server", 403)
            if action == "heartbeat":
                peers = data.get("peers")
                if not isinstance(peers, list) or len(peers) > self.args.players or any(type(p) is not int or p <= 1 for p in peers):
                    raise Rejected("invalid_peers")
                # Keep in-flight authentication reservations across a stale heartbeat.
                now = time.monotonic()
                room["peers"] = {peer: dict(value, deadline=0 if peer in peers else value["deadline"])
                                 for peer, value in room["peers"].items() if peer in peers or value["deadline"] > now}
                room["joinable"] = data.get("joinable") is True
                room["heartbeat"] = time.monotonic()
                room["empty_since"] = room["empty_since"] if not room["peers"] else time.monotonic()
                room["ready"].set()
                return {"ok": True}
            token = data.get("token", "")
            peer = data.get("peer")
            if not isinstance(token, str) or len(token) > 128 or type(peer) is not int or peer <= 1:
                raise Rejected("invalid_admission", 403)
            digest = hashlib.sha256(token.encode()).hexdigest()
            reservation = room["tokens"].pop(digest, None)
            if reservation is None or reservation["expiry"] <= time.monotonic() or peer in room["peers"] or not room["joinable"]:
                raise Rejected("invalid_admission", 403)
            room["peers"][peer] = {"deadline": time.monotonic() + 6, "profile_id": reservation["profile_id"]}
            return dict(ok=True, profile_id=reservation["profile_id"]) if self.profiles is not None else {"ok": True}

    def round_request(self, action, data):
        with self.lock:
            room_id, key = data.get("room_id"), data.get("key")
            room = self.rooms.get(room_id) if isinstance(room_id, str) else None
            if self.closed or room is None or not isinstance(key, str) or not hmac.compare_digest(key, room["key"]):
                raise Rejected("invalid_server", 403)
            if self.profiles is None:
                raise Rejected("profiles_unavailable", 503)
            instance = hashlib.sha256(key.encode()).hexdigest()
            if action == "round/start":
                sequence, peers = data.get("sequence"), data.get("peers")
                duration = data.get("match_duration", 600.0)
                if (type(sequence) is not int or sequence < 1 or not isinstance(peers, list)
                        or not 1 <= len(peers) <= self.args.players
                        or any(type(peer) is not int or peer <= 1 for peer in peers)
                        or len(set(peers)) != len(peers) or type(duration) not in (int, float)
                        or not 0 < duration <= 3600 or not math.isfinite(duration)):
                    raise Rejected("invalid_round")
                previous = room.get("round", {})
                if sequence == previous.get("sequence") and sorted(peers) == previous["peers"] and duration == previous["match_duration"]:
                    record = previous
                elif sequence < previous.get("sequence", 0):
                    # Recover an issued ID after response loss and a fast rematch.
                    record = dict(sequence=sequence, peers=sorted(peers), match_duration=float(duration))
                else:
                    if sequence <= previous.get("sequence", 0):
                        raise Rejected("invalid_round_sequence", 409)
                    roster = {peer: room["peers"].get(peer, {}).get("profile_id", "") for peer in peers}
                    if any(not profile for profile in roster.values()) or len(set(roster.values())) != len(roster):
                        raise Rejected("invalid_round_roster", 403)
                    record = dict(sequence=sequence, round_id=secrets.token_hex(16),
                                  peers=sorted(peers), roster=roster, match_duration=float(duration))
                    room["round"] = record
                    room["joinable"] = False
        # SQLite must never stall room heartbeats/admission under the registry lock.
        if action == "round/start":
            return dict(ok=True, round_id=self.profiles.register_round(instance, record))
        return self.profiles.finalize_round(instance, data.get("completion"))

    def remove(self, room):
        if self.rooms.get(room["id"]) is not room:
            return
        process = room["process"]
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        room["config"].unlink(missing_ok=True)
        del self.rooms[room["id"]]
        room["ready"].set()
        LOG.info("removed room=%s port=%d", room["id"], room["port"])

    def reap(self):
        with self.lock:
            now = time.monotonic()
            for room in list(self.rooms.values()):
                room["tokens"] = {key: value for key, value in room["tokens"].items() if value["expiry"] > now}
                if (room["process"].poll() is not None or now - room["heartbeat"] > self.args.heartbeat_timeout
                        or (not room["peers"] and not room["tokens"] and now - room["empty_since"] > self.args.empty_timeout)):
                    self.remove(room)

    def close(self):
        with self.lock:
            self.closed = True
            for room in list(self.rooms.values()):
                self.remove(room)
            self.directory.cleanup()


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, service):
        self.service = service
        self.slots = threading.BoundedSemaphore(32)
        super().__init__(address, Handler)

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *_args):
        pass  # Never log request bodies, tokens or passwords.

    def do_POST(self):
        status = 200
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= (16384 if self.path == "/internal/round/finish" else 2048):
                raise Rejected("invalid_body")
            data = json.loads(self.rfile.read(size))
            if not isinstance(data, dict):
                raise Rejected("invalid_body")
            service = self.server.service
            if self.path in ("/internal/consume", "/internal/heartbeat", "/internal/round/start", "/internal/round/finish"):
                if self.client_address[0] != "127.0.0.1":
                    raise Rejected("forbidden", 403)
                result = service.internal(self.path.removeprefix("/internal/"), data)
            elif self.path in ("/v1/rooms/create", "/v1/rooms/join"):
                service.rate_limit(self.client_address[0])
                authorization = self.headers.get("Authorization", "")
                result = service.create(data, authorization) if self.path.endswith("create") else service.join(data, authorization)
            elif self.path in ("/v1/profiles/create", "/v1/profiles/fetch", "/v1/profiles/open"):
                service.rate_limit(self.client_address[0])
                action = self.path.rsplit("/", 1)[1]
                result = service.profile(action, data, self.headers.get("Authorization", ""))
            else:
                raise Rejected("not_found", 404)
        except Rejected as error:
            status, result = error.status, {"error": error.code, "protocol": PROTOCOL}
        except sqlite3.Error:
            # Storage failure is visible, but neither secrets nor raw DB errors
            # belong in a response/log. Never fall back to a fresh database.
            status, result = 503, {"error": "profile_store_unavailable", "protocol": PROTOCOL}
        except (ValueError, TypeError):
            status, result = 400, {"error": "invalid_body", "protocol": PROTOCOL}
        payload = json.dumps(result).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        try:
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            # A timed-out/cancelled HTTP caller cannot receive a reply. Allocation
            # and reservations still follow their normal bounded expiry policy.
            pass


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen-port", type=int, default=29800)
    parser.add_argument("--public-address", default="127.0.0.1")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--build", default="development")
    parser.add_argument("--profile-store", help="Opt-in SQLite file in an existing private directory outside releases")
    parser.add_argument("--port-start", type=int, default=29810)
    parser.add_argument("--port-end", type=int, default=29813)
    parser.add_argument("--rooms", type=int, default=4)
    parser.add_argument("--players", type=int, default=20)
    parser.add_argument("--token-ttl", type=float, default=20)
    parser.add_argument("--startup-timeout", type=float, default=15)
    parser.add_argument("--heartbeat-timeout", type=float, default=10)
    parser.add_argument("--empty-timeout", type=float, default=60)
    args = parser.parse_args()
    if not (1 <= args.port_start <= args.port_end <= 65535 and 1 <= args.listen_port <= 65535
            and 1 <= args.rooms <= 16 and 1 <= args.players <= 20
            and all(value > 0 for value in (args.token_ttl, args.startup_timeout, args.heartbeat_timeout, args.empty_timeout))):
        parser.error("invalid capacity, port range or timeout")
    return args


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    try:
        service = RoomService(arguments())
    except (sqlite3.Error, OSError, ValueError):
        LOG.error("PROFILE_STORE_STARTUP_FAILED: inspect permissions/schema/backup; store was not reset")
        return 1
    server = Server(("127.0.0.1", service.args.listen_port), service)
    service.internal_url = f"http://127.0.0.1:{server.server_port}/internal/"
    stop = threading.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: stop.set())
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    LOG.info("ROOM_SERVICE_READY port=%d protocol=%d build=%s", server.server_port, PROTOCOL, service.args.build)
    try:
        while not stop.wait(0.25):
            service.reap()
    finally:
        server.shutdown()
        service.close()
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
