You are a senior indie game developer and game designer. Build a playable prototype of a multiplayer PC game called **Disaster Party**.

The target platform is **Steam / Windows PC**.

The game is a casual multiplayer survival party game designed for **2–20 players initially**, with architecture that can later scale toward larger lobbies.

The project is being developed by **one indie developer**, so aggressively control scope. Prioritize a fun, polished core loop over content quantity.

# 1. Game concept

Disaster Party is a chaotic multiplayer survival game where players spawn together in a small interactive map and try to survive a sequence of increasingly dangerous random disasters.

Think of the accessibility and chaos of party games:

- Fall Guys
- Pummel Party
- Human Fall Flat
- Only Up
- Natural Disaster Survival

But do not clone any of them.

The core fantasy is:

> "You and your friends are trapped in a playground where increasingly ridiculous disasters keep happening. Survive longer than everyone else."

A match should generate funny emergent situations naturally through:

- physics
- movement
- environmental destruction
- disasters interacting with each other
- players accidentally interfering with each other

No complex progression, story, crafting, inventory system, microtransactions, classes, skill trees, or large content system is required.

---

# 2. Match structure

Target match duration:

**8–12 minutes**

Flow:

Lobby
→ Players spawn
→ 10-second countdown
→ Disaster #1
→ short recovery period
→ Disaster #2
→ Disaster #3
→ overlapping disasters
→ final extreme phase
→ last surviving player wins
→ results screen
→ rematch

Do not eliminate players too quickly.

The first ~2 minutes should be relatively forgiving.

Difficulty should escalate through:

1. stronger disasters
2. shorter warning times
3. multiple disasters occurring simultaneously

Example:

0:00–2:00
One simple disaster at a time.

2:00–5:00
Stronger disasters.

5:00–8:00
Occasional combinations of two disasters.

8:00+
Continuous chaos and combinations.

If only one player remains alive, end the match immediately.

If the timer expires with multiple survivors, rank survivors based on survival plus a simple tie-breaking score.

---

# 3. MVP map

Build ONE map first.

Theme:

**Small suburban / city block playground**

It should contain:

- central plaza
- 2–3 small buildings
- rooftops
- stairs
- elevated platforms
- trees
- street
- vehicles or large props
- fences
- signs
- loose physics objects
- indoor and outdoor areas

The map should be compact enough that players frequently see each other.

Verticality is important because disasters should make different elevations strategically useful.

Examples:

Flood → go high.

Meteor → get under cover.

Earthquake → avoid unstable buildings.

Tornado → indoor areas may be safer.

Fire → enclosed buildings may become dangerous.

Therefore there should be **no permanently safe location**.

Different disasters must change which parts of the map are desirable.

---

# 4. Player controller

Use a simple third-person controller.

Required actions:

- move
- sprint
- jump
- crouch
- grab / hold physics objects
- grab ledges if simple to implement
- ragdoll
- recover from ragdoll

Optional only if implementation remains simple:

- shove
- emotes

Movement should feel responsive rather than realistic.

Players should have enough air control to make platforming enjoyable.

Physics interactions should produce funny situations but should not make basic movement frustrating.

Players can collide with each other.

High-impact forces can trigger ragdoll.

Examples:

meteor impact
→ shockwave
→ player thrown into another player
→ both ragdoll
→ flood carries them away

This kind of chain reaction is desirable.

---

# 5. Health

Keep health extremely simple.

Player:

100 HP

Damage examples:

small collision: 5–10

fall: based on velocity

fire: damage over time

meteor direct hit: lethal

debris: 10–40

lightning: 50–100

Players should usually die because of obvious environmental events rather than invisible damage.

Display health clearly.

Dead players become spectators.

---

# 6. Disaster system

Create disasters as modular components implementing a common interface.

Conceptually:

Disaster

- StartWarning()
- Start()
- Update()
- Stop()
- Cleanup()

Each disaster contains metadata such as:

name
difficulty
duration
warningDuration
minimumMatchTime
incompatibleDisasters
combinationTags

The game manager should select disasters dynamically.

Do NOT hardcode the entire match as a fixed sequence.

---

# 7. MVP disasters

Implement these disasters first.

## Flood

Water rises from the bottom of the map.

Stages:

warning siren
→ water appears
→ water level rises
→ low areas become dangerous
→ players must reach higher ground

Water should:

- damage or eliminate submerged players
- move loose physics objects
- optionally push players with current

---

## Meteor Shower

Show obvious indicators where meteors will land.

After a short delay:

meteor
→ impact
→ explosion
→ physics impulse

Meteors can:

- damage players
- ragdoll players
- move props
- potentially destroy selected lightweight environment pieces

Telegraph attacks clearly so deaths feel fair.

---

## Tornado

A tornado moves around the map.

It creates an attraction force.

Objects and players near it are pulled toward the tornado.

Players very close to it:

→ lifted into air
→ spun around
→ thrown away

Loose props should also be affected.

This disaster should produce strong emergent physics moments.

---

## Earthquake

The map shakes.

Effects:

- player movement becomes harder
- loose objects move
- some predefined structures collapse
- debris falls
- players can ragdoll from severe impacts

Do NOT attempt fully dynamic building destruction.

Use predefined breakable sections.

---

## Lightning Storm

Lightning periodically targets areas.

Before impact:

visible warning
→ sound
→ short delay
→ lightning strike

Interesting interaction:

**water increases lightning danger.**

If Flood + Lightning occur simultaneously, standing in flooded areas becomes extremely dangerous.

---

## Fire

Several locations ignite.

Fire spreads between predefined flammable objects/zones.

Players touching fire receive damage over time.

Fire gradually makes indoor spaces unsafe.

Do not build a complex voxel fire simulation.

Use a simple graph/neighbor propagation system.

---

# 8. Disaster combinations

This is one of the most important systems in the game.

Disasters should not simply coexist.

Some should interact.

Examples:

Flood + Lightning

Water becomes electrically dangerous when lightning strikes.

Tornado + Fire

Tornado spreads burning objects around the map.

Tornado + Meteor

Meteor debris can be picked up and thrown by the tornado.

Earthquake + Flood

Previously safe elevated structures can collapse.

Fire + Earthquake

Burning structures can drop dangerous debris.

The architecture should allow additional interactions later without rewriting each disaster.

Prefer event-driven interactions.

Example conceptual events:

OnObjectIgnited
OnWaterLevelChanged
OnExplosion
OnStructureDestroyed
OnLightningStrike

Other disasters can react to these events.

---

# 9. Disaster director

Create a Disaster Director controlling match intensity.

Intensity increases with match time.

Example:

Intensity 1:
single low-danger disaster

Intensity 2:
stronger disasters

Intensity 3:
two compatible disasters

Intensity 4:
frequent combinations

Intensity 5:
final chaos

Selection should contain randomness but avoid unfair combinations.

Avoid repeatedly selecting the same disaster.

Each match should feel different.

---

# 10. Warning system

Every major disaster must be clearly telegraphed.

Example:

WARNING

🌊 FLOOD INCOMING

5
4
3
2
1

Use:

- screen message
- environmental sound
- world effects

The player should usually understand **why they died**.

Chaos is good.

Unreadable randomness is bad.

---

# 11. Multiplayer

Multiplayer is fundamental.

Design gameplay server-authoritatively where practical.

The server controls:

- disaster selection
- match state
- player health/death
- important physics outcomes
- winner

Clients handle presentation and prediction where appropriate.

Prototype target:

2–20 players.

Architecture should avoid assumptions preventing future scaling.

Do NOT attempt 100-player networking in the first version.

The game must also be testable locally with:

- one player
- multiple local development clients / bots where practical

Do not make development dependent on having several humans online.

---

# 12. Lobby

Keep lobby simple.

Required:

Create lobby
Join lobby
Player list
Ready state
Host starts game

If Steam integration would slow down the prototype, first implement a networking abstraction that can later connect to Steam lobby APIs.

Do not spend excessive development time on account systems.

---

# 13. Spectating

Dead players should remain engaged.

After death:

spectate living player

Controls:

next player
previous player
free camera if easy

Show:

player name
remaining players

Do not respawn players during the main competitive mode.

---

# 14. UI

Keep UI minimal.

During match:

Top:
current disaster(s)

Example:

TORNADO +
FLOOD

Corner:

Players Alive
12 / 20

Bottom:

HP

When disaster approaches:

large warning message.

End screen:

WINNER

player name

Then:

survival time
disasters survived
deaths / funny stats if available

Possible funny statistics:

Most Air Time
Longest Fall
Closest Meteor Dodge
Most Ragdolls
Most Distance Thrown

These are optional but architect the event tracking so they can be added later.

---

# 15. Art direction

Do NOT pursue realistic graphics.

Use:

stylized
low-poly
bright
readable
slightly exaggerated proportions

The game must remain visually readable when many players and disasters are happening simultaneously.

Prioritize silhouettes and effects readability over detail.

Use simple placeholder assets during prototype development.

Do not block gameplay development on final art.

---

# 16. Audio

Audio should communicate gameplay.

Important sounds:

disaster warning
meteor falling
meteor impact
tornado
earthquake rumble
fire
lightning
player impacts
death
victory

Use placeholder audio if necessary.

Disaster warnings must remain recognizable even during chaotic scenes.

---

# 17. Performance

Target:

60 FPS on mainstream gaming PCs.

Avoid expensive simulations.

Use:

object pooling
limited rigidbody counts
predefined destruction
simplified fire propagation
reasonable network update rates
distance-based simulation where useful

Do not create thousands of networked physics objects.

Physics chaos should be carefully constrained.

---

# 18. Development priorities

Implement in this order:

PHASE 1 — Core sandbox

Player controller
Camera
Basic map
Ragdoll
Physics interactions

PHASE 2 — Match

Lobby placeholder
Match timer
Health
Death
Spectating
Winner

PHASE 3 — First disasters

Meteor
Flood
Tornado

At this point the game MUST already be fun.

PHASE 4 — Additional disasters

Earthquake
Lightning
Fire

PHASE 5 — Disaster combinations

Implement cross-disaster interactions.

PHASE 6 — Multiplayer stabilization

Test:

2 players
4 players
8 players
20 players

PHASE 7 — Polish

UI
audio
VFX
feedback
results screen

---

# 19. Vertical slice success criteria

The prototype is successful when:

- 4 players can join a match.
- Players can move and interact reliably.
- One compact map is playable.
- At least Meteor, Flood and Tornado work.
- Disasters are randomized.
- Two disasters can overlap.
- Physics interactions create unexpected situations.
- Players can die and spectate.
- Last surviving player wins.
- A complete match can restart without restarting the application.
- Playing several matches produces meaningfully different situations.
- The game remains fun even without progression systems.

Most importantly:

**Players should laugh when something goes wrong.**

A technically impressive disaster simulation is less valuable than a simple disaster that creates funny player interactions.

---

# 20. Scope rules

This project is being built by ONE developer.

Whenever choosing between:

more systems

vs.

better core gameplay

choose better core gameplay.

DO NOT implement during the initial prototype:

- battle pass
- microtransactions
- marketplace
- NFTs
- crypto
- ranked matchmaking
- skill trees
- character classes
- crafting
- large inventory
- quests
- story campaign
- open world
- procedural cities
- advanced destruction
- complex AI enemies
- persistent player economy
- 100-player networking

Do not prematurely build infrastructure for hypothetical features.

---

# 21. Design philosophy

Every feature should support at least one of these:

SURVIVE

MOVE

INTERACT

PANIC

LAUGH

The ideal gameplay moment looks like:

Flood starts.

Players run to a rooftop.

Meteor destroys part of the roof.

Five players jump to another building.

A tornado arrives.

A loose sign hits one player.

That player ragdolls into another player.

Both fall toward the flood.

One catches a ledge.

Lightning hits the water below them.

Everyone watching starts laughing.

That is Disaster Party.

Build toward those moments.

---

# 22. First deliverable

Do not attempt to build the complete game at once.

First produce the smallest playable vertical slice containing:

- one compact greybox map
- third-person movement
- jumping
- basic physics interaction
- ragdoll
- health/death
- 4-player multiplayer
- Meteor Shower
- Flood
- Tornado
- random Disaster Director
- disaster warnings
- spectating
- winner detection
- match restart

Use placeholder models, materials, particles, UI and sounds where necessary.

The vertical slice should answer one question:

> **Is surviving random disasters with friends genuinely fun?**

Once that works, expand the game rather than expanding infrastructure prematurely.
