---
name: reviewing-godot-gameplay
description: Reviews Disaster Party GDScript, scene lifetimes, signals, async work, server authority and performance. Use for Godot gameplay code reviews or hardening changes to controllers, hazards, action removal and rematches.
license: MIT
---

# Reviewing Godot Gameplay

Find concrete gameplay failures in the requested scope; do not turn a review into a general rewrite.

## Context and Scope

1. Load `advancing-disaster-party` and read the active task, `DESIGN.md` and relevant acceptance gates.
2. Read the changed code, its callers, scene ownership and nearby tests. Identify the observable behavior and the authority that owns it before judging implementation details.
3. Check the engine recorded in `progress.json` against the executable used for validation (`godot --version`, or the configured Godot binary). Verify unfamiliar APIs against that version's official documentation; do not import the upstream template's engine pin.
4. Preserve existing project style and wire contracts unless the request changes them. Prefer typed parameters, return values, signals and collections; type inference is acceptable when unambiguous. Do not blanket-convert dictionaries, editor signal connections or working scene layouts.

## Review Checklist

- **Authority:** clients send intent; the server validates movement inputs, health, hazard effects, object ownership, structure changes and winner state. Presentation and cosmetic physics must not become gameplay authority.
- **Scene lifetime:** every allocated Node has an owner/lifetime and is attached or explicitly freed. Check construction without `_ready`, scene departure, peer departure and repeated rematches. Look for stale references, orphan nodes and duplicate listeners.
- **Signals:** typed notifications describe completed changes; synchronous queries use methods. Check duplicate connections and long-lived emitters/listeners. Godot normally removes connections to freed objects; require explicit cleanup only where a surviving object or retained callable makes it necessary.
- **Async work:** after `await`, verify the relevant scene/session generation, target validity and cancellation conditions. Old timers or loading completions must not mutate a new match. A validity check on `self` alone does not prove the session is still current.
- **Resources:** shared data must not accidentally hold per-player or per-match mutable state. Duplicate only what needs independent ownership, accounting for nested resources; do not assume a shallow duplicate isolates everything.
- **Physics and actions:** movement runs at the intended physics cadence; impulses, damage and object forces are bounded. Check removal of obsolete action paths, death/ragdoll release, recovery protection and terrain-relative contact rather than visual overlap.
- **Animation/UI:** feedback follows the actual action state. Transition timing must agree with authority and remain interruptible on death, ragdoll or departure. Visual squash, accessories and animation must not silently alter colliders.
- **Performance:** inspect allocations, repeated lookups, expensive queries and unnecessary processing in hot paths. Cache stable references where useful, but do not retain freed scene nodes. Recommend pooling, threaded loading or GDExtension only after measuring the relevant bottleneck.
- **Rematch reset:** restore structures, hazard state, loose bodies, callbacks, timers and presentation without restarting the application. Preserve the solo-test and simultaneous-elimination rules.

## Verification and Output

1. For a suspected bug, state its failing sequence and run the narrowest existing test or reproduction that exercises it. A code observation is not an executed failure.
2. Use relevant existing suites such as `tests/test_player_integration.gd`, `tests/test_rematch_integration.gd` and the requested hazard suite. Keep legacy action suites only while removal is being validated, then remove stale references with the feature. If engine class caches are missing, import with `godot --headless --editor --path . --quit` first; run script suites with `godot --headless --path . --script tests/<suite>.gd`.
3. When a fix changes shared authority, run the appropriate real-client matrix; do not infer multiplayer readiness from a headless unit suite. For broad UI/session regressions use the existing `tests/run_ui_regression.sh` workflow.
4. For visual changes, render affected states and inspect captures. For profiling, state hardware, renderer, resolution, build, player count and sample conditions; do not promise 60 FPS from source inspection.
5. Return findings as **severity, file/line, failing behavior, evidence, smallest fix**. Separate confirmed failures from unverified risks. If implementing, follow the active-phase evidence workflow; if only reviewing, do not make unsolicited code edits.

## Provenance

Adapted from [claude-code-game-studios / godot-gdscript-specialist](https://github.com/donchitos/claude-code-game-studios/blob/main/.claude/agents/godot-gdscript-specialist.md), inspected 2026-10-14. Removed Claude-specific tools, model selection, approval loops and documentation paths; revised blanket rules for this project's engine and ownership contracts. Upstream copyright and MIT terms are retained in [CCGS-LICENSE.md](../CCGS-LICENSE.md).
