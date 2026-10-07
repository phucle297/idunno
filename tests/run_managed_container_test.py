#!/usr/bin/env python3
"""Two managed rooms with one separately addressed container per player."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(os.environ.get("GODOT_BIN", shutil.which("godot"))).resolve()
IMAGE = "disaster-party-local-validation"


def docker(*args):
    return subprocess.check_output(["docker", *map(str, args)], text=True, stderr=subprocess.STDOUT).strip()


def session(players):
    prefix = f"disaster-managed-{os.getpid()}-{players}"
    directory = ROOT / ".scratch" / prefix
    directory.mkdir()
    names = []
    sequences = {}
    metrics = {}

    def read(label):
        path = directory / f"{label}.json"
        return json.loads(path.read_text()) if path.exists() else {}

    def wait(predicate, message, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.1)
        raise AssertionError(message)

    def command(label, action, **data):
        sequences[label] = sequences.get(label, 0) + 1
        path = directory / f"{label}.command"
        temp = path.with_suffix(".tmp")
        temp.write_text(json.dumps(dict(data, action=action, sequence=sequences[label])))
        temp.chmod(0o600)
        temp.replace(path)
        wait(lambda: read(label).get("sequence", 0) == sequences[label], f"{label}: {action} was not processed")

    def start(label, *args, service=False):
        name = prefix + "-" + label
        names.append(name)
        docker("run", "-d", "--name", name, "--network", prefix,
               *( ["--network-alias", "service"] if service else []),
               "--cpus", "2" if service else "1", "--memory", "1g",
               "-v", f"{ROOT}:/source:ro", "-v", f"{ENGINE}:/opt/godot:ro",
               "-v", f"{directory}:/control", IMAGE, *args)

    # Requests originate in a client namespace, not the service's loopback.
    def post(path, payload, status=200):
        if path.endswith("create"):
            label = "server-" + payload["room_id"]
            for suffix in (".json", ".command"):
                (directory / (label + suffix)).unlink(missing_ok=True)
            sequences.pop(label, None)
        code = """import json,sys
from urllib.request import Request,urlopen
from urllib.error import HTTPError
r=Request('http://service:29801'+sys.argv[1],data=sys.argv[2].encode(),headers={'Content-Type':'application/json'})
try: response=urlopen(r,timeout=20)
except HTTPError as error: response=error
with response: print(json.dumps({'status':response.status,'body':json.load(response)}))
"""
        result = json.loads(docker("exec", prefix + "-alpha-0", "python3", "-c", code, path, json.dumps(payload)))
        assert result["status"] == status, (path, result["status"], status)
        return result["body"]

    def data(room, **extra):
        return dict(protocol=1, build="development", room_id=room, password="fixture", **extra)

    def connect(label, ticket):
        command(label, "join", ticket=ticket)
        wait(lambda: read(label).get("owner", 0) > 1, f"{label} was not admitted")
        return read(label)["local_id"]

    def room_state(room, state, labels=None):
        labels = labels if labels is not None else [f"{room.lower()}-{i}" for i in range(players)]
        wait(lambda: read("server-" + room).get("state") == state and
             all(read(label).get("state") == state for label in labels), f"{room}: state {state} must replicate")

    try:
        docker("network", "create", "--internal", prefix)
        start("service", "--suite=managed-service", str(players), service=True)
        for room in ("alpha", "bravo"):
            for index in range(players):
                start(f"{room}-{index}", "--suite=managed-client", f"--client-id={room}-{index}")
        wait(lambda: read("service").get("ready") and
             all((directory / f"{room}-{i}.prepared").exists() for room in ("alpha", "bravo") for i in range(players)),
             "All private import caches and clients must prepare", 120)
        assert post("/internal/heartbeat", {}, 403)["error"] == "forbidden"
        tickets = {}
        ids = {}
        for room in ("ALPHA", "BRAVO"):
            tickets[room] = post("/v1/rooms/create", data(room))
            ids[room] = [connect(f"{room.lower()}-0", tickets[room])]
            for i in range(1, players):
                ids[room].append(connect(f"{room.lower()}-{i}", post("/v1/rooms/join", data(room))))
            wait(lambda: all(read(f"{room.lower()}-{i}").get("ids") == sorted(ids[room]) for i in range(players)), "Full roster must reach every peer")
            assert 1 not in ids[room]
            assert post("/v1/rooms/join", data(room), 409)["error"] == "room_full"
        assert post("/v1/rooms/create", data("THIRD"), 503)["error"] == "service_full"
        # Same server machine, independent UDP ports and actual managed instances.
        assert tickets["ALPHA"]["port"] != tickets["BRAVO"]["port"]
        for i in range(players):
            command(f"alpha-{i}", "ready")
        wait(lambda: read("server-ALPHA").get("can_start") and read("alpha-0").get("can_start"), "All ready requests must reach authority before Start")
        command("alpha-0", "start")
        room_state("ALPHA", 1)
        command("server-ALPHA", "cleanup")
        victim = ids["ALPHA"][1]
        command("server-ALPHA", "damage", peer=victim, amount=17)
        command("server-ALPHA", "hazards", warning=40)
        wait(lambda: all(read(f"alpha-{i}").get("health", {}).get(str(victim)) == 83 and
                         read(f"alpha-{i}").get("flood", 0) != 0 and read(f"alpha-{i}").get("meteor", 0) != 0
                         for i in range(players)), "Alpha damage/hazards must replicate")
        for i in range(players):
            other = read(f"bravo-{i}")
            assert other["ids"] == sorted(ids["BRAVO"]) and other["state"] == 0
            assert set(other["health"].values()) == {100} and other["flood"] == other["meteor"] == 0
        command("alpha-2", "forge")
        time.sleep(0.4)
        assert read("server-ALPHA")["state"] == 1, "Non-owner lobby request must not mutate state"
        origin = read("alpha-0")["positions"][str(ids["ALPHA"][0])][0]
        command("alpha-0", "move")
        wait(lambda: read("alpha-0")["positions"][str(ids["ALPHA"][0])][0] > origin + 0.75, "Authoritative movement must replicate")
        for cycle in range(6):
            command("server-ALPHA", "finish")
            room_state("ALPHA", 2)
            assert all(read(f"alpha-{i}")["winners"] == [ids["ALPHA"][0]] for i in range(players))
            assert all(read(f"bravo-{i}")["state"] == 0 for i in range(players))
            if cycle != 5:
                command("alpha-0", "rematch")
                room_state("ALPHA", 1)
                command("server-ALPHA", "cleanup")
                assert set(read("server-ALPHA")["health"].values()) == {100}
        for i in range(players):
            command(f"bravo-{i}", "ready")
        wait(lambda: read("server-BRAVO").get("can_start") and read("bravo-0").get("can_start"), "Bravo ready requests must reach authority before Start")
        command("bravo-0", "start")
        room_state("BRAVO", 1)
        for cycle in range(6):
            command("server-BRAVO", "finish")
            room_state("BRAVO", 2)
            assert all(read(f"bravo-{i}")["winners"] == [ids["BRAVO"][0]] for i in range(players))
            assert all(read(f"alpha-{i}")["state"] == 2 and read(f"alpha-{i}")["winners"] == [ids["ALPHA"][0]] for i in range(players))
            if cycle != 5:
                command("bravo-0", "rematch")
                room_state("BRAVO", 1)
                command("server-BRAVO", "cleanup")
        # Profile both full rooms concurrently with real physics and overlapping hazards.
        command("alpha-0", "rematch")
        command("bravo-0", "rematch")
        for room in ("ALPHA", "BRAVO"):
            room_state(room, 1)
            command("server-" + room, "hazards")
            command("server-" + room, "profile")
        metrics["docker_stats"] = []
        for _ in range(3):
            metrics["docker_stats"].append(json.loads(docker("stats", "--no-stream", "--format", "{{json .}}", prefix + "-service")))
            time.sleep(1)
        wait(lambda: all(read("server-" + room).get("profile") for room in ("ALPHA", "BRAVO")), "Both rooms must record 600 physics samples", 30)
        metrics["profiles"] = {room: read("server-" + room)["profile"] for room in ("ALPHA", "BRAVO")}
        metrics["client_rtt_ms"] = {f"{room}-{i}": read(f"{room}-{i}")["rtt_ms"] for room in ("alpha", "bravo") for i in range(players)}
        for profile in metrics["profiles"].values():
            assert profile["samples"] == 600 and profile["physics_work_p95_ms"] < 1000 / 60
        command("alpha-0", "disconnect")
        remaining = [f"alpha-{i}" for i in range(1, players)]
        wait(lambda: all(read(label)["owner"] == ids["ALPHA"][1] for label in remaining), "Owner transfer must preserve longest connected peer")
        assert read("server-ALPHA")["state"] == 1 and len(read("server-ALPHA")["ids"]) == players - 1
        command("server-ALPHA", "finish")
        room_state("ALPHA", 2, remaining)
        command("alpha-1", "rematch")
        room_state("ALPHA", 1, remaining)
        command("service", "kill_room", room="BRAVO")
        wait(lambda: "BRAVO" not in read("service")["rooms"] and
             all(not read(f"bravo-{i}")["network"] for i in range(players)), "Crash must reclaim room and recover all clients", 20)
        # Fail admission, then recover with a valid fresh ticket in the same process.
        fresh = post("/v1/rooms/create", data("BRAVO"))
        assert fresh["port"] == tickets["BRAVO"]["port"]
        command("bravo-0", "join", ticket=dict(fresh, token="invalid"))
        wait(lambda: not read("bravo-0")["network"] and read("bravo-0")["ids"] == [1], "Bad admission must restore offline state")
        connect("bravo-0", fresh)
        command("service", "outage")
        wait(lambda: not read("service")["rooms"] and not read("bravo-0")["network"] and
             all(not read(label)["network"] for label in remaining), "Heartbeat outage must fail closed and recover clients", 25)
        command("service", "resume")
        unused = post("/v1/rooms/create", data("ALPHA"))
        issued_at = time.monotonic()
        # Restart with a live room and an unused, unexpired ticket. Rejecting an
        # expired or already-consumed token would not prove instance invalidation.
        (directory / "service.command").unlink()
        docker("restart", prefix + "-service")
        (directory / "service.json").unlink(missing_ok=True)
        wait(lambda: read("service").get("ready"), "Service must restart", 90)
        sequences["service"] = 0
        assert not read("service")["rooms"], "Registry must not survive restart"
        final = post("/v1/rooms/create", data("ALPHA"))
        assert final["port"] == unused["port"]
        assert time.monotonic() - issued_at < unused["expires_in"], "Old ticket must still be within TTL"
        command("alpha-0", "join", ticket=dict(final, token=unused["token"]))
        wait(lambda: not read("alpha-0")["network"], "Old instance token must be rejected")
        connect("alpha-0", final)
        command("alpha-0", "disconnect")
        wait(lambda: "ALPHA" not in read("service")["rooms"], "Empty room must expire after all participants leave", 10)
        reclaimed = post("/v1/rooms/create", data("ALPHA"))
        assert reclaimed["port"] == final["port"]
        metrics.update(players_per_room=players, rooms=2, server_cpus=2, server_memory_limit="1GiB",
                       engine=subprocess.check_output([str(ENGINE), "--version"], text=True).strip(),
                       hardware=subprocess.check_output(["lscpu"], text=True), kernel=os.uname().release,
                       build="development source; headless Compatibility; no rendering/audio claim",
                       network="internal Docker bridge; no emulated latency/loss; no published ports")
        (directory / "metrics.json").write_text(json.dumps(metrics, indent=2))
    finally:
        errors = []
        for name in names:
            log = docker("logs", name)
            (directory / f"{name}.log").write_text(log)
            errors.extend(line for line in log.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "Traceback (most recent call last):")) and "resources still in use at exit" not in line)
        if names:
            docker("rm", "-f", *names)
        docker("network", "rm", prefix)
        assert not errors, errors
    print(f"MANAGED_CONTAINER_OK rooms=2 players_per_room={players} rematches=5 isolation=passed failures=passed profile=passed", flush=True)


if __name__ == "__main__":
    docker("info")
    subprocess.run(["docker", "compose", "-f", str(ROOT / "tools/container-tests/compose.yml"), "build", "alpha"],
                   env=dict(os.environ, GODOT_BIN=str(ENGINE)), check=True)
    for count in (4, 8):
        session(count)
