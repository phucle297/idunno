---
name: designing-disaster-counterplay
description: Defines and validates readable hazard counterplay, terrain-aware escape routes and action tradeoffs for Disaster Party. Use when designing or tuning disasters, action removal, collapse, meteor waves or overlapping hazards.
license: MIT
---

# Designing Disaster Counterplay

Make survival choices readable, reachable and authoritative without removing the funny chaos.

## Start from Evidence

1. Load `advancing-disaster-party`; read `DESIGN.md`, the active milestone and relevant rules in the existing code. Do not replace the design bible or create a parallel GDD/story system.
2. Separate the reported symptom from its proposed cause. Reproduce existing behavior before tuning: record seed, map/terrain state, player action, authority, contact, HP changes, damage cause and animation/pose where relevant.
3. State the intended player experience using the project's pillars: survive, move, interact, panic, laugh. Ask only about unresolved choices that materially change the mechanic; do not add speculative progression or infrastructure.

## Compact Mechanic Contract

Record the following in the active decision log/checklist, not a new planning hierarchy:

| Field | Required answer |
| --- | --- |
| Trigger and authority | What begins the effect, which server state validates it, and when it ends |
| Telegraph | What players can see/hear before danger; visibility from the gameplay camera, including overlapping hazards |
| Hazard volume | Terrain-relative footprint, vertical reach, contact rules and boundaries; cosmetic effects are not hit detection |
| Counter | Player input or route, eligibility, benefit, cost and interruption; include animation transition phases when movement has no special action |
| Feedback | How success, rejection and damage cause are communicated; feedback timing is measured, not assumed |
| Escape | A navigable route within the warning window using actual movement, slope, jump and collision limits |
| Tuning | Feel knobs (responsiveness), curve knobs (damage/intensity) and gate knobs (timing/availability), with units and rationale |
| Reset | What is restored on rematch and cleared on death, ragdoll, release or disconnect |

Keep proposed values distinct from measured outcomes. An action animation must not delay or hide server acceptance; fast cosmetic feedback must not promise an action the server rejected.

## Fairness and Combination Audit

- Inspect sightlines, landmarks, chokepoints and alternate paths at ground, indoor and elevated positions. Check the actual mutated/expanded map, not only the original map dimensions.
- Evaluate execution difficulty, knowledge required, resource pressure, time pressure and simultaneous decision load separately. A shorter warning is not a substitute for a readable hazard.
- For each overlap, record **A + B → combined effect → intended? → surviving counter/route**. Test each hazard alone as a control. Do not assume two individually fair hazards make a fair combination.
- Check early versus late intensity, crowding, destroyed routes and newly exposed shelter. Area-aware waves must cap footprint/concurrency when usable area shrinks instead of compounding elapsed-time escalation with zone concentration.
- Look for dominant strategies and traps: unavoidable repeated stun, a counter unavailable from the threatened area, or growth without a new choice. Explain the smallest rule or spatial change rather than adding another system.
- Preserve server-authoritative damage and ownership, bounded physics, readable death causes and rematch cleanup. This skill does not authorize new capacity, deployment or a redesign of match rules.

## Example Investigation: Fire + Flood or Localized Earthquake

Treat flood suppression and earthquake escape as proposed contracts until the active scope defines them and execution proves them. Compare Fire alone with Fire + Flood at matched positions/seed; trace water level, support height, wetness, HP and cause. For localized earthquake danger, trace warned fracture/collapse/debris positions, reachable stable support, controller state and HP cause; do not infer counterplay from screen shake or a static layout.

## Verification and Handoff

1. Run deterministic boundary/control cases: outside/inside the footprint, early/on-time/late response, low/elevated/sheltered terrain, interruption and rematch. Keep only tests of public behavior that catch plausible regressions.
2. Execute real-client checks for authoritative actions and hazard results, including ownership conflicts where relevant. Use existing hazard, map-safety and rematch suites rather than inventing a replacement runner.
3. Render and inspect warning/response/success/failure/overlap states from the gameplay camera. Log whether the counter is actually reachable; screenshots alone do not prove escape or damage rules.
4. Report the contract, before/after evidence, unresolved design choices and exactly one next action. Record executed results in `progress.json`; player comprehension and fun require real playtest evidence, not an automated pass.
5. Load `validating-game-assets` for any mesh, animation, VFX or audio work. Preserve asset provenance and the shared toy-world style.

## Provenance

Adapted from upstream [game-designer](https://github.com/donchitos/claude-code-game-studios/blob/main/.claude/agents/game-designer.md), [level-designer](https://github.com/donchitos/claude-code-game-studios/blob/main/.claude/agents/level-designer.md) and [difficulty-curve](https://github.com/donchitos/claude-code-game-studios/blob/main/.claude/docs/templates/difficulty-curve.md), inspected 2026-10-14. Retains mechanic contracts, tuning categories, spatial fairness and cross-system difficulty review; omits studio orchestration and unrelated progression. Copyright and MIT terms: [CCGS-LICENSE.md](../CCGS-LICENSE.md).
