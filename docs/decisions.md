# Disaster Party — Active Decisions

No phase is active. Phase9 completed all agent-owned source/local-package gates;
its [checklist](old-docs/phase-9-weather-rockslides/checklist.md),
[decisions](old-docs/phase-9-weather-rockslides/decisions.md) and
[full evidence](old-docs/phase-9-weather-rockslides/progress.json) are archived together.
Root [progress](../progress.json) tracks subsequent authorized release delivery.

Phase10–12 remain planned. The owner subsequently requested "release and deploy after
finish". Ship the validated Phase9 source through the existing main/EC2 workflow and
publish matching GitHub playtest bundles; no capacity/storage change is authorized.
Matching uncommitted Windows/Linux packages and inspected images remain historical
local orb handoff evidence; public delivery must use the committed/deployed revision.
The existing [human acceptance waiver](../NEED_REAL_CHECK.md) remains unchanged;
native Windows/GPU/audio/human/separate-network acceptance is unverified.

## 2026-10-14 — Authorized Phase9 shipment verified

Source [c0a7800](https://github.com/phucle297/idunno/commit/c0a780067c10372ca6676725f03916503994aa5e)
passes staged45-suite/five-network-group/managed20/settings-restart and41 Python tests.
[Existing EC2 workflow](https://github.com/phucle297/idunno/actions/runs/38615376266)
deploys that exact revision with backend readiness; no tests run in deployment.
[Public pre-release](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-c0a7800)
contains exact CI Linux artifact and Windows with byte-exact deployed PCK/refreshed
hashes. All105 local/CI PCK entry payloads match; only container bytes differ.
Three release assets downloaded and compared, tag verified. Exact final-PCK Weather471/
Rock72 and standalone Linux lifecycle pass. Two public exact-PCK clients pass TLS,
tickets/ENet,Ready/Start/ACTIVE,remote movement and404/409 controls; same orb/upstream,
not native Windows/GPU/audio/separate-network human acceptance. Source/failed logs,
images and packages remain under `.amp/in/artifacts/phase9*`; Phase10–12 stay planned.
This documentation-only checkpoint skips CI to avoid a redundant deployment.
