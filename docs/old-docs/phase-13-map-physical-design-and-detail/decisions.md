# Active phase decisions

Phase13 Toy Town follow-up review and shipment are recorded here. Phase12 completed its technical/local-package gates and source
delivery; [decisions](../phase-12-match-powerup-drops/decisions.md) and
[evidence](../phase-12-match-powerup-drops/progress.json) are archived.
Owner-authorized Phase13 is now deployed/published. Root `progress.json` owns delivery boundaries
and the next action; no further deployment is inferred. Dated entries below retain
their original planning/execution context.

## 2026-10-16 — Map audit and proposed Phase13, not implementation

The owner defers the network timeout investigation and asks for a comprehensive
map collision/placement review, then a detailed repair/enrichment plan. The
[proposed checklist](checklist.md) owns
findings D01–D10, area briefs and milestones13.1–13.5. No map source or asset changed.

- Audit both Town and Harbor, including the expanded Town districts; do not scope
  the repair to the reported garage or only inspect collider node counts.
- Garage shelf placement is a real controller-reproduced walk-through defect.
  Relocate it out of the full4 m arrival lane before making it solid; enabling its
  collider in place would convert a misleading obstacle into a blocked refuge route.
- Physical truth comes before detail enrichment. Classify structural surfaces,
  reachable furniture, traversal rails and cosmetic trim; do not globally turn
  every visual detail into a collider. Replace stale canopy proxies rather than
  retaining them as compatibility fallbacks.
- Detail comes from distinct functional interiors and grounded assemblies, not
  a larger population of identical blocks. Preserve open hazard sightlines,
  base-movement escape routes, prop crossing and collapse/rematch ownership.
- A proposed phase is not an active implementation phase. Preserve the earlier
  verification failure/evidence as deferred, keep the human waiver, and do not
  infer commit/push, packaging, deployment or changed hazard rules from this plan.

## 2026-10-16 — Owner narrows to Town and requests expansion/denser infrastructure

This supersedes the earlier both-map implementation proposal, not its audit evidence.
Harbor detail/collision work is deferred. Oracle reviewed the Town builders, current
plan, collapse ownership and route tests; revised contract is checklist§0.

- Propose144×144m greybox, not uniform scale or wider building spacing. Start13m
  pitch instead of15m for8m district buildings, preserving3m clear circulation;
  add four connected functional blocks, candidate19 enclosed buildings total.
- Treat original DESIGN§6 64m footprint as the original slice baseline. Explicit
  owner expansion direction permits a local phase-specific deviation; keep the
  bible unchanged and retain its clearance, style and open-area requirements.
- Replace low slabs over continuous ground with flush pedestrian crossings;
  relocate two breakable traversal roles to real elevated optional footbridges.
  Redesign Civic stairs away from the road, roofwalk rail offsets, curb junctions
  and landings as one circulation layout before decorative work.
- Footprint, collapse cuts, hazard geography and complete refuge paths must move
  together. Oracle identified a source-level Apartments/Market roof crossing of
  seamz20; runtime reproduction remains open. Existing Shop/Hall route checks do
  not establish all-district safety. No hazard damage/count increase is implied.
- Milestone13.1 now starts with topology/expansion greybox;13.4 becomes Town route,
  collapse and crowd acceptance instead of Harbor work. Preserve stable IDs and
  not_run gates; current changes are local planning only, not a redesigned build.

## 2026-10-16 — Implement the approved connected Town layout

The owner's subsequent “commit plan, then do till done” authorizes source delivery,
not public packaging/deployment. The plan is already pushed; implementation adopts
144m extent with13m district pitch,19 enclosed buildings and the open garage.

- New outer stairs are beside building doors, with roof turn landings. Four lateral
  flights connect outer circuit to the two terraces; the civic approach has a
  continuous five-metre road. Compact streets do not imply narrower roofwalk gates.
- Substantial furniture, stair rails, canopy slopes, pool edges and House gable
  slabs have matching collision. The garage shelf moves to its west service bay
  before becoming solid. ParkRamp uses low edge trim rather than a ghost barrier,
  retaining the shared crossing needed by the crate route.
- Bridges are optional raised shortcuts between district roofs and independently
  accessible annexes. Breakage/collapse removes deck AND rails; reset restores both.
  Roof-level Fire anchors preserve rubble ignition at the new bridge height without
  changing damage or vertical ignition rules.
- Town cuts move with layout. Static mesh triangles and rotated box proxies are
  clipped at district planes; retained children keep their own transforms/lifetimes.
  All Town ascent routes are checked across278 legal masks on the two maps, instead
  of treating Shop/Hall as representative of every new neighborhood.
- Rendered four-player software comparison records the cost rather than claiming
  native performance: p95 frame472.88→636.87ms; draws4384→5889; physics p950.95ms
  unchanged; authoritative bodies remain7. No dynamic bodies are added for detail.
  Both llvmpipe runs fail60FPS. Native GPU/audio/human readability remain unverified;
  this is not permission to remove meaningful detail or alter player capacity.
- Final contact probes caught the remaining ghost House gable: rays previously hit
  the flat slab at4.855m despite the higher visible roof. Matching rotated roof
  colliders now return5.39598m on both sampled halves, with a permanent regression.

## 2026-10-16 — Follow-up damaged bridge review

- Reproduced both bridges' damaged-state visual tilt leaving their collider flat:
  four sampled deck contacts diverge, and16 rail meshes retain the intact material.
- Railed bridge decks now stay level through DAMAGED, preserving physical joints
  and rail alignment. Darkening deck and rails together provides the warning;
  other breakables retain the existing tilt telegraph. BROKEN/reset ownership is
  unchanged. Layout6874 and earthquake96 checks pass; all four bridge states were
  rendered with production lighting and inspected.
- Independent nine-district runtime visibility probe found no surviving visible
  mesh accidentally hidden by removal of a neighboring district (zero failures).
  This is a targeted control, not exhaustive proof of every camera/contact case.
