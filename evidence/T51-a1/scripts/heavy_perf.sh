#!/usr/bin/env bash
# T51 A1 perf gate: 6 interleaved 4P moving bench pairs (odd B,A / even A,B), B=d2e1e0f3.
# Run as: flock /home/box/game-factory/.heavy.lock evidence/T51-a1/scripts/heavy_perf.sh
# Reuses evidence/T46-a1/scripts/perf_bench_moving.gd (present at both B and A).
set -u
F=/home/box/game-factory
A=$F/repos/idunno-T51
B=$F/repos/idunno-T51-base
P=$A/evidence/T51-a1/perf
G=/home/box/bin/godot
mkdir -p "$P"
log(){ echo "$(date -u -d '+7 hours' '+%F %T') ICT $*" | tee -a $P/heavy.log; }
one(){
  local T=$1 R=$2 PP
  if [[ $T == A ]]; then PP=$A; else PP=$B; fi
  timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path $PP --script res://evidence/T46-a1/scripts/perf_bench_moving.gd -- --label=${T}$R > $P/moving_${T}_run$R.log 2>&1
  log "4P $T run$R exit=$? $(grep -o 'PERF_4P.*' $P/moving_${T}_run$R.log || echo MISSING)"
}
log "HEAVY start A=$(git -C $A rev-parse HEAD) B=$(git -C $B rev-parse HEAD) override_A=$(test -f $A/override.cfg && echo PRESENT || echo ABSENT) override_B=$(test -f $B/override.cfg && echo PRESENT || echo ABSENT)"
for r in $(seq ${START_PAIR:-1} 6); do
  if (( r % 2 == 1 )); then one B $r; one A $r; else one A $r; one B $r; fi
done
python3 - "$P" << 'PY'
import re,sys,pathlib
P=pathlib.Path(sys.argv[1])
pat=re.compile(r"PERF_4P label=\S+ avg_ms=([\d.]+) p95_ms=([\d.]+) max_ms=([\d.]+) draw_calls=(\d+) primitives=(\d+)")
rows=[];out=["| pair | B avg | A avg | d | B p95 | A p95 | d | B prims | A prims | d |","|--|--|--|--|--|--|--|--|--|--|"]
da=[];dp=[];dr=[]
for i in range(1,7):
    v={}
    for T in "AB":
        m=pat.search((P/f"moving_{T}_run{i}.log").read_text(errors="replace"))
        v[T]=[float(x) for x in m.groups()] if m else None
    if not v["A"] or not v["B"]:
        out.append(f"| {i} | MISSING |"); continue
    a,b=v["A"],v["B"]
    d1=(a[0]-b[0])/b[0]*100; d2=(a[1]-b[1])/b[1]*100; d3=(a[4]-b[4])/b[4]*100
    da.append(d1);dp.append(d2);dr.append(d3)
    out.append(f"| {i} | {b[0]:.2f} | {a[0]:.2f} | {d1:+.1f}% | {b[1]:.2f} | {a[1]:.2f} | {d2:+.1f}% | {int(b[4])} | {int(a[4])} | {d3:+.2f}% |")
if da:
    ma,mp,mr=sum(da)/len(da),sum(dp)/len(dp),sum(dr)/len(dr)
    gate="PASS" if ma<=10 and mp<=10 and mr<=5 and len(da)==6 else "FAIL"
    out.append(f"\nMean of per-pair deltas over {len(da)} pairs: avg {ma:+.2f}%, p95 {mp:+.2f}%, prims {mr:+.3f}% (gate avg/p95 <= +10%, prims <= +5%): {gate}")
txt="# T51 A1 4P moving bench (toy_town, 6 interleaved pairs, B=d2e1e0f3, llvmpipe/xvfb)\n"+"\n".join(out)+"\n"
(P/"PERF_SUMMARY.md").write_text(txt); print(txt)
PY
log "HEAVY done"
