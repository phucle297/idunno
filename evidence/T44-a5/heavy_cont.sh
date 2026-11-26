#!/usr/bin/env bash
# T44 A5 interior-trace continuation (gate pairs 1-6, A3 interleave order). Caller holds the heavy lock.
# Runs only the gate traces that have no INDOOR_TRACE line yet. AA-off via uncommitted override.cfg (deleted on exit).
set -u
F=/home/box/game-factory; G=/home/box/bin/godot
A=$F/repos/idunno-T44-a2; B=$F/repos/idunno-T44-base; E=$A/evidence/T44-a5; P=$E/perf; LOG=$E/heavy.log
log(){ echo "- $(date -u '+%F %T UTC') $*" | tee -a "$LOG"; }
trap 'rm -f "$A/override.cfg"; log "cont: override.cfg removed"' EXIT
log "CONT START A=$(git -C $A rev-parse --short HEAD)"
for i in 1 2 3 4 5 6; do
  if [ $((i % 2)) -eq 1 ]; then ORDER="B Aoff"; else ORDER="Aoff B"; fi
  for w in $ORDER; do
    if [ $w = B ]; then T=$B; L=trace_B_run$i; O=$P/trace-B-run$i; rm -f "$A/override.cfg"
    else T=$A; L=trace_Aoff_run$i; O=$P/trace-Aoff-run$i; printf '[rendering]\nanti_aliasing/quality/msaa_3d=0\n' > "$A/override.cfg"; fi
    if rg -q 'INDOOR_TRACE' "$P/$L.log" 2>/dev/null; then continue; fi
    mkdir -p "$O"; ec=0
    timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path $T --script res://tools/render_indoor_lighting.gd -- --mode=trace --out=$O > $P/$L.log 2>&1 || ec=$?
    if ! rg -q 'INDOOR_TRACE' "$P/$L.log"; then
      log "TRACE $w run$i EXIT=$ec FAIL no INDOOR_TRACE, retry once"
      timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path $T --script res://tools/render_indoor_lighting.gd -- --mode=trace --out=$O > $P/$L.log 2>&1 || ec=$?
    fi
    log "TRACE $w run$i EXIT=$ec $(rg -o 'INDOOR_TRACE overall=\{[^}]+\}' $P/$L.log | head -1)"
  done
done
rm -f "$A/override.cfg"
log "CONT_GATE_TRACES_DONE"
