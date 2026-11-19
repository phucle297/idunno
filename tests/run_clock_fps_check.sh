#!/usr/bin/env bash
# T11 two-frame-rate check: the same seeded short match, run A uncapped
# (--max-fps 0) vs run B throttled (--max-fps 15 + BUSY_MS busy loop per frame),
# never --fixed-fps. Gate: identical disaster start names/order, start tick and
# end tick within 1 physics step. Both maps offline, plus an online real-ENet
# pair per map (server throttled + client uncapped, and the reverse); the
# client's received starts/end must match its server.
# Usage: GODOT_BIN=godot [MAPS=..] [SEED=1101] [DURATION=60] [BUSY_MS=30] [ONLINE=1] tests/run_clock_fps_check.sh [OUT_DIR]
set -euo pipefail
ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
GODOT_BIN="${GODOT_BIN:-godot}"
OUT_DIR="$(realpath -m "${1:-/tmp/idunno-T11-clock}")"
MAPS="${MAPS:-toy_town toy_harbor}"
SEED="${SEED:-1101}"
DURATION="${DURATION:-60}"
BUSY_MS="${BUSY_MS:-30}"
ONLINE="${ONLINE:-1}"
PORT="${PORT:-29990}"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.log
NO_ASLR=()
if command -v setarch > /dev/null && setarch "$(uname -m)" -R true 2> /dev/null; then NO_ASLR=(setarch "$(uname -m)" -R); fi
LIMIT=$((${DURATION%.*} + 150))
SLOW=(--max-fps 15)
FAST=(--max-fps 0)

offline() { # map tag fps-args... -- busy
  local map="$1" tag="$2" busy="$3"; shift 3
  timeout "$LIMIT" "${NO_ASLR[@]}" "$GODOT_BIN" --headless "$@" --path "$ROOT" --script res://tests/test_clock_fps_independence.gd -- \
    --map-id="$map" --seed="$SEED" --duration="$DURATION" --busy-ms="$busy" > "$OUT_DIR/offline-$map-$tag.log" 2>&1
}
online() { # map tag port server-busy client-busy server-fps client-fps
  local map="$1" tag="$2" port="$3" sbusy="$4" cbusy="$5" sfps="$6" cfps="$7"
  timeout "$LIMIT" "${NO_ASLR[@]}" "$GODOT_BIN" --headless --max-fps "$sfps" --path "$ROOT" --script res://tests/clock_fps_network_peer.gd -- \
    --role=server --map-id="$map" --seed="$SEED" --duration="$DURATION" --busy-ms="$sbusy" --host-port="$port" > "$OUT_DIR/online-$map-$tag-server.log" 2>&1 &
  local server=$!; sleep 0.5
  timeout "$LIMIT" "${NO_ASLR[@]}" "$GODOT_BIN" --headless --max-fps "$cfps" --path "$ROOT" --script res://tests/clock_fps_network_peer.gd -- \
    --role=client --map-id="$map" --seed="$SEED" --duration="$DURATION" --busy-ms="$cbusy" --join-address=127.0.0.1 --join-port="$port" > "$OUT_DIR/online-$map-$tag-client.log" 2>&1 || true
  wait "$server" || true
}

pids=()
index=0
for map in $MAPS; do
  offline "$map" A 0 "${FAST[@]}" & pids+=("$!")
  offline "$map" B "$BUSY_MS" "${SLOW[@]}" & pids+=("$!")
  if [[ "$ONLINE" == 1 ]]; then
    online "$map" slowserver $((PORT + index)) "$BUSY_MS" 0 15 0 & pids+=("$!")
    online "$map" slowclient $((PORT + index + 1)) 0 "$BUSY_MS" 0 15 & pids+=("$!")
  fi
  index=$((index + 2))
done
for pid in "${pids[@]}"; do wait "$pid" || true; done

python3 - "$OUT_DIR" "$ONLINE" $MAPS <<'PY'
import re, sys, pathlib
out, online, maps = pathlib.Path(sys.argv[1]), sys.argv[2] == "1", sys.argv[3:]
ev = re.compile(r"^(CLOCK|CLIENT)_EVENT kind=(\w+) name=(\S+)(?: tick=(\d+))? elapsed=([\d.]+)", re.M)
def load(name):
    p = out / name
    text = p.read_text(errors="replace") if p.exists() else ""
    errors = [l for l in text.splitlines() if re.match(r"^(SCRIPT ERROR|ERROR):", l) and "resources still in use at exit" not in l]
    rows = [(m[2], m[3], int(m[4]) if m[4] else None, float(m[5])) for m in ev.finditer(text)]
    return rows, errors, text
fails = []
def compare(label, a, b):
    sa = [r for r in a if r[0] == "start"]; sb = [r for r in b if r[0] == "start"]
    ea = [r for r in a if r[0] == "end"]; eb = [r for r in b if r[0] == "end"]
    names_a, names_b = [r[1] for r in sa], [r[1] for r in sb]
    worst = max([abs(x[2] - y[2]) for x, y in zip(sa, sb)] or [0])
    end_diff = abs(ea[0][2] - eb[0][2]) if ea and eb else None
    ok = bool(sa) and names_a == names_b and worst <= 1 and end_diff is not None and end_diff <= 1
    print(f"CLOCK_FPS_COMPARE {label} starts={len(sa)}/{len(sb)} names_equal={names_a == names_b} max_start_tick_diff={worst} end_tick_diff={end_diff} {'PASS' if ok else 'FAIL'}")
    for x, y in zip(sa, sb):
        print(f"  {x[1]:<14} A tick={x[2]:>6} elapsed={x[3]:9.4f} | B {y[1]:<14} tick={y[2]:>6} elapsed={y[3]:9.4f} | dtick={y[2]-x[2]:+d}")
    if ea and eb:
        print(f"  match_end      A tick={ea[0][2]:>6} elapsed={ea[0][3]:9.4f} | B tick={eb[0][2]:>6} elapsed={eb[0][3]:9.4f} | dtick={eb[0][2]-ea[0][2]:+d}")
    if not ok:
        fails.append(label)
def client_vs_server(label, server, client):
    ss = [r for r in server if r[0] == "start"]; cs = [r for r in client if r[0] == "start"]
    se = [r for r in server if r[0] == "end"]; ce = [r for r in client if r[0] == "end"]
    names_ok = [r[1] for r in ss] == [r[1] for r in cs]
    lag = [c[3] - s[3] for s, c in zip(ss, cs)]
    lag_ok = all(-0.02 <= x <= 0.5 for x in lag)
    end_ok = bool(se and ce) and abs(se[0][3] - ce[0][3]) <= 0.001
    ok = bool(ss) and names_ok and lag_ok and end_ok
    print(f"CLOCK_FPS_CLIENT {label} starts={len(ss)}/{len(cs)} names_equal={names_ok} client_lag_s={[round(x, 3) for x in lag]} end_server={se[0][3] if se else None} end_client={ce[0][3] if ce else None} {'PASS' if ok else 'FAIL'}")
    if not ok:
        fails.append(label + ":client")
for m in maps:
    a, ea_, ta = load(f"offline-{m}-A.log"); b, eb_, tb = load(f"offline-{m}-B.log")
    for t, n in ((ta, "A"), (tb, "B")):
        r = re.search(r"^CLOCK_FPS_RUN .*$", t, re.M); print(f"RUN offline {m} {n}: {r[0] if r else 'MISSING'}")
    if ea_ or eb_:
        fails.append(f"offline-{m}:errors"); print("ERRORS", (ea_ + eb_)[:5])
    compare(f"offline-{m}", a, b)
    if online:
        s1, e1, _ = load(f"online-{m}-slowclient-server.log"); c1, f1, _ = load(f"online-{m}-slowclient-client.log")
        s2, e2, _ = load(f"online-{m}-slowserver-server.log"); c2, f2, _ = load(f"online-{m}-slowserver-client.log")
        if e1 or f1 or e2 or f2:
            fails.append(f"online-{m}:errors"); print("ERRORS", (e1 + f1 + e2 + f2)[:5])
        compare(f"online-{m}-server(uncapped)-vs-server(throttled)", s1, s2)
        client_vs_server(f"online-{m}-slowclient", s1, c1)
        client_vs_server(f"online-{m}-slowserver", s2, c2)
if fails:
    print("CLOCK_FPS_CHECK_FAILED " + " ".join(fails)); sys.exit(1)
print(f"CLOCK_FPS_CHECK_OK maps={','.join(maps)} online={online}")
PY
