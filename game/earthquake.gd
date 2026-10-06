class_name Earthquake
extends Node3D

signal warning_started(duration: float)
signal activated
signal structure_changed(piece_id: String, state: int)
signal finished

enum Phase {
	IDLE,
	WARNING,
	ACTIVE
}

const DISASTER_NAME := "Earthquake"
const DAMAGE_CAUSE := "Earthquake"

@export var warning_duration := 4.0
@export var active_duration := 8.0
@export var pulse_interval := 1.25
@export var pulse_damage := 5.0
@export var player_velocity_cap := 4.5
@export var prop_impulse_max := 12.0
@export var max_broken_sections := 2

var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var pulse_count := 0

var _match_manager: MatchManager
var _players: Dictionary = {}
var _pulse_remaining := 0.0
var _rng := RandomNumberGenerator.new()
var _effect: Node3D


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 2,
		"minimum_match_time": 90.0,
		"incompatible_disasters": [],
		"combination_tags": ["ground", "debris", "structure"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	_rng.seed = rng.randi()
	return start_warning()


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


func start_warning() -> bool:
	if not _can_mutate() or phase != Phase.IDLE or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE:
		return false
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = active_duration
	_pulse_remaining = 0.0
	pulse_count = 0
	_spawn_effect()
	warning_started.emit(warning_duration)
	return true


func tick(delta: float) -> void:
	if not _can_mutate() or phase == Phase.IDLE:
		return
	var safe_delta := maxf(delta, 0.0)
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		_update_effect()
		if warning_remaining <= 0.0:
			phase = Phase.ACTIVE
			_pulse_remaining = 0.0
			activated.emit()
	elif phase == Phase.ACTIVE:
		active_remaining = maxf(active_remaining - safe_delta, 0.0)
		_pulse_remaining -= safe_delta
		while _pulse_remaining <= 0.0 and active_remaining > 0.0:
			_pulse_remaining += pulse_interval
			_apply_pulse()
		_update_effect()
		if active_remaining <= 0.0:
			_finish()


func cleanup() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	active_remaining = 0.0
	_pulse_remaining = 0.0


func active_effect_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func create_presentation_snapshot() -> Dictionary:
	var structure_states := PackedByteArray()
	for section in _sections():
		structure_states.append(section.structure_state)
	return {
		"phase": int(phase),
		"warning_remaining": warning_remaining,
		"active_remaining": active_remaining,
		"structure_states": structure_states,
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var next_phase := clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.ACTIVE)
	if next_phase == Phase.IDLE:
		cleanup()
	else:
		phase = next_phase
		warning_remaining = maxf(float(snapshot.get("warning_remaining", 0.0)), 0.0)
		active_remaining = maxf(float(snapshot.get("active_remaining", 0.0)), 0.0)
		if not is_instance_valid(_effect):
			_spawn_effect()
		_update_effect()
	var structure_states: PackedByteArray = snapshot.get("structure_states", PackedByteArray())
	var sections := _sections()
	for index in mini(structure_states.size(), sections.size()):
		sections[index].set_structure_state(int(structure_states[index]), false)
	return true


func get_structure_states() -> Dictionary:
	var result := {}
	for section in _sections():
		result[section.piece_id] = section.structure_state
	return result


func _process(delta: float) -> void:
	tick(delta)


func _apply_pulse() -> void:
	pulse_count += 1
	var damage_events: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as PartyPlayer
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		damage_events.append({"peer_id": peer_id, "amount": pulse_damage, "cause": DAMAGE_CAUSE})
		var direction := Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(0.25, 0.55),
			_rng.randf_range(-1.0, 1.0)
		).normalized()
		player.apply_hazard_velocity(direction * player_velocity_cap, player_velocity_cap)
		if pulse_count % 3 == 0 and not player.is_knocked_down():
			player.apply_knockdown(direction * 3.0)
	if not damage_events.is_empty():
		_match_manager.apply_damage_batch(damage_events)
	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.sleeping = false
		body.apply_central_impulse(Vector3(
			_rng.randf_range(-1.0, 1.0),
			0.35,
			_rng.randf_range(-1.0, 1.0)
		).normalized() * prop_impulse_max)
	_damage_structure()


func _damage_structure() -> void:
	var candidates: Array[BreakableStructure] = []
	var broken_count := 0
	for section in _sections():
		if section.structure_state == BreakableStructure.StructureState.BROKEN:
			broken_count += 1
		else:
			candidates.append(section)
	if candidates.is_empty():
		return
	var section := candidates[_rng.randi_range(0, candidates.size() - 1)]
	if section.structure_state == BreakableStructure.StructureState.DAMAGED and broken_count >= max_broken_sections:
		return
	if section.apply_damage(true):
		structure_changed.emit(section.piece_id, section.structure_state)


func _sections() -> Array[BreakableStructure]:
	var result: Array[BreakableStructure] = []
	if not is_inside_tree():
		return result
	for candidate in get_tree().get_nodes_in_group("breakable_structure"):
		if candidate is BreakableStructure:
			result.append(candidate)
	result.sort_custom(func(a: BreakableStructure, b: BreakableStructure) -> bool: return a.piece_id < b.piece_id)
	return result


func _spawn_effect() -> void:
	_effect = Node3D.new()
	_effect.name = "EarthquakeEffect"
	add_child(_effect)
	var crack_material := StandardMaterial3D.new()
	crack_material.albedo_color = Color(0.125, 0.165, 0.22, 1.0)
	crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in 6:
		var crack := MeshInstance3D.new()
		crack.name = "Crack%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(4.0 + index * 0.45, 0.035, 0.24)
		mesh.material = crack_material
		crack.mesh = mesh
		crack.position = Vector3(-10.0 + index * 4.0, 0.11, -7.0 + (index % 3) * 7.0)
		crack.rotation.y = deg_to_rad(-35.0 + index * 13.0)
		_effect.add_child(crack)
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.941, 0.392, 0.22, 0.82)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in 3:
		var dust := MeshInstance3D.new()
		dust.name = "Dust%d" % index
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.2 + index * 0.8
		mesh.outer_radius = mesh.inner_radius + 0.28
		mesh.rings = 24
		mesh.ring_segments = 6
		mesh.material = dust_material
		dust.mesh = mesh
		dust.position = Vector3(-8.0 + index * 8.0, 0.12, -4.0 + index * 4.0)
		_effect.add_child(dust)
	_update_effect()


func _update_effect() -> void:
	if not is_instance_valid(_effect):
		return
	var time := warning_remaining if phase == Phase.WARNING else active_remaining
	var strength := 0.08 if phase == Phase.WARNING else 0.22
	_effect.position.x = sin(time * 20.0) * strength
	_effect.position.z = cos(time * 17.0) * strength
	for index in 3:
		var dust := _effect.get_node("Dust%d" % index) as MeshInstance3D
		var pulse := 1.0 + sin(time * 7.0 + index) * (0.08 if phase == Phase.WARNING else 0.2)
		dust.scale = Vector3(pulse, 1.0, pulse)


func _finish() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	cleanup()
	finished.emit()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
