# T47 A1 survival / T9 notes
Times in matrix-progress are UTC (add 7h for ICT).

## T9 same-seed replay (t47m1 vs t47m2, seeds 101-110, 2 maps x 4 controls = 80)
See replay_determinism.log: 80/80 selection_history, survived, death cause/disaster, camp_broken equal; max death-time delta 0.0 s; max HP-by-360 delta 0; max alive position delta 0.0 m. Zero deltas on repeat. No re-baseline.

## T3z Hard matrix (t47m1) vs T14 standing (main 27a35bf3), NOT vs f395fe84
A f395fe84 matrix was NOT RUN (one pass is ~15 min, over the 10 min cap). Do not treat T14 deltas as T47-only.

Gates on t47m1 (score-t47m1.log): rooftop camp 10/10 x4 PASS; active_route town 6/10, harbor 10/10 PASS (plan: camp >= 8/10, route >= 6/10). Dead-time pass.

Two outcome flips vs T14, both toy_town active_route, both Flood near 7:30 of the 8:00 horizon, neither is a Volcano death:
- seed 101: T14 dead 447.8 s Flood / T47 survived. Histories match through Earthquake ~336 s, then diverge (T14: UFO 357 s then Bees/Snow/Flood 399-450; T47: Tornado 357 s then Meteor/Flood 361-412). T47 Flood damage 0; T14 Flood 27.9 + Tornado 32.1 + Bees 40.
- seed 106: T14 survived / T47 dead 449.3 s Flood (92 HP Flood). Histories match through first Flood ~170 s, then diverge (T14: Snow/Lightning/EQ/Tornado/Fire/Rockslide, last Flood 451-480 with 43.9 HP Flood and survived; T47: Bees/Lightning/Flood/EQ/UFO..., fourth Flood 406-457).

Volcano vs T14 (not a clean T47 vs base delta): 0 Volcano deaths and 0 Volcano HP in all 80 T47 cells. Of cells with a Volcano in the active history on both sides, start times match 21/21. T47 has Volcano in 29 more cells than T14 (0 the other way) — can be later-main director/viability drift and/or T47's "any valid random site" viability; unattributed without an f395fe84 matrix.

## Interior trace
NOT RUN. Plan budget is hours at T45 rates (>10 min cap this turn).
