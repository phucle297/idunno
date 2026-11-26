# T45 A1 PERF_SUMMARY (4P toy_town moving bench, evidence/T44-a3-qa/scripts/perf_bench_moving.gd; xvfb llvmpipe; A=871dca9 B=77b7ae29; interleaved B,A / A,B)
| pair | B avg | A avg | d avg | B p95 | A p95 | d p95 | B prims | A prims |
|---|---|---|---|---|---|---|---|---|
| 1 | 199.83 | 208.14 | +4.2% | 213.23 | 233.00 | +9.3% | 753327 | 754487 |
| 2 | 204.34 | 224.73 | +10.0% | 216.21 | 247.49 | +14.5% | 753327 | 754487 |
| 3 | 197.04 | 194.20 | -1.4% | 212.85 | 207.68 | -2.4% | 753903 | 754487 |
| 4 | 222.39 | 198.61 | -10.7% | 242.75 | 212.22 | -12.6% | 753327 | 754487 |
| 5 | 307.86 | 215.38 | -30.0% | 237.22 | 242.47 | +2.2% | 753327 | 754487 |
| 6 | 201.07 | 201.33 | +0.1% | 219.03 | 214.29 | -2.2% | 753903 | 754487 |

Pairs: 6. Mean of per-pair deltas: avg -4.7%, p95 +1.5%, prims +0.13%.
Means: B avg 222.09 ms / p95 223.55 ms; A avg 207.06 ms / p95 226.19 ms => avg -6.8%, p95 +1.2%.
Gate (mean avg & p95 <= B+10%, prims <= B+5%): PASS
sync_rig micro (x10000, headless; perf/micro_*.log): A w1 0.01507 / w0 0.00751 ms; B w1 0.01442 / w0 0.00527 ms => +0.0007 run, +0.0022 idle ms/call (gate <= +0.05) PASS; OBJECT_COUNT delta 0 both.
Interior trace (tools/render_indoor_lighting.gd --mode=trace): NOT RUN (budget).
Note: B5 contains one 8051 ms hitch frame (max_ms) that inflates B5 avg; excluding pair 5: mean avg +0.4%, mean p95 +1.3% (still PASS). Box TZ data missing: "ICT" stamps in perf_heavy.out are really UTC (06:09-06:27 UTC = 13:09-13:27 ICT).
