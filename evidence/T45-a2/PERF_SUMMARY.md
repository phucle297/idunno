# T45 A2 PERF (4P toy_town moving bench, 3 interleaved pairs, B=f432e8a6 A=this branch worktree; llvmpipe)
| pair | B avg | A avg | d | B p95 | A p95 | d | B prims | A prims |
|--|--|--|--|--|--|--|--|--|
| 1 | 202.11 | 209.00 | +3.4% | 213.82 | 228.04 | +6.7% | 755063 | 754487 |
| 2 | 198.63 | 200.06 | +0.7% | 216.62 | 213.37 | -1.5% | 754487 | 754487 |
| 3 | 199.34 | 206.41 | +3.5% | 222.11 | 224.16 | +0.9% | 754487 | 754487 |

Mean of per-pair deltas: avg +2.6%, p95 +2.0%, prims -0.025% (gate avg/p95 <= +10%, prims <= +0.5%): PASS
Interior trace: NOT RUN (per Architect §5.7 QA runs it or PM/Cat waive).
