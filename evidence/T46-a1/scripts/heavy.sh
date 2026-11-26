#!/usr/bin/env bash
# T46 A1 heavy: 6 interleaved 4P moving bench pairs, then 3 interior-trace pairs
# (B,A / A,B / B,A). Caller already holds /home/box/game-factory/.heavy.lock.
# B=a42ff032 (repos/idunno-T46-base). override.cfg is NOT used (project.godot msaa_3d=1);
# each pair logs proof that override.cfg is absent + the project.godot msaa line.
set -u
F=/home/box/game-factory
E=$F/evidence/T46-a1
P=$E/perf
G=/home/box/bin/godot
A=$F/repos/idunno-T46
B=$F/repos/idunno-T46-base
mkdir -p "$P"
log(){ echo "$(TZ=Asia/Saigon date '+%F %T') ICT $*" | tee -a $P/heavy.log; }
X(){ timeout "$1" xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$2" --script "$3" -- "${@:4}"; }
proof(){ # $1=tree $2=label
  local t=$1 L=$2 d=$P/proof_$L
  mkdir -p "$d"
  date -u +%FT%TZ > "$d/time_utc.txt"
  TZ=Asia/Saigon date '+%F %T ICT' > "$d/time_ict.txt"
  git -C "$t" rev-parse HEAD > "$d/HEAD"
  if [[ -f $t/override.cfg ]]; then
    echo PRESENT > "$d/override.cfg.status"
    cp "$t/override.cfg" "$d/override.cfg"
  else
    echo ABSENT > "$d/override.cfg.status"
  fi
  rg -n "msaa_3d" "$t/project.godot" > "$d/project.godot.msaa" || true
  sha256sum "$t/project.godot" > "$d/project.godot.sha256"
}
one4p(){
  local T=$1 R=$2 PP
  if [[ $T == A ]]; then PP=$A; else PP=$B; fi
  proof "$PP" "4P_${T}${R}"
  log "4P start $T run$R"
  X 900 $PP res://evidence/T46-a1/scripts/perf_bench_moving.gd --label=${T}$R > $P/moving_${T}_run$R.log 2>&1 || true
  log "4P $T run$R ec=$(rg -c PERF_4P $P/moving_${T}_run$R.log || echo none) $(rg -o 'PERF_4P.*' $P/moving_${T}_run$R.log || true)"
}
log "HEAVY start A=$(git -C $A rev-parse HEAD) B=$(git -C $B rev-parse HEAD)"
# 6 interleaved pairs: odd B,A  even A,B
for r in 1 2 3 4 5 6; do
  if (( r % 2 == 1 )); then one4p B $r; one4p A $r; else one4p A $r; one4p B $r; fi
done
log "4P_DONE"
# summarize 4P
python3 - "$P" << 'PY'
import re,sys,pathlib
P=pathlib.Path(sys.argv[1])
rows=[]
for i in range(1,7):
    rec={}
    for T in "AB":
        t=(P/f"moving_{T}_run{i}.log").read_text(errors="replace")
        m=re.search(r"PERF_4P label=\S+ avg_ms=([\d.]+) p95_ms=([\d.]+) max_ms=([\d.]+) draw_calls=(\d+) primitives=(\d+)", t)
        rec[T]=None if not m else tuple(float(x) if i<3 else int(float(x)) for i,x in enumerate(m.groups()))
    rows.append(rec)
    print(rec)
def pct(a,b):
    return None if not (a and b) else (a-b)/b*100
avgs=[]; p95s=[]; prims=[]
print("| pair | B avg | A avg | d | B p95 | A p95 | d | B prims | A prims |")
print("|--|--|--|--|--|--|--|--|--|")
for i,rec in enumerate(rows,1):
    B,A=rec["B"],rec["A"]
    if not B or not A:
        print(f"| {i} | MISSING |"); continue
    da=pct(A[0],B[0]); dp=pct(A[1],B[1]); dpr=pct(A[4],B[4])
    avgs.append(da); p95s.append(dp); prims.append(dpr)
    print(f"| {i} | {B[0]:.2f} | {A[0]:.2f} | {da:+.1f}% | {B[1]:.2f} | {A[1]:.2f} | {dp:+.1f}% | {B[4]} | {A[4]} |")
if avgs:
    ma,mp,mpr=sum(avgs)/len(avgs),sum(p95s)/len(p95s),sum(prims)/len(prims)
    gate="PASS" if ma<=10 and mp<=10 and mpr<=5 else "FAIL"
    print(f"\nMean of per-pair deltas: avg {ma:+.2f}%, p95 {mp:+.2f}%, prims {mpr:+.3f}% (gate avg/p95 <= +10%, prims <= +5%): {gate}")
    pathlib.Path(P/"PERF_SUMMARY.md").write_text(
        f"# T46 A1 4P moving bench (toy_town, 6 interleaved pairs, B=a42ff032, llvmpipe)\n"
        f"Mean avg {ma:+.2f}% p95 {mp:+.2f}% prims {mpr:+.3f}% -> {gate}\n"
    )
PY

# 3 interior pairs B,A / A,B / B,A
trace(){
  local T=$1 R=$2 PP
  if [[ $T == A ]]; then PP=$A; else PP=$B; fi
  local out=$P/trace-${T}-run$R
  mkdir -p "$out"
  proof "$PP" "trace_${T}${R}"
  log "TRACE start $T run$R"
  X 2400 $PP res://tools/render_indoor_lighting.gd --mode=trace --out=$out > $P/trace_${T}_run$R.log 2>&1 || true
  if ! rg -q 'INDOOR_TRACE' $P/trace_${T}_run$R.log; then
    log "TRACE $T run$R no INDOOR_TRACE, retry once"
    X 2400 $PP res://tools/render_indoor_lighting.gd --mode=trace --out=$out > $P/trace_${T}_run$R.log 2>&1 || true
  fi
  # copy proof next to the trace
  cp -a $P/proof_trace_${T}${R} $out/override_proof
  log "TRACE $T run$R $(rg -o 'INDOOR_TRACE overall=\{[^}]+\}' $P/trace_${T}_run$R.log | head -1 || echo MISSING)"
}
# order: pair1 B,A  pair2 A,B  pair3 B,A
trace B 1; trace A 1
trace A 2; trace B 2
trace B 3; trace A 3
log "TRACE_DONE"
python3 - "$P" << 'PY'
import re,sys,pathlib
P=pathlib.Path(sys.argv[1])
def p95(T,i):
    t=(P/f"trace_{T}_run{i}.log").read_text(errors="replace")
    # INDOOR_TRACE overall={avg=.., p95=.., ...}  -- be liberal
    m=re.search(r"INDOOR_TRACE overall=\{[^}]*p95[=:](\s*)([\d.]+)", t)
    if not m:
        m=re.search(r"overall p95[=:\s]+([\d.]+)", t)
        return None if not m else float(m.group(1))
    return float(m.group(2))
print("# Interior trace (3 interleaved pairs, B=a42ff032)")
ds=[]
for i,order in enumerate([( "B","A"),("A","B"),("B","A")],1):
    b,a=p95("B",i),p95("A",i)
    print(f"pair {i} order={order[0]},{order[1]} B_p95={b} A_p95={a}")
    if b and a:
        d=(a-b)/b*100
        ds.append(d)
        print(f"  delta {d:+.1f}%")
if ds:
    m=sum(ds)/len(ds)
    if m<=10: gate="PASS"
    elif m<=12: gate="NEAR-MISS PASS"
    else: gate="ABOVE +12% (report as-is)"
    print(f"Mean overall p95 delta {m:+.2f}% -> {gate} (gate <= +10%, near-miss <= +12%)")
    pathlib.Path(P/"TRACE_SUMMARY.md").write_text(
        f"# T46 A1 interior trace (3 pairs B=a42ff032)\nMean overall p95 {m:+.2f}% -> {gate}\n"
    )
PY
log "HEAVY done"
