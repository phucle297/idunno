# Active phase decisions

## 2026-10-18 — Outfit selection and four new starter costumes

Owner reports outfit menu cannot select and requests more costumes. Reproduce
pointer routing before changing equip rules. Existing tests call select_outfit
directly and cannot establish mouse usability. Append Chef/Firefighter/Sailor/Pilot
as free starters; preserve eight existing IDs and four earned reward slots.
Use existing procedural toy accessory pipeline, open faces and unchanged physics.
Grid must scroll to keep controls within 720p. No shop/currency/stat changes.

[Phase18 checklist](checklists/phase-18-outfit-selection-and-costumes.md).

Owner additionally requests music in game and menu. Generate two original
instrumental32s themes through deterministic standard-library synthesis, seed297.
Separate Music bus with persisted volume/mute, bounded two-voice interruptible
crossfade, warning ducking, no dedicated/headless music players. Preserve existing
reserved warning/effect pool. New M18.4 precedes final M18.3 integration/delivery.

Actual X11 reproduction confirmed Home intercepted clicks despite Collection's
higher drawing z_index. Move modal to sibling front on opening. A second native
control caught offline Equip waiting on profile HTTP; skip profile refresh outside
profile-enabled sessions, not an equip-authority bypass. Final native outfit/
scroll/Pilot equip/Home/Choose Map/gameplay control passed24 checks.

Owner screenshot inspected separately: the large missing center matches real
district collapse, not weather hiding floor meshes. Focused both-map collapse
5040 controls and static geometry audit found no surviving center static mesh.
A frozen client crate without newer prop snapshots stays suspended by design;
that isolated control is not proof of an actual live-network defect. Do not hide
all airborne props over a void or weaken ordered-stream rematch ownership without
a real replication reproduction. Tree anomaly in the owner's session remains
unconfirmed; no speculative terrain/prop behavior change is included.

Phase17 completed technical gates, source push, deployment and matching prerelease.

- [Phase17 decisions](old-docs/phase-17-continuous-weather/decisions.md)
- [Full chronological evidence](old-docs/phase-17-continuous-weather/progress.json)
- [Completed checklist](old-docs/phase-17-continuous-weather/checklist.md)

Root `progress.json` owns the next action. Existing human acceptance waiver and
unverified native Windows/GPU/audio/separate-network limits remain unchanged.
