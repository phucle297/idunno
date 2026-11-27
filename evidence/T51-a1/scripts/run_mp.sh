#!/usr/bin/env bash
# T51 A1: server + client replication check -> evidence/T51-a1/mp-replication.log
set -u
A="$(cd "$(dirname "$0")/../../.." && pwd)"
G=${GODOT_BIN:-/home/box/bin/godot}
E=$A/evidence/T51-a1
P=${PORT:-29751}
timeout 60 $G --headless --path "$A" --script res://evidence/T51-a1/scripts/mp_peer.gd -- --role=server --port=$P > /tmp/t51_mp_server.log 2>&1 &
s=$!
sleep 0.5
timeout 60 $G --headless --path "$A" --script res://evidence/T51-a1/scripts/mp_peer.gd -- --role=client --port=$P > /tmp/t51_mp_client.log 2>&1
c=$?
wait $s; sv=$?
{ echo "# T51 A1 mp replication $(date -u -d '+7 hours' '+%F %T') ICT head=$(git -C "$A" rev-parse --short HEAD) server_exit=$sv client_exit=$c"
  echo "## server"; grep -E "^SERVER|T51_MP|ERROR" /tmp/t51_mp_server.log
  echo "## client"; grep -E "^CLIENT|T51_MP|ERROR" /tmp/t51_mp_client.log; } > "$E/mp-replication.log"
cat "$E/mp-replication.log"
[[ $sv == 0 && $c == 0 ]]
