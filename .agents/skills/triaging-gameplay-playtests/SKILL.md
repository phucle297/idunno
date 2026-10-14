---
name: triaging-gameplay-playtests
description: Turns Disaster Party player feedback, recordings and session logs into reproducible bugs, counterplay issues, balance questions and polish priorities. Use for playtest notes, confusing deaths, ineffective actions or repeated-match feedback.
license: MIT
---

# Triaging Gameplay Playtests

Turn what players experienced into evidence and a focused next investigation, not speculative tuning.

## Intake

1. Load `advancing-disaster-party` and read the relevant `DESIGN.md` rules, active milestone and existing validation. Respect any recorded acceptance waiver; never convert waived or untested human checks into passes.
2. Read the supplied notes/logs/recording. Preserve exact observations and timestamps separately from player explanations and your hypotheses. Missing information is **unknown**, not a guessed value.
3. Capture only available session facts: build/revision, date, duration, platform/input, renderer, player count, dedicated/local mode, same/separate networks, RTT when measured, map/seed, active disasters and rematch number. Do not request credentials or personal information.
4. For new sessions, use the compact template below. For an existing complaint, investigate with available evidence first; ask a focused question only if missing context prevents a useful reproduction.

## Session Template

- **Build and conditions:** version, platform/input, player/network conditions, seed/map, duration/rematches.
- **Focus/hypothesis:** one mechanic or flow and the intended observable outcome.
- **Comprehension:** did players understand the goal, controls, warning and counter? Mark unknown if not observed.
- **Gameplay:** what worked, confusion/friction, and moments of delight, with timestamps where available.
- **Measured data:** deaths/locations/causes, movement/action traces, animation/pose transitions, escape attempts, disconnects and frame timing if actually measured.
- **Findings:** observation, expected behavior, evidence, reproducibility, category, severity and next check.
- **Top priorities:** at most three evidence-backed items; explain why the first matters most.

## Classification

| Category | Evidence and next step |
| --- | --- |
| Bug | An implementation violates its contract: crash, softlock, incorrect authority/HP, failed reset or action. Reproduce on the same build/conditions and inspect code/logs; a suspected bug stays unconfirmed until supported. |
| Design/counterplay | Behavior may match code but players cannot understand or meaningfully respond. Use `designing-disaster-counterplay` to inspect telegraph, routes, action cost and overlap. |
| Balance | Rules are understood and function, but numbers or pacing appear wrong. Compare controlled cases and intended tuning ranges before adjusting values. |
| Polish | Presentation or feedback friction without a demonstrated rule failure. Inspect the affected state; escalate if it hides danger or blocks an action. |

A finding can have a primary category and secondary hypothesis. "Died indoors" does not establish a damage bug: compare contact/height/cover rules and authoritative damage cause. "Controls feel wrong" could mean an input is still accepted, an animation transition is wrong, or a proposed action was not removed everywhere; distinguish these before changing code.

## Reproduction and Prioritization

1. Define minimal steps and expected/actual outcome for each priority. Compare single-hazard controls to overlap, valid versus invalid action, and first match versus rematch. Keep seed and terrain state stable where possible.
2. Use the relevant existing game/test path. Record command, build, logs and positive markers; report script/runtime errors rather than filtering them away. Use real clients when checking networking claims.
3. Rank by harm, frequency and confidence: crashes/desync or impossible survival before speculative polish. Do not elevate one unverified opinion into a universal balance rule.
4. Fix only the authorized/current work unit; queue other findings in the existing active checklist or report them for later scope. Do not create `production/`, a second backlog, or automatic external issues.
5. After a fix, rerun the same scenario and controls. For visual changes inspect rendered captures; for fun/comprehension distinguish actual player feedback from agent interpretation.

## Recording and Output

- Return a concise table: **observation | category | severity | evidence/confidence | repro | next action**; include relevant file/log/recording links.
- Record technical execution in `progress.json`. Record actual user/device/network acceptance in `NEED_REAL_CHECK.md` only through `organizing-phase-tracking`, with build and conditions; automated clients are not human acceptance.
- Update existing phase documents only when there is new actionable evidence. Do not rewrite `DESIGN.md`, close a gate from anecdote, reset phase state or lose unresolved reports.
- State which claims remain unverified. End with one concrete next investigation aligned with the active milestone.

## Provenance

Adapted from [claude-code-game-studios / playtest-report](https://github.com/donchitos/claude-code-game-studios/blob/main/.claude/skills/playtest-report/SKILL.md), inspected 2026-10-14. Replaces upstream slash commands, director gates, shell interpolation and `production/` report paths with Disaster Party's evidence and phase workflow. Copyright and MIT terms: [CCGS-LICENSE.md](../CCGS-LICENSE.md).
