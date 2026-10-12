#!/usr/bin/env python3
"""Real HTTP allocator and twenty dedicated ENet clients on loopback, not Docker/Internet."""
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
from tools.room_service import RoomService, Server


def run():
    engine = os.environ.get("GODOT_BIN", shutil.which("godot"))
    logs = ROOT / ".scratch/managed-scale"
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
            port_end=29910, rooms=1, players=20, token_ttl=20,
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

        def post(action, expected=200):
            request = Request(f"http://127.0.0.1:{http.server_port}/v1/rooms/{action}",
                data=json.dumps(dict(protocol=1, build="development", room_id="SCALE")).encode(),
                headers={"Content-Type": "application/json"})
            try:
                response = urlopen(request, timeout=20)
            except HTTPError as error:
                response = error
            with response:
                assert response.status == expected, (action, response.status, expected)
                return json.load(response)

        def state(value, labels):
            wait(lambda: read("server-SCALE").get("state") == value and
                 all(read(label).get("state") == value for label in labels), f"State {value}")

        labels = [f"client-{i}" for i in range(20)]
        try:
            for label in labels:
                with (logs / (label + ".log")).open("w") as output:
                    processes.append(subprocess.Popen([engine, "--headless", "--path", str(ROOT),
                        "--script", "res://tests/managed_container_peer.gd", "--",
                        f"--client-id={label}", f"--control-dir={control}"],
                        stdout=output, stderr=subprocess.STDOUT))
            wait(lambda: all((control / (label + ".prepared")).exists() for label in labels), "Client startup", 30)
            ids = []
            for index, label in enumerate(labels):
                ticket = post("create" if index == 0 else "join")
                command(label, "join", ticket=ticket)
                wait(lambda: read(label).get("owner", 0) > 1, f"Admission {label}")
                ids.append(read(label)["local_id"])
            assert len(set(ids)) == 20 and 1 not in ids
            wait(lambda: read("server-SCALE").get("ids") == sorted(ids) and
                 all(read(label).get("ids") == sorted(ids) for label in labels), "Twenty-client roster")
            assert post("join", 409)["error"] == "room_full"
            for label in labels:
                command(label, "ready")
            wait(lambda: read("server-SCALE").get("can_start"), "Ready acknowledgements")
            command(labels[0], "start")
            state(1, labels)
            command("server-SCALE", "cleanup")
            # Server position and every remote observation, not just local prediction.
            moving = str(ids[0])
            origin = read("server-SCALE")["positions"][moving][0]
            command(labels[0], "move")
            wait(lambda: read("server-SCALE")["positions"][moving][0] > origin + 0.75 and
                 all(read(label)["positions"][moving][0] > origin + 0.75 for label in labels), "Authoritative movement at all twenty clients")
            for cycle in range(6):
                command("server-SCALE", "finish")
                state(2, labels)
                assert all(read(label)["winners"] == [ids[0]] for label in labels)
                if cycle < 5:
                    command(labels[0], "rematch")
                    state(1, labels)
                    command("server-SCALE", "cleanup")
                    assert set(read("server-SCALE")["health"].values()) == {100}
            command(labels[0], "disconnect")
            remaining = labels[1:]
            wait(lambda: read("server-SCALE").get("owner") == ids[1] and
                 all(read(label).get("owner") == ids[1] for label in remaining), "Owner transfer")
            command(labels[1], "rematch")
            state(1, remaining)
            command("server-SCALE", "cleanup")
            service.rooms["SCALE"]["process"].kill()
            service.rooms["SCALE"]["process"].wait()
            service.reap()
            wait(lambda: all(not read(label).get("network") for label in remaining), "Crash recovery", 20)
            for suffix in (".json", ".command"):
                (control / ("server-SCALE" + suffix)).unlink(missing_ok=True)
            sequences.pop("server-SCALE", None)
            fresh = post("create")
            command(labels[1], "join", ticket=dict(fresh, token="invalid"))
            wait(lambda: not read(labels[1]).get("network") and read(labels[1]).get("ids") == [1], "Invalid admission recovery")
            command(labels[1], "join", ticket=fresh)
            wait(lambda: read(labels[1]).get("owner", 0) > 1, "Fresh-ticket retry")
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
    print("MANAGED_SCALE_OK clients=20 authority=passed movement_all_peers=passed capacity=passed rematches=5 owner_transfer=passed crash_retry=passed network=loopback")


if __name__ == "__main__":
    run()
