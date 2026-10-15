class_name BeeSwarm
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }
const SPEED := 3.0
const REACH := 1.4
const STING_DAMAGE := 8.0
const PURSUIT_TIME := 6.0
const RETARGET_WARNING := 3.0
const MAX_STALLED_TIME := 2.0

@export var warning_duration := 5.0
@export var active_duration := 24.0
var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var target_id := 0
var swarm_position := Vector3.ZERO
var water_level: Callable
var target_is_viable: Callable
var _manager: MatchManager
var _players: Dictionary = {}
var _last_target := 0
var _pursuit_remaining := 0.0
var _sting_remaining := 0.0
var _stalled := 0.0
var _visual: Node3D
var _label: Label3D
var _bees: Array[MeshInstance3D] = []
var _visual_time := 0.0


func configure(manager: MatchManager) -> void:
	_manager = manager


func get_disaster_metadata() -> Dictionary:
	return {"name": "Bee Swarm", "difficulty": 1, "minimum_match_time": 30.0,
		"incompatible_disasters": ["Tornado", "Earthquake", "UFO", "Volcano", "Fire", "Rockslide", "Meteor Shower", "Lightning"],
		"combination_tags": ["pursuit"]}


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


func start_disaster(rng: RandomNumberGenerator) -> bool:
	if not _can_mutate() or is_active() or not is_instance_valid(_manager) or _manager.state != MatchManager.MatchState.ACTIVE:
		return false
	var candidates := _eligible_targets()
	if candidates.is_empty():
		return false
	_last_target = candidates[rng.randi_range(0, candidates.size() - 1)]
	# Rotation starts after this seeded predecessor; transfers never consume RNG.
	active_remaining = active_duration
	if not _select_target(warning_duration):
		return false
	swarm_position = (_players[target_id] as Node3D).global_position + Vector3.UP
	return true


func is_active() -> bool:
	return phase != Phase.IDLE


func _eligible_targets() -> Array[int]:
	var candidates: Array[int] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as Node3D
		if is_instance_valid(player) and _manager.is_player_alive(peer_id) and not _protected(player.global_position):
			if not target_is_viable.is_valid() or bool(target_is_viable.call(player.global_position)):
				candidates.append(peer_id)
	candidates.sort()
	return candidates


func _select_target(warning: float) -> bool:
	var candidates := _eligible_targets()
	if candidates.is_empty():
		cleanup()
		return false
	var index := candidates.find(_last_target)
	target_id = candidates[(index + 1) % candidates.size()]
	_last_target = target_id
	phase = Phase.WARNING
	warning_remaining = warning
	_pursuit_remaining = PURSUIT_TIME
	_sting_remaining = 1.0
	_stalled = 0.0
	return true


func _protected(feet: Vector3) -> bool:
	if water_level.is_valid() and float(water_level.call()) >= feet.y + 1.5:
		return true
	# Actual overhead collision, not a player action or an arbitrary shelter tag.
	return not _clear(feet + Vector3.UP * 1.4, feet + Vector3.UP * 80.0)


func _clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _move_toward(goal: Vector3, delta: float) -> void:
	var direction := swarm_position.direction_to(goal)
	var distance := minf(SPEED * delta, swarm_position.distance_to(goal))
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, swarm_position)
	# Bounded local steering: never tunnel through walls or search indefinitely.
	for angle in [0.0, PI / 3, -PI / 3]:
		var motion := direction.rotated(Vector3.UP, angle) * distance
		query.motion = motion
		var result := get_world_3d().direct_space_state.cast_motion(query)
		if result[0] >= 0.99 and _clear(swarm_position + motion, goal):
			swarm_position += motion
			_stalled = 0.0
			return
	_stalled += delta


func tick(delta: float) -> void:
	if not _can_mutate() or not is_active() or not is_finite(delta) or delta <= 0:
		return
	if _manager.state != MatchManager.MatchState.ACTIVE:
		cleanup()
		return
	# Fixed substeps preserve warnings and sting intervals across caller partitions.
	var remaining := delta
	while remaining > 0.00001 and is_active():
		var step := minf(remaining, 1.0 / 60)
		remaining -= step
		_step(step)


func _step(delta: float) -> void:
	var player := _players.get(target_id) as Node3D
	if not is_instance_valid(player) or not _manager.is_player_alive(target_id) or _protected(player.global_position):
		_select_target(RETARGET_WARNING)
		return
	active_remaining = maxf(active_remaining - delta, 0)
	if active_remaining <= 0:
		cleanup()
		return
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - delta, 0)
		if warning_remaining <= 0.00001:
			phase = Phase.ACTIVE
		return
	_pursuit_remaining -= delta
	if _pursuit_remaining <= 0 or _stalled >= MAX_STALLED_TIME:
		_select_target(RETARGET_WARNING)
		return
	var goal := player.global_position + Vector3.UP
	_move_toward(goal, delta)
	_sting_remaining -= delta
	if _sting_remaining <= 0 and swarm_position.distance_to(goal) <= REACH and _clear(swarm_position, goal):
		_sting_remaining = 1.0
		_manager.apply_damage(target_id, STING_DAMAGE, "Bee Swarm")


func cleanup() -> void:
	phase = Phase.IDLE
	warning_remaining = 0
	active_remaining = 0
	target_id = 0
	_last_target = 0
	_pursuit_remaining = 0
	_sting_remaining = 0
	_stalled = 0
	swarm_position = Vector3.ZERO
	if is_instance_valid(_visual):
		_visual.hide()


func create_presentation_snapshot() -> Dictionary:
	return {"phase": phase, "warning": warning_remaining, "active": active_remaining,
		"target": target_id, "position": swarm_position}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if _can_mutate():
		return false
	if not snapshot.get("position", Vector3.ZERO) is Vector3:
		return false
	var point: Vector3 = snapshot.get("position", Vector3.ZERO)
	if not point.is_finite():
		return false
	phase = clampi(int(snapshot.get("phase", 0)), 0, 2)
	warning_remaining = maxf(float(snapshot.get("warning", 0)), 0)
	active_remaining = maxf(float(snapshot.get("active", 0)), 0)
	target_id = maxi(int(snapshot.get("target", 0)), 0)
	swarm_position = point
	return true


func _process(delta: float) -> void:
	_visual_time += delta
	if not is_instance_valid(_visual):
		_visual = Node3D.new()
		add_child(_visual)
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 36
		_label.pixel_size = 0.012
		_label.position.y = 1.3
		_visual.add_child(_label)
		for index in 12:
			var bee := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.12
			mesh.height = 0.2
			mesh.radial_segments = 8
			mesh.rings = 4
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("ffbf3f") if index % 2 == 0 else Color("202a38")
			mesh.material = material
			bee.mesh = mesh
			_visual.add_child(bee)
			_bees.append(bee)
	_visual.visible = is_active()
	_visual.position = swarm_position
	_label.text = "BEES → #%d%s" % [target_id, " — %.0fs" % ceilf(warning_remaining) if phase == Phase.WARNING else " — RUN / SHELTER"]
	for index in _bees.size():
		var angle := _visual_time * 4 + index * 2.4
		_bees[index].position = Vector3(cos(angle), sin(angle * 1.7) * 0.5, sin(angle)) * 0.8


func _physics_process(delta: float) -> void:
	tick(delta)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
