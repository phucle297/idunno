class_name Tornado
extends Node3D

signal warning_started(start: Vector3, duration: float)
signal activated
signal finished
# T3q: a committed roof carry starts / releases. T6: the carried/thrown player
# also gets PartyPlayer.credit_fall_to(DISASTER_NAME), so main.gd credits the
# landing's fall damage to the Tornado (cause "Tornado", via "Fall").
signal carry_started(peer_id: int, target: Vector3)
signal carry_released(peer_id: int, position: Vector3)

enum Phase {
	IDLE,
	WARNING,
	ACTIVE
}

const DISASTER_NAME := "Tornado"
# T3k: an exposed standee at least this far above the lane's authored ground
# counts as a rooftop camper the published lane may bend onto.
const ROOF_TARGET_MIN_HEIGHT := 1.5
# T3q roof carry (INFERRED values from the T3q contract): hover just off the
# pad so ground braking is off, travel to the nearest lip plus a margin at
# throw_speed, then release with no upward launch.
const CARRY_HOVER_HEIGHT := 0.8
const CARRY_PAST_LIP := 1.0
const CARRY_MAX_TIME := 2.5
const CARRY_LIFT_GAIN := 8.0
const CARRY_LIFT_SPEED_MAX := 4.0
const LIP_PROBE_DIRECTIONS := 16
const LIP_PROBE_RANGE := 12.0
const LIP_PROBE_STEP := 0.25
const LIP_MIN_DROP := 1.0
const MAP_COLLISION_MASK := 1

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
var carry_count := 0
var path_preset_index := -1
var path_reversed := false

var _match_manager: MatchManager
var _players: Dictionary = {}
var _core_exposure: Dictionary = {}
var _thrown_players: Dictionary = {}
# peer_id -> {"target": Vector3, "direction": Vector3, "hover_y": float, "elapsed": float}
var _carries: Dictionary = {}
# peer_id -> true for every player carried off a roof during this event.
var _carried_players: Dictionary = {}
var _cover_volumes: Array[AABB] = []
var path_presets: Array = [
	[Vector3(-24.0, 0.0, -12.0), Vector3(24.0, 0.0, 12.0)],
	[Vector3(24.0, 0.0, -12.0), Vector3(-24.0, 0.0, 12.0)],
	[Vector3(-12.0, 0.0, -24.0), Vector3(12.0, 0.0, 24.0)],
	[Vector3(12.0, 0.0, -24.0), Vector3(-12.0, 0.0, 24.0)]
]
var _effect: Node3D
var surface_height: Callable
var path_for_terrain: Callable


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
	for attempt in 16:
		path_preset_index = rng.randi_range(0, path_presets.size() - 1)
		path_reversed = (rng.randi_range(0, 1) == 1)
		var path: Array = path_presets[path_preset_index]
		# T3k: idle standees brake at 25 m/s^2, which cancels the outer pull
		# (<= 13 m/s^2), so only the core moves a camper. Shift the lane
		# sideways (at most influence_radius) so its core crosses an exposed
		# roof camper already inside the authored footprint; the shifted lane
		# is the one published with the 3.0 s warning.
		var roof_lane := _valid_roof_lane(path)
		# T3q: when the drawn preset passes too far from every exposed roof
		# camper to bend onto one, use the next preset (in index order) that
		# can. RNG draws are unchanged; ground-only matches are unaffected.
		if roof_lane.is_empty():
			for step in range(1, path_presets.size()):
				var alternate_index := (path_preset_index + step) % path_presets.size()
				roof_lane = _valid_roof_lane(path_presets[alternate_index])
				if roof_lane.size() == 2:
					path_preset_index = alternate_index
					break
		if roof_lane.size() == 2:
			path = roof_lane
		elif path_for_terrain.is_valid():
			path = path_for_terrain.call(path)
		if path.size() != 2:
			continue
		if path_reversed:
			return start_warning(path[1], path[0])
		return start_warning(path[0], path[1])
	return false


func _valid_roof_lane(path: Array) -> Array:
	var roof_lane := _lane_through_exposed_roof(path)
	if roof_lane.size() == 2 and path_for_terrain.is_valid():
		roof_lane = path_for_terrain.call(roof_lane)
	return roof_lane if roof_lane.size() == 2 else []


func _lane_through_exposed_roof(path: Array) -> Array:
	if path.size() != 2 or not is_instance_valid(_match_manager):
		return []
	var a: Vector3 = path[0]
	var b: Vector3 = path[1]
	var lane := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var lane_length_squared := lane.length_squared()
	if lane_length_squared < 0.01:
		return []
	var ground_y := minf(a.y, b.y)
	var best_shift := Vector3.ZERO
	var best_distance := INF
	var peer_ids: Array = _players.keys()
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var feet := player.global_position
		if feet.y - ground_y < ROOF_TARGET_MIN_HEIGHT or is_position_covered(feet):
			continue
		var along := (Vector3(feet.x - a.x, 0.0, feet.z - a.z)).dot(lane) / lane_length_squared
		if along < 0.0 or along > 1.0:
			continue
		var closest := Vector3(a.x, 0.0, a.z) + lane * along
		var shift := Vector3(feet.x, 0.0, feet.z) - closest
		var distance := shift.length()
		if distance <= influence_radius and distance < best_distance:
			best_distance = distance
			best_shift = shift
	if best_distance == INF:
		return []
	return [a + best_shift, b + best_shift]


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
	_carries.erase(peer_id)
	_carried_players.erase(peer_id)
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
	if surface_height.is_valid():
		start_position.y = float(surface_height.call(start_position))
		end_position.y = float(surface_height.call(end_position))
	if start_position.distance_to(end_position) < 0.1:
		return false
	active_duration = start_position.distance_to(end_position) / maxf(travel_speed, 0.01)
	active_elapsed = 0.0
	warning_remaining = warning_duration
	phase = Phase.WARNING
	_core_exposure.clear()
	_thrown_players.clear()
	_carries.clear()
	_carried_players.clear()
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
		if surface_height.is_valid():
			global_position.y = float(surface_height.call(global_position))
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
	path_preset_index = -1
	path_reversed = false
	_core_exposure.clear()
	_thrown_players.clear()
	_carries.clear()
	_carried_players.clear()


func is_carrying(peer_id: int) -> bool:
	return _carries.has(peer_id)


func was_carried(peer_id: int) -> bool:
	return _carried_players.has(peer_id)


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
		"path_preset_index": path_preset_index,
		"path_reversed": path_reversed,
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
	path_preset_index = int(snapshot.get("path_preset_index", -1))
	path_reversed = bool(snapshot.get("path_reversed", false))
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
			_carries.erase(peer_id)
			continue
		if _carries.has(peer_id):
			_update_carry(peer_id, player, delta)
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
				_thrown_players[peer_id] = true
				throw_count += 1
				player.credit_fall_to(DISASTER_NAME)
				if not _commit_carry(peer_id, player):
					var outward := -inward
					player.apply_hazard_velocity((outward + Vector3.UP * 0.75).normalized() * throw_speed, throw_speed)
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
		var inward := horizontal.normalized() if distance > 0.05 else Vector3.RIGHT
		var tangent := Vector3(-inward.z, 0.0, inward.x)
		var proximity := 1.0 - distance / influence_radius
		var force := (inward + tangent * 0.6 + Vector3.UP * proximity).normalized() * prop_force_max * proximity
		body.sleeping = false
		body.apply_central_force(force.limit_length(prop_force_max))


# T3q: an exposed roof camper who stayed in the core for lift_time is carried
# off the nearest lip instead of getting the ground throw (which ground
# braking / knockdown damping eat before it can clear a roof).
func _commit_carry(peer_id: int, player: PartyPlayer) -> bool:
	var feet := player.global_position
	if feet.y - minf(start_position.y, end_position.y) < ROOF_TARGET_MIN_HEIGHT:
		return false
	var lip := _nearest_lip(feet)
	if lip.is_empty():
		return false
	var direction: Vector3 = lip.direction
	var target := feet + direction * (float(lip.distance) + CARRY_PAST_LIP)
	_carries[peer_id] = {"target": target, "direction": direction, "hover_y": feet.y + CARRY_HOVER_HEIGHT, "elapsed": 0.0}
	_carried_players[peer_id] = true
	carry_count += 1
	_update_carry(peer_id, player, 0.0)
	carry_started.emit(peer_id, target)
	return true


func _update_carry(peer_id: int, player: PartyPlayer, delta: float) -> void:
	var carry: Dictionary = _carries[peer_id]
	carry.elapsed = float(carry.elapsed) + delta
	player.credit_fall_to(DISASTER_NAME) # T6: refresh while carried (a mid-carry touch-down consumes it)
	var position := player.global_position
	var direction: Vector3 = carry.direction
	var target: Vector3 = carry.target
	var remaining := Vector3(target.x - position.x, 0.0, target.z - position.z).dot(direction)
	if remaining <= 0.0 or float(carry.elapsed) >= CARRY_MAX_TIME or is_position_covered(position):
		# Release past the lip: keep the sideways speed, never launch upward.
		player.velocity.y = minf(player.velocity.y, 0.0)
		_carries.erase(peer_id)
		carry_released.emit(peer_id, position)
		return
	var lift := clampf((float(carry.hover_y) - position.y) * CARRY_LIFT_GAIN, -CARRY_LIFT_SPEED_MAX, CARRY_LIFT_SPEED_MAX)
	var desired := (direction * throw_speed + Vector3.UP * lift).limit_length(throw_speed)
	# Override, not an impulse: velocity_change = desired - current.
	player.apply_hazard_velocity(desired - player.velocity, throw_speed)


# Nearest direction (of LIP_PROBE_DIRECTIONS) where the support under the
# probe drops at least LIP_MIN_DROP below the feet, with no wall in between.
func _nearest_lip(feet: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	var best := {}
	var best_distance := INF
	for index in LIP_PROBE_DIRECTIONS:
		var angle := TAU * float(index) / float(LIP_PROBE_DIRECTIONS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var step := LIP_PROBE_STEP
		while step <= LIP_PROBE_RANGE and step < best_distance:
			var probe := feet + direction * step
			var down := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.4, probe + Vector3.DOWN * 60.0, MAP_COLLISION_MASK)
			var hit := space.intersect_ray(down)
			if hit.is_empty() or float(hit.position.y) < feet.y - LIP_MIN_DROP:
				var chest := Vector3.UP * (CARRY_HOVER_HEIGHT + 0.9)
				var past := feet + direction * (step + CARRY_PAST_LIP)
				var across := PhysicsRayQueryParameters3D.create(feet + chest, past + chest, MAP_COLLISION_MASK)
				if space.intersect_ray(across).is_empty():
					best_distance = step
					best = {"direction": direction, "distance": step}
				break
			if float(hit.position.y) > feet.y + 0.6:
				break
			step += LIP_PROBE_STEP
	return best


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
