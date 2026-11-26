# T46 A1 4P moving bench (toy_town, 6 interleaved pairs, B=a42ff032, A=ebc5a415, llvmpipe/xvfb)
override.cfg: ABSENT on every run (proof in proof_4P_*/override.cfg.status). project.godot msaa_3d=1.

| pair | order | B avg | A avg | d | B p95 | A p95 | d | B prims | A prims |
|--|--|--|--|--|--|--|--|--|--|
| 1 | B,A | 239.14 | 240.88 | +0.73% | 265.56 | 275.21 | +3.63% | 754487 | 754487 |
| 2 | A,B | 251.78 | 240.32 | -4.55% | 311.30 | 264.02 | -15.19% | 754487 | 754487 |
| 3 | B,A | 253.54 | 245.05 | -3.35% | 292.48 | 262.10 | -10.39% | 754487 | 754487 |
| 4 | A,B | 242.11 | 234.39 | -3.19% | 272.94 | 260.21 | -4.66% | 754487 | 754487 |
| 5 | B,A | 240.97 | 256.94 | +6.63% | 261.17 | 285.07 | +9.15% | 754487 | 754487 |
| 6 | A,B | 263.80 | 236.34 | -10.41% | 301.36 | 260.98 | -13.40% | 755063 | 755063 |

Mean of per-pair deltas: avg -2.36%, p95 -5.14%, prims +0.000% (gate avg/p95 <= +10%, prims <= +5%): **PASS**

## Interior trace (render_indoor_lighting --mode=trace, 3 interleaved pairs)

Order: pair 1 B,A / pair 2 A,B / pair 3 B,A. B=`a42ff032`, A=`61c09bc` (evidence follow-up; same gameplay code as `ebc5a415`). llvmpipe/xvfb. Gate: mean overall p95 <= B+10% (near-miss <= +12%).

**Time stamps:** `heavy.log` and `lock.txt` labels that say "ICT" are actually UTC (box clock is UTC). ICT = UTC+7 is used below.

Lock acquired 16:27:34 UTC = 23:27:34 ICT (UTC+7) 26 Nov; released 22:58:58 UTC = 05:58:58 ICT (UTC+7) 27 Nov.

override.cfg: ABSENT on every trace (`perf/proof_trace_{A,B}{1,2,3}/override.cfg.status`; copies also in `perf/trace-*-run*/override_proof/`). project.godot msaa_3d=1.

Numbers verified from the per-run `INDOOR_TRACE overall={...}` lines in `perf/trace_{A,B}_run{1,2,3}.log` (not only heavy.log).

| pair | order | B p95 | A p95 | d | B avg | A avg | notes |
|--|--|--|--|--|--|--|--|
| 1 | B,A | 358.77 | 368.53 | +2.72% | 392.42 | 723.64 | first try both; A1 avg outlier |
| 2 | A,B | 363.52 | 361.98 | -0.42% | 508.27 | 370.50 | B2: 1 retry (see below) |
| 3 | B,A | 356.03 | 350.19 | -1.64% | 346.63 | 327.29 | A3: 1 retry (see below) |

Mean overall **p95**: B 359.44 ms, A 360.23 ms = **+0.22%** → **PASS** (gate <= +10%).
Mean overall **avg** (informational, not the gate): B 415.77 ms, A 473.81 ms = **+13.96%** (~+14%), driven by A1 outlier avg 723.64 (A1 p95 was still 368.53).

### Retries
The heavy script overwrites the per-run log on retry (`>`), so the failed first tries are recorded in `perf/heavy.log` (and `perf/nohup.out`), not in the final `trace_*_run*.log`.

- **B2 first try:** 18:55:07–19:14:06 UTC (01:55–02:14 ICT 27 Nov, UTC+7) — no `INDOOR_TRACE`. Retry 19:14:06–20:15:28 UTC (02:14–03:15 ICT): p95 363.52, avg 508.27. Confirmed in `trace_B_run2.log`.
- **A3 first try:** 21:04:55–21:58:14 UTC (04:04–04:58 ICT) — no `INDOOR_TRACE`. Retry 21:58:14–22:58:58 UTC (04:58–05:58 ICT): p95 350.19, avg 327.29. Confirmed in `trace_A_run3.log`.

B1, A1, A2, B3 produced `INDOOR_TRACE` on the first try. Proof dirs: `perf/proof_trace_B1`, `proof_trace_A1`, `proof_trace_A2`, `proof_trace_B2`, `proof_trace_B3`, `proof_trace_A3`.
