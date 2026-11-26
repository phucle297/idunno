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

Interior trace: 3 pairs started after 4P (B run1 in flight at 16:41:30 UTC / 23:41:30 ICT UTC+7). Not finished; do not treat as passing.
