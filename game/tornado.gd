class_name Tornado
extends Node3D

signal warning_started(start: Vector3, duration: float)
signal activated
signal finished

enum Phase {
	IDLE,
	WARNING,
	ACTIVE
}

const DISASTER_NAME := "Tornado"

@export var warning_duration := 3.0
@export var influence_radius := 8.0
@export var core_radius := 2.0
@export var travel_speed := 2.0
@export var pull_acceleration_max := 13.0
@export var player_speed_cap := 8.0
@export var prop_force_max := 220.0
@export var lift_time := 0.75
@export var throw_speed := 8.0
@export var cover_multiplier := 0.25

var phase := Phase.IDLE
var warning_remaining := 0.0
var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var active_duration := 0.0
var active_elapsed := 0.0
var throw_count := 0

var _match_manager: MatchManager
var _players: Dictionary = {}
var _core_exposure: Dictionary = {}
var _thrown_players: Dictionary = {}
var _cover_volumes: Array[AABB] = []
var path_presets: Array = [
	[Vector3(-24.0, 0.0, -12.0), Vector3(24.0, 0.0, 12.0)],
	[Vector3(24.0, 0.0, -12.0), Vector3(-24.0, 0.0, 12.0)],
	[Vector3(-12.0, 0.0, -24.0), Vector3(12.0, 0.0, 24.0)],
	[Vector3(12.0, 0.0, -24.0), Vector3(-12.0, 0.0, 24.0)]
]
var _effect: Node3D


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 2,
		"minimum_match_time": 120.0,
		"incompatible_disasters": [],
		"combination_tags": ["wind", "debris"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	if path_presets.is_empty():
		return false
	var path: Array = path_presets[rng.randi_range(0, path_presets.size() - 1)]
	return start_warning(path[0], path[1])


func is_active() -> bool:
	return phase != Phase.IDLE


func register_player(peer_id: int, player: Node3D) -> bool:
	if not _can_mutate() or peer_id <= 0 or not is_instance_valid(player) or _players.has(peer_id):
		return false
	_players[peer_id] = player
	return true


func unregister_player(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	_players.erase(peer_id)
	_core_exposure.erase(peer_id)
	_thrown_players.erase(peer_id)
	return true


func add_cover_volume(volume: AABB) -> void:
	_cover_volumes.append(volume)


func set_cover_volumes(volumes: Array) -> void:
	_cover_volumes.clear()
	for volume in volumes:
		_cover_volumes.append(volume as AABB)


func set_path_presets(paths: Array) -> void:
	path_presets = paths.duplicate()


func start_warning(path_start: Vector3, path_end: Vector3) -> bool:
	if not _can_mutate() or phase != Phase.IDLE or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE:
		return false
	start_position = Vector3(path_start.x, 0.0, path_start.z)
	end_position = Vector3(path_end.x, 0.0, path_end.z)
	if start_position.distance_to(end_position) < 0.1:
		return false
	active_duration = start_position.distance_to(end_position) / maxf(travel_speed, 0.01)
	active_elapsed = 0.0
	warning_remaining = warning_duration
	phase = Phase.WARNING
	_core_exposure.clear()
	_thrown_players.clear()
	_spawn_effect()
	warning_started.emit(start_position, warning_duration)
	return true


func tick(delta: float) -> void:
	if not _can_mutate() or phase == Phase.IDLE:
		return
	var safe_delta := maxf(delta, 0.0)
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		_update_warning_visual()
		if warning_remaining <= 0.0:
			phase = Phase.ACTIVE
			activated.emit()
	elif phase == Phase.ACTIVE:
		active_elapsed = minf(active_elapsed + safe_delta, active_duration)
		var progress := active_elapsed / maxf(active_duration, 0.001)
		global_position = start_position.lerp(end_position, progress)
		_apply_forces(safe_delta)
		_update_active_visual(safe_delta)
		if active_elapsed >= active_duration:
			_finish()


func cleanup() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	active_elapsed = 0.0
	active_duration = 0.0
	_core_exposure.clear()
	_thrown_players.clear()


func active_effect_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func create_presentation_snapshot() -> Dictionary:
	return {
		"phase": int(phase),
		"warning_remaining": warning_remaining,
		"start_position": start_position,
		"end_position": end_position,
		"active_duration": active_duration,
		"active_elapsed": active_elapsed,
		"position": global_position,
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var next_phase := clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.ACTIVE)
	if next_phase == Phase.IDLE:
		cleanup()
		return true
	phase = next_phase
	warning_remaining = maxf(float(snapshot.get("warning_remaining", 0.0)), 0.0)
	start_position = snapshot.get("start_position", Vector3.ZERO)
	end_position = snapshot.get("end_position", Vector3.ZERO)
	active_duration = maxf(float(snapshot.get("active_duration", 0.0)), 0.0)
	active_elapsed = clampf(float(snapshot.get("active_elapsed", 0.0)), 0.0, active_duration)
	if not is_instance_valid(_effect):
		_spawn_effect()
	global_position = snapshot.get("position", start_position)
	if phase == Phase.WARNING:
		_update_warning_visual()
	else:
		_update_active_visual(0.1)
	return true


func is_position_covered(position: Vector3) -> bool:
	for volume in _cover_volumes:
		if volume.has_point(position):
			return true
	return false


func _process(delta: float) -> void:
	tick(delta)


func _apply_forces(delta: float) -> void:
	for peer_id: int in _players:
		var player := _players[peer_id] as PartyPlayer
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var offset := global_position - player.global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance := horizontal.length()
		if distance > influence_radius:
			_core_exposure[peer_id] = 0.0
			continue
		var proximity := 1.0 - distance / influence_radius
		var multiplier := cover_multiplier if is_position_covered(player.global_position) else 1.0
		var inward := horizontal.normalized() if distance > 0.05 else Vector3.RIGHT
		var tangent := Vector3(-inward.z, 0.0, inward.x)
		var acceleration := (inward + tangent * 0.45 + Vector3.UP * proximity * 0.55).normalized()
		player.apply_hazard_velocity(acceleration * pull_acceleration_max * proximity * multiplier * delta, player_speed_cap)
		if distance <= core_radius and multiplier >= 1.0:
			var exposure := float(_core_exposure.get(peer_id, 0.0)) + delta
			_core_exposure[peer_id] = exposure
			if not player.is_knocked_down():
				player.apply_knockdown((tangent + Vector3.UP).normalized() * 4.0)
			if exposure >= lift_time and not _thrown_players.has(peer_id):
				var outward := -inward
				player.apply_hazard_velocity((outward + Vector3.UP * 0.75).normalized() * throw_speed, throw_speed)
				_thrown_players[peer_id] = true
				throw_count += 1
		else:
			_core_exposure[peer_id] = 0.0

	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body):
			continue
		var offset := global_position - body.global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance := horizontal.length()
		if distance > influence_radius:
			continue
		if body.has_meta("grab_owner_peer_id"):
			var owner := _players.get(int(body.get_meta("grab_owner_peer_id"))) as PartyPlayer
			if is_instance_valid(owner):
				owner.release_held_object()
		var inward := horizontal.normalized() if distance > 0.05 else Vector3.RIGHT
		var tangent := Vector3(-inward.z, 0.0, inward.x)
		var proximity := 1.0 - distance / influence_radius
		var force := (inward + tangent * 0.6 + Vector3.UP * proximity).normalized() * prop_force_max * proximity
		body.sleeping = false
		body.apply_central_force(force.limit_length(prop_force_max))


func _spawn_effect() -> void:
	global_position = start_position
	_effect = Node3D.new()
	_effect.name = "TornadoEffect"
	add_child(_effect)
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.2863, 0.3373, 0.4157, 0.68)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var funnel := MeshInstance3D.new()
	funnel.name = "Funnel"
	var funnel_mesh := CylinderMesh.new()
	funnel_mesh.top_radius = 1.8
	funnel_mesh.bottom_radius = 0.35
	funnel_mesh.height = 3.8
	funnel_mesh.radial_segments = 20
	funnel_mesh.material = dust_material
	funnel.mesh = funnel_mesh
	funnel.position.y = 1.9
	_effect.add_child(funnel)
	for index in 4:
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % index
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.45 + index * 0.38
		mesh.outer_radius = mesh.inner_radius + 0.18
		mesh.rings = 24
		mesh.ring_segments = 8
		mesh.material = dust_material
		ring.mesh = mesh
		ring.position.y = 0.4 + index * 0.9
		_effect.add_child(ring)
	var footprint := MeshInstance3D.new()
	footprint.name = "DangerFootprint"
	var footprint_mesh := TorusMesh.new()
	footprint_mesh.inner_radius = influence_radius - 0.22
	footprint_mesh.outer_radius = influence_radius
	footprint_mesh.rings = 48
	footprint_mesh.ring_segments = 8
	var footprint_material := StandardMaterial3D.new()
	footprint_material.albedo_color = Color(1.0, 0.749, 0.247, 0.78)
	footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint_mesh.material = footprint_material
	footprint.mesh = footprint_mesh
	footprint.position.y = 0.06
	_effect.add_child(footprint)
	var core := MeshInstance3D.new()
	core.name = "CoreFootprint"
	var core_mesh := TorusMesh.new()
	core_mesh.inner_radius = core_radius - 0.16
	core_mesh.outer_radius = core_radius
	core_mesh.rings = 32
	core_mesh.ring_segments = 8
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(0.9412, 0.3922, 0.2196, 0.9)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mesh.material = core_material
	core.mesh = core_mesh
	core.position.y = 0.07
	_effect.add_child(core)


func _update_warning_visual() -> void:
	if not is_instance_valid(_effect):
		return
	var pulse := 1.0 + sin(warning_remaining * TAU * 2.0) * 0.08
	_effect.get_node("DangerFootprint").scale = Vector3(pulse, 1.0, pulse)


func _update_active_visual(delta: float) -> void:
	if not is_instance_valid(_effect):
		return
	for index in 4:
		var ring := _effect.get_node("Ring%d" % index) as MeshInstance3D
		ring.rotation.y += delta * (2.4 + index * 0.65)
		ring.rotation.z = sin(active_elapsed * 1.7 + index) * 0.08


func _finish() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	cleanup()
	finished.emit()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
