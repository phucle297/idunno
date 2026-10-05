class_name DisasterDirector
extends Node

signal disaster_started(disaster_name: String, intensity: int, active_disasters: Array[String])

@export var initial_delay := 10.0
@export var recovery_duration := 4.0
@export var overlap_delay := 8.0

var running := false
var selection_history: Array[String] = []

var _match_manager: MatchManager
var _disasters: Dictionary = {}
var _active: Array[String] = []
var _completed_solo: Dictionary = {}
var _solo_eligible: Dictionary = {}
var _next_start_in := 0.0
var _rng := RandomNumberGenerator.new()


func configure(match_manager: MatchManager) -> bool:
	if not _can_mutate() or not is_instance_valid(match_manager):
		return false
	_match_manager = match_manager
	return true


func register_disaster(disaster: Node) -> bool:
	if not _can_mutate() or running or not is_instance_valid(disaster):
		return false
	if not disaster.has_method("get_disaster_metadata") or not disaster.has_method("start_disaster"):
		return false
	if not disaster.has_method("is_active") or not disaster.has_method("cleanup"):
		return false
	var metadata: Dictionary = disaster.get_disaster_metadata()
	var disaster_name := String(metadata.get("name", ""))
	if disaster_name.is_empty() or _disasters.has(disaster_name):
		return false
	_disasters[disaster_name] = {"node": disaster, "metadata": metadata}
	return true


func start_directing(seed: int = -1) -> bool:
	if not _can_mutate() or running or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE or _disasters.is_empty():
		return false
	_reset_runtime_state()
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	running = true
	_next_start_in = initial_delay
	return true


func tick(delta: float) -> void:
	if not _can_mutate() or not running:
		return
	if not is_instance_valid(_match_manager) or _match_manager.state != MatchManager.MatchState.ACTIVE:
		cleanup()
		return
	var previous_active_count := _active.size()
	_refresh_active()
	if _active.size() < previous_active_count:
		_next_start_in = recovery_duration if _active.is_empty() else overlap_delay
	_next_start_in = maxf(_next_start_in - maxf(delta, 0.0), 0.0)
	if _next_start_in > 0.0 or _active.size() >= _maximum_simultaneous():
		return
	var candidates := _eligible_candidates()
	if candidates.is_empty():
		_next_start_in = 1.0
		return
	var chosen: String = candidates[_rng.randi_range(0, candidates.size() - 1)]
	if try_start_disaster(chosen):
		_next_start_in = overlap_delay


func try_start_disaster(disaster_name: String) -> bool:
	if not _can_mutate() or not running or not _disasters.has(disaster_name):
		return false
	_refresh_active()
	if disaster_name not in _eligible_candidates():
		return false
	var disaster := _disasters[disaster_name].node as Node
	var starts_solo := _active.is_empty()
	if not disaster.start_disaster(_rng):
		return false
	if not starts_solo:
		for active_name in _active:
			_solo_eligible[active_name] = false
	_active.append(disaster_name)
	_solo_eligible[disaster_name] = starts_solo
	selection_history.append(disaster_name)
	disaster_started.emit(disaster_name, get_intensity(), get_active_disaster_names())
	return true


func get_intensity() -> int:
	if not is_instance_valid(_match_manager):
		return 1
	var elapsed := _match_manager.elapsed_time
	if elapsed >= 540.0:
		return 5
	if elapsed >= 480.0:
		return 4
	if elapsed >= 300.0:
		return 3
	if elapsed >= 120.0:
		return 2
	return 1


func get_active_disaster_names() -> Array[String]:
	_refresh_active()
	return _active.duplicate()


func has_completed_solo(disaster_name: String) -> bool:
	_refresh_active()
	return bool(_completed_solo.get(disaster_name, false))


func cleanup() -> void:
	if not _can_mutate():
		return
	for entry: Dictionary in _disasters.values():
		var disaster := entry.node as Node
		if is_instance_valid(disaster):
			disaster.cleanup()
	running = false
	_reset_runtime_state()


func _process(delta: float) -> void:
	tick(delta)


func _eligible_candidates() -> Array[String]:
	var candidates: Array[String] = []
	if _active.size() >= _maximum_simultaneous():
		return candidates
	for disaster_name: String in _disasters:
		var entry: Dictionary = _disasters[disaster_name]
		var disaster := entry.node as Node
		var metadata: Dictionary = entry.metadata
		if disaster.is_active():
			continue
		if float(metadata.get("minimum_match_time", 0.0)) > _match_manager.elapsed_time:
			continue
		if int(metadata.get("difficulty", 1)) > get_intensity():
			continue
		if not selection_history.is_empty() and selection_history.back() == disaster_name:
			continue
		if not _active.is_empty():
			if not has_completed_solo(disaster_name) or not _active_all_completed_solo():
				continue
			if not _is_compatible_with_active(disaster_name):
				continue
		candidates.append(disaster_name)
	return candidates


func _refresh_active() -> void:
	var still_active: Array[String] = []
	for disaster_name in _active:
		var entry: Dictionary = _disasters.get(disaster_name, {})
		var disaster := entry.get("node") as Node
		if is_instance_valid(disaster) and disaster.is_active():
			still_active.append(disaster_name)
		else:
			if bool(_solo_eligible.get(disaster_name, false)):
				_completed_solo[disaster_name] = true
			_solo_eligible.erase(disaster_name)
	_active = still_active


func _active_all_completed_solo() -> bool:
	for disaster_name in _active:
		if not bool(_completed_solo.get(disaster_name, false)):
			return false
	return true


func _is_compatible_with_active(disaster_name: String) -> bool:
	var incompatible: Array = _disasters[disaster_name].metadata.get("incompatible_disasters", [])
	for active_name in _active:
		var active_incompatible: Array = _disasters[active_name].metadata.get("incompatible_disasters", [])
		if active_name in incompatible or disaster_name in active_incompatible:
			return false
	return true


func _maximum_simultaneous() -> int:
	return 2 if get_intensity() >= 3 else 1


func _reset_runtime_state() -> void:
	selection_history.clear()
	_active.clear()
	_completed_solo.clear()
	_solo_eligible.clear()
	_next_start_in = 0.0


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
