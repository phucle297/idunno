class_name MatchClock
extends Node
## T9 shared simulation clock. Counts physics ticks so gameplay windows
## (shove protection/cooldown, emote expiry) are measured in sim time and do
## not depend on machine load. Never advanced from _process, never reset on
## rematch (windows are relative). Official match time stays in MatchManager.

## Monotonic physics-tick count since this clock was created.
var tick: int = 0


func _init() -> void:
	# Tick before Main/ShoveManager in every physics step.
	process_physics_priority = -1000


func _physics_process(_delta: float) -> void:
	tick += 1


## Sim seconds since creation: drop-in replacement for a wall `_now()`.
func now() -> float:
	return tick / float(Engine.physics_ticks_per_second)


## Integer tick count covering `seconds` of sim time.
func ticks_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


## Thin pass-through: official match time lives in MatchManager.
func match_elapsed(manager: MatchManager) -> float:
	return manager.elapsed_time if is_instance_valid(manager) else 0.0


## Stable seed for a NEW per-system RNG stream. Existing seed + k*prime
## derivations stay unchanged (they key the published-seed baselines).
static func derive_seed(base_seed: int, stream: StringName) -> int:
	return hash([base_seed, stream])
