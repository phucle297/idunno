#!/usr/bin/env python3
"""Check a standalone Linux release bundle; no editor, gameplay driver or Internet claim."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--port", type=int, default=29870)
    args = parser.parse_args()
    args.package = args.package.resolve()
    args.log = args.log.resolve()
    assert not args.log.exists(), "Choose a fresh log path"
    files = {}
    for line in (args.package / "SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split(None, 1)
        assert Path(name).name == name, "Only flat package files are accepted"
        files[name] = digest
    assert set(files) == {"DisasterParty.x86_64", "DisasterParty.pck", "room_service.py", "BUILD.txt"}
    with tempfile.TemporaryDirectory(prefix="release-room-") as folder:
        stage = Path(folder)
        for name, digest in files.items():
            assert hashlib.sha256((args.package / name).read_bytes()).hexdigest() == digest
            shutil.copy2(args.package / name, stage / name)
        revision = (stage / "BUILD.txt").read_text().split("Source revision: ")[1].splitlines()[0]
        assert len(revision) == 40

        def post(path, data, status=200):
            request = Request(f"http://127.0.0.1:{args.port}{path}", data=json.dumps(data).encode(),
                              headers={"Content-Type": "application/json"})
            try:
                response = urlopen(request, timeout=20)
            except HTTPError as error:
                response = error
            with response:
                body = json.load(response)
                assert response.status == status, (response.status, body.get("error"))
                return body

        data = dict(protocol=1, build=revision, room_id="RELEASE-42", password="")
        with args.log.open("w") as output:
            service = subprocess.Popen([
                "python3", str(stage / "room_service.py"), "--godot", str(stage / "DisasterParty.x86_64"),
                "--project", str(stage), "--build", revision, "--listen-port", str(args.port),
                "--port-start", str(args.port + 1), "--port-end", str(args.port + 2),
                "--rooms", "2", "--players", "4"], cwd=stage, stdout=output, stderr=subprocess.STDOUT)
            children_path = Path(f"/proc/{service.pid}/task/{service.pid}/children")
            children = []
            try:
                for _ in range(100):
                    assert service.poll() is None, "Service exited before readiness"
                    try:
                        assert post("/v1/rooms/join", data, 404)["error"] == "unknown_room"
                        break
                    except URLError:
                        time.sleep(0.1)
                else:
                    raise AssertionError("Service readiness timeout")
                assert post("/v1/rooms/create", dict(data, build="development"), 409)["error"] == "incompatible_version"
                ticket = post("/v1/rooms/create", data)
                assert (ticket["build"], ticket["port"], ticket["room_id"]) == (revision, args.port + 1, "RELEASE-42")
                assert post("/v1/rooms/join", dict(data, password="wrong"), 403)["error"] == "bad_password"
                assert post("/v1/rooms/join", data)["build"] == revision
                children = children_path.read_text().split()
                assert len(children) == 1
                os.kill(int(children[0]), signal.SIGKILL)
                deadline = time.monotonic() + 5
                while children_path.read_text().strip() and time.monotonic() < deadline:
                    time.sleep(0.1)
                assert not children_path.read_text().strip(), "Crashed server was not reaped"
                assert post("/v1/rooms/join", data, 404)["error"] == "unknown_room"
                retry = post("/v1/rooms/create", data)
                assert retry["port"] == ticket["port"] and retry["token"] != ticket["token"]
                children = children_path.read_text().split()
                assert len(children) == 1
            finally:
                service.terminate()
                assert service.wait(timeout=10) == 0
        assert all(not Path("/proc", child).exists() for child in children)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
            udp.bind(("127.0.0.1", args.port + 1))
        text = args.log.read_text()
        assert f"DISASTER_PARTY_BUILD revision={revision}" in text
        assert "DEDICATED_SERVER_READY" in text
        assert not any(line.startswith(("ERROR:", "SCRIPT ERROR:", "Traceback")) for line in text.splitlines()), text
        assert not (stage / ".godot").exists()
    print("RELEASE_MANAGED_LINUX_OK checksum=passed standalone=passed version_rejection=passed "
          "create_join=passed crash_retry=passed sigterm=passed port_reclaimed=passed cache_absent=passed")


if __name__ == "__main__":
    main()
