class_name Flood
extends Node3D

signal warning_started(duration: float)
signal water_level_changed(level: float)
signal electrified(target: Vector3, duration: float)
signal finished

enum Phase {
	IDLE,
	WARNING,
	RISING,
	HOLDING,
	DRAINING
}

const DAMAGE_CAUSE := "Flood"
const ELECTRIC_DAMAGE_CAUSE := "Electrified Flood"
const DISASTER_NAME := "Flood"
const CARDINAL_DIRECTIONS: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]

enum RisePattern {
	STEADY,
	SURGE
}

enum CurrentPattern {
	CALM,
	DRIFT
}

@export var warning_duration := 6.0
@export var start_level := -0.5
@export var target_level := 3.5
@export var rise_duration := 35.0
@export var hold_duration := 5.0
@export var drain_duration := 5.0
@export var breathing_grace := 2.0
@export var damage_per_second := 12.0
@export var buoyancy_acceleration := 11.0
@export var buoyancy_force_max := 180.0
@export var drag_force_max := 90.0
@export var current_speed := 1.5
@export var electrified_duration := 3.0
@export var electrified_damage_per_second := 25.0

var phase := Phase.IDLE
var warning_remaining := 0.0
var water_level := -0.5
var electrified_remaining := 0.0
var electrified_target := Vector3.ZERO
var rise_pattern := RisePattern.STEADY
var current_pattern := CurrentPattern.DRIFT
var current_direction := Vector3.RIGHT

var _phase_elapsed := 0.0
var _match_manager: MatchManager
var _players: Dictionary = {}
var _submerged_time: Dictionary = {}
var _surface: MeshInstance3D
var _water_material: StandardMaterial3D
var _ripple_material: StandardMaterial3D
var _electric_material: StandardMaterial3D


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 1,
		"minimum_match_time": 0.0,
		"incompatible_disasters": [],
		"combination_tags": ["water", "low_ground"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	rise_pattern = RisePattern.STEADY if rng.randi_range(0, 1) == 0 else RisePattern.SURGE
	current_pattern = CurrentPattern.CALM if rng.randi_range(0, 1) == 0 else CurrentPattern.DRIFT
	current_direction = CARDINAL_DIRECTIONS[rng.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)]
	return start_warning()


func is_active() -> bool:
	return phase != Phase.IDLE


func register_player(peer_id: int, player: Node3D) -> bool:
	if not _can_mutate() or peer_id <= 0 or not is_instance_valid(player) or _players.has(peer_id):
		return false
	_players[peer_id] = player
	_submerged_time[peer_id] = 0.0
	return true


func unregister_player(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	_players.erase(peer_id)
	_submerged_time.erase(peer_id)
	return true


func start_warning() -> bool:
	if not _can_mutate() or phase != Phase.IDLE or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE:
		return false
	phase = Phase.WARNING
	warning_remaining = warning_duration
	water_level = start_level
	_phase_elapsed = 0.0
	_submerged_time.clear()
	for peer_id: int in _players:
		_submerged_time[peer_id] = 0.0
	_spawn_surface()
	warning_started.emit(warning_duration)
	return true


func tick(delta: float) -> void:
	if not _can_mutate() or phase == Phase.IDLE:
		return
	var safe_delta := maxf(delta, 0.0)
	var electrified_delta := minf(safe_delta, electrified_remaining)
	match phase:
		Phase.WARNING:
			warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
			if warning_remaining <= 0.0:
				phase = Phase.RISING
				_phase_elapsed = 0.0
		Phase.RISING:
			var previous_level := water_level
			_phase_elapsed = minf(_phase_elapsed + safe_delta, rise_duration)
			_set_water_level(_rise_level(_phase_elapsed))
			_apply_water_effects(safe_delta, previous_level, electrified_delta)
			if _phase_elapsed >= rise_duration:
				phase = Phase.HOLDING
				_phase_elapsed = 0.0
		Phase.HOLDING:
			_phase_elapsed = minf(_phase_elapsed + safe_delta, hold_duration)
			_apply_water_effects(safe_delta, water_level, electrified_delta)
			if _phase_elapsed >= hold_duration:
				phase = Phase.DRAINING
				_phase_elapsed = 0.0
		Phase.DRAINING:
			var previous_level := water_level
			_phase_elapsed = minf(_phase_elapsed + safe_delta, drain_duration)
			_set_water_level(lerpf(target_level, start_level, _phase_elapsed / maxf(drain_duration, 0.001)))
			_apply_water_effects(safe_delta, previous_level, electrified_delta)
			if _phase_elapsed >= drain_duration:
				_finish()
	electrified_remaining = maxf(electrified_remaining - safe_delta, 0.0)
	_update_electric_visual()


func electrify_at(target: Vector3) -> bool:
	if not _can_mutate() or phase < Phase.RISING or not is_position_flooded(target):
		return false
	electrified_target = target
	electrified_remaining = electrified_duration
	_update_electric_visual()
	electrified.emit(target, electrified_duration)
	return true


func is_position_flooded(position: Vector3) -> bool:
	return phase >= Phase.RISING and water_level >= position.y


func cleanup() -> void:
	if is_instance_valid(_surface):
		_surface.queue_free()
	_surface = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	water_level = start_level
	electrified_remaining = 0.0
	electrified_target = Vector3.ZERO
	rise_pattern = RisePattern.STEADY
	current_pattern = CurrentPattern.DRIFT
	current_direction = Vector3.RIGHT
	_phase_elapsed = 0.0
	_submerged_time.clear()
	_water_material = null
	_ripple_material = null
	_electric_material = null


func active_effect_count() -> int:
	return 1 if is_instance_valid(_surface) else 0


func create_presentation_snapshot() -> Dictionary:
	var peer_ids: Array[int] = []
	for peer_id: int in _submerged_time:
		peer_ids.append(peer_id)
	peer_ids.sort()
	var submerged_peer_ids := PackedInt32Array()
	var submerged_times := PackedFloat32Array()
	for peer_id: int in peer_ids:
		submerged_peer_ids.append(peer_id)
		submerged_times.append(float(_submerged_time[peer_id]))
	return {
		"phase": int(phase),
		"warning_remaining": warning_remaining,
		"water_level": water_level,
		"electrified_remaining": electrified_remaining,
		"electrified_target": electrified_target,
		"rise_pattern": int(rise_pattern),
		"current_pattern": int(current_pattern),
		"current_direction": current_direction,
		"submerged_peer_ids": submerged_peer_ids,
		"submerged_times": submerged_times,
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var next_phase := clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.DRAINING)
	if next_phase == Phase.IDLE:
		cleanup()
		return true
	phase = next_phase
	warning_remaining = maxf(float(snapshot.get("warning_remaining", 0.0)), 0.0)
	electrified_remaining = maxf(float(snapshot.get("electrified_remaining", 0.0)), 0.0)
	electrified_target = snapshot.get("electrified_target", Vector3.ZERO)
	rise_pattern = clampi(int(snapshot.get("rise_pattern", RisePattern.STEADY)), RisePattern.STEADY, RisePattern.SURGE)
	current_pattern = clampi(int(snapshot.get("current_pattern", CurrentPattern.DRIFT)), CurrentPattern.CALM, CurrentPattern.DRIFT)
	current_direction = snapshot.get("current_direction", Vector3.RIGHT)
	var submerged_peer_ids: PackedInt32Array = snapshot.get("submerged_peer_ids", PackedInt32Array())
	var submerged_times: PackedFloat32Array = snapshot.get("submerged_times", PackedFloat32Array())
	_submerged_time.clear()
	if submerged_peer_ids.size() == submerged_times.size():
		for index: int in submerged_peer_ids.size():
			_submerged_time[submerged_peer_ids[index]] = maxf(submerged_times[index], 0.0)
	if not is_instance_valid(_surface):
		_spawn_surface()
	_set_water_level(float(snapshot.get("water_level", start_level)))
	_update_electric_visual()
	return true


func get_submerged_time(peer_id: int) -> float:
	return float(_submerged_time.get(peer_id, 0.0))


func _process(delta: float) -> void:
	tick(delta)


func _apply_water_effects(delta: float, previous_water_level: float, electrified_delta: float) -> void:
	var damage_events: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var head_height := _player_head_height(player)
		var was_submerged := previous_water_level >= head_height
		var is_submerged := water_level >= head_height
		var submerged_delta := 0.0
		if was_submerged and is_submerged:
			submerged_delta = delta
		elif not was_submerged and is_submerged:
			submerged_delta = delta * clampf((water_level - head_height) / maxf(water_level - previous_water_level, 0.001), 0.0, 1.0)
		elif was_submerged and not is_submerged:
			submerged_delta = delta * clampf((previous_water_level - head_height) / maxf(previous_water_level - water_level, 0.001), 0.0, 1.0)
		if submerged_delta > 0.0:
			var previous := float(_submerged_time.get(peer_id, 0.0))
			var current := previous + submerged_delta
			_submerged_time[peer_id] = current
			var damaging_time := maxf(current - breathing_grace, 0.0) - maxf(previous - breathing_grace, 0.0)
			if damaging_time > 0.0:
				damage_events.append({"peer_id": peer_id, "amount": damage_per_second * damaging_time, "cause": DAMAGE_CAUSE})
		if not is_submerged:
			_submerged_time[peer_id] = 0.0
		if electrified_delta > 0.0 and is_position_flooded(player.global_position):
			damage_events.append({"peer_id": peer_id, "amount": electrified_damage_per_second * electrified_delta, "cause": ELECTRIC_DAMAGE_CAUSE})
	if not damage_events.is_empty():
		_match_manager.apply_damage_batch(damage_events)

	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body) or body.global_position.y >= water_level:
			continue
		body.sleeping = false
		var depth := clampf(water_level - body.global_position.y, 0.0, 1.0)
		var lift := minf(body.mass * buoyancy_acceleration * depth, buoyancy_force_max)
		var desired_current := _current_vector()
		var drag := (desired_current - Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)) * body.mass
		var damping := -body.linear_velocity * body.mass * 0.35
		body.apply_central_force(Vector3.UP * lift + drag.limit_length(drag_force_max) + damping.limit_length(drag_force_max))


func _rise_level(elapsed: float) -> float:
	var progress := clampf(elapsed / maxf(rise_duration, 0.001), 0.0, 1.0)
	var fraction := progress
	if rise_pattern == RisePattern.SURGE:
		# Bounded two-stage surge: quick first swell, short plateau, final push.
		if progress <= 0.45:
			fraction = (progress / 0.45) * 0.65
		elif progress <= 0.60:
			fraction = 0.65
		else:
			fraction = 0.65 + ((progress - 0.60) / 0.40) * 0.35
	return lerpf(start_level, target_level, fraction)


func _current_vector() -> Vector3:
	return current_direction.normalized() * current_speed if current_pattern == CurrentPattern.DRIFT else Vector3.ZERO


func _player_head_height(player: Node3D) -> float:
	if player.has_method("get_head_sample_position"):
		return float(player.call("get_head_sample_position").y)
	return player.global_position.y + 1.35


func _spawn_surface() -> void:
	_surface = MeshInstance3D.new()
	_surface.name = "FloodSurface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(64.0, 0.08, 64.0)
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(0.2588, 0.7216, 0.9098, 0.68)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_material.roughness = 0.2
	_water_material.metallic = 0.0
	mesh.material = _water_material
	_surface.mesh = mesh
	add_child(_surface)
	_ripple_material = StandardMaterial3D.new()
	_ripple_material.albedo_color = Color(0.9569, 0.902, 0.7843, 0.75)
	_ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ripple_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_electric_material = StandardMaterial3D.new()
	_electric_material.albedo_color = Color(0.694, 0.235, 1.0, 0.94)
	_electric_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_electric_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ripple_data in [[Vector3(-8.0, 0.08, 4.0), 2.0], [Vector3(10.0, 0.08, -7.0), 3.0], [Vector3(2.0, 0.08, 12.0), 1.5]]:
		var ripple := MeshInstance3D.new()
		var ripple_mesh := TorusMesh.new()
		ripple_mesh.inner_radius = ripple_data[1]
		ripple_mesh.outer_radius = ripple_data[1] + 0.12
		ripple_mesh.rings = 32
		ripple_mesh.ring_segments = 6
		ripple_mesh.material = _ripple_material
		ripple.mesh = ripple_mesh
		ripple.position = ripple_data[0]
		_surface.add_child(ripple)
	for index in 3:
		var electric_ripple := MeshInstance3D.new()
		electric_ripple.name = "ElectricStrikeRipple%d" % index
		var electric_mesh := TorusMesh.new()
		electric_mesh.inner_radius = 1.2 + index * 1.1
		electric_mesh.outer_radius = electric_mesh.inner_radius + 0.28
		electric_mesh.rings = 40
		electric_mesh.ring_segments = 8
		electric_mesh.material = _electric_material
		electric_ripple.mesh = electric_mesh
		electric_ripple.visible = false
		_surface.add_child(electric_ripple)
	_set_water_level(start_level)
	_update_electric_visual()


func _update_electric_visual() -> void:
	if not is_instance_valid(_surface):
		return
	var active := electrified_remaining > 0.0
	for ripple in _surface.get_children():
		var ripple_mesh := ripple as MeshInstance3D
		ripple_mesh.material_override = _electric_material if active else _ripple_material
	for index in 3:
		var strike_ripple := _surface.get_node("ElectricStrikeRipple%d" % index) as MeshInstance3D
		strike_ripple.visible = active
		strike_ripple.position = Vector3(electrified_target.x, 0.1, electrified_target.z)
		var pulse := 1.0 + sin(electrified_remaining * TAU * 2.0 + index) * 0.08
		strike_ripple.scale = Vector3(pulse, 1.0, pulse)


func _set_water_level(level: float) -> void:
	water_level = clampf(level, start_level, target_level)
	if is_instance_valid(_surface):
		_surface.position.y = water_level
	water_level_changed.emit(water_level)


func _finish() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	cleanup()
	finished.emit()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
