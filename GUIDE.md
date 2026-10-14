# Disaster Party Play Guide

This is an unsigned Windows x86_64 playtest prototype, not a Steam release.
Players use the packaged executable; no Godot editor or repository checkout is
needed. Current builds default to dedicated-room create/join by ID;
`https://server.permees.com` is built in. The owner-authorized
[Phase 8 + Solid Environment Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-e68a912)
supplies matching Windows/Linux bundles and deployed server revision
`e68a912a91c6dce339ddb254a559e68be26c53ce`. Download the new Windows ZIP and run
`DisasterParty.exe`; older bundles are incompatible. Public two-client exact-PCK
Linux editor-driven smoke passed, not native Windows/separate-network acceptance.
Task 2.2.7's `94ad2fd` bundles and older `7eb1f25` direct-IP ZIP are historical.
No lobby browser, Steam invites or
NAT traversal is implemented.
Same-PC checks do not prove physical LAN or Internet play.

## Prepare and verify the package

1. Extract the ZIP to a local folder on every PC. Keep `DisasterParty.exe`,
   `DisasterParty.pck`, `BUILD.txt` and `SHA256SUMS.txt` together; do not run from
   inside the ZIP or mix files from different builds.
2. Compare **Source revision** and **Engine** in `BUILD.txt` on every PC.
3. Open PowerShell in that folder and verify the delivered files:

```powershell
foreach ($line in Get-Content .\SHA256SUMS.txt) {
    $parts = $line -split '\s+', 2
    $actual = (Get-FileHash $parts[1] -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $parts[0]) { throw "Checksum mismatch: $($parts[1])" }
}
Get-Content .\BUILD.txt
```

Stop on any mismatch and replace the complete package. Windows may warn about
an unsigned app; verify its source and checksums before choosing to run it.
Do not disable antivirus or firewall protection globally.

## Play alone

Double-click `DisasterParty.exe`, or launch from its package folder:

```powershell
.\DisasterParty.exe --log-file solo.log
```

The solo match starts automatically and continues until death or timeout; having
one player does not immediately declare a winner. The first warning can appear
after about 10 seconds. Use **L** to open the lobby for network play.
Developers can still run `godot --path .`; see `README.md` for build commands.

## Create or join a room

Start the local service as described below, then launch a source client (packaged
Windows commands are in the operator runbook):

```bash
godot --path . -- --room-service-url=http://127.0.0.1:29800
```

1. Press **L** or select **LOBBY**. Enter a custom **ROOM ID** (3–24 ASCII
   letters/digits/hyphens, starting with a letter/digit), or leave it blank when
   creating to receive a generated ID. Case and surrounding spaces are normalized.
2. Optionally enter a password; select **CREATE ROOM**. Share the displayed ID
   and password with friends, not an admission token. Friends enter the same
   ID/password and select **JOIN ROOM**. Joining requires an ID.
3. Every admitted player selects **READY UP**. The first admitted player is
   marked **OWNER** and can select **START MATCH** when at least two players are
   present and all are ready. Guests see waiting text instead of owner controls.
   Owner-only rematch/return controls remain in results; ownership transfers if
   the owner leaves.
4. Lookup errors leave solo gameplay intact and allow correction/retry. If the
   room server disconnects, the client restores its offline lobby; create or
   join again to obtain a fresh ticket. Connecting/admitting has a ten-second
   deadline, separate from the twenty-second HTTP request deadline. Do not retry
   an old token. A restarted service does not retain previous rooms.

Remote operator URLs must use **HTTPS**; plain HTTP is accepted only for the
explicit `127.0.0.1:<port>` development endpoint. The game defaults to
`https://server.permees.com` through `network/room_service_url`; players can run
`DisasterParty.exe` directly without a launcher, `.env`, or network configuration.
Development can override it using `--room-service-url=`. Discovery uses HTTP;
gameplay remains authoritative ENet/UDP. Client and server full revisions must match.
Local loopback and native Windows UI checks are not public routing evidence.

For legacy listen-host development, select **DIRECT IP (DEV)** or launch with
`--direct-ip`. **INTERNET ROOMS** switches back while disconnected. Existing
`--host-port=` / `--join-address=` commands automatically select direct-IP mode.
This is not a way to bypass admission on a managed room server.

## Play with another member on the same LAN

### 1. Prepare every PC

1. Verify the same package revision/checksums on every PC.
2. Connect the PCs to the same trusted LAN; guest Wi-Fi/client isolation can prevent peers connecting.
3. Allow **DisasterParty.exe** through Windows Firewall on the trusted private network when prompted. The host must accept inbound UDP on the selected port; do not change shared firewall policy without permission.
4. Keep UDP port `29730` available.

The host can find their LAN IPv4 address with:

```powershell
ipconfig
```

Use the address shown for the active Ethernet or Wi-Fi adapter, such as `192.168.1.25`. Do not give another PC `127.0.0.1`; that address only works when both processes run on the same PC.

### 2. Start or join in game

Press **L** (or select **LOBBY**) to open the panel; in the new source UI select **DIRECT IP (DEV)** first. The host leaves the default UDP port or enters another port and selects **CREATE**. Each other player enters the host's LAN IPv4 address and the same port, then selects **JOIN**.

Each connected player selects **READY**. The panel lists every player as ready or waiting. When at least two players are connected and all are ready, the host selects **START MATCH** or presses **Enter**.

You can also launch directly from PowerShell. To host:

From the package directory in PowerShell:

```powershell
.\DisasterParty.exe --log-file host.log -- --host-port=29730
```

The host still uses the in-game lobby to mark ready and start the match.

Replace the sample address with the host's LAN IPv4 address:

```powershell
.\DisasterParty.exe --log-file client.log -- --join-address=192.168.1.25 --join-port=29730
```

The client marks ready in the in-game lobby and waits for the host to start the match.

Engine flags such as `--log-file` go **before** `--`; game/session flags go
**after** it. For two processes on one PC, join `127.0.0.1` instead. That tests
localhost transport only, even when using Windows executables.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Orbit camera |
| Shift | Sprint |
| Space | Jump |
| C | Crouch |
| F | Grab or release a nearby physics crate |
| L | Toggle the direct-IP lobby panel |
| R | Trigger the current knockdown test |
| Escape / controller B | Open local pause; Back from settings; Resume from pause (match keeps running) |
| Left click | Recapture the cursor |
| Q / E | Previous/next spectator target after death |

The HUD shows health at bottom-left, match time at top-center, and alive players at top-right. Large centered text names active disaster warnings.

When a match ends, every peer sees the same ranked results with winner, survival time, disasters survived, damage taken, and death cause. Gameplay HUD and local gameplay input are suppressed, and the cursor is released. The host selects **REMATCH** or presses **Enter** to start another round; clients remain connected and display **WAITING FOR HOST TO START REMATCH**. Tab or controller left/right moves between rankings and available actions; controller A confirms.

The host can instead select **RETURN TO LOBBY** to bring the session back to readiness without disconnecting anyone. All players must ready up again before the host starts. Solo results offer the same two actions; the returned offline lobby includes **START MATCH** to resume solo play. Every peer can open **SETTINGS** from results or the local pause menu. Master, effects and warning volume, mouse sensitivity, invert-Y, camera shake, fullscreen and reduced motion save automatically across restarts. Opening the menu blocks only your input: hazards, networking and the match timer keep running. Reduced motion disables UI transitions and camera shake; warning identity and audio remain available.

**Windowed Resolution** selects client-window pixels: 1280×720, 1366×768, 1600×900, 1920×1080 or 2560×1440 when the desktop and native window frame fit. Smaller displays get a fitting fallback. Manual sizes are remembered as custom choices; changing audio/input settings does not undo resizing. The selector is disabled in fullscreen, and returning to windowed restores the last windowed size. This is not internal render scaling.

Warnings, impacts, jumping, death, and victory have synthesized placeholder audio. Flood, Meteor, and Tornado use distinct warning cues. Warning audio has a reserved voice so overlapping impact effects cannot silence it.

## Disaster timing

- About **0:10**: the first Meteor or Flood warning can begin.
- Before **2:00**: one Meteor or Flood runs at a time.
- At **2:00**: Tornado, Earthquake, and Lightning become eligible.
- At **5:00**: two compatible disasters can overlap, but only after both have completed alone at least once.
- At most two disasters overlap in the current prototype.

Implemented disasters are **Meteor Shower, Flood, Tornado, Earthquake, Lightning, and Fire**.

- **Flood:** ordinary water does not damage you while your head remains above the surface. A bottom danger card distinguishes wading, the two-second breathing grace, and `DROWNING` at 12 HP/s, with a head-above-water escape instruction. There is no full-screen blue overlay. Electrified water is a separate danger: even shallow foot contact causes damage, so leave the water entirely.
- **Flood + Lightning:** a strike in active floodwater electrifies the connected water for three seconds. Violet ripples and the `ELECTRIFIED WATER` warning identify it. Get onto raised ground immediately.
- **Tornado + Fire:** Tornado wind doubles Fire's spread frequency and carries one visibly flaming debris body. Keep away from both the funnel and orange Fire-zone rings.

Earthquake, Lightning, and Tornado become eligible as intensity rises after 2:00. Fire and two-disaster overlaps unlock at 5:00. A disaster must complete alone before the director can use it in an overlap.

To inspect the implemented visuals immediately without waiting for normal match timing, launch one of these local demo states:

```powershell
.\DisasterParty.exe -- --meteor-demo
.\DisasterParty.exe -- --flood-demo
.\DisasterParty.exe -- --flood-grace-demo
.\DisasterParty.exe -- --flood-damage-demo
.\DisasterParty.exe -- --tornado-demo
.\DisasterParty.exe -- --earthquake-demo
.\DisasterParty.exe -- --lightning-demo
.\DisasterParty.exe -- --fire-demo
.\DisasterParty.exe -- --electric-flood-demo
.\DisasterParty.exe -- --fire-tornado-demo
.\DisasterParty.exe -- --overlap-demo
.\DisasterParty.exe -- --results-demo
```

These are presentation/debug launches, not accelerated competitive matches.

## Current multiplayer limitations

- Source-project localhost sessions are validated. The package has passed standalone Windows launch; physical two-PC LAN and Internet play remain unverified. Do not infer these from native editor-driver checks against the exported PCK. Internet play may require UDP forwarding; router/shared-network changes require permission and are not part of the LAN smoke check.
- The host owns match state, health, movement, disasters, and winner decisions.
- There is a packaged Windows build, but no public lobby browser, Steam integration or NAT traversal; create/join uses direct IP.
- Only the host can initiate a network rematch; readiness is required before the initial network match, not between rematches.
- Audio is synthesized placeholder content rather than final authored sound design.

## Troubleshooting

- **Can connect but match does not start:** every player must select **READY**, then the host selects **START MATCH** or presses Enter.
- **Cannot connect:** verify host LAN IPv4, matching UDP port, matching package checksums, private-network firewall permission and Wi-Fi isolation. Room and direct-IP joins return to offline play if admission has not completed within 10 seconds. A failed join restores editable lobby fields; correct them and select **JOIN** again (room retries request a fresh ticket). Room-service HTTP lookup has a separate 20-second timeout before UDP joining begins.
- **Host disconnects:** clients return to an offline lobby with cleared remote players and hazards. Restart/create the host, then use **JOIN** to retry. There is no host migration or automatic competitive-match resume.
- **Files/resources missing or build identity wrong:** re-extract the complete package, keep PCK beside EXE and rerun checksum checks. Do not repair a package by copying individual files from another revision.
- **Need logs:** launch with `--log-file host.log` / `client.log` before `--`; attach both logs and `BUILD.txt` when reporting a failure. The startup `DISASTER_PARTY_BUILD` line must agree with the build notes.
- **No disaster yet:** wait at least 10 seconds after the host starts the match. Overlap intentionally does not unlock until 5 minutes.
- **Mouse does not rotate the camera:** left-click the game window to capture the cursor.
- **HP is not changing:** damage only occurs when a disaster actually reaches the player; HP starts at 100.

## Physical LAN checklist (optional legacy-path coverage)

Use **two separate Windows PCs**, the same package, and the host's LAN address—not
localhost. This requires an actual person/PC session; automation cannot certify it.
The former mandatory LAN task was cancelled in favor of Internet-room readiness;
this checklist does not validate the planned room service or dedicated servers.

- Record date, revision/checksums, host/client OS/GPU, resolution, network type,
  input devices, UDP port and logs. Keep private IPs/logs private when sharing publicly.
- Join, compare both rosters, ready both players and start from the host. Confirm
  clients cannot start; move both players and contend for/release a prop.
- Observe actual warnings and damage, death/spectating where survivors remain,
  and matching results. Complete **five host-initiated rematches** without restarting
  applications; check restored health/players/props and cleared stale hazards.
- On each PC, edit settings, close/relaunch, and verify persistence. Listen on real
  output devices: independent warning/effect volume and warnings during impacts.
  Record loudness/clarity complaints; WASAPI initialization alone proves neither.
- Close the host, observe client lobby recovery, recreate it and retry from the
  same client. Also try an unavailable port and confirm actionable failure/retry.
- Record pass/fail and reproduction details for each item; leave unavailable
  checks unverified. Baseline human research now requires the planned Internet
  readiness gates, not a localhost-only or legacy LAN claim.

## Developer checks against the exported payload

The release template does **not** execute external `--script` fixtures. The
following uses the matching native Windows **editor** only as an external driver
for the exact shipped PCK (no source-project `--path` and no tests added to the
package). It covers settings restart/routing, session state, room/direct-IP
failure and retry, and five rematches. It also launches the exact release EXE
separately for a headless startup/identity check. Service error mappings are
injected responses; UDP connection failures and disconnects use local ENet
fixtures. These checks do not replace release-runtime UI, physical LAN/audio
or public Internet testing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run_windows_package_checks.ps1 `
  -PackageDir C:\playtest\DisasterParty `
  -GodotEditor C:\tools\Godot_v4.7.2-stable_win64.exe `
  -OutputDir C:\playtest\checks-new -Port 29740
```

Run from the development checkout. Use the editor executable directly, not its
`_console.exe` launcher, and place it on a Windows-local drive rather than a WSL
UNC path. Output must be a fresh directory. The policy
override applies only to this process, not the machine. Logs identify the payload,
engine, test markers and evidence limitations; keep any failed checks visible.
Checksums must match before the game is launched. `release-startup.log` records
the release process separately from the editor-driven checks; `room-retry.log`
and `room-ui-*-1280x720.png` record recovery assertions and rendered states.

## Local room-service development (source checkout only)

Tasks 2.2.4/2.2.5 add the allocator/admission backend and room-ID client UI,
not a new release package. Python 3.10+ (standard library only) and Godot 4.7.2
are required. From the checkout on Linux:

```bash
godot --headless --editor --path . --quit
python3 tools/room_service.py --godot "$(command -v godot)"
```

The HTTP service listens only on `127.0.0.1:29800`. Defaults allow four rooms,
each with eight player slots, on UDP ports `29810–29813`. These are conservative
configuration limits, not measured production capacity. Ctrl+C/SIGTERM stops
all managed servers and deletes their private configuration files. A crashed
service loses its in-memory registry; old servers fail closed after eight seconds
without a successful heartbeat. Clients must create/join again with new tickets.

Create and join use POST JSON. Both require `protocol: 1` and the exact server
`build` (`development` for this source checkout):

```bash
curl --fail-with-body http://127.0.0.1:29800/v1/rooms/create \
  -H 'Content-Type: application/json' \
  -d '{"protocol":1,"build":"development","room_id":"FRIENDS-42","password":""}'
curl --fail-with-body http://127.0.0.1:29800/v1/rooms/join \
  -H 'Content-Type: application/json' \
  -d '{"protocol":1,"build":"development","room_id":"friends-42","password":""}'
```

IDs are trimmed/uppercased, 3–24 ASCII letters/digits/hyphens with an alphanumeric
first character. Empty/omitted create ID generates an eight-character ID. IDs
are locators, not secrets. Optional passwords are stored as salted scrypt hashes;
do not put real passwords in shell history. Responses contain `room_id`,
`address`, UDP `port`, `protocol`, `build`, a single-use `token`, and `expires_in`
(20 seconds by default). Outstanding tickets reserve player slots. Expired
tickets free their reservations. Use a new ticket for every connection attempt.
Tokens are room-instance-bound and hashed in memory; never publish them in logs.

The room UI obtains a ticket and passes it to `join_game(address, port, token)`;
the HTTP client never owns match simulation. Managed servers authenticate through
Godot's ENet pre-registration hook. Raw direct-IP clients cannot bypass it.
Unmanaged `--server-port=` remains an **unauthenticated development mode** and
must not be exposed publicly. Room owner is the first admitted player, not
necessarily the creator if the creator has not connected yet.

### Phase 6 profile foundation (Task 6.1.1)

Profiles are **opt-in, local-validation only** at this stage. They authenticate
Create/Join Room and admission tickets, reward grants, collection and equipment.
Existing room operation is unchanged when `--profile-store` is omitted; profile requests then
return `profiles_unavailable` (503). No shared service/proxy has been changed.

For local development, choose a new private directory outside the checkout's release
trees and disposable room files. The parent must already exist; do not use the database
or credentials as review artifacts or commit them. Example local service configuration:

```bash
install -d -m 700 "$HOME/.local/share/disaster-party-profiles"
python3 tools/room_service.py --godot "$(command -v godot)" \
  --profile-store "$HOME/.local/share/disaster-party-profiles/profiles.sqlite3"
```

The profile POST JSON endpoints require `protocol: 1` and the exact service `build`:

- `/v1/profiles/create`: body contains only `protocol` and `build`. Returns a
  service-issued `profile_id`, a one-time returned 256-bit bearer `credential`, four
  owned starters (`plain`, `cap`, `hard_hat`, `backpack`), equipped `plain`, and
  initial `pending: []`. Client-supplied identity/ownership/equipment is rejected.
- `/v1/profiles/fetch`: body adds only `profile_id`; send the credential in the
  `Authorization: Bearer …` header, never the URL or a roster. Returns authoritative
  state without credential/hash. Wrong/missing/another profile's credential returns
  the same `invalid_profile_credentials` (403).
- `/v1/profiles/open`: body adds `profile_id` and `box_id`; Bearer authentication
  opens only that profile's saved box. See [opening](#authenticated-box-opening-task-623).

All use the existing 2 KiB body cap, 32 workers, 30 requests/minute backend backstop,
build checks and `Cache-Control: no-store`. Remote operation requires HTTPS termination;
HTTP is only for loopback validation. A later separately approved proxy change must
allowlist these exact routes and redact Authorization/request/response bodies. Current
public route policy is unchanged; do not expose `/internal/*` or enable profiles remotely.

Schema 2 uses SQLite transactions to create profiles/starters and persist round/reward
receipts atomically. Valid schema-1 stores upgrade transactionally without resetting
identity, ownership or equipment. The durable ledger stores credential and room-instance
key hashes, not raw secrets. Store files are mode 0600;
an existing corrupt, incomplete or unsupported schema stops startup nonzero with
`PROFILE_STORE_STARTUP_FAILED`, without resetting its contents. Missing/unreadable/locked
storage during requests returns `profile_store_unavailable` (503), not empty ownership.
An existing zero-byte file is not treated as a new database. Profile disk I/O does not
hold the room registry lock. Rooms/tickets still disappear on service restart; profiles
persist only if the same durable store and credential are retained.

`game/session/profile_client.gd` is the credential owner used by room discovery.
It creates/fetches a profile through `ensure_profile()`, emits credential-free state or
a failure, refuses remote HTTP and redirects, and saves only service URL/ID/credential
to `user://profile-<service-URL-SHA256>.json`. A temporary file is flushed and renamed,
with owner-only Unix permissions set before secret bytes are written. On Windows it
relies on the OS user-data directory ACL; native Windows ACL behavior is unverified.
Credentials are bearer secrets, not encrypted locally. Separate services get separate
files. Invalid saved files/rejected credentials are preserved, not silently replaced.
No automatic cloud/device recovery: deleting/losing that file loses access to its profile.
A lost create response can leave an inaccessible empty starter profile; no reward is
granted and no recovery guarantee is implied. Never print/copy credentials into logs,
shell arguments, bug reports, exports or screenshots.

For backup/restore, stop a **local** service and all its room writers before copying
its SQLite file, or use SQLite's online backup API into a new private file; never
copy a live database with ordinary `cp` (journals/WAL may hold committed data).
Keep backups outside release trees, mode 0600 in a mode-0700 directory. Verify the
backup's `PRAGMA quick_check` returns `ok`, `PRAGMA foreign_key_check` returns no
rows and `PRAGMA user_version` matches the intended code. Restore only while all
writers are stopped: preserve the current store first, then install the verified
backup at the configured path with the service user's ownership and permissions.
Do not mix database and journal/WAL files from different snapshots. Check a private
restored copy with matching code and the same disposable test credential before
resuming service; never put credentials or database contents in reports.
Back up before first starting the upgraded local service: schema 1 → 2 is automatic.
Older schema-1-only code rejects schema 2; there is no down-migration or lossless rollback
of new reward receipts. Keep a pre-upgrade backup and matching code, but never restore
it over newer shared data without approval and an explicit receipt-loss decision.
Opening/equip use the existing schema 2: a rollback to schema-2-capable code must
also understand every persisted catalog ID and receipt state; a matching schema
number alone does not establish catalog/client compatibility.
Do not delete shared data, migrate/deploy/restart a shared service or replace a damaged
store without separate approval. See [transactional grants](#transactional-reward-grants-task-622).

### Identity-bound room admission (Task 6.1.2)

With `--profile-store`, both room routes require a validated `profile_id` in the
body and matching `Authorization: Bearer …` header. Missing identity returns
`profile_required` (403); invalid credentials return `invalid_profile_credentials`
(403), and unavailable storage returns 503. There is no anonymous fallback.
The shipped room client responds to that explicit challenge by securely creating
or fetching its service-scoped identity and retrying the lookup. Profile-disabled
services retain their existing development behavior without creating a profile.
Direct-IP/player-hosted sessions remain unauthenticated and cannot earn future rewards.

One profile may have **one outstanding ticket or active peer** across the service's
rooms. Duplicates return `profile_in_use` (409); a copied credential does not grant a
second seat. Creating a room reserves the identity atomically before process startup;
startup failure releases it. A returned ticket gets the full configured TTL after
startup. Cancellation/lost responses retain their reservation until expiry rather
than minting another identity. Leaving an admitted room releases it through the
next heartbeat; failed/incomplete authentication reservations expire after six seconds.

ENet sends only the short-lived single-use ticket, never the durable credential.
Consume resolves the identity from that ticket, ignoring any supplied profile ID,
and returns it only to the authenticated room process. Godot retains peer-to-profile
bindings server-side, clears them on disconnect/auth failure, and ignores stale
HTTP callbacks for replaced authentication requests. Public tickets, gameplay/roster
snapshots, room configuration and client logs contain no durable profile credentials.
Old room keys cannot act on replacement instances; heartbeat cleanup in one room
does not erase another room's newer reservation. Dedicated peer relay stays disabled.

Real HTTP/ENet tests cover malformed/wrong-profile credentials, concurrent duplicate
reservations, active duplicates, replay/wrong-room/expiry, cleanup and two actual
lobby clients performing Ready/Start/crash/retry with distinct retained identities.
Integrated service/client restart and isolation also pass Task 6.1.3 below.
The unchanged 30-request/minute per-address backstop includes profile requests;
large same-address cold starts are not proven profile-enabled capacity. No proxy,
shared store, deployment, release or Windows ACL change has been performed.

### Profile restart and isolation (Task 6.1.3)

Milestone 6.1 is validated on the local Linux/Godot stack. The combined lifecycle
uses actual lobby controls, stops the real service with an admitted client, then
starts fresh service/client processes on the same endpoint/store. The client restores
the exact credential and server-owned starter state. A non-default saved `cap` fixture
distinguishes restoration from silently resetting to `plain`; it is not an equip API.
A second profile remains independent. Old rooms disappear, solo retry returns, and
an unused old ticket fails against the recreated same-ID/same-port room while its
original TTL is still valid. New authenticated Create/Join succeeds.

Keep these two pieces together across local restarts:

- **Service:** the operator-selected SQLite file outside temporary room and
  release directories. Back up only after stopping the local service; retain mode0600
  and its private parent. Retain the complete database, not just a copied profile ID.
- **Client:** its private `user://profile-<service-URL-SHA256>.json` file and the exact
  service URL (normalized by removing the trailing slash). A different endpoint/port
  gets a different default identity file; copying a file for another URL is rejected.

Restarting does not require an identity reset. Invalid local JSON, rejected credentials
or damaged/unavailable storage fail visibly and must not be deleted to make retry work.
Deleting the client file creates a new identity on the next successful lookup and loses
access to the old profile; it does not delete or transfer server ownership. Deleting or
replacing a service store is not a supported reset/recovery operation. Recover a local
damaged file only from a verified private backup; shared writes/restarts need approval.
No cloud recovery or cross-device account system exists. Copying a valid bearer file
transfers access, subject to the same one-ticket/one-peer restriction.

The original 21-test identity-foundation suite verifies restart, wrong-profile/corrupt-file rejection,
unchanged victim state, no replacement profiles and no credentials/tokens in logs.
Temporary fixture reports are private and deleted, not exports or review artifacts.
Those foundation checks did not implement rewards; task 6.2.2 adds sealed receipts below.
Box opening is implemented below; equip mutations remain unimplemented. No new
Windows ACL, public-Internet, hardware-performance, package or deployment claim follows
from these local restart checks.

### Transactional reward grants (Task 6.2.2)

Only the managed profile-enabled authority calls loopback `/internal/round/start` and
`/internal/round/finish` with its private room key. Never expose those routes publicly.
Starts persist a unique ID, hashed instance, sequence, authenticated roster and match
duration. Finish validates that binding and all participation facts. It atomically stores
the canonical completion, one receipt per round/profile, and private item reservations.
Identical replay returns the saved response; conflicting evidence cannot reroll.
SQLite work runs outside the room registry lock, including when the store is busy.

Standard 600-second matches may finish early through normal gameplay. A round needs
at least two distinct start profiles and 120 seconds elapsed; each recipient needs
60 seconds alive/connected ACTIVE play and no live departure. Eliminated players may
depart without forfeiting. Solo, short/nonstandard rounds and live departures record
explicit no-drop reasons. Winners do not improve odds. Each eligible profile receives
one free sealed box while an unowned/unreserved outfit remains. Version-1 earned IDs
are `raincoat`, `mechanic`, `park_ranger`, `meteor_observer`; the four starter IDs remain
unchanged. These IDs establish the ledger contract, not new visual assets.

Selection is uniform among the remaining outfits and saved at grant time. Each sealed
receipt exposes its `box_id`, `round_id`, `state`, `catalog_version`, grant-time `pool`
and exact `odds` numerator/denominator (1/4, 1/3, 1/2, 1/1). It does not expose the
reserved item or add it to `owned`. Authenticated profile fetch returns pending boxes
after reconnect/service restart; fetch itself never opens or equips them.

Godot retains frozen completion envelopes across rematches and retries transport/5xx
failures while the room lives. Issuance is ordered; a lost start reply can recover the
durable ID after a newer start. Invalid evidence is unavailable, not a local grant.
Committed receipts survive restart, but unreported/uncommitted completions are not
recoverable after room death. A restarted service rejects the old room key/registry.
No UI, remote store migration, proxy change, deployment or release is implied.

### Authenticated box opening (Task 6.2.3)

`POST /v1/profiles/open` requires Bearer authentication and exactly `protocol`, `build`,
`profile_id`, `box_id`. The box must belong to that identity. One immediate SQLite
transaction adds the previously reserved item to ownership and marks the box opened.
Opening does not select an item or change saved odds. Concurrent requests and later
replay return the same immutable receipt, including `cosmetic_id` and grant-time pool.
Wrong-profile/unknown boxes reject without revealing their contents.

If a reply is lost, retry the same box ID. Authenticated fetch restores ownership and
remaining sealed boxes after client/service restart. Fetch never creates a replacement
identity, opens boxes, or equips an outfit. Skipping presentation cannot lose committed
loot. The service store and original credential are both required for recovery.

### Collection, reveal and lobby equipment (Phase 6 source builds)

Open **COLLECTION** from the lobby or results to browse owned/locked outfits and
their preview. Offline play offers the four starters only; it neither grants boxes
nor treats offline choices as durable service ownership. Cosmetics do not change
hitboxes, movement or reward eligibility. The published Phase 5 package above does
not include this new source UI.

Select a sealed box to inspect its saved grant-time pool and equal odds, then choose
**OPEN FREE BOX**. There is no purchase, rarity tier, duplicate or reroll: owned
outfits and other sealed reservations are excluded at grant time. Once all rewards
are owned/reserved, there is no new drop. Reveal follows the committed receipt;
**SKIP** or reduced motion changes presentation only. Retry a lost reply using the
same box, or refresh the profile to recover ownership.

Select an owned outfit and **EQUIP** in the lobby. Managed equipment requests are
bound to the actual ENet sender's admitted profile, not a client-selected identity.
The authority validates ownership and lobby state, persists the change, then
acknowledges it before the roster/visuals update. Wait for that acknowledgement;
equipment is not a local optimistic grant. No midmatch equipment change is allowed.
Results can show the collection, but return to lobby before equipping.

Anonymous credentials are service-scoped bearer secrets, not accounts: there is no
password reset, account linking, trading or cross-service transfer. Keep the private
client credential file and durable server store; losing either can lose access to
earned outfits. A copied credential can impersonate its owner, and one profile
cannot occupy multiple rooms/tickets simultaneously. Do not delete a rejected file
to fix a timeout; retry or restore a verified private backup.

For a future separately approved HTTPS rollout, allowlist POST
`/v1/rooms/create`, `/v1/rooms/join`, `/v1/profiles/create`,
`/v1/profiles/fetch` and `/v1/profiles/open` only. There is no public equip route:
`/internal/equip` and all other `/internal/*` remain loopback/private-room-key only.
Keep Authorization and bodies out of proxy logs and retain edge limits. Configure
`--profile-store` to a separate durable SQLite path outside versioned bundles and
disposable room directories; Linux bundles need their matching `room_service.py`
and `cosmetic_catalog.json` as well as executable/PCK. Export committed HEAD only,
with fresh output directories and matching Linux/Windows revisions/checksums.

Phase 6 completed local packages and persistent-store lifecycle checks; see the
[archived evidence](docs/old-docs/phase-6-cosmetic-loot-box-drops-and-customization/progress.json)
and `.amp/in/artifacts/phase6-packages/PLAYTEST-NOTES.md`. Repeated per-platform
exports and cross-platform PCK match. Standalone Linux restart restores earned
ownership/equipment and identical opening replay after synthetic authenticated completion.
No new remote deployment, shared-store mutation or release occurred. Historical
deployment evidence and outstanding human/hardware acceptance (including existing
waivers) remain unchanged. Profile-enabled 4/8/20 loopback validation is not public
multi-room capacity evidence; llvmpipe p95 measurements did not meet 60 FPS.

Errors use an HTTP status plus JSON `error`: invalid input (400), bad password
(403), unknown room (404), duplicate/full/incompatible/active match (409), rate
limit (429), capacity/startup failure (503). Join is lobby-only. Player counts,
joinability and startup readiness are reported by authenticated loopback
heartbeats. Empty rooms expire after 60 seconds once reservations are gone;
dead or unresponsive processes are removed and their ports reclaimed.

Run the executed local backend tests separately from gameplay regression:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_room_service.py -v
GODOT_BIN="$(command -v godot)" tests/run_ui_regression.sh
```

Public operation is **not configured or approved**. A future HTTPS reverse proxy
must expose only `/v1/rooms/create` and `/v1/rooms/join`, never `/internal/*`, and
apply per-client IP limits at the edge (the backend sees the loopback proxy IP
and has a conservative 30-request/minute backstop). Request bodies are capped
at 2 KiB and concurrent HTTP workers at 32. Only operator-owned executable/path
configuration is launched, without a shell. Private per-room credentials use a
mode-0600 file in a mode-0700 temporary directory. Do not enable proxy body
logging. Public DNS/TLS/firewall/UDP changes require approval and actual remote
Windows validation in Task 2.2.7. HTTPS does not encrypt ENet gameplay traffic;
this prototype does not promise gameplay transport confidentiality.

## Local container network validation (Task 2.2.6)

Requirements: a running local Docker daemon, Docker Compose, and the verified
Linux x86_64 Godot 4.7.2 executable. From the checkout:

```bash
GODOT_BIN="$(command -v godot)" bash tests/run_container_network_test.sh
GODOT_BIN="$(command -v godot)" python3 tests/run_managed_container_test.py
```

The runner builds a Debian/Python dependency image, mounts the engine and source
read-only, and prepares a private import cache/preferences in every container.
It starts two dedicated development servers on the same UDP port in different
containers, with one owner and one guest container per room. Import preparation
finishes before network deadlines start. An internal Docker bridge provides
separate client addresses and DNS names; no host ports are published.

Each room must pass authoritative movement, exact two-player rosters, consistent
winners, five rematches and server-close/offline recovery. The runner also runs
the existing room-service HTTP/ENet failure/admission tests, dedicated ownership
contract and 4-/8-/20-player source scale matrix inside one additional container.
Those regression peers use container-local loopback, **not** separate container
addresses. Logs are retained under `.scratch/container-network/`. Exit status,
positive markers and network script/runtime errors are checked; existing
shutdown-only resource-in-use diagnostics are reported, not silently fixed.
The runner removes its own containers/network when it exits and leaves the
local image cached. Do not run two copies concurrently with the same Compose
project name.

The managed runner adds the real allocator/admission implementation with two
simultaneous four-player rooms, then two eight-player rooms. Each player has its
own container address. HTTP requests originate from a client container; private
server heartbeats remain on service-container loopback. A test-only bridge HTTP
listener exposes the same handler and rejects remote `/internal/*` requests.
Production loopback binding and HTTPS-only client UI are unchanged. No host ports
are published, and the command never configures a public server.

Checks include distinct rosters, asymmetric 17-HP damage and Flood/Meteor state,
matching winners, five rematches per room, real non-owner RPC rejection, owner
transfer, full room/service capacity, invalid admission followed by valid retry,
server crash, heartbeat outage, service restart, rejection of an unused old ticket
within its TTL, empty-room expiry and port reclamation. Test control files are
local fixture machinery, not gameplay RPCs or shipped client/server features;
never use these external test drivers in a public deployment.

The managed service plus both game processes share a **2-CPU / 1-GiB** container
budget. Every client has a separate 1-CPU / 1-GiB ceiling. Profiles record 120
warmup ticks then 600 samples with actual map physics and Flood/Meteor overlap,
three Docker CPU/RAM samples, and ENet RTT. Per-run logs and `metrics.json` are
under `.scratch/disaster-managed-<pid>-4/` and `-8/`. The runner rejects unexpected
Godot errors and Python tracebacks and cleans only its uniquely named containers
and internal network. Images and evidence remain local.

Use **two rooms with four players each** as the conservative initial local-test
limit (`room_service.py --rooms 2 --players 4`), not the default configuration
ceilings or a production concurrency promise. Eight-player rooms are additional
stress coverage. WSL measurements distinguish physics work from tick cadence:
sub-budget physics does not establish perfectly paced 60-Hz ticks, 60-FPS client
rendering, or Internet latency. Re-measure on the approved deployment hardware
and real network before raising limits. Public routing, release clients,
physical audio and human feel remain Task 2.2.7/Playtest gates.

## Packaged server operator runbook (Task 2.2.7)

This is local release preparation, **not deployment authorization or a tested
public service**. Obtain approval for the exact server, domain, region, costs,
TLS termination and inbound firewall/UDP rules before changing shared systems.
Start with two rooms/four players per room; measure again on deployment hardware.

### Verify and start locally

Export both targets from the same committed revision using `README.md`. Copy
only the Linux executable, PCK, `room_service.py`, `BUILD.txt` and `SHA256SUMS.txt`
to a fresh directory, not source/tests or import caches. On Linux x86_64 with
Python 3.10+ and the runtime libraries required by the Godot template, run from
that package directory as an unprivileged operator:

```bash
sha256sum -c SHA256SUMS.txt
chmod +x DisasterParty.x86_64
BUILD=$(sed -n 's/^Source revision: //p' BUILD.txt)
test ${#BUILD} -eq 40
python3 ./room_service.py \
  --godot "$PWD/DisasterParty.x86_64" --project "$PWD" --build "$BUILD" \
  --public-address 127.0.0.1 --listen-port 29800 \
  --port-start 29810 --port-end 29811 --rooms 2 --players 4 \
  > room-service.log 2>&1 &
SERVICE_PID=$!
```

The Linux release template auto-loads the adjacent PCK; do not substitute a
source checkout or development build. `ROOM_SERVICE_READY` confirms the HTTP
listener, not a game server. A successful Create must also print
`DISASTER_PARTY_BUILD`, `DEDICATED_SERVER_READY` and `ready room=... build=...`
with the same revision. HTTP version checks and server admission fail closed
on a mismatched build. Stop only the process started above:

```bash
kill -TERM "$SERVICE_PID"
wait "$SERVICE_PID"
```

SIGTERM closes managed children and reclaims ports. For a supervised deployment,
use a service manager with a dedicated user, private writable runtime/preferences
directory, restart-on-failure and whole-process-group cleanup. Do not run as root
or auto-update binaries under live rooms. Keep read-only versioned package
directories; stop/drain sessions before switching the executable/PCK/service as
one unit. Roll back the whole bundle **and clients**, not just the executable.

Developers can run the packaged Linux lifecycle check from the repository (the
runner copies only checksum-verified runtime files into a temporary directory):

```bash
python3 tests/run_release_linux_test.py .scratch/linux-a --log .scratch/linux-release-check.log
```

Choose a fresh log path and unused TCP/UDP ports (`--port 29870` uses TCP 29870,
UDP 29871–29872). It validates release startup, build rejection, HTTP create/join,
room crash/recreate, SIGTERM and port reclamation without editor/cache inputs;
it does not admit release clients or prove Internet gameplay.

From the matching Windows package, local discovery is:

```powershell
.\DisasterParty.exe --log-file room-client.log -- --room-service-url=http://127.0.0.1:29800
```

Here loopback refers to the Windows PC. For Windows/WSL split networking it works
only when Windows can reach the WSL loopback-forwarded service and advertised
UDP ports; failure is not Internet evidence. Use the source-only local checks or
a verified host address/topology instead of assuming forwarding works.

### Approved public deployment checklist (not executed)

- Keep Python HTTP on `127.0.0.1:29800`; set `--public-address` to the reachable
  game-server IPv4 address or DNS name, never loopback/private container DNS.
  Discovery HTTPS and ENet UDP must reach this same machine and port mapping.
- Terminate TLS on HTTPS port 443 with a valid trusted certificate for the chosen
  domain. Proxy **only** POST `/v1/rooms/create` and `/v1/rooms/join` to the same
  loopback paths. Return 404 for every other route, especially `/internal/*`.
  Restrict method/body size (2 KiB), edge per-client-IP rate/concurrency limits
  and upstream timeouts longer than the 15-second room startup budget. Do not
  expose port 29800. Validate proxy configuration before reload and test that
  remote internal routes stay inaccessible. Never publish test-fixture listeners.
- Allow inbound UDP 29810–29811 on the server/provider firewall (not TCP for
  gameplay) plus HTTPS 443. Preserve restricted operator access. Room creation
  is unauthenticated and capacity-bounded, not an account/abuse-prevention service.
  Players do not forward inbound router ports; their network must allow outbound
  HTTPS and UDP/replies. HTTPS does not encrypt gameplay packets.
- Give players a launcher command replacing `https://rooms.example.com` with the
  approved endpoint: `DisasterParty.exe --log-file room-client.log --
  --room-service-url=https://rooms.example.com`. Do not share tokens or room
  passwords in logs/screenshots. Do not log proxy request/response bodies or
  authorization data. Restrict log permissions/retention and collect only build,
  room ID, timestamps, lifecycle/errors and performance/network measurements.
- If HTTP succeeds but admission times out, verify advertised address, UDP rules,
  matching revisions and server readiness. If only HTTPS fails, check DNS,
  certificate trust/expiry and proxy route/timeouts; never disable certificate
  validation. Full service gives 503; active/full rooms give 409. A room crash
  removes that room; service restart loses all rooms/tickets. Clients recover
  offline and Create/Join obtains fresh tickets. Never replay an old ticket.

### Existing EC2 pipeline (main only)

`.github/workflows/deploy-existing-ec2.yml` runs on pushes to `main` or manually
from Actions on `main`. Stages are **validate/build → deploy**, serialized so two
deployments cannot overlap. It builds only the Linux server, retains a seven-day
workflow artifact, then uses a short-lived signed download URL through SSM.
No GitHub token reaches EC2, no Windows ZIP is copied there, and no GitHub Release
or Steam publication occurs. Windows distribution is separate future work; use
the same full revision when producing clients, because admission requires it.

The target is existing instance `i-0fd134761df1f88bf`, account `665808487768`,
region `ap-northeast-1`. **Do not run Terraform apply to create another server.**
The earlier `infra/ec2` module remains an optional reference, not a pipeline stage.

Before the first deployment, configure:

1. Repository **Settings → Secrets and variables → Actions → Variables**:
   `AWS_DEPLOY_ROLE_ARN` = the ARN of the separate GitHub deploy role. Its OIDC
   trust must require audience `sts.amazonaws.com` and subject
   `repo:phucle297@72026735/idunno@1401508578:ref:refs/heads/main`.
   This repository uses GitHub's immutable OIDC subject; the older name-only
   subject does not match. Do not add a GitHub Environment to
   this workflow: that changes the subject. Grant `ssm:SendCommand` only for
   `arn:aws:ssm:ap-northeast-1::document/AWS-RunShellScript` and the exact instance
   ARN, plus `ssm:GetCommandInvocation` for status. No AWS access keys are needed.
2. Attach a **different instance runtime role** with
   `AmazonSSMManagedInstanceCore` to EC2. Ensure the SSM agent is running and the
   instance is **Online** in Systems Manager, with outbound HTTPS connectivity.
   The workflow does not attach roles, create instances, or change networking.
3. On a dedicated Ubuntu 24.04 x86_64 host, prepare the `disaster-party` user,
   `/etc/disaster-party/server.env`, systemd unit and Caddy configuration before
   deployment. The existing template can be rendered **without Terraform**:

   ```bash
   # Run from this repository; inspect the output before copying to EC2.
   python3 - <<'PY' > /tmp/disaster-party-bootstrap.sh
   from pathlib import Path
   template = Path('infra/ec2/bootstrap.sh.tftpl').read_text()
   print(template.replace('${domain}', 'server.permees.com').replace('$${', '${'), end='')
   PY
   bash -n /tmp/disaster-party-bootstrap.sh
   ```

   Copy that reviewed script to EC2 and run `sudo bash disaster-party-bootstrap.sh`
   **once**. It installs packages, creates the service user, replaces Caddy's
   configuration, and restarts Caddy; do not run it on a shared host with existing
   Caddy sites or rerun it over an installed service. It enables but does not start
   the game until deployment. A non-Ubuntu host needs equivalent setup rather than
   this apt-based script. No host OS or bootstrap has been verified remotely.
4. Point `server.permees.com` to the existing EC2 public IPv4 (preferably a stable
   Elastic IP) using the authoritative DNS provider. Route 53 is not required
   when Spaceship already hosts DNS. Allow TCP 80/443 and UDP 29810–29811 in the
   Security Group/host firewall; leave TCP 29800 private. DNS/firewall setup is
   operator-managed, not performed by this pipeline. The Caddy template bounds
   request sizes/routes/timeouts, but has no per-IP edge rate limiter; the service
   has a shared 30-request/minute limit, not full public abuse protection.

Deployment verifies archive/payload hashes and revision, stops active rooms,
switches a root-owned versioned bundle, and starts the unprivileged service.
It checks loopback unknown-room/version behavior without allocating a room;
failed startup restores the previous bundle/config when available. Restarting
loses rooms/tickets, so schedule updates between playtests. On EC2 inspect:

```bash
sudo systemctl status disaster-party caddy
sudo journalctl -u disaster-party -n 100 --no-pager
sudo cat /opt/disaster-party/current/BUILD.txt
```

`EXISTING_EC2_DEPLOY_OK` proves only the service startup probe, **not** public
TLS, UDP reachability or release-client gameplay. If status polling times out,
inspect the SSM command first; it may still run. Do not blindly redeploy.

On 2026-10-08 the operator completed deployment of revision `6fb1e8d`, and
actual Godot clients on two separate Docker bridge networks received valid
HTTPS Create/Join tickets for `server.permees.com:29810`. Initial ENet admission
failed while the SG had UDP port0. After the operator corrected inbound UDP to
29810–29811, the unchanged server passed real admission, roster/ready/start,
authoritative movement, Flood/health and later Meteor observations, six natural
results/five rematches, owner transfer and a new-owner rematch. Result-time RTT
samples were124–137ms; mostly stationary clients ended rounds in43–51s, not a
human balance/performance benchmark. No runtime errors. Default local DNS was
intermittent; container DNS1.1.1.1 resolved the public address for the repeat.
Clients use Linux editor/source and share a host/upstream NAT: this does not
pass Windows release, physically separate networks, all hazards/props,
server-loss retry or physical audio/settings gates. No redeploy was needed.

### Remaining release acceptance

Current package is the [Phase 8 + Solid Environment Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-e68a912)
Windows ZIP at revision `e68a912a91c6dce339ddb254a559e68be26c53ce`.
Run the EXE directly; no launcher is required. CI deployment and post-deploy
public tickets/ENet/Ready/Start passed with
two Linux Godot exact-PCK clients on one orb/upstream. EC2 room-count and
player limits are unchanged. Native Windows, separate-network human sessions,
GPU and physical audio gates remain unverified; the instructions below describe
the outstanding acceptance, not a mandatory prerequisite to reporting bugs.

**Historical 2026-10-08 handoff (older build; not the current download):**

The matching Windows package `DisasterParty-Windows-Internet-6fb1e8d.zip` is
prepared locally and copied to the operator's Windows Downloads directory.
Extract the entire ZIP into a fresh writable folder and run `Play-Internet.cmd`.
This launcher passes `--room-service-url=https://server.permees.com` and writes
`room-client.log` beside the EXE. Open Multiplayer Lobby [L], Create a custom
Room ID, then use the same package/ID on the second PC to Join; Ready both and
let the owner Start. Keep EXE/PCK together. `SHA256SUMS.txt` verifies runtime,
build notes, launcher and `PLAYTEST.txt`. No public Release/Steam upload occurs.
Native standalone launch and launcher argument checks pass; settings/recovery
and five-rematch exported-PCK fixtures use an editor driver, not the release
EXE. Those results do not replace the following acceptance session.

Use unchanged release executables on separate Windows PCs on different Internet
networks. Record client/server full revisions, server CPU/RAM/OS/region, GPU and
resolution, network type/RTT/loss/disconnects and timestamped credential-free
logs. Create/join a custom ID, exercise ready/start, movement/props, every hazard
warning, death/spectating/results, five rematches, owner departure/transfer and
server-loss retry without restarting clients. Inspect asset presentation, change
settings then restart the executable, and have participants confirm physical
warning/effect audibility at documented volume levels. Scripted PCK/editor or
Dummy-audio checks cannot pass those release-runtime/listening gates. Keep
Internet and human gates open until these sessions are executed and recorded.
