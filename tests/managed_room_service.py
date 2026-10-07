"""Internal-bridge-only test driver. Production service remains loopback-only."""
import json
from pathlib import Path
import signal
import sys
import threading
import time
from types import SimpleNamespace

from tools.room_service import RoomService, Server

control = Path("/control")
args = SimpleNamespace(godot="/work/tests/container_room_godot.sh", project="/work",
                       build="development", public_address="service", port_start=29810,
                       port_end=29811, rooms=2, players=int(sys.argv[1]), token_ttl=20,
                       startup_timeout=15, heartbeat_timeout=10, empty_timeout=3)
service = RoomService(args)
internal = Server(("127.0.0.1", 29800), service)
external = Server(("0.0.0.0", 29801), service)
service.internal_url = "http://127.0.0.1:29800/internal/"
stop = threading.Event()
for sig in (signal.SIGTERM, signal.SIGINT):
    signal.signal(sig, lambda *_: stop.set())


def start_http():
    for server in (internal, external):
        threading.Thread(target=server.serve_forever, daemon=True).start()


start_http()
sequence = 0
departures = []
try:
    while not stop.wait(0.1):
        path = control / "service.command"
        command = json.loads(path.read_text()) if path.exists() else {}
        if command.get("sequence", 0) > sequence:
            sequence = command["sequence"]
            if command["action"] == "kill_room":
                service.rooms[command["room"]]["process"].kill()
            elif command["action"] == "outage":
                internal.shutdown()
                external.shutdown()
            elif command["action"] == "resume":
                start_http()
        before = dict(service.rooms)
        service.reap()
        for key, room in before.items():
            if key not in service.rooms:
                departures.append({"room": key, "exit_code": room["process"].poll(),
                                   "heartbeat_age": time.monotonic() - room["heartbeat"]})
        with service.lock:
            rooms = {key: {"port": room["port"], "pid": room["process"].pid,
                           "peers": list(room["peers"]), "joinable": room["joinable"]}
                     for key, room in service.rooms.items()}
        temp = control / "service.json.tmp"
        temp.write_text(json.dumps({"ready": True, "sequence": sequence, "rooms": rooms, "departures": departures}))
        temp.replace(control / "service.json")
finally:
    service.close()
    internal.server_close()
    external.server_close()
