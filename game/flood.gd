class_name Flood
extends Node3D

signal warning_started(duration: float)
signal water_level_changed(level: float)
signal finished

enum Phase {
	IDLE,
	WARNING,
	RISING,
	HOLDING,
	DRAINING
}

const DAMAGE_CAUSE := "Flood"
const DISASTER_NAME := "Flood"

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

var phase := Phase.IDLE
var warning_remaining := 0.0
var water_level := -0.5

var _phase_elapsed := 0.0
var _match_manager: MatchManager
var _players: Dictionary = {}
var _submerged_time: Dictionary = {}
var _surface: MeshInstance3D


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


func start_disaster(_rng: RandomNumberGenerator) -> bool:
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
	match phase:
		Phase.WARNING:
			warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
			if warning_remaining <= 0.0:
				phase = Phase.RISING
				_phase_elapsed = 0.0
		Phase.RISING:
			var previous_level := water_level
			_phase_elapsed = minf(_phase_elapsed + safe_delta, rise_duration)
			_set_water_level(lerpf(start_level, target_level, _phase_elapsed / maxf(rise_duration, 0.001)))
			_apply_water_effects(safe_delta, previous_level)
			if _phase_elapsed >= rise_duration:
				phase = Phase.HOLDING
				_phase_elapsed = 0.0
		Phase.HOLDING:
			_phase_elapsed = minf(_phase_elapsed + safe_delta, hold_duration)
			_apply_water_effects(safe_delta, water_level)
			if _phase_elapsed >= hold_duration:
				phase = Phase.DRAINING
				_phase_elapsed = 0.0
		Phase.DRAINING:
			var previous_level := water_level
			_phase_elapsed = minf(_phase_elapsed + safe_delta, drain_duration)
			_set_water_level(lerpf(target_level, start_level, _phase_elapsed / maxf(drain_duration, 0.001)))
			_apply_water_effects(safe_delta, previous_level)
			if _phase_elapsed >= drain_duration:
				_finish()


func cleanup() -> void:
	if is_instance_valid(_surface):
		_surface.queue_free()
	_surface = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	water_level = start_level
	_phase_elapsed = 0.0
	_submerged_time.clear()


func active_effect_count() -> int:
	return 1 if is_instance_valid(_surface) else 0


func create_presentation_snapshot() -> Dictionary:
	return {
		"phase": int(phase),
		"warning_remaining": warning_remaining,
		"water_level": water_level,
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
	if not is_instance_valid(_surface):
		_spawn_surface()
	_set_water_level(float(snapshot.get("water_level", start_level)))
	return true


func get_submerged_time(peer_id: int) -> float:
	return float(_submerged_time.get(peer_id, 0.0))


func _process(delta: float) -> void:
	tick(delta)


func _apply_water_effects(delta: float, previous_water_level: float) -> void:
	var damage_events: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var head_height := player.global_position.y + 1.35
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
	if not damage_events.is_empty():
		_match_manager.apply_damage_batch(damage_events)

	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body) or body.global_position.y >= water_level:
			continue
		body.sleeping = false
		var depth := clampf(water_level - body.global_position.y, 0.0, 1.0)
		var lift := minf(body.mass * buoyancy_acceleration * depth, buoyancy_force_max)
		var desired_current := Vector3(current_speed, 0.0, 0.0)
		var drag := (desired_current - Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)) * body.mass
		var damping := -body.linear_velocity * body.mass * 0.35
		body.apply_central_force(Vector3.UP * lift + drag.limit_length(drag_force_max) + damping.limit_length(drag_force_max))


func _spawn_surface() -> void:
	_surface = MeshInstance3D.new()
	_surface.name = "FloodSurface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(64.0, 0.08, 64.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2588, 0.7216, 0.9098, 0.68)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 0.2
	material.metallic = 0.0
	mesh.material = material
	_surface.mesh = mesh
	add_child(_surface)
	var ripple_material := StandardMaterial3D.new()
	ripple_material.albedo_color = Color(0.9569, 0.902, 0.7843, 0.75)
	ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ripple_data in [[Vector3(-8.0, 0.08, 4.0), 2.0], [Vector3(10.0, 0.08, -7.0), 3.0], [Vector3(2.0, 0.08, 12.0), 1.5]]:
		var ripple := MeshInstance3D.new()
		var ripple_mesh := TorusMesh.new()
		ripple_mesh.inner_radius = ripple_data[1]
		ripple_mesh.outer_radius = ripple_data[1] + 0.12
		ripple_mesh.rings = 32
		ripple_mesh.ring_segments = 6
		ripple_mesh.material = ripple_material
		ripple.mesh = ripple_mesh
		ripple.position = ripple_data[0]
		_surface.add_child(ripple)
	_set_water_level(start_level)


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
