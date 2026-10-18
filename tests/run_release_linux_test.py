#!/usr/bin/env python3
"""Check a standalone Linux release bundle; no editor, gameplay driver or Internet claim."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
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
    parser.add_argument("--profiles", action="store_true", help="External durable store and service restart")
    args = parser.parse_args()
    args.package = args.package.resolve()
    args.log = args.log.resolve()
    assert not args.log.exists(), "Choose a fresh log path"
    files = {}
    for line in (args.package / "SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split(None, 1)
        assert Path(name).name == name, "Only flat package files are accepted"
        files[name] = digest
    assert set(files) == {"DisasterParty.x86_64", "DisasterParty.pck", "room_service.py", "cosmetic_catalog.json", "BUILD.txt"}
    with tempfile.TemporaryDirectory(prefix="release-room-") as folder, tempfile.TemporaryDirectory(prefix="release-profiles-") as durable:
        stage = Path(folder)
        for name, digest in files.items():
            assert hashlib.sha256((args.package / name).read_bytes()).hexdigest() == digest
            shutil.copy2(args.package / name, stage / name)
        revision = (stage / "BUILD.txt").read_text().split("Source revision: ")[1].splitlines()[0]
        assert len(revision) == 40
        catalog = json.loads((stage / "cosmetic_catalog.json").read_text())
        starters = {item["id"] for item in catalog["items"] if item["pool"] == "starter"}

        identity = {}

        def post(path, data, status=200, credential=None):
            headers = {"Content-Type": "application/json"}
            bearer = identity.get("credential", "") if credential is None else credential
            if bearer:
                headers["Authorization"] = "Bearer " + bearer
            request = Request(f"http://127.0.0.1:{args.port}{path}", data=json.dumps(data).encode(),
                              headers=headers)
            try:
                response = urlopen(request, timeout=20)
            except HTTPError as error:
                response = error
            with response:
                body = json.load(response)
                assert response.status == status, (response.status, body.get("error"))
                return body

        data = dict(protocol=1, build=revision, room_id="RELEASE-42", password="")
        service_command = [
            "python3", str(stage / "room_service.py"), "--godot", str(stage / "DisasterParty.x86_64"),
            "--project", str(stage), "--build", revision, "--listen-port", str(args.port),
            "--port-start", str(args.port + 1), "--port-end", str(args.port + 2),
            "--rooms", "2", "--players", "4"]
        if args.profiles:
            service_command += ["--profile-store", str(Path(durable) / "profiles.sqlite3")]
        with args.log.open("w") as output:
            service = subprocess.Popen(service_command, cwd=stage, stdout=output, stderr=subprocess.STDOUT)
            children_path = Path(f"/proc/{service.pid}/task/{service.pid}/children")
            children = []
            try:
                for _ in range(100):
                    assert service.poll() is None, "Service exited before readiness"
                    try:
                        assert post("/v1/rooms/join", data, 403 if args.profiles else 404)["error"] == ("profile_required" if args.profiles else "unknown_room")
                        break
                    except URLError:
                        time.sleep(0.1)
                else:
                    raise AssertionError("Service readiness timeout")
                if args.profiles:
                    base = dict(protocol=1, build=revision)
                    identity = post("/v1/profiles/create", base)
                    second = post("/v1/profiles/create", base)
                    data["profile_id"] = identity["profile_id"]
                    query = dict(base, profile_id=identity["profile_id"])
                    initial = post("/v1/profiles/fetch", query)
                    assert initial["equipped"] == "plain" and set(initial["owned"]) == starters and initial["pending"] == []
                assert post("/v1/rooms/create", dict(data, build="development"), 409)["error"] == "incompatible_version"
                ticket = post("/v1/rooms/create", data)
                assert (ticket["build"], ticket["port"], ticket["room_id"]) == (revision, args.port + 1, "RELEASE-42")
                join_data = dict(data, profile_id=second["profile_id"]) if args.profiles else data
                join_credential = second["credential"] if args.profiles else None
                assert post("/v1/rooms/join", dict(join_data, password="wrong"), 403, join_credential)["error"] == "bad_password"
                second_ticket = post("/v1/rooms/join", join_data, credential=join_credential)
                assert second_ticket["build"] == revision
                children = children_path.read_text().split()
                assert len(children) == 1
                if args.profiles:
                    argv = Path(f"/proc/{children[0]}/cmdline").read_bytes().decode().split("\0")
                    config = json.loads(Path(next(arg.split("=", 1)[1] for arg in argv if arg.startswith("--room-config="))).read_text())
                    internal = dict(room_id=ticket["room_id"], key=config["key"], peer=42)
                    consumed = post("/internal/consume", dict(internal, token=ticket["token"]))
                    assert consumed["profile_id"] == identity["profile_id"] and consumed["equipped"] == "plain"
                    assert post("/internal/equip", dict(internal, lobby=True, sequence=1, outfit_id="cap"))["equipped"] == "cap"
                    post("/internal/consume", dict(internal, peer=43, token=second_ticket["token"]))
                    # Synthetic room-key-authenticated completion exercises packaged
                    # catalog/ledger, not a gameplay or 120s live-client claim.
                    started = post("/internal/round/start", dict(internal, sequence=1, peers=[42, 43], match_duration=600.0))
                    completion = dict(round_id=started["round_id"], sequence=1, duration=120.0,
                        match_duration=600.0, finished=True, participants={
                            str(peer): dict(profile_id=profile["profile_id"], connected_duration=120.0,
                                elimination_time=-1.0, departure_time=-1.0, departed_alive=False)
                            for peer, profile in [(42, identity), (43, second)]})
                    committed = post("/internal/round/finish", dict(internal, completion=completion))
                    assert len(committed["receipts"]) == 2
                    sealed = post("/v1/profiles/fetch", query)["pending"]
                    assert len(sealed) == 1 and sealed[0]["odds"] == dict(numerator=1, denominator=4)
                    opening = dict(query, box_id=sealed[0]["box_id"])
                    opened = post("/v1/profiles/open", opening)
                    assert post("/v1/profiles/open", opening) == opened
                    assert post("/internal/equip", dict(internal, lobby=True, sequence=2,
                        outfit_id=opened["cosmetic_id"]))["equipped"] == opened["cosmetic_id"]
                    saved = post("/v1/profiles/fetch", query)
                    assert saved["equipped"] == opened["cosmetic_id"] and set(saved["owned"]) == set(initial["owned"]) | {opened["cosmetic_id"]} and not saved["pending"]
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
        if args.profiles:
            with args.log.open("a") as output:
                service = subprocess.Popen(service_command, cwd=stage, stdout=output, stderr=subprocess.STDOUT)
                try:
                    for _ in range(100):
                        assert service.poll() is None, "Restarted service exited"
                        try:
                            restored = post("/v1/profiles/fetch", query)
                            break
                        except URLError:
                            time.sleep(0.1)
                    else:
                        raise AssertionError("Restart readiness timeout")
                    assert restored == saved, "External store restores acknowledged equipment and ownership"
                    assert post("/v1/profiles/open", opening) == opened, "Restart cannot reroll opened receipt"
                    assert post("/v1/rooms/join", data, 404)["error"] == "unknown_room"
                    assert post("/v1/profiles/fetch", query, 403, second["credential"])["error"] == "invalid_profile_credentials"
                finally:
                    service.terminate()
                    assert service.wait(timeout=10) == 0
        text = args.log.read_text()
        assert all(value not in text for value in [identity.get("credential", "")] if value), "Credential leaked"
        assert f"DISASTER_PARTY_BUILD revision={revision}" in text
        assert "DEDICATED_SERVER_READY" in text
        errors = [line for line in text.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "Traceback"))
                  and not re.fullmatch(r"ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.", line)]
        assert not errors, text
        assert not (stage / ".godot").exists()
    print("RELEASE_MANAGED_LINUX_OK checksum=passed standalone=passed version_rejection=passed "
          "create_join=passed crash_retry=passed sigterm=passed port_reclaimed=passed cache_absent=passed"
          + (" profiles=passed external_store_restart=passed reward_open_replay=passed saved_equipment=passed isolation=passed completion_fixture=synthetic" if args.profiles else ""))


if __name__ == "__main__":
    main()
