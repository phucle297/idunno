class_name Fire
extends Node3D

signal warning_started(zone_id: int, duration: float)
signal propagation_warning(zone_id: int, duration: float)
signal zone_ignited(zone_id: int, position: Vector3)
signal wind_state_changed(active: bool)
signal finished

enum Phase {
	IDLE,
	WARNING,
	ACTIVE
}

enum ZoneState {
	SAFE,
	WARNING,
	BURNING
}

const DISASTER_NAME := "Fire"
const DAMAGE_CAUSE := "Fire"
const ZONE_POSITIONS := [
	Vector3(-12.0, 0.08, -5.0),
	Vector3(-5.0, 0.08, -5.0),
	Vector3(2.0, 0.08, -5.0),
	Vector3(9.0, 0.08, -5.0),
	Vector3(-12.0, 0.08, 5.0),
	Vector3(-5.0, 0.08, 5.0),
	Vector3(2.0, 0.08, 5.0),
	Vector3(9.0, 0.08, 5.0),
]
const ZONE_NEIGHBORS := [
	[1, 4],
	[0, 2, 5],
	[1, 3, 6],
	[2, 7],
	[0, 5],
	[1, 4, 6],
	[2, 5, 7],
	[3, 6],
]

@export var warning_duration := 3.5
@export var active_duration := 24.0
@export var zone_radius := 2.4
@export var damage_per_second := 12.0
@export var propagation_interval := 4.0
@export var propagation_warning_duration := 1.5
@export var wind_interval_multiplier := 0.5

var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var propagation_remaining := 0.0
var wind_active := false

var _match_manager: MatchManager
var _players: Dictionary = {}
var _zone_states := PackedByteArray()
var _pending_zone := -1
var _rng := RandomNumberGenerator.new()
var _effect: Node3D
var _warning_material: StandardMaterial3D
var _fire_material: StandardMaterial3D
var _amber_material: StandardMaterial3D


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager
	_reset_zone_states()


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 3,
		"minimum_match_time": 180.0,
		"incompatible_disasters": [],
		"combination_tags": ["fire", "wind", "flammable"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	_rng.seed = rng.randi()
	return start_warning(_rng.randi_range(0, ZONE_POSITIONS.size() - 1))


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
	return true


func start_warning(zone_id: int) -> bool:
	if not _can_mutate() or phase != Phase.IDLE or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE or zone_id < 0 or zone_id >= ZONE_POSITIONS.size():
		return false
	_reset_zone_states()
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = active_duration
	_pending_zone = zone_id
	_zone_states[zone_id] = ZoneState.WARNING
	_spawn_effect()
	_update_effect()
	warning_started.emit(zone_id, warning_duration)
	return true


func set_wind_active(active: bool) -> bool:
	if not _can_mutate() or wind_active == active:
		return false
	wind_active = active
	wind_state_changed.emit(active)
	return true


func tick(delta: float) -> void:
	if not _can_mutate() or phase == Phase.IDLE:
		return
	var safe_delta := maxf(delta, 0.0)
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		if warning_remaining <= 0.0:
			phase = Phase.ACTIVE
			_ignite_pending_zone()
			propagation_remaining = _current_propagation_interval()
	elif phase == Phase.ACTIVE:
		active_remaining = maxf(active_remaining - safe_delta, 0.0)
		_apply_fire_damage(safe_delta)
		propagation_remaining -= safe_delta
		if _pending_zone >= 0 and propagation_remaining <= 0.0:
			_ignite_pending_zone()
			propagation_remaining = _current_propagation_interval()
		elif _pending_zone < 0 and propagation_remaining <= propagation_warning_duration:
			_warn_next_zone()
		if active_remaining <= 0.0:
			_finish()
	_update_effect()


func cleanup() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	_warning_material = null
	_fire_material = null
	_amber_material = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	active_remaining = 0.0
	propagation_remaining = 0.0
	_pending_zone = -1
	wind_active = false
	_reset_zone_states()


func active_effect_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func get_zone_state(zone_id: int) -> int:
	return int(_zone_states[zone_id]) if zone_id >= 0 and zone_id < _zone_states.size() else ZoneState.SAFE


func get_burning_zone_ids() -> Array[int]:
	var result: Array[int] = []
	for zone_id in _zone_states.size():
		if _zone_states[zone_id] == ZoneState.BURNING:
			result.append(zone_id)
	return result


func create_presentation_snapshot() -> Dictionary:
	return {
		"phase": int(phase),
		"warning": warning_remaining,
		"active": active_remaining,
		"propagation": propagation_remaining,
		"wind": wind_active,
		"zones": _zone_states,
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var next_phase := clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.ACTIVE)
	if next_phase == Phase.IDLE:
		cleanup()
		return true
	phase = next_phase
	warning_remaining = maxf(float(snapshot.get("warning", 0.0)), 0.0)
	active_remaining = maxf(float(snapshot.get("active", 0.0)), 0.0)
	propagation_remaining = maxf(float(snapshot.get("propagation", 0.0)), 0.0)
	wind_active = bool(snapshot.get("wind", false))
	_zone_states = (snapshot.get("zones", PackedByteArray()) as PackedByteArray).duplicate()
	if not is_instance_valid(_effect):
		_spawn_effect()
	_update_effect()
	return true


func _process(delta: float) -> void:
	tick(delta)


func _apply_fire_damage(delta: float) -> void:
	var damage_events: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as PartyPlayer
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		for zone_id in get_burning_zone_ids():
			var zone := ZONE_POSITIONS[zone_id] as Vector3
			if Vector2(player.global_position.x - zone.x, player.global_position.z - zone.z).length() <= zone_radius:
				damage_events.append({"peer_id": peer_id, "amount": damage_per_second * delta, "cause": DAMAGE_CAUSE})
				break
	if not damage_events.is_empty():
		_match_manager.apply_damage_batch(damage_events)


func _warn_next_zone() -> void:
	var candidates: Array[int] = []
	for burning_zone in get_burning_zone_ids():
		for neighbor: int in ZONE_NEIGHBORS[burning_zone]:
			if _zone_states[neighbor] == ZoneState.SAFE and neighbor not in candidates:
				candidates.append(neighbor)
	if candidates.is_empty():
		return
	candidates.sort()
	_pending_zone = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_zone_states[_pending_zone] = ZoneState.WARNING
	propagation_warning.emit(_pending_zone, propagation_warning_duration)


func _ignite_pending_zone() -> void:
	if _pending_zone < 0:
		return
	_zone_states[_pending_zone] = ZoneState.BURNING
	zone_ignited.emit(_pending_zone, ZONE_POSITIONS[_pending_zone])
	_pending_zone = -1


func _current_propagation_interval() -> float:
	return propagation_interval * (wind_interval_multiplier if wind_active else 1.0)


func _reset_zone_states() -> void:
	_zone_states = PackedByteArray()
	_zone_states.resize(ZONE_POSITIONS.size())
	_zone_states.fill(ZoneState.SAFE)


func _spawn_effect() -> void:
	_effect = Node3D.new()
	_effect.name = "FireEffect"
	add_child(_effect)
	_warning_material = _zone_material(Color("ffbf3f"), 0.82)
	_fire_material = _zone_material(Color("f06438"), 0.95)
	_amber_material = _zone_material(Color("ffbf3f"), 0.95)
	for zone_id in ZONE_POSITIONS.size():
		var zone := Node3D.new()
		zone.name = "Zone%d" % zone_id
		zone.position = ZONE_POSITIONS[zone_id]
		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = zone_radius - 0.2
		ring_mesh.outer_radius = zone_radius
		ring_mesh.rings = 36
		ring_mesh.ring_segments = 8
		ring.mesh = ring_mesh
		zone.add_child(ring)
		for flame_index in 4:
			var flame := MeshInstance3D.new()
			flame.name = "Flame%d" % flame_index
			var mesh := SphereMesh.new()
			mesh.radius = 0.32 + flame_index * 0.05
			mesh.height = 1.0 + flame_index * 0.12
			mesh.radial_segments = 8
			mesh.rings = 4
			flame.mesh = mesh
			flame.position = Vector3(-0.9 + flame_index * 0.6, 0.55, sin(flame_index * 2.0) * 0.45)
			zone.add_child(flame)
		_effect.add_child(zone)
	_update_effect()


func _update_effect() -> void:
	if not is_instance_valid(_effect):
		return
	for zone_id in ZONE_POSITIONS.size():
		var zone := _effect.get_node("Zone%d" % zone_id) as Node3D
		var state := get_zone_state(zone_id)
		zone.visible = state != ZoneState.SAFE
		if not zone.visible:
			continue
		var ring := zone.get_node("Ring") as MeshInstance3D
		ring.material_override = _warning_material if state == ZoneState.WARNING else _fire_material
		var pulse := 1.0 + sin((warning_remaining + propagation_remaining) * TAU * 2.0 + zone_id) * 0.08
		ring.scale = Vector3(pulse, 1.0, pulse)
		for flame_index in 4:
			var flame := zone.get_node("Flame%d" % flame_index) as MeshInstance3D
			flame.visible = state == ZoneState.BURNING
			flame.material_override = _fire_material if flame_index % 2 == 0 else _amber_material
			flame.scale.y = 0.85 + sin(active_remaining * 7.0 + flame_index) * 0.15


func _zone_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _finish() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	cleanup()
	finished.emit()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
