class_name Precipitation
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }

@export var disaster_name := "Rain"
@export var warning_duration := 5.0
@export var active_duration := 24.0

var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var variant := 0
var _manager: MatchManager


func configure(manager: MatchManager) -> void:
	_manager = manager


func get_disaster_metadata() -> Dictionary:
	return {"name": disaster_name, "difficulty": 1, "minimum_match_time": 0.0,
		"incompatible_disasters": ["Snowfall" if disaster_name == "Rain" else "Rain", "Tornado", "Earthquake"],
		"combination_tags": ["weather"]}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	if not _can_mutate() or is_active() or not is_instance_valid(_manager) or _manager.state != MatchManager.MatchState.ACTIVE:
		return false
	variant = rng.randi_range(0, 2)
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = active_duration + variant * 2.0
	return true


func is_active() -> bool:
	return phase != Phase.IDLE


func tick(delta: float) -> void:
	if not _can_mutate() or not is_active():
		return
	if _manager.state != MatchManager.MatchState.ACTIVE:
		cleanup()
		return
	var remaining := maxf(delta, 0.0)
	if phase == Phase.WARNING:
		var warning_step := minf(remaining, warning_remaining)
		warning_remaining -= warning_step
		remaining -= warning_step
		if warning_remaining <= 0.0:
			phase = Phase.ACTIVE
	if phase == Phase.ACTIVE:
		active_remaining = maxf(active_remaining - remaining, 0.0)
		if active_remaining <= 0.0:
			cleanup()


func cleanup() -> void:
	phase = Phase.IDLE
	warning_remaining = 0.0
	active_remaining = 0.0


func create_presentation_snapshot() -> Dictionary:
	return {"phase": phase, "warning": warning_remaining, "active": active_remaining, "variant": variant}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	phase = clampi(int(snapshot.get("phase", 0)), Phase.IDLE, Phase.ACTIVE)
	warning_remaining = maxf(float(snapshot.get("warning", 0.0)), 0.0)
	active_remaining = maxf(float(snapshot.get("active", 0.0)), 0.0)
	variant = clampi(int(snapshot.get("variant", 0)), 0, 2)
	return true


func _process(delta: float) -> void:
	tick(delta)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
