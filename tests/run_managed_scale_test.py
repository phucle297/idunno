#!/usr/bin/env python3
"""Real HTTP allocator and dedicated ENet clients on loopback, not Docker/Internet."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from types import SimpleNamespace
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.room_service import ProfileStore, RoomService, Server


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clients", type=int, choices=(4, 8, 20), default=20)
    parser.add_argument("--profiles", action="store_true")
    options = parser.parse_args()
    engine = os.environ.get("GODOT_BIN", shutil.which("godot"))
    logs = ROOT / (f".scratch/managed-scale-{options.clients}-profiles" if options.profiles
                   else ".scratch/managed-scale")
    logs.mkdir(parents=True, exist_ok=True)
    processes, sequences = [], {}
    with tempfile.TemporaryDirectory(prefix="managed-scale-") as temporary:
        control = Path(temporary)
        wrapper = control / "server.sh"
        wrapper.write_text("#!/bin/sh\nexec " + shlex.quote(engine) +
                           " --script res://tests/managed_container_peer.gd \"$@\" " +
                           shlex.quote(f"--control-dir={control}") + " >> " +
                           shlex.quote(str(logs / "server.log")) + " 2>&1\n")
        wrapper.chmod(0o700)
        (logs / "server.log").write_text("")
        service = RoomService(SimpleNamespace(godot=str(wrapper), project=str(ROOT),
            build="development", public_address="127.0.0.1", port_start=29910,
            port_end=29910, rooms=1, players=options.clients, token_ttl=20,
            profile_store=control / "profiles.sqlite3" if options.profiles else None,
            startup_timeout=15, heartbeat_timeout=10, empty_timeout=60))
        http = Server(("127.0.0.1", 0), service)
        service.internal_url = f"http://127.0.0.1:{http.server_port}/internal/"
        worker = threading.Thread(target=http.serve_forever, daemon=True)
        worker.start()

        def read(label):
            path = control / (label + ".json")
            return json.loads(path.read_text()) if path.exists() else {}

        def wait(predicate, message, timeout=15):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                if predicate():
                    return
                time.sleep(0.05)
            raise AssertionError(message)

        def command(label, action, **data):
            sequences[label] = sequences.get(label, 0) + 1
            path = control / (label + ".command")
            temp = path.with_suffix(".tmp")
            temp.write_text(json.dumps(dict(data, action=action, sequence=sequences[label])))
            temp.chmod(0o600)
            temp.replace(path)
            wait(lambda: read(label).get("sequence") == sequences[label], f"{label}: {action}")

        last_request = 0.0

        def post(action, expected=200, profile=None, **extra):
            nonlocal last_request
            # Respect the real shared loopback 30/minute public API limit.
            if options.profiles:
                time.sleep(max(0, last_request + 2.1 - time.monotonic()))
            last_request = time.monotonic()
            data = dict(protocol=1, build="development", **extra)
            route = action if action.startswith("/") else "/v1/rooms/" + action
            if route.startswith("/v1/rooms/"):
                data["room_id"] = "SCALE"
            headers = {"Content-Type": "application/json"}
            if profile is not None:
                data["profile_id"] = profile["profile_id"]
                headers["Authorization"] = "Bearer " + profile["credential"]
            request = Request(f"http://127.0.0.1:{http.server_port}{route}",
                data=json.dumps(data).encode(), headers=headers)
            try:
                response = urlopen(request, timeout=20)
            except HTTPError as error:
                response = error
            with response:
                assert response.status == expected, (action, response.status, expected)
                return json.load(response)

        def state(value, labels):
            wait(lambda: read("server-SCALE").get("state") == value and
                 all(read(label).get("state") == value for label in labels), f"State {value}: {labels}")

        labels = [f"client-{i}" for i in range(options.clients)]
        profiles, equipped = {}, {}

        def outfits_agree(active, peer_ids):
            expected = {str(peer): equipped[label] for label, peer in zip(active, peer_ids)}
            wait(lambda: all(read(label).get("outfits") == expected
                             for label in ["server-SCALE", *active]), "Equipment agreement")

        def equip(label, outfit):
            old = read(label).get("outfit_reply", {}).get("sequence", 0)
            command(label, "equip", outfit_id=outfit)
            wait(lambda: read(label).get("outfit_reply") ==
                 dict(outfit_id=outfit, sequence=old + 1, error=""), "Equipment acknowledgement")
            equipped[label] = outfit

        try:
            if options.profiles:
                for label in [*labels, "extra"]:
                    profiles[label] = post("/v1/profiles/create")
                assert len({p["profile_id"] for p in profiles.values()}) == len(profiles)
            for label in labels:
                with (logs / (label + ".log")).open("w") as output:
                    processes.append(subprocess.Popen([engine, "--headless", "--path", str(ROOT),
                        "--script", "res://tests/managed_container_peer.gd", "--",
                        f"--client-id={label}", f"--control-dir={control}"],
                        stdout=output, stderr=subprocess.STDOUT))
            wait(lambda: all((control / (label + ".prepared")).exists() for label in labels), "Client startup", 30)
            ids = []
            for index, label in enumerate(labels):
                ticket = post("create" if index == 0 else "join", profile=profiles.get(label))
                command(label, "join", ticket=ticket)
                wait(lambda: read(label).get("owner", 0) > 1, f"Admission {label}")
                ids.append(read(label)["local_id"])
            assert len(set(ids)) == options.clients and 1 not in ids
            wait(lambda: read("server-SCALE").get("ids") == sorted(ids) and
                 all(read(label).get("ids") == sorted(ids) for label in labels), "Full client roster")
            assert post("join", 409, profile=profiles.get("extra"))["error"] == "room_full"
            if options.profiles:
                for index, label in enumerate(labels):
                    outfit = ProfileStore.STARTERS[index % len(ProfileStore.STARTERS)]
                    assert outfit in profiles[label]["owned"]
                    equip(label, outfit)
                outfits_agree(labels, ids)
            for label in labels:
                command(label, "ready")
            wait(lambda: all(read(label).get("can_start") for label in ["server-SCALE", *labels]),
                 "Ready snapshots at authority and clients")
            command(labels[0], "start")
            state(1, labels)
            command("server-SCALE", "cleanup")
            # Server position and every remote observation, not just local prediction.
            moving = str(ids[0])
            origin = read("server-SCALE")["positions"][moving][0]
            command(labels[0], "move")
            wait(lambda: read("server-SCALE")["positions"][moving][0] > origin + 0.75 and
                 all(read(label)["positions"][moving][0] > origin + 0.75 for label in labels), "Authoritative movement at all clients")
            if options.profiles:
                # Real reward pipeline with accelerated authority clock, not 120s wall-clock play.
                command("server-SCALE", "advance", seconds=120.0)
                command("server-SCALE", "finish")
                state(2, labels)
                wait(lambda: all(read(label).get("reward_notice", {}).get("reason") == "earned"
                                 for label in labels), "Earned reward notices")
                earned = {}
                for label in labels:
                    fetched = post("/v1/profiles/fetch", profile=profiles[label])
                    assert len(fetched["pending"]) == 1
                    opened = post("/v1/profiles/open", profile=profiles[label],
                                  box_id=fetched["pending"][0]["box_id"])
                    assert opened["state"] == "opened"
                    earned[label] = opened["cosmetic_id"]
                    assert earned[label] not in ProfileStore.STARTERS
                    if label == labels[0]:
                        assert post("/v1/profiles/open", profile=profiles[label],
                                    box_id=opened["box_id"]) == opened, "Open replay preserves exact receipt"
                    fetched = post("/v1/profiles/fetch", profile=profiles[label])
                    assert earned[label] in fetched["owned"] and not fetched["pending"]
                command(labels[0], "lobby")
                state(0, labels)
                for label in labels:
                    equip(label, earned[label])
                outfits_agree(labels, ids)
                for label in labels:
                    command(label, "ready")
                wait(lambda: all(read(label).get("can_start") for label in ["server-SCALE", *labels]),
                     "Reward rematch readiness at authority and clients")
                command(labels[0], "start")
                state(1, labels)
                command("server-SCALE", "cleanup")
            for cycle in range(6):
                command("server-SCALE", "finish")
                state(2, labels)
                assert all(read(label)["winners"] == [ids[0]] for label in labels)
                if options.profiles:
                    outfits_agree(labels, ids)
                if cycle < 5:
                    command(labels[0], "rematch")
                    state(1, labels)
                    command("server-SCALE", "cleanup")
                    assert set(read("server-SCALE")["health"].values()) == {100}
                    if options.profiles:
                        outfits_agree(labels, ids)
            command(labels[0], "disconnect")
            remaining = labels[1:]
            wait(lambda: read("server-SCALE").get("owner") == ids[1] and
                 all(read(label).get("owner") == ids[1] for label in remaining), "Owner transfer")
            if options.profiles:
                outfits_agree(remaining, ids[1:])
            command(labels[1], "rematch")
            state(1, remaining)
            command("server-SCALE", "cleanup")
            if options.profiles:
                outfits_agree(remaining, ids[1:])
            service.rooms["SCALE"]["process"].kill()
            service.rooms["SCALE"]["process"].wait()
            service.reap()
            wait(lambda: all(not read(label).get("network") for label in remaining), "Crash recovery", 20)
            for suffix in (".json", ".command"):
                (control / ("server-SCALE" + suffix)).unlink(missing_ok=True)
            sequences.pop("server-SCALE", None)
            fresh = post("create", profile=profiles.get(labels[1]))
            command(labels[1], "join", ticket=dict(fresh, token="invalid"))
            wait(lambda: not read(labels[1]).get("network") and read(labels[1]).get("ids") == [1], "Invalid admission recovery")
            command(labels[1], "join", ticket=fresh)
            wait(lambda: read(labels[1]).get("owner", 0) > 1, "Fresh-ticket retry")
            if options.profiles:
                new_id = read(labels[1])["local_id"]
                assert new_id != ids[1], "Retry must exercise a changed ENet peer ID"
                outfits_agree([labels[1]], [new_id])
                fetched = post("/v1/profiles/fetch", profile=profiles[labels[1]])
                assert fetched["equipped"] == equipped[labels[1]]
                assert service.profiles.path.exists(), "Store survives disposable room replacement"
        finally:
            for process in processes:
                process.terminate()
            for process in processes:
                process.wait(timeout=10)
            service.close()
            http.shutdown()
            http.server_close()
            worker.join()
        errors = [line for path in logs.glob("*.log") for line in path.read_text().splitlines()
                  if line.startswith(("SCRIPT ERROR:", "ERROR:")) and "resources still in use at exit" not in line]
        assert not errors, errors
        for profile in profiles.values():
            assert all(profile["credential"] not in path.read_text() for path in logs.glob("*.log")), "Credential leaked to logs"
    print(f"MANAGED_SCALE_OK clients={options.clients} authority=passed movement_all_peers=passed capacity=passed rematches=5 owner_transfer=passed crash_retry=passed network=loopback"
          + (" profiles=passed reward_open_equip=passed reward_clock=accelerated_authority_120s retry_equipped_changed_peer_id=passed" if options.profiles else ""))


if __name__ == "__main__":
    run()
