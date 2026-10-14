class_name Rockslide
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }
const MAX_ROCKS := 3
const RADIUS := 0.65
const MAX_SPEED := 9.0
const DAMAGE := 25.0

@export var warning_duration := 5.0
@export var active_duration := 10.0
var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var lane: Dictionary = {}
var variant := 0
var _manager: MatchManager
var _rocks: Array[CharacterBody3D] = []
var _remote_rocks: Array[MeshInstance3D] = []
var _warning: Node3D
var _players: Dictionary = {}
var _spawn_remaining := 0.0
var _spawned := 0


func configure(manager: MatchManager) -> void:
	_manager = manager


func set_lane(authored_lane: Dictionary) -> void:
	cleanup()
	lane = authored_lane.duplicate(true)


func get_disaster_metadata() -> Dictionary:
	return {"name": "Rockslide", "difficulty": 2, "minimum_match_time": 90.0,
		"incompatible_disasters": ["Tornado", "Meteor Shower", "Earthquake", "Flood", "Lightning", "Fire"],
		"combination_tags": ["rock", "ground"]}


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
	if not _can_mutate() or is_active() or lane.is_empty() or not is_instance_valid(_manager) or _manager.state != MatchManager.MatchState.ACTIVE:
		return false
	variant = rng.randi_range(0, 2)
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = active_duration
	_spawned = 0
	_spawn_remaining = 0.0
	_show_warning()
	return true


func is_active() -> bool:
	return phase != Phase.IDLE


func tick(delta: float) -> void:
	if not _can_mutate() or not is_active():
		return
	if _manager.state != MatchManager.MatchState.ACTIVE:
		cleanup()
		return
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - maxf(delta, 0), 0)
		if warning_remaining <= 0:
			phase = Phase.ACTIVE
		return
	active_remaining = maxf(active_remaining - maxf(delta, 0), 0)
	if active_remaining <= 0:
		cleanup()
		return
	_spawn_remaining -= delta
	if _spawned < MAX_ROCKS and _spawn_remaining <= 0:
		_spawn_rock()
		_spawn_remaining = 1.0 + variant * 0.2
	var impacts: Array[Dictionary] = []
	for rock in _rocks:
		if rock.get_meta("stopped", false):
			continue
		rock.velocity.y -= 20.0 * delta
		rock.velocity = rock.velocity.limit_length(MAX_SPEED)
		var motion := rock.velocity * delta
		# Swept sphere collision, including real static cover and player capsules.
		for iteration in 3:
			var collision := rock.move_and_collide(motion)
			if collision == null:
				break
			var collider := collision.get_collider()
			if collider is PartyPlayer:
				for peer_id: int in _players:
					if _players[peer_id] == collider and _manager.is_player_alive(peer_id):
						collider.apply_knockdown(Vector3(0, 2, 5))
						impacts.append({"peer_id": peer_id, "amount": DAMAGE, "cause": "Rockslide"})
				rock.set_meta("stopped", true)
				break
			if collision.get_normal().y < 0.65:
				rock.set_meta("stopped", true)
				rock.velocity = Vector3.ZERO
				break
			rock.velocity = rock.velocity.slide(collision.get_normal())
			motion = collision.get_remainder().slide(collision.get_normal())
		var visual := rock.get_child(1) as MeshInstance3D
		visual.rotate_x(rock.velocity.z * delta / RADIUS)
		if rock.position.z > (lane.low as Vector3).z + 8.0:
			rock.set_meta("stopped", true)
	# Winner evaluation can synchronously clean up every hazard. Finish this
	# iteration first; simultaneous impacts use the existing batch contract.
	if not impacts.is_empty():
		_manager.apply_damage_batch(impacts)


func _spawn_rock() -> void:
	var rock := CharacterBody3D.new()
	rock.collision_layer = 0
	rock.collision_mask = 3
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	rock.add_child(shape)
	rock.add_child(_rock_visual())
	add_child(rock)
	var offset := float((_spawned + variant) % 3 - 1) * 1.0
	rock.position = (lane.high as Vector3) + Vector3(offset, RADIUS + 0.05, 0.5)
	rock.velocity = Vector3(0, -1, 4.0)
	_rocks.append(rock)
	_spawned += 1


func _rock_visual() -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("49566a")
	material.roughness = 0.85
	mesh.material = material
	visual.mesh = mesh
	return visual


func _show_warning() -> void:
	if is_instance_valid(_warning) or lane.is_empty():
		return
	_warning = Node3D.new()
	add_child(_warning)
	var high: Vector3 = lane.high
	var low: Vector3 = lane.low
	for index in 12:
		var point := high.lerp(low, index / 11.0) + Vector3.UP * 0.04
		var stripe := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4, 0.04, 0.22)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffbf3f")
		box.material = material
		stripe.mesh = box
		stripe.position = point
		stripe.rotation.x = -atan2(high.y - low.y, high.z - low.z)
		_warning.add_child(stripe)
	var label := Label3D.new()
	label.text = "↓ ROCKSLIDE ↓"
	label.position = low + Vector3(0, 2.0, -2.0)
	label.font_size = 40
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f4e6c8")
	label.outline_modulate = Color("202a38")
	label.outline_size = 8
	_warning.add_child(label)


func cleanup() -> void:
	phase = Phase.IDLE
	warning_remaining = 0
	active_remaining = 0
	for rock in _rocks:
		rock.free()
	_rocks.clear()
	for visual in _remote_rocks:
		visual.free()
	_remote_rocks.clear()
	if is_instance_valid(_warning):
		_warning.free()
	_warning = null


func create_presentation_snapshot() -> Dictionary:
	var positions := PackedVector3Array()
	var rotations := PackedVector3Array()
	for rock in _rocks:
		positions.append(rock.position)
		rotations.append((rock.get_child(1) as Node3D).rotation)
	return {"phase": phase, "warning": warning_remaining, "active": active_remaining, "variant": variant,
		"positions": positions, "rotations": rotations}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var positions: PackedVector3Array = snapshot.get("positions", PackedVector3Array())
	var rotations: PackedVector3Array = snapshot.get("rotations", PackedVector3Array())
	if positions.size() > MAX_ROCKS or positions.size() != rotations.size():
		return false
	phase = clampi(int(snapshot.get("phase", 0)), 0, 2)
	warning_remaining = maxf(float(snapshot.get("warning", 0)), 0)
	active_remaining = maxf(float(snapshot.get("active", 0)), 0)
	variant = clampi(int(snapshot.get("variant", 0)), 0, 2)
	if phase == Phase.IDLE:
		cleanup()
		return true
	_show_warning()
	while _remote_rocks.size() > positions.size():
		_remote_rocks.pop_back().free()
	while _remote_rocks.size() < positions.size():
		var visual := _rock_visual()
		add_child(visual)
		_remote_rocks.append(visual)
	for index in positions.size():
		_remote_rocks[index].position = positions[index]
		_remote_rocks[index].rotation = rotations[index]
	return true


func _physics_process(delta: float) -> void:
	tick(delta)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
