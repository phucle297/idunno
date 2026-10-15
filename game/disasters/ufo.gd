class_name UFO
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }
const BEAM_RADIUS := 3.5
const LIFT_HEIGHT := 2.5
const LIFT_SPEED := 3.0

@export var warning_duration := 5.0
@export var active_duration := 4.0
var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var beam_position := Vector3.ZERO
var support_height: Callable
var captured := PackedInt32Array()
var _manager: MatchManager
var _players: Dictionary = {}
var _released: Dictionary = {}
var _visual: Node3D
var _beam: MeshInstance3D
var _column: MeshInstance3D
var _label: Label3D


func configure(manager: MatchManager) -> void:
	_manager = manager


func get_disaster_metadata() -> Dictionary:
	return {"name": "UFO", "difficulty": 2, "minimum_match_time": 120.0,
		"incompatible_disasters": ["Flood", "Tornado", "Earthquake", "Meteor Shower", "Lightning", "Fire", "Rockslide", "Bee Swarm", "Volcano"],
		"combination_tags": ["beam"]}


func register_player(peer_id: int, player: Node3D) -> bool:
	if not _can_mutate() or peer_id <= 0 or not is_instance_valid(player) or _players.has(peer_id):
		return false
	_players[peer_id] = player
	return true


func unregister_player(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	_players.erase(peer_id)
	captured.erase(peer_id)
	_released.erase(peer_id)
	return true


func start_disaster(rng: RandomNumberGenerator) -> bool:
	if not _can_mutate() or is_active() or not is_instance_valid(_manager) or _manager.state != MatchManager.MatchState.ACTIVE:
		return false
	var candidates: Array[Vector3] = []
	var ids := _players.keys()
	ids.sort()
	for id: int in ids:
		var player := _players[id] as PartyPlayer
		if is_instance_valid(player) and _manager.is_player_alive(id) and not player.is_knocked_down() and _exposed(player.global_position):
			candidates.append(player.global_position)
	if candidates.is_empty():
		return false
	beam_position = candidates[rng.randi_range(0, candidates.size() - 1)]
	if support_height.is_valid():
		beam_position.y = float(support_height.call(beam_position))
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = active_duration
	captured.clear()
	_released.clear()
	return true


func is_active() -> bool:
	return phase != Phase.IDLE


func _exposed(feet: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.45, feet + Vector3.UP * 80, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func tick(delta: float) -> void:
	if not _can_mutate() or not is_active() or not is_finite(delta) or delta <= 0:
		return
	if _manager.state != MatchManager.MatchState.ACTIVE:
		cleanup()
		return
	var remaining := delta
	if phase == Phase.WARNING:
		var step := minf(remaining, warning_remaining)
		warning_remaining -= step
		remaining -= step
		if warning_remaining <= 0:
			phase = Phase.ACTIVE
	if phase != Phase.ACTIVE:
		return
	active_remaining = maxf(active_remaining - remaining, 0)
	if active_remaining <= 0:
		cleanup()
		return
	for id: int in _players:
		var player := _players[id] as PartyPlayer
		if not is_instance_valid(player):
			continue
		var feet := player.global_position
		var offset := Vector2(feet.x - beam_position.x, feet.z - beam_position.z)
		var eligible := _manager.is_player_alive(id) and not player.is_knocked_down() and not _released.has(id)
		eligible = eligible and offset.length() <= BEAM_RADIUS and feet.y >= beam_position.y - 0.3 and feet.y < beam_position.y + LIFT_HEIGHT
		eligible = eligible and _exposed(feet)
		if not eligible:
			if id in captured:
				# No extra launch impulse on release, including ceiling interruption.
				player.velocity.y = minf(player.velocity.y, 0)
				captured.erase(id)
				_released[id] = true
			continue
		if id not in captured:
			captured.append(id)
		# Preserve horizontal air control. One capture/event; height and upward
		# speed are bounded rather than translating the body through collision.
		var height_left := beam_position.y + LIFT_HEIGHT - feet.y
		player.velocity.y = minf(LIFT_SPEED, height_left / maxf(remaining, 1.0 / 60))


func cleanup() -> void:
	if _can_mutate():
		for id in captured:
			var player := _players.get(id) as PartyPlayer
			if is_instance_valid(player):
				player.velocity.y = minf(player.velocity.y, 0)
	phase = Phase.IDLE
	warning_remaining = 0
	active_remaining = 0
	beam_position = Vector3.ZERO
	captured.clear()
	_released.clear()
	if is_instance_valid(_visual):
		_visual.hide()


func create_presentation_snapshot() -> Dictionary:
	return {"phase": phase, "warning": warning_remaining, "active": active_remaining,
		"position": beam_position, "captured": captured.duplicate()}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if _can_mutate():
		return false
	if not snapshot.get("position", Vector3.ZERO) is Vector3 or not snapshot.get("captured", PackedInt32Array()) is PackedInt32Array:
		return false
	var point: Vector3 = snapshot.get("position", Vector3.ZERO)
	var ids: PackedInt32Array = snapshot.get("captured", PackedInt32Array())
	if not point.is_finite() or ids.size() > 20:
		return false
	phase = clampi(int(snapshot.get("phase", 0)), 0, 2)
	warning_remaining = maxf(float(snapshot.get("warning", 0)), 0)
	active_remaining = maxf(float(snapshot.get("active", 0)), 0)
	beam_position = point
	captured = ids.duplicate()
	return true


func _process(_delta: float) -> void:
	if not is_instance_valid(_visual):
		_visual = Node3D.new()
		add_child(_visual)
		var saucer := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 2.2
		mesh.height = 1.0
		mesh.radial_segments = 24
		mesh.rings = 8
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("73b7ad")
		material.roughness = 0.8
		mesh.material = material
		saucer.mesh = mesh
		saucer.position.y = 6.0
		_visual.add_child(saucer)
		_beam = MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = BEAM_RADIUS
		cylinder.bottom_radius = BEAM_RADIUS
		cylinder.height = 0.04
		cylinder.radial_segments = 32
		_beam.mesh = cylinder
		material = StandardMaterial3D.new()
		material.albedo_color = Color("ffbf3f")
		_beam.material_override = material
		_beam.position.y = 0.04
		_visual.add_child(_beam)
		_column = MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = 1.5
		column.bottom_radius = BEAM_RADIUS
		column.height = 5.5
		column.radial_segments = 24
		_column.mesh = column
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.72, 0.57, 1.0, 0.12)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_column.material_override = material
		_column.position.y = 2.8
		_visual.add_child(_column)
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.position.y = 3.5
		_label.font_size = 36
		_label.pixel_size = 0.012
		_visual.add_child(_label)
	_visual.visible = is_active()
	_visual.position = beam_position
	_column.visible = phase == Phase.ACTIVE
	(_beam.material_override as StandardMaterial3D).albedo_color = Color("ffbf3f") if phase == Phase.WARNING else Color("b892ff")
	_label.text = "UFO — LEAVE RING %.0fs" % ceilf(warning_remaining) if phase == Phase.WARNING else "UFO — MOVE SIDEWAYS TO ESCAPE"


func _physics_process(delta: float) -> void:
	tick(delta)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
