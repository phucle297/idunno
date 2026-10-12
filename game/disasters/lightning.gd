class_name Lightning
extends Node3D

signal warning_started(target: Vector3, duration: float)
signal struck(target: Vector3)
signal finished

enum Phase {
	IDLE,
	WARNING,
	FLASH
}

const DISASTER_NAME := "Lightning"
const DAMAGE_CAUSE := "Lightning"

@export var warning_duration := 2.0
@export var strike_radius := 2.5
@export var direct_radius := 0.75
@export var direct_damage := 70.0
@export var edge_damage := 25.0
@export var knockdown_speed := 6.0
@export var flash_duration := 0.45

var phase := Phase.IDLE
var warning_remaining := 0.0
var flash_remaining := 0.0
var target_position := Vector3.ZERO
var strike_count := 0
var strike_half_extent := 18.0

var _match_manager: MatchManager
var _players: Dictionary = {}
var _effect: Node3D


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func set_strike_area(half_extent: float) -> void:
	strike_half_extent = half_extent


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 2,
		"minimum_match_time": 60.0,
		"incompatible_disasters": [],
		"combination_tags": ["electric", "water"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	return start_warning(Vector3(rng.randf_range(-strike_half_extent, strike_half_extent), 0.06, rng.randf_range(-strike_half_extent, strike_half_extent)))


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


func start_warning(target: Vector3) -> bool:
	if not _can_mutate() or phase != Phase.IDLE or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE:
		return false
	target_position = Vector3(target.x, maxf(target.y, 0.06), target.z)
	warning_remaining = warning_duration
	flash_remaining = flash_duration
	phase = Phase.WARNING
	_spawn_effect()
	warning_started.emit(target_position, warning_duration)
	return true


func tick(delta: float) -> void:
	if not _can_mutate() or phase == Phase.IDLE:
		return
	var safe_delta := maxf(delta, 0.0)
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		_update_effect()
		if warning_remaining <= 0.0:
			_apply_strike()
	elif phase == Phase.FLASH:
		flash_remaining = maxf(flash_remaining - safe_delta, 0.0)
		_update_effect()
		if flash_remaining <= 0.0:
			_finish()


func cleanup() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	flash_remaining = 0.0


func active_effect_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func create_presentation_snapshot() -> Dictionary:
	return {
		"phase": int(phase),
		"warning_remaining": warning_remaining,
		"flash_remaining": flash_remaining,
		"target": target_position,
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var next_phase := clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.FLASH)
	if next_phase == Phase.IDLE:
		cleanup()
		return true
	phase = next_phase
	warning_remaining = maxf(float(snapshot.get("warning_remaining", 0.0)), 0.0)
	flash_remaining = maxf(float(snapshot.get("flash_remaining", 0.0)), 0.0)
	target_position = snapshot.get("target", Vector3.ZERO)
	if not is_instance_valid(_effect):
		_spawn_effect()
	_update_effect()
	return true


func _process(delta: float) -> void:
	tick(delta)


func _apply_strike() -> void:
	if phase != Phase.WARNING:
		return
	phase = Phase.FLASH
	warning_remaining = 0.0
	strike_count += 1
	var damage_events: Array[Dictionary] = []
	var affected: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as PartyPlayer
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var distance := Vector2(player.global_position.x - target_position.x, player.global_position.z - target_position.z).length()
		if distance > strike_radius:
			continue
		var proximity := 1.0 - distance / strike_radius
		var damage := direct_damage if distance <= direct_radius else lerpf(edge_damage, direct_damage, proximity)
		damage_events.append({"peer_id": peer_id, "amount": damage, "cause": DAMAGE_CAUSE})
		affected.append({"peer_id": peer_id, "player": player})
	if not damage_events.is_empty():
		_match_manager.apply_damage_batch(damage_events)
	for entry in affected:
		if _match_manager.is_player_alive(int(entry.peer_id)):
			var player := entry.player as PartyPlayer
			var direction := Vector3(player.global_position.x - target_position.x, 0.65, player.global_position.z - target_position.z)
			if direction.length_squared() < 0.01:
				direction = Vector3(0.7, 0.65, 0.0)
			player.apply_knockdown(direction.normalized() * knockdown_speed)
	struck.emit(target_position)


func _spawn_effect() -> void:
	_effect = Node3D.new()
	_effect.name = "LightningEffect"
	_effect.position = target_position
	add_child(_effect)
	var violet := StandardMaterial3D.new()
	violet.albedo_color = Color(0.63, 0.42, 0.95, 0.78)
	violet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	violet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.name = "TargetRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = strike_radius - 0.18
	ring_mesh.outer_radius = strike_radius
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 8
	ring_mesh.material = violet
	ring.mesh = ring_mesh
	ring.position.y = 0.08
	_effect.add_child(ring)
	var column := MeshInstance3D.new()
	column.name = "TargetColumn"
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.07
	column_mesh.bottom_radius = 0.18
	column_mesh.height = 9.0
	column_mesh.radial_segments = 10
	column_mesh.material = violet
	column.mesh = column_mesh
	column.position.y = 4.5
	_effect.add_child(column)
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.position.y = 2.5
	flash.light_color = Color(0.72, 0.58, 1.0)
	flash.omni_range = 8.0
	flash.light_energy = 0.0
	_effect.add_child(flash)
	_update_effect()


func _update_effect() -> void:
	if not is_instance_valid(_effect):
		return
	var ring := _effect.get_node("TargetRing") as MeshInstance3D
	var column := _effect.get_node("TargetColumn") as MeshInstance3D
	var flash := _effect.get_node("Flash") as OmniLight3D
	if phase == Phase.WARNING:
		var pulse := 1.0 + sin(warning_remaining * TAU * 3.0) * 0.08
		ring.scale = Vector3(pulse, 1.0, pulse)
		column.scale.x = pulse
		column.scale.z = pulse
		flash.light_energy = 0.0
	else:
		ring.visible = false
		column.scale = Vector3(2.4, 1.0, 2.4)
		column.material_override = _flash_material()
		flash.light_energy = 8.0 * flash_remaining / maxf(flash_duration, 0.001)


func _flash_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.92, 1.0, 0.95)
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
