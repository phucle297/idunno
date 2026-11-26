#!/usr/bin/env bash
# T44 A5 heavy session. Caller holds /home/box/game-factory/.heavy.lock.
# Log times = UTC (ICT = +7). override.cfg is written only on A and deleted at the end.
set -u
F=/home/box/game-factory
G=/home/box/bin/godot
A=$F/repos/idunno-T44-a2
B=$F/repos/idunno-T44-base
E=$A/evidence/T44-a5
P=$E/perf
LOG=$E/heavy.log
mkdir -p "$P" "$A/.scratch" "$B/.scratch"
cp "$E/capture_t44_a5_aa.gd" "$A/.scratch/capture_t44_a5_aa.gd"
cp "$F/evidence/T44-a3-qa/scripts/perf_bench_moving.gd" "$A/.scratch/perf_bench_moving.gd"
cp "$F/evidence/T44-a3-qa/scripts/perf_bench_moving.gd" "$B/.scratch/perf_bench_moving.gd"

log(){ echo "- $(date -u '+%F %T UTC') $*" | tee -a "$LOG"; }
X(){ timeout "$1" xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$2" --script "$3" -- "${@:4}"; }

aa_off(){
  cat > "$A/override.cfg" <<CFG
[rendering]
anti_aliasing/quality/msaa_3d=0
CFG
}
aa_on(){ rm -f "$A/override.cfg"; }

cleanup(){ rm -f "$A/override.cfg"; log "override.cfg removed"; }
trap cleanup EXIT

log "A5 HEAVY START A=$(git -C $A rev-parse --short HEAD) B=$(git -C $B rev-parse --short HEAD) msaa_key=$(rg -N 'msaa_3d' $A/project.godot)"

# --- Visual evidence (default AA-on from project.godot; script toggles root.msaa_3d) ---
aa_on
log "CAPTURE start"
X 600 $A res://.scratch/capture_t44_a5_aa.gd --out=$E > $E/capture.log 2>&1
log "CAPTURE EXIT=$? $(rg -o 'MSAA_DEFAULT.*|A5_CAPTURE_OK' $E/capture.log | tr '\n' ' ')"
python3 $E/compose_and_edges.py > $E/compose.log 2>&1
log "COMPOSE EXIT=$? $(rg -o 'EDGES.*|COMPOSE_OK' $E/compose.log | tr '\n' ' | ')"

# --- Gate: AA-off vs B, 6 interleaved moving pairs ---
for i in 1 2 3 4 5 6; do
  if [ $((i % 2)) -eq 1 ]; then ORDER="B Aoff"; else ORDER="Aoff B"; fi
  for w in $ORDER; do
    if [ $w = B ]; then
      T=$B; L=B_ae933edd_moving_run$i
    else
      aa_off; T=$A; L=Aoff_moving_run$i
    fi
    X 900 $T res://.scratch/perf_bench_moving.gd --label=$L > $P/${L}.log 2>&1
    log "MOVING $w run$i EXIT=$? $(rg -o 'planted_toggles=\d+|PERF_4P.*' $P/${L}.log | tr '\n' ' ')"
  done
done
log "MOVING_GATE_DONE"

# --- Info: AA-on vs AA-off on A5 tree, 6 interleaved moving pairs ---
for i in 1 2 3 4 5 6; do
  if [ $((i % 2)) -eq 1 ]; then ORDER="Aoff Aon"; else ORDER="Aon Aoff"; fi
  for w in $ORDER; do
    if [ $w = Aoff ]; then aa_off; L=Aoff_vsAon_moving_run$i
    else aa_on; L=Aon_moving_run$i
    fi
    X 900 $A res://.scratch/perf_bench_moving.gd --label=$L > $P/${L}.log 2>&1
    log "MOVING $w run$i EXIT=$? $(rg -o 'PERF_4P.*' $P/${L}.log | tr '\n' ' ')"
  done
done
aa_on
log "MOVING_INFO_DONE"

# --- Interior traces: 6 interleaved AA-off vs B, then as many AA-on vs AA-off as time allows ---
# Each trace can take ~8-15 min. Stop interiors at hard_stop if set.
HARD_STOP_UTC=${HARD_STOP_UTC:-}

should_stop(){
  if [ -n "$HARD_STOP_UTC" ]; then
    now=$(date -u +%s)
    stop=$(date -u -d "$HARD_STOP_UTC" +%s 2>/dev/null || echo 0)
    if [ "$stop" -gt 0 ] && [ "$now" -ge "$stop" ]; then return 0; fi
  fi
  return 1
}

run_trace(){
  local w=$1 i=$2 mode=$3  # mode=gate|info
  local T out L
  if [ $w = B ]; then T=$B; out=$P/trace-B-run$i; L=trace_B_run$i; aa_on
  elif [ $w = Aoff ]; then aa_off; T=$A; out=$P/trace-Aoff-run$i; L=trace_Aoff_run$i
  else aa_on; T=$A; out=$P/trace-Aon-run$i; L=trace_Aon_run$i
  fi
  mkdir -p "$out"
  local ec=0
  X 1500 $T res://tools/render_indoor_lighting.gd --mode=trace --out=$out > $P/${L}.log 2>&1 || ec=$?
  if ! rg -q 'INDOOR_TRACE' $P/${L}.log; then
    log "TRACE $w run$i EXIT=$ec FAIL no INDOOR_TRACE, retry once"
    X 1500 $T res://tools/render_indoor_lighting.gd --mode=trace --out=$out > $P/${L}.log 2>&1 || ec=$?
  fi
  log "TRACE $w run$i EXIT=$ec $(rg -o 'INDOOR_TRACE overall=\{[^}]+\}' $P/${L}.log | head -1)"
}

for i in 1 2 3 4 5 6; do
  should_stop && { log "HARD_STOP before interior gate pair $i"; break; }
  if [ $((i % 2)) -eq 1 ]; then ORDER="B Aoff"; else ORDER="Aoff B"; fi
  for w in $ORDER; do
    should_stop && { log "HARD_STOP mid interior gate pair $i"; break 2; }
    run_trace $w $i gate
  done
done
log "TRACE_GATE_DONE (pairs attempted)"

for i in 1 2 3 4 5 6; do
  should_stop && { log "HARD_STOP before interior info pair $i"; break; }
  if [ $((i % 2)) -eq 1 ]; then ORDER="Aoff Aon"; else ORDER="Aon Aoff"; fi
  for w in $ORDER; do
    should_stop && { log "HARD_STOP mid interior info pair $i"; break 2; }
    run_trace $w $i info
  done
done
aa_on
log "TRACE_INFO_DONE"
log "HEAVY_DONE"
