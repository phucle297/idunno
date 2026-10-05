class_name MeteorShower
extends Node3D

signal warning_started(target: Vector3, duration: float)
signal impacted(target: Vector3)
signal finished

enum Phase {
	IDLE,
	WARNING,
	IMPACT
}

const TelegraphScene = preload("res://assets/generated/VFX_MeteorTelegraph_v001.tscn")
const IMPACT_CAUSE := "Meteor"
const DISASTER_NAME := "Meteor Shower"

@export var warning_duration := 2.5
@export var impact_radius := 3.0
@export var direct_hit_radius := 0.75
@export var edge_damage := 20.0
@export var player_impulse_max := 8.0
@export var prop_impulse_max := 18.0
@export var impact_visual_duration := 0.65

var phase := Phase.IDLE
var warning_remaining := 0.0
var target_position := Vector3.ZERO
var impact_count := 0

var _match_manager: MatchManager
var _players: Dictionary = {}
var _effect: Node3D
var _impact_remaining := 0.0
var _countdown: Label3D


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 1,
		"minimum_match_time": 0.0,
		"incompatible_disasters": [],
		"combination_tags": ["explosion", "debris"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	return start_warning(Vector3(rng.randf_range(-18.0, 18.0), 0.06, rng.randf_range(-18.0, 18.0)))


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
	phase = Phase.WARNING
	_spawn_telegraph()
	warning_started.emit(target_position, warning_duration)
	return true


func tick(delta: float) -> void:
	if not _can_mutate():
		return
	var safe_delta := maxf(delta, 0.0)
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		_update_warning_visual()
		if warning_remaining <= 0.0:
			_apply_impact()
	elif phase == Phase.IMPACT:
		_impact_remaining = maxf(_impact_remaining - safe_delta, 0.0)
		_update_impact_visual()
		if _impact_remaining <= 0.0:
			_finish_impact()


func cleanup() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	_countdown = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	_impact_remaining = 0.0


func active_effect_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func _process(delta: float) -> void:
	tick(delta)


func _spawn_telegraph() -> void:
	_effect = TelegraphScene.instantiate()
	_effect.name = "MeteorEffect"
	_effect.position = target_position
	add_child(_effect)
	var footprint := _effect.get_node("WarningFootprint") as MeshInstance3D
	footprint.scale = Vector3(2.0, 1.0, 2.0)
	var meteor := _effect.get_node("Meteor") as MeshInstance3D
	meteor.position.y = 14.0
	meteor.scale = Vector3.ONE * 1.35
	_style_meteor(meteor)
	_countdown = Label3D.new()
	_countdown.name = "Countdown"
	_countdown.position = Vector3(0.0, 0.45, 0.0)
	_countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_countdown.font_size = 128
	_countdown.pixel_size = 0.01
	_countdown.modulate = Color("202a38")
	_countdown.outline_size = 18
	_countdown.outline_modulate = Color("ffbf3f")
	_countdown.no_depth_test = true
	_effect.add_child(_countdown)
	_update_warning_visual()


func _style_meteor(meteor: MeshInstance3D) -> void:
	meteor.material_override = load("res://assets/materials/MAT_Slate_v001.tres")
	var core := MeshInstance3D.new()
	core.name = "HotCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.24
	core_mesh.height = 0.48
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	core_mesh.material = load("res://assets/materials/MAT_Orange_v001.tres")
	core.mesh = core_mesh
	core.position = Vector3(0.0, -0.28, 0.30)
	meteor.add_child(core)
	var trail := MeshInstance3D.new()
	trail.name = "Trail"
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = 0.04
	trail_mesh.bottom_radius = 0.18
	trail_mesh.height = 1.5
	trail_mesh.radial_segments = 8
	trail_mesh.material = load("res://assets/materials/MAT_Orange_v001.tres")
	trail.mesh = trail_mesh
	trail.position.y = 0.95
	meteor.add_child(trail)


func _update_warning_visual() -> void:
	if not is_instance_valid(_effect):
		return
	var progress := 1.0 - warning_remaining / maxf(warning_duration, 0.001)
	var footprint := _effect.get_node("WarningFootprint") as MeshInstance3D
	var pulse := 1.0 + sin(progress * TAU * 4.0) * 0.08
	footprint.scale = Vector3(2.0 * pulse, 1.0, 2.0 * pulse)
	var meteor := _effect.get_node("Meteor") as MeshInstance3D
	meteor.position.y = lerpf(14.0, 0.8, progress)
	if is_instance_valid(_countdown):
		_countdown.text = str(maxi(1, ceili(warning_remaining)))


func _apply_impact() -> void:
	if phase != Phase.WARNING:
		return
	phase = Phase.IMPACT
	warning_remaining = 0.0
	_impact_remaining = impact_visual_duration
	impact_count += 1
	_show_impact_visual()

	var damage_events: Array[Dictionary] = []
	var affected_players: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var distance := _horizontal_distance(player.global_position, target_position)
		if distance > impact_radius:
			continue
		var proximity := 1.0 - distance / impact_radius
		var damage := 100.0 if distance <= direct_hit_radius else lerpf(edge_damage, 100.0, proximity)
		damage_events.append({"peer_id": peer_id, "amount": damage, "cause": IMPACT_CAUSE})
		affected_players.append({"peer_id": peer_id, "player": player, "distance": distance})
	_match_manager.apply_damage_batch(damage_events)

	for affected: Dictionary in affected_players:
		var peer_id: int = affected.peer_id
		if not _match_manager.is_player_alive(peer_id):
			continue
		var player := affected.player as Node3D
		var impulse := _radial_impulse(player.global_position, affected.distance, player_impulse_max)
		player.apply_knockdown(impulse)

	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body):
			continue
		var distance := _horizontal_distance(body.global_position, target_position)
		if distance > impact_radius:
			continue
		if body.has_meta("grab_owner_peer_id"):
			var owner_id := int(body.get_meta("grab_owner_peer_id"))
			var owner := _players.get(owner_id) as Node3D
			if is_instance_valid(owner):
				owner.release_held_object()
		body.sleeping = false
		body.apply_central_impulse(_radial_impulse(body.global_position, distance, prop_impulse_max))
	impacted.emit(target_position)


func _show_impact_visual() -> void:
	if not is_instance_valid(_effect):
		return
	_effect.get_node("WarningFootprint").visible = false
	_effect.get_node("Meteor").position.y = 0.8
	if is_instance_valid(_countdown):
		_countdown.visible = false
	var flash := MeshInstance3D.new()
	flash.name = "ImpactFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.9
	flash_mesh.height = 1.8
	flash_mesh.radial_segments = 12
	flash_mesh.rings = 6
	flash_mesh.material = load("res://assets/materials/MAT_Orange_v001.tres")
	flash.mesh = flash_mesh
	flash.position.y = 0.8
	_effect.add_child(flash)
	var ring := MeshInstance3D.new()
	ring.name = "DustRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 1.05
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	ring_mesh.material = load("res://assets/materials/MAT_Amber_v001.tres")
	ring.mesh = ring_mesh
	ring.position.y = 0.08
	_effect.add_child(ring)


func _update_impact_visual() -> void:
	if not is_instance_valid(_effect):
		return
	var progress := 1.0 - _impact_remaining / maxf(impact_visual_duration, 0.001)
	var flash := _effect.get_node_or_null("ImpactFlash") as MeshInstance3D
	if is_instance_valid(flash):
		flash.scale = Vector3.ONE * lerpf(0.4, 2.2, progress)
	var ring := _effect.get_node_or_null("DustRing") as MeshInstance3D
	if is_instance_valid(ring):
		ring.scale = Vector3.ONE * lerpf(0.5, 3.0, progress)


func _finish_impact() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	cleanup()
	finished.emit()


func _radial_impulse(position: Vector3, distance: float, maximum: float) -> Vector3:
	var direction := Vector3(position.x - target_position.x, 0.0, position.z - target_position.z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.RIGHT
	else:
		direction = direction.normalized()
	var proximity := clampf(1.0 - distance / impact_radius, 0.0, 1.0)
	var strength := lerpf(maximum * 0.25, maximum, proximity)
	return (direction + Vector3.UP * 0.45).normalized() * strength


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
