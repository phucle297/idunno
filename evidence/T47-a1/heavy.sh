#!/usr/bin/env bash
# T47 A1 heavy evidence (caller holds the heavy lock): import both trees, captures A/B, perf pairs.
F=/home/box/game-factory; E=$F/evidence/T47-a1; G=/home/box/bin/godot; S=$E/scripts
A=$F/repos/idunno-T47; B=$F/repos/idunno-T47-base
log(){ echo "$(TZ=Asia/Saigon date '+%F %T ICT') $*" | tee -a $E/heavy.log; }
X(){ timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$1" --script "$2" -- "${@:3}"; }
log "START A=$(git -C $A rev-parse --short HEAD) B=$(git -C $B rev-parse --short HEAD)"
$F/tools/godot-import.sh $A $E/import | tee -a $E/heavy.log; [[ ${PIPESTATUS[0]} -eq 0 ]] || { log IMPORT_FAILED_A; exit 2; }
$F/tools/godot-import.sh $B $E/import-base | tee -a $E/heavy.log; [[ ${PIPESTATUS[0]} -eq 0 ]] || { log IMPORT_FAILED_B; exit 2; }
if [[ "${SKIP_CAPTURE:-0}" != 1 ]]; then
  X $A $S/capture.gd --out=$E/captures --tag=A > $E/capture-A.log 2>&1; log "capture A exit=$? $(grep -c '^shot' $E/capture-A.log) shots"
  X $B $S/capture.gd --out=$E/captures --tag=B > $E/capture-B.log 2>&1; log "capture B exit=$? $(grep -c '^shot' $E/capture-B.log) shots"
fi
if [[ "${SKIP_PERF:-0}" != 1 ]]; then
  for i in 1 2 3 4 5 6; do
    X $B $S/perf_bench_lava.gd --label=B$i 2>&1 | grep -E 'PERF_4P|T47_LAVA' >> $E/perf.txt
    X $A $S/perf_bench_lava.gd --label=A$i 2>&1 | grep -E 'PERF_4P|T47_LAVA' >> $E/perf.txt
  done
  for i in 1 2 3; do X $A $S/perf_bench_lava.gd --label=Az$i --zones 2>&1 | grep -E 'PERF_4P|T47_LAVA' >> $E/perf.txt; done
  log PERF_DONE
fi
log END
