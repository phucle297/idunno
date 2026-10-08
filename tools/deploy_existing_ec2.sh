#!/usr/bin/env bash
# Executed as root by the authorized main-only SSM deployment workflow.
set -euo pipefail
REVISION="${1:?Expected full source revision}"
EXPECTED_HASH="${2:?Expected server archive SHA256}"
URL="${3:?Expected short-lived HTTPS artifact URL}"
[[ "$URL" == https://* ]] || exit 1
[[ "$REVISION" =~ ^[0-9a-f]{40}$ && "$EXPECTED_HASH" =~ ^[0-9a-f]{64}$ ]] || {
  echo 'Invalid revision/hash' >&2; exit 1;
}
[[ "$EUID" -eq 0 ]] || { echo 'SSM root execution required' >&2; exit 1; }
test -f /etc/disaster-party/server.env
test -f /etc/systemd/system/disaster-party.service
id disaster-party >/dev/null
command -v python3 >/dev/null
command -v curl >/dev/null
if [[ -e /opt/disaster-party/current && ! -L /opt/disaster-party/current ]]; then
  echo 'Expected current to be a release symlink, not a directory/file' >&2; exit 1
fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
curl -fL --retry 3 --connect-timeout 10 --max-time 180 "$URL" -o "$WORK/artifact.zip"
python3 - "$WORK" <<'PY'
import pathlib, sys, zipfile
work = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(work / 'artifact.zip') as archive:
    assert archive.namelist() == ['DisasterParty-Linux.tar.gz']
    (work / 'server.tar.gz').write_bytes(archive.read('DisasterParty-Linux.tar.gz'))
PY
printf '%s  %s\n' "$EXPECTED_HASH" "$WORK/server.tar.gz" | sha256sum -c -
# Reject traversal, extra paths and non-regular archive entries before root extraction.
python3 - "$WORK/server.tar.gz" <<'PY'
import sys, tarfile
expected = {'DisasterParty.x86_64', 'DisasterParty.pck', 'room_service.py', 'BUILD.txt', 'SHA256SUMS.txt'}
with tarfile.open(sys.argv[1]) as archive:
    members = archive.getmembers()
    assert len(members) == len(expected) and {m.name for m in members} == expected
    assert all(m.isfile() for m in members)
PY
mkdir "$WORK/payload"
tar -xzf "$WORK/server.tar.gz" -C "$WORK/payload" --no-same-owner
(cd "$WORK/payload" && sha256sum -c SHA256SUMS.txt)
test "$(sed -n 's/^Source revision: //p' "$WORK/payload/BUILD.txt")" = "$REVISION"
DEST="/opt/disaster-party/releases/$REVISION"
if [[ -e "$DEST" ]]; then
  for file in DisasterParty.x86_64 DisasterParty.pck room_service.py BUILD.txt SHA256SUMS.txt; do
    cmp "$WORK/payload/$file" "$DEST/$file"
  done
else
  install -d -m 755 /opt/disaster-party/releases
  # Stage on the same filesystem, then rename: interrupted copies never become releases.
  STAGED=$(mktemp -d /opt/disaster-party/releases/.deploy-XXXXXX)
  trap 'rm -rf "$WORK" "${STAGED:-}"' EXIT
  cp "$WORK/payload/"* "$STAGED/"
  chmod 755 "$STAGED"
  mv "$STAGED" "$DEST"
fi
chmod +x "$DEST/DisasterParty.x86_64"
chmod 644 "$DEST/DisasterParty.pck" "$DEST/room_service.py" "$DEST/BUILD.txt" "$DEST/SHA256SUMS.txt"
chown -R root:root "$DEST"
PREVIOUS=$(readlink -e /opt/disaster-party/current || true)
cp /etc/disaster-party/server.env "$WORK/previous.env"
grep -q '^BUILD_REVISION=' /etc/disaster-party/server.env
rollback() {
  trap - ERR
  echo 'Deployment failed; restoring previous release/config.' >&2
  systemctl stop disaster-party || true
  cp "$WORK/previous.env" /etc/disaster-party/server.env
  if [[ -n "$PREVIOUS" ]]; then
    ln -sfn "$PREVIOUS" /opt/disaster-party/current
    systemctl start disaster-party || true
  else
    rm -f /opt/disaster-party/current
  fi
}
trap 'rollback' ERR
systemctl stop disaster-party
ln -sfn "$DEST" /opt/disaster-party/current
sed -i "s/^BUILD_REVISION=.*/BUILD_REVISION=$REVISION/" /etc/disaster-party/server.env

check_backend() {
  for _ in $(seq 1 20); do
    if systemctl is-active --quiet disaster-party && curl -sS --max-time 3 \
      -H 'Content-Type: application/json' -d "{\"protocol\":1,\"build\":\"$REVISION\",\"room_id\":\"DEPLOY-CHECK\"}" \
      -o "$WORK/response.json" -w '%{http_code}' http://127.0.0.1:29800/v1/rooms/join > "$WORK/status"; then
      if [[ "$(cat "$WORK/status")" == 404 ]] && python3 - "$WORK/response.json" <<'PY'
import json, sys
assert json.load(open(sys.argv[1])).get('error') == 'unknown_room'
PY
      then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

if systemctl start disaster-party && check_backend; then
  trap - ERR
  echo "EXISTING_EC2_DEPLOY_OK revision=$REVISION backend=passed internet_gameplay=not_checked"
else
  rollback
  exit 1
fi
