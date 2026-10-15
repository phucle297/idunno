class_name MeteorShower
extends Node3D

signal warning_started(target: Vector3, duration: float)
signal impacted(target: Vector3)
signal finished

enum Phase { IDLE, WARNING, IMPACT }
enum Variant { CLUSTER, LANE, SCATTER }

const TelegraphScene = preload("res://assets/generated/VFX_MeteorTelegraph_v001.tscn")
const IMPACT_CAUSE := "Meteor"
const IMPACT_DEBRIS_CAUSE := "Impact Debris"
const DISASTER_NAME := "Meteor Shower"
const MINIMUM_STRIKE_WARNING := 1.2
const MAX_WAVE_EFFECTS := 4
const AREA_PER_STRIKE := 3072.0 # Four warnings on the 112m Town, one on the 64m Harbor.
const CLUSTER_RADIUS := 8.0
const LANE_SPACING := 7.0
const IMPACT_DEBRIS_COUNT := 3
const IMPACT_DEBRIS_MAX_ALIVE := 6

@export var warning_duration := 2.5
@export var impact_radius := 3.0
@export var direct_hit_radius := 0.75
@export var edge_damage := 20.0
@export var player_impulse_max := 8.0
@export var prop_impulse_max := 18.0
@export var impact_visual_duration := 0.65
@export var vertical_exposure := 3.5
@export var roof_check_height := 5.0
@export var impact_debris_mass := 3.0
@export var impact_debris_hit_speed := 5.0
@export var impact_debris_hit_radius := 1.0
@export var impact_debris_damage := 25.0
@export var impact_debris_lifetime := 10.0

var phase := Phase.IDLE
var warning_remaining := 0.0
var target_position := Vector3.ZERO # Compatibility: first frozen point in the current wave.
var impact_count := 0
var strike_half_extent := 18.0
var usable_area := Rect2(-18.0, -18.0, 36.0, 36.0)
var variant := Variant.CLUSTER
var strike_points: Array[Vector3] = [] # All frozen points in the current wave.
var wind_active := false
var surface_height: Callable
var navigable_area_query: Callable

var _match_manager: MatchManager
var _players: Dictionary = {}
var _effects: Array[Node3D] = []
var _impact_remaining := 0.0
var _impact_debris: Array[Dictionary] = []
var _impact_debris_visuals: Array[MeshInstance3D] = []
var _route_safety_query: Callable


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


# Existing callers may continue supplying a symmetric half extent. New callers can
# supply a Rect2 usable footprint, allowing Phase 11 to shrink only this hazard's area.
func set_strike_area(half_extent: float, height_query := Callable()) -> void:
	half_extent = maxf(half_extent, 0.0)
	set_usable_area(Rect2(-half_extent, -half_extent, half_extent * 2.0, half_extent * 2.0), height_query)


func set_usable_area(area: Rect2, height_query := Callable()) -> void:
	usable_area = Rect2(area.position, Vector2(maxf(area.size.x, 0.0), maxf(area.size.y, 0.0)))
	strike_half_extent = maxf(maxf(absf(usable_area.position.x), absf(usable_area.end.x)), maxf(absf(usable_area.position.y), absf(usable_area.end.y)))
	if height_query.is_valid():
		surface_height = height_query


# Optional callback contract: func(points: Array[Vector3]) -> bool. Return false to
# reject a carpet/route-conflicting wave before its warning is published.
func set_route_safety_query(query: Callable) -> void:
	_route_safety_query = query


func wave_budget_for_area() -> int:
	var area := usable_area.get_area()
	if navigable_area_query.is_valid():
		area = minf(area, maxf(float(navigable_area_query.call()), 0.0))
	return mini(MAX_WAVE_EFFECTS, maxi(0, floori(area / AREA_PER_STRIKE)))


func set_wind_active(active: bool) -> bool:
	if not _can_mutate() or wind_active == active:
		return false
	wind_active = active
	return true


func impact_debris_count() -> int:
	var alive := 0
	for entry: Dictionary in _impact_debris:
		if is_instance_valid(entry.get("body")):
			alive += 1
	return alive


func get_disaster_metadata() -> Dictionary:
	return {"name": DISASTER_NAME, "difficulty": 1, "minimum_match_time": 0.0, "incompatible_disasters": [], "combination_tags": ["explosion", "debris"]}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	if not _can_start():
		return false
	var budget := wave_budget_for_area()
	if budget <= 0:
		return false
	variant = rng.randi_range(Variant.CLUSTER, Variant.SCATTER) as Variant
	for attempt in 16:
		strike_points = _choose_wave_points(rng, budget)
		if not strike_points.is_empty() and (not _route_safety_query.is_valid() or bool(_route_safety_query.call(strike_points))):
			return _begin_wave()
	strike_points.clear()
	return false


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


# Singleton/manual warning remains a public compatibility path.
func start_warning(target: Vector3) -> bool:
	if not _can_start():
		return false
	strike_points = [_bounded_point(target)]
	variant = Variant.SCATTER
	return _begin_wave()


func tick(delta: float) -> void:
	if not _can_mutate():
		return
	var safe_delta := maxf(delta, 0.0)
	_update_impact_debris(safe_delta)
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		_update_warning_visuals()
		if warning_remaining <= 0.0:
			_apply_wave_impact()
	elif phase == Phase.IMPACT:
		_impact_remaining = maxf(_impact_remaining - safe_delta, 0.0)
		_update_impact_visuals()
		if _impact_remaining <= 0.0:
			_finish_wave()


func cleanup() -> void:
	_reset_strike_state()
	_clear_impact_debris()
	wind_active = false


func active_effect_count() -> int:
	var alive := 0
	for effect in _effects:
		if is_instance_valid(effect):
			alive += 1
	return alive


func create_presentation_snapshot() -> Dictionary:
	return {"phase": int(phase), "warning_remaining": warning_remaining, "target_position": target_position, "impact_remaining": _impact_remaining, "variant": int(variant), "strike_points": PackedVector3Array(strike_points), "impact_debris": _debris_positions()}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var previous_points := strike_points.duplicate()
	var previous_phase := phase
	phase = clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.IMPACT)
	warning_remaining = maxf(float(snapshot.get("warning_remaining", 0.0)), 0.0)
	_impact_remaining = maxf(float(snapshot.get("impact_remaining", 0.0)), 0.0)
	variant = clampi(int(snapshot.get("variant", Variant.CLUSTER)), Variant.CLUSTER, Variant.SCATTER)
	strike_points.clear()
	for point: Vector3 in snapshot.get("strike_points", PackedVector3Array()):
		strike_points.append(point)
	target_position = snapshot.get("target_position", strike_points[0] if not strike_points.is_empty() else Vector3.ZERO)
	if phase == Phase.IDLE:
		_reset_strike_state()
	else:
		if previous_points != strike_points or previous_phase == Phase.IDLE or (phase == Phase.WARNING and previous_phase != Phase.WARNING):
			_sync_effects()
		if phase == Phase.WARNING:
			_update_warning_visuals()
		else:
			_show_impact_visuals()
			_update_impact_visuals()
	_apply_debris_presentation(snapshot.get("impact_debris", PackedVector3Array()))
	return true


func _process(delta: float) -> void:
	tick(delta)


func _can_start() -> bool:
	return _can_mutate() and phase == Phase.IDLE and is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE


func _begin_wave() -> bool:
	target_position = strike_points[0]
	warning_remaining = maxf(warning_duration, MINIMUM_STRIKE_WARNING)
	phase = Phase.WARNING
	_sync_effects()
	for point in strike_points:
		warning_started.emit(point, warning_remaining)
	return true


func _choose_wave_points(rng: RandomNumberGenerator, budget: int) -> Array[Vector3]:
	var center := _district_target(rng)
	var points: Array[Vector3] = []
	match variant:
		Variant.CLUSTER:
			for index in budget:
				var angle := TAU * float(index) / float(budget) + rng.randf_range(-0.35, 0.35)
				points.append(_bounded_point(center + Vector3(cos(angle), 0.0, sin(angle)) * CLUSTER_RADIUS))
		Variant.LANE:
			var angle := rng.randf_range(0.0, TAU)
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			for index in budget:
				points.append(_bounded_point(center + direction * (float(index) - float(budget - 1) * 0.5) * LANE_SPACING))
		_:
			for index in budget:
				points.append(_district_target(rng))
	return _separate_points(points)


func _district_target(rng: RandomNumberGenerator) -> Vector3:
	var candidates: Array[Vector3] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as Node3D
		if is_instance_valid(player) and _match_manager.is_player_alive(peer_id):
			candidates.append(player.global_position)
	var origin := candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else Vector3(rng.randf_range(usable_area.position.x, usable_area.end.x), 0.0, rng.randf_range(usable_area.position.y, usable_area.end.y))
	# Quantized district selection with an offset deliberately prevents foot chasing.
	var x := roundf(origin.x / 8.0) * 8.0 + rng.randf_range(-3.0, 3.0)
	var z := roundf(origin.z / 8.0) * 8.0 + rng.randf_range(-3.0, 3.0)
	return _bounded_point(Vector3(x, origin.y, z))


func _separate_points(points: Array[Vector3]) -> Array[Vector3]:
	var accepted: Array[Vector3] = []
	for point in points:
		var separated := true
		for other in accepted:
			if _horizontal_distance(point, other) < impact_radius * 2.0 + 0.5:
				separated = false
		if separated:
			accepted.append(point)
	return accepted


func _sync_effects() -> void:
	_clear_effects()
	for point in strike_points:
		var effect := TelegraphScene.instantiate() as Node3D
		effect.name = "MeteorEffect"
		effect.position = point
		add_child(effect)
		var footprint := effect.get_node("WarningFootprint") as MeshInstance3D
		footprint.scale = Vector3(2.0, 1.0, 2.0)
		var meteor := effect.get_node("Meteor") as MeshInstance3D
		meteor.position.y = 14.0
		meteor.scale = Vector3.ONE * 1.35
		_style_meteor(meteor)
		var countdown := Label3D.new()
		countdown.name = "Countdown"
		countdown.position.y = 1.1
		countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		countdown.font_size = 64
		countdown.pixel_size = 0.006
		countdown.modulate = Color("ffbf3f")
		countdown.outline_size = 12
		countdown.outline_modulate = Color("202a38")
		countdown.no_depth_test = true
		effect.add_child(countdown)
		_effects.append(effect)
	_update_warning_visuals()


func _style_meteor(meteor: MeshInstance3D) -> void:
	meteor.material_override = load("res://assets/materials/MAT_Slate_v001.tres")
	var core := MeshInstance3D.new()
	core.name = "HotCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.18
	core_mesh.height = 0.36
	core_mesh.radial_segments = 7
	core_mesh.rings = 4
	core_mesh.material = load("res://assets/materials/MAT_Amber_v001.tres")
	core.mesh = core_mesh
	core.position = Vector3(0.0, -0.26, 0.24)
	meteor.add_child(core)


func _update_warning_visuals() -> void:
	var progress := clampf(1.0 - warning_remaining / maxf(warning_duration, MINIMUM_STRIKE_WARNING), 0.0, 1.0)
	for effect in _effects:
		if not is_instance_valid(effect):
			continue
		# Keep the outside edge at the real damage radius throughout the warning.
		(effect.get_node("WarningFootprint") as MeshInstance3D).scale = Vector3(impact_radius / 1.5, 1.0, impact_radius / 1.5)
		(effect.get_node("Meteor") as MeshInstance3D).position.y = lerpf(14.0, 0.8, progress)
		(effect.get_node("Countdown") as Label3D).text = "METEOR %d" % maxi(1, ceili(warning_remaining))


func _apply_wave_impact() -> void:
	if phase != Phase.WARNING:
		return
	phase = Phase.IMPACT
	warning_remaining = 0.0
	_impact_remaining = impact_visual_duration
	impact_count += strike_points.size()
	_show_impact_visuals()
	var damage_by_player: Dictionary = {}
	for peer_id: int in _players:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id) or _is_sheltered(player):
			continue
		for point in strike_points:
			var distance := _horizontal_distance(player.global_position, point)
			if absf(player.global_position.y - point.y) > vertical_exposure or distance > impact_radius:
				continue
			var damage := 100.0 if distance <= direct_hit_radius else lerpf(edge_damage, 100.0, 1.0 - distance / impact_radius)
			var current: Dictionary = damage_by_player.get(peer_id, {})
			if current.is_empty() or damage > float(current.damage):
				damage_by_player[peer_id] = {"damage": damage, "distance": distance, "point": point}
	var events: Array[Dictionary] = []
	for peer_id: int in damage_by_player:
		events.append({"peer_id": peer_id, "amount": damage_by_player[peer_id].damage, "cause": IMPACT_CAUSE})
	_match_manager.apply_damage_batch(events)
	for peer_id: int in damage_by_player:
		if _match_manager.is_player_alive(peer_id):
			var hit: Dictionary = damage_by_player[peer_id]
			(_players[peer_id] as Node3D).apply_knockdown(_radial_impulse(_players[peer_id].global_position, hit.point, hit.distance, player_impulse_max))
	_apply_prop_impulses()
	if wind_active:
		_spawn_impact_debris()
	for point in strike_points:
		impacted.emit(point)


func _is_sheltered(player: Node3D) -> bool:
	var state := get_world_3d().direct_space_state
	if state == null:
		return false
	# Static visible roofs, not another avatar or a passing loose prop, shelter
	# a player. Start above the head so a nearby low ledge is not a roof.
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.6, player.global_position + Vector3.UP * roof_check_height, 1)
	return not state.intersect_ray(query).is_empty()


func _apply_prop_impulses() -> void:
	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body):
			continue
		var best_distance := INF
		var best_point := Vector3.ZERO
		for point in strike_points:
			var distance := _horizontal_distance(body.global_position, point)
			if absf(body.global_position.y - point.y) <= vertical_exposure and distance <= impact_radius and distance < best_distance:
				best_distance = distance
				best_point = point
		if best_distance < INF:
			body.sleeping = false
			body.apply_central_impulse(_radial_impulse(body.global_position, best_point, best_distance, prop_impulse_max))


func _show_impact_visuals() -> void:
	for effect in _effects:
		if not is_instance_valid(effect):
			continue
		(effect.get_node("WarningFootprint") as MeshInstance3D).visible = false
		(effect.get_node("Meteor") as MeshInstance3D).position.y = 0.8
		(effect.get_node("Countdown") as Label3D).visible = false
		if effect.get_node_or_null("ImpactFlash") == null:
			var flash := MeshInstance3D.new()
			flash.name = "ImpactFlash"
			var mesh := SphereMesh.new()
			mesh.radius = 0.9
			mesh.height = 1.8
			mesh.radial_segments = 12
			mesh.rings = 6
			mesh.material = load("res://assets/materials/MAT_Orange_v001.tres")
			flash.mesh = mesh
			flash.position.y = 0.8
			effect.add_child(flash)


func _update_impact_visuals() -> void:
	var progress := 1.0 - _impact_remaining / maxf(impact_visual_duration, 0.001)
	for effect in _effects:
		var flash := effect.get_node_or_null("ImpactFlash") as MeshInstance3D
		if is_instance_valid(flash):
			flash.scale = Vector3.ONE * lerpf(0.4, 2.2, progress)


func _finish_wave() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	_reset_strike_state()
	finished.emit()


func _reset_strike_state() -> void:
	_clear_effects()
	phase = Phase.IDLE
	warning_remaining = 0.0
	_impact_remaining = 0.0
	strike_points.clear()


func _clear_effects() -> void:
	for effect in _effects:
		if is_instance_valid(effect):
			remove_child(effect)
			effect.queue_free()
	_effects.clear()


func _bounded_point(point: Vector3) -> Vector3:
	var x := clampf(point.x, usable_area.position.x, usable_area.end.x)
	var z := clampf(point.z, usable_area.position.y, usable_area.end.y)
	var target := Vector3(x, 0.06, z)
	if surface_height.is_valid():
		target.y = float(surface_height.call(target)) + 0.06
	return target


func _radial_impulse(position: Vector3, point: Vector3, distance: float, maximum: float) -> Vector3:
	var direction := Vector3(position.x - point.x, 0.0, position.z - point.z).normalized()
	if direction.is_zero_approx(): direction = Vector3.RIGHT
	return (direction + Vector3.UP * 0.45).normalized() * lerpf(maximum * 0.25, maximum, 1.0 - distance / impact_radius)


func _spawn_impact_debris() -> void:
	for index in mini(IMPACT_DEBRIS_COUNT, IMPACT_DEBRIS_MAX_ALIVE - _impact_debris.size()):
		var body := RigidBody3D.new()
		body.name = "ImpactDebris%d_%d" % [impact_count, index]
		body.mass = impact_debris_mass
		body.collision_layer = 4
		body.add_to_group("grabbable")
		body.add_to_group("meteor_impact_debris")
		body.set_meta("impact_debris", true)
		var point := strike_points[index % strike_points.size()]
		var angle := TAU * (float(index) + 0.5) / float(IMPACT_DEBRIS_COUNT)
		var offset := Vector3(cos(angle), 0, sin(angle)) * direct_hit_radius * 0.5
		body.position = point + offset + Vector3.UP * 0.35
		body.add_child(_create_debris_visual())
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.3
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		body.apply_central_impulse(_radial_impulse(body.position, point, offset.length(), prop_impulse_max))
		_impact_debris.append({"body": body, "age": 0.0, "hits": {}})


func _update_impact_debris(delta: float) -> void:
	for entry in _impact_debris.duplicate():
		var body := entry.body as RigidBody3D
		entry.age = float(entry.age) + delta
		if not is_instance_valid(body) or float(entry.age) >= impact_debris_lifetime:
			_impact_debris.erase(entry)
			if is_instance_valid(body): body.queue_free()
			continue
		if body.linear_velocity.length() < impact_debris_hit_speed: continue
		for peer_id: int in _players:
			if entry.hits.has(peer_id): continue
			var player := _players[peer_id] as Node3D
			if is_instance_valid(player) and _match_manager.is_player_alive(peer_id) and body.global_position.distance_to(player.global_position) <= impact_debris_hit_radius:
				entry.hits[peer_id] = true
				_match_manager.apply_damage(peer_id, impact_debris_damage, IMPACT_DEBRIS_CAUSE)
				if _match_manager.is_player_alive(peer_id):
					var knock := (body.linear_velocity.normalized() + Vector3.UP * 0.25).normalized()
					player.apply_knockdown(knock * minf(body.linear_velocity.length() * 0.5, player_impulse_max))


func _clear_impact_debris() -> void:
	for entry in _impact_debris:
		var body := entry.body as RigidBody3D
		if is_instance_valid(body): body.queue_free()
	_impact_debris.clear()
	_apply_debris_presentation(PackedVector3Array())


func _debris_positions() -> PackedVector3Array:
	var positions := PackedVector3Array()
	for entry in _impact_debris:
		var body := entry.body as RigidBody3D
		if is_instance_valid(body): positions.append(body.global_position)
	return positions


func _apply_debris_presentation(positions: PackedVector3Array) -> void:
	while _impact_debris_visuals.size() > positions.size():
		var visual := _impact_debris_visuals.pop_back() as MeshInstance3D
		if is_instance_valid(visual): visual.queue_free()
	while _impact_debris_visuals.size() < positions.size():
		var visual := _create_debris_visual()
		add_child(visual)
		_impact_debris_visuals.append(visual)
	for index in positions.size():
		_impact_debris_visuals[index].global_position = positions[index]


func _create_debris_visual() -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.55, 0.42, 0.5)
	chunk.material = load("res://assets/materials/MAT_Slate_v001.tres")
	visual.mesh = chunk
	return visual


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
