# Disaster Party Play Guide

This repository is a Godot prototype, not a packaged Steam build. Every player currently needs the same checkout and Godot 4.7.2 stable. Multiplayer uses direct ENet IP connections; there is no lobby browser or Steam invite flow yet.

## Play alone

Open `project.godot` in Godot and press **F5/Run Project**, or run:

```bash
godot --path .
```

The match starts automatically. The first disaster warning appears after about 10 seconds.

## Play with another member on the same LAN

### 1. Prepare every PC

1. Install Godot 4.7.2 stable.
2. Check out the same repository commit on every PC.
3. Allow Godot through Windows Firewall on private networks when prompted.
4. Keep UDP port `29730` available.

The host can find their LAN IPv4 address with:

```powershell
ipconfig
```

Use the address shown for the active Ethernet or Wi-Fi adapter, such as `192.168.1.25`. Do not give another PC `127.0.0.1`; that address only works when both processes run on the same PC.

### 2. Start or join in game

Press **L** (or select **LOBBY**) to open the direct-IP panel. The host leaves the default UDP port or enters another port and selects **CREATE**. Each other player enters the host's LAN IPv4 address and the same port, then selects **JOIN**.

Each connected player selects **READY**. The panel lists every player as ready or waiting. When at least two players are connected and all are ready, the host selects **START MATCH** or presses **Enter**.

You can also launch directly from PowerShell. To host:

From the repository directory in PowerShell:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --host-port=29730
```

The host still uses the in-game lobby to mark ready and start the match.

Replace the sample address with the host's LAN IPv4 address:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --join-address=192.168.1.25 --join-port=29730
```

The client marks ready in the in-game lobby and waits for the host to start the match.

For two processes on one development PC, join `127.0.0.1` instead.

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
| Escape | Release the cursor |
| Left click | Recapture the cursor |
| Q / E | Previous/next spectator target after death |

The HUD shows health at bottom-left, match time at top-center, and alive players at top-right. Large centered text names active disaster warnings.

When a match ends, every peer sees the same ranked results with winner, survival time, disasters survived, damage taken, and death cause. The host presses **Enter** to start a rematch; clients remain connected and display **WAITING FOR HOST TO START REMATCH** until the new round begins.

Warnings, impacts, jumping, death, and victory have synthesized placeholder audio. Flood, Meteor, and Tornado use distinct warning cues. Warning audio has a reserved voice so overlapping impact effects cannot silence it.

## Disaster timing

- About **0:10**: the first Meteor or Flood warning can begin.
- Before **2:00**: one Meteor or Flood runs at a time.
- At **2:00**: Tornado, Earthquake, and Lightning become eligible.
- At **5:00**: two compatible disasters can overlap, but only after both have completed alone at least once.
- At most two disasters overlap in the current prototype.

Implemented disasters are **Meteor Shower, Flood, Tornado, Earthquake, Lightning, and Fire**.

- **Flood:** water is safe while your head remains above the surface. Once submerged, the screen turns blue and a two-second `HOLD BREATH` countdown appears; after that, `DROWNING` displays the 12 HP/s damage rate until you surface.
- **Flood + Lightning:** a strike in active floodwater electrifies the connected water for three seconds. Violet ripples and the `ELECTRIFIED WATER` warning identify it. Get onto raised ground immediately.
- **Tornado + Fire:** Tornado wind doubles Fire's spread frequency and carries one visibly flaming debris body. Keep away from both the funnel and orange Fire-zone rings.

Earthquake, Lightning, and Tornado become eligible as intensity rises after 2:00. Fire and two-disaster overlaps unlock at 5:00. A disaster must complete alone before the director can use it in an overlap.

To inspect the implemented visuals immediately without waiting for normal match timing, launch one of these local demo states:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --meteor-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --flood-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --flood-grace-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --flood-damage-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --tornado-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --earthquake-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --lightning-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --fire-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --electric-flood-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --fire-tornado-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --overlap-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --results-demo
```

These are presentation/debug launches, not accelerated competitive matches.

## Current multiplayer limitations

- LAN and same-PC direct-IP sessions are validated. Internet play requires router/firewall UDP forwarding and is not validated.
- The host owns match state, health, movement, disasters, and winner decisions.
- There is no public lobby browser, Steam integration, NAT traversal, or packaged Windows build; create/join uses direct IP.
- Only the host can initiate a network rematch; readiness is required before the initial network match, not between rematches.
- Audio is synthesized placeholder content rather than final authored sound design.

## Troubleshooting

- **Can connect but match does not start:** every player must select **READY**, then the host selects **START MATCH** or presses Enter.
- **Cannot connect:** verify the host IP, UDP port `29730`, matching commits, and Windows Firewall permissions.
- **No disaster yet:** wait at least 10 seconds after the host starts the match. Overlap intentionally does not unlock until 5 minutes.
- **Mouse does not rotate the camera:** left-click the game window to capture the cursor.
- **HP is not changing:** damage only occurs when a disaster actually reaches the player; HP starts at 100.
