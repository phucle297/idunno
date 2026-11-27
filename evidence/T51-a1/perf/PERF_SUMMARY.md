# T51 A1 4P moving bench (toy_town, 6 interleaved pairs, B=d2e1e0f3, llvmpipe/xvfb)
| pair | B avg | A avg | d | B p95 | A p95 | d | B prims | A prims | d |
|--|--|--|--|--|--|--|--|--|--|
| 1 | 229.14 | 236.32 | +3.1% | 259.80 | 322.76 | +24.2% | 754391 | 754391 | +0.00% |
| 2 | 238.77 | 226.96 | -4.9% | 268.10 | 250.12 | -6.7% | 754391 | 754391 | +0.00% |
| 3 | 233.81 | 219.64 | -6.1% | 263.84 | 238.30 | -9.7% | 754391 | 754391 | +0.00% |
| 4 | 216.06 | 216.60 | +0.2% | 232.10 | 231.63 | -0.2% | 754391 | 754391 | +0.00% |
| 5 | 224.70 | 216.01 | -3.9% | 240.53 | 230.86 | -4.0% | 754391 | 754967 | +0.08% |
| 6 | 224.81 | 237.36 | +5.6% | 240.42 | 260.05 | +8.2% | 754391 | 754391 | +0.00% |

Mean of per-pair deltas over 6 pairs: avg -0.98%, p95 +1.96%, prims +0.013% (gate avg/p95 <= +10%, prims <= +5%): PASS

Raw: 12/12 moving_{A,B}_run{1..6}.log each contain exactly one PERF_4P line (6 complete pairs). Pairs 1-3 ran 07:12-07:19 ICT; the box restarted ~07:20 ICT during A run4 (partial log discarded); pairs 4-6 re-ran in full under the heavy lock 07:26-07:33 ICT (see heavy.log).
