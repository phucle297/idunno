class_name Rockslide
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }
const MAX_ROCKS := 3
const RADIUS := 0.65
const MAX_SPEED := 9.0
const DAMAGE := 25.0
# A rock blocked by a raised surface may ride onto it only when an exposed,
# alive standee is on that same surface inside the lane corridor. Unoccupied
# solid cover (and anyone sheltering behind or under it) still stops rocks.
const MAX_CLIMB := 6.0
const CORRIDOR_HALF_WIDTH := 2.4
const EXPOSURE_HEIGHT := 8.0
# T3r: the authored lane rarely crosses a real roof, so start_disaster may
# publish a different corridor whose 5.0 s warning runs across the nearest
# alive, exposed standee at least ROOF_TARGET_MIN_HEIGHT above the ground the
# rocks start on (same idea as the T3k tornado bend). The corridor is checked
# with real collision before it is chosen; otherwise the authored lane stays.
const ROOF_TARGET_MIN_HEIGHT := 1.5
const TARGET_HEADINGS := 16
const TARGET_RUN_UPS: Array[float] = [6.0, 4.5, 3.0]
const TARGET_MAX_ROOF_RUN := 10.0
const TARGET_RUN_PAST := 2.0
const SAMPLE_STEP := 0.25
# T22: rocks on the authored lane roll this far past `low` before they stop;
# lane_extent_of() uses the same run-out so pickups never spawn in it.
const AUTHORED_RUNOUT := 8.0

@export var warning_duration := 5.0
@export var active_duration := 10.0
var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var lane: Dictionary = {}
var authored_lane: Dictionary = {}
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


func set_lane(new_lane: Dictionary) -> void:
	cleanup()
	authored_lane = new_lane.duplicate(true)
	lane = new_lane.duplicate(true)


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
	if authored_lane.is_empty():
		authored_lane = lane.duplicate(true)
	lane = authored_lane.duplicate(true)
	var roof_lane := _lane_through_exposed_roof()
	if not roof_lane.is_empty():
		lane = roof_lane
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
						collider.apply_knockdown(Vector3(0, 2, 0) + _lane_forward() * 5.0)
						impacts.append({"peer_id": peer_id, "amount": DAMAGE, "cause": "Rockslide"})
				rock.set_meta("stopped", true)
				break
			if collision.get_normal().y < 0.65:
				if not rock.get_meta("climbed", false) and _ride_onto_occupied_surface(rock, collision):
					motion = Vector3(rock.velocity.x, 0, rock.velocity.z) * delta
					continue
				rock.set_meta("stopped", true)
				rock.velocity = Vector3.ZERO
				break
			rock.velocity = rock.velocity.slide(collision.get_normal())
			motion = collision.get_remainder().slide(collision.get_normal())
		var visual := rock.get_child(1) as MeshInstance3D
		visual.rotate_x(rock.velocity.z * delta / RADIUS)
		if lane.get("chosen", false):
			# A chosen corridor ends where its warning ends, and rocks never
			# leave its published width.
			var along := (rock.position - (lane.high as Vector3)).dot(_lane_forward())
			if along > float(lane.length) or _lane_offset(rock.position) > CORRIDOR_HALF_WIDTH:
				rock.set_meta("stopped", true)
				rock.velocity = Vector3.ZERO
		elif rock.position.z > (lane.low as Vector3).z + AUTHORED_RUNOUT:
			rock.set_meta("stopped", true)
	# Winner evaluation can synchronously clean up every hazard. Finish this
	# iteration first; simultaneous impacts use the existing batch contract.
	if not impacts.is_empty():
		_manager.apply_damage_batch(impacts)


func _ride_onto_occupied_surface(rock: CharacterBody3D, collision: KinematicCollision3D) -> bool:
	var body := collision.get_collider() as CollisionObject3D
	var normal := collision.get_normal()
	var forward := Vector3(-normal.x, 0, -normal.z)
	if body == null or body is PartyPlayer or forward.length() < 0.5:
		return false
	forward = forward.normalized()
	var contact := collision.get_position()
	var bottom := rock.global_position.y - RADIUS
	var space := get_world_3d().direct_space_state
	if lane.get("chosen", false):
		return _ride_onto_chosen_roof(rock, space, contact, bottom)
	var edge := Vector3(rock.global_position.x, 0, contact.z) + forward * 0.15
	var down := PhysicsRayQueryParameters3D.create(Vector3(edge.x, bottom + MAX_CLIMB, edge.z), Vector3(edge.x, bottom, edge.z), 1)
	var top := space.intersect_ray(down)
	if top.is_empty() or top.collider != body or top.normal.y < 0.65:
		return false
	var top_y := float(top.position.y)
	if not _has_exposed_standee(space, body, top_y, contact, forward):
		return false
	rock.global_position = Vector3(rock.global_position.x, top_y + RADIUS + 0.05, contact.z + forward.z * 0.05)
	var speed := maxf(Vector2(rock.velocity.x, rock.velocity.z).length(), 4.0)
	rock.velocity = forward * minf(speed, MAX_SPEED)
	rock.set_meta("climbed", true)
	return true


# Chosen corridors were validated up to one roof surface (roof_y). Real roofs
# are several slabs on separate wall bodies, so the climb accepts that surface
# rather than the wall's own top, but only along the lane heading, only once,
# and only while an exposed alive standee is still on that roof ahead.
func _ride_onto_chosen_roof(rock: CharacterBody3D, space: PhysicsDirectSpaceState3D, contact: Vector3, bottom: float) -> bool:
	var forward := _lane_forward()
	var roof_y := float(lane.roof_y)
	var base := rock.global_position + forward * ((contact - rock.global_position).dot(forward))
	var landing := _roof_landing(space, base, forward, roof_y, bottom)
	if not landing.is_finite() or not _has_exposed_standee(space, null, roof_y, contact, forward):
		return false
	rock.global_position = landing
	var speed := maxf(Vector2(rock.velocity.x, rock.velocity.z).length(), 4.0)
	rock.velocity = forward * minf(speed, MAX_SPEED)
	rock.set_meta("climbed", true)
	return true


# Where a rock meeting the wall at `base` lands on the chosen roof: the first
# point just past the wall line with roof surface under it and room for the
# whole rock (rails, posts and planters at the edge block a landing).
func _roof_landing(space: PhysicsDirectSpaceState3D, base: Vector3, forward: Vector3, roof_y: float, bottom: float) -> Vector3:
	if roof_y - bottom > MAX_CLIMB or roof_y - bottom < 0.3:
		return Vector3.INF
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	for step: float in [0.15, 0.4, 0.7, 1.0]:
		var edge := base + forward * step
		var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(edge.x, roof_y + 1.0, edge.z), Vector3(edge.x, bottom, edge.z), 1))
		if top.is_empty() or top.normal.y < 0.65 or absf(float(top.position.y) - roof_y) > 0.3:
			continue
		var landing := Vector3(edge.x, roof_y + RADIUS + 0.05, edge.z) + forward * 0.05
		query.transform = Transform3D(Basis(), landing)
		if space.intersect_shape(query, 1).is_empty():
			return landing
	return Vector3.INF


func _has_exposed_standee(space: PhysicsDirectSpaceState3D, body: CollisionObject3D, top_y: float, contact: Vector3, forward: Vector3) -> bool:
	for peer_id: int in _players:
		var player: Node3D = _players[peer_id]
		if not is_instance_valid(player) or not _manager.is_player_alive(peer_id):
			continue
		var feet := player.global_position
		if absf(feet.y - top_y) > 0.6 or _lane_offset(feet) > CORRIDOR_HALF_WIDTH:
			continue
		if (feet - contact).dot(forward) <= 0:
			continue
		var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.35, feet + Vector3.DOWN * 0.6, 1))
		if support.is_empty():
			continue
		if body != null and support.collider != body:
			continue
		if body == null and absf(float(support.position.y) - top_y) > 0.3:
			continue
		var overhead := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.0, feet + Vector3.UP * EXPOSURE_HEIGHT, 1))
		if overhead.is_empty():
			return true
	return false


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
	var forward := _lane_forward()
	var side := Vector3(forward.z, 0, -forward.x)
	# Authored lanes run +z, where this is exactly high + (offset, r, 0.5).
	rock.position = (lane.high as Vector3) + side * offset + Vector3(0, RADIUS + 0.05, 0) + forward * 0.5
	rock.velocity = Vector3(0, -1, 0) + forward * 4.0
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
	if lane.get("chosen", false):
		_show_chosen_warning(high, low)
		return
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


# Stripes for a chosen corridor sit on the real surface under each point
# (ground run, then the roof), across the full published width.
func _show_chosen_warning(high: Vector3, low: Vector3) -> void:
	var forward := _lane_forward()
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var top := maxf(high.y, low.y) + 3.0
	var count := maxi(12, ceili(Vector2(low.x - high.x, low.z - high.z).length() / 0.8) + 1)
	for index in count:
		var point := high.lerp(low, index / float(count - 1))
		if space != null:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, top, point.z), Vector3(point.x, minf(high.y, low.y) - 1.0, point.z), 1))
			if not hit.is_empty():
				point.y = float(hit.position.y)
		var stripe := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4, 0.04, 0.22)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffbf3f")
		box.material = material
		stripe.mesh = box
		stripe.position = point + Vector3.UP * 0.04
		stripe.rotation.y = atan2(forward.x, forward.z)
		_warning.add_child(stripe)
	var label := Label3D.new()
	label.text = "↓ ROCKSLIDE ↓"
	label.position = Vector3(low.x, float(lane.get("roof_y", low.y)), low.z) + Vector3(0, 2.0, 0) - forward * 2.0
	label.font_size = 40
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f4e6c8")
	label.outline_modulate = Color("202a38")
	label.outline_size = 8
	_warning.add_child(label)


func _lane_forward() -> Vector3:
	return _forward_of(lane)


func _forward_of(l: Dictionary) -> Vector3:
	var run := (l.low as Vector3) - (l.high as Vector3)
	run.y = 0
	return run.normalized() if run.length_squared() > 0.0001 else Vector3.BACK


## T22: the flat ground rectangle a lane's rocks can cover, height ignored.
## It runs from `high` along the lane for `length`: a chosen corridor uses its
## published length; the authored lane uses the horizontal high->low run plus
## the AUTHORED_RUNOUT stop line.
func lane_extent_of(l: Dictionary) -> Dictionary:
	if l.is_empty():
		return {}
	var high: Vector3 = l.high
	var low: Vector3 = l.low
	var length := float(l.length) if l.get("chosen", false) else Vector2(low.x - high.x, low.z - high.z).length() + AUTHORED_RUNOUT
	return {"start": high, "forward": _forward_of(l), "length": length, "half_width": CORRIDOR_HALF_WIDTH}


## T22: true when `point` (grown by `margin`) is inside the authored lane,
## which is a static embankment so it is always checked, or inside the
## current lane while a slide is warning or active. Toy Harbor's authored
## lane at x=27 overlaps the east edge of the pickup zones (x 24.6-26); it is
## kept there on purpose (Architect, T22) and this check rejects that strip.
func lane_contains(point: Vector3, margin: float) -> bool:
	if _extent_contains(lane_extent_of(authored_lane), point, margin):
		return true
	return is_active() and _extent_contains(lane_extent_of(lane), point, margin)


func _extent_contains(extent: Dictionary, point: Vector3, margin: float) -> bool:
	if extent.is_empty():
		return false
	var rel: Vector3 = point - (extent.start as Vector3)
	rel.y = 0
	var forward: Vector3 = extent.forward
	var along := rel.dot(forward)
	if along < -margin or along > float(extent.length) + margin:
		return false
	return (rel - forward * along).length() <= float(extent.half_width) + margin


func _lane_offset(point: Vector3) -> float:
	var forward := _lane_forward()
	var rel := point - (lane.low as Vector3)
	rel.y = 0
	return (rel - forward * rel.dot(forward)).length()


# Nearest (to the authored lane) alive, exposed standee >= 1.5 m above the
# ground the rocks would start on, with a corridor that real collision says a
# rock can follow: flat ground run, one wall it may climb (<= MAX_CLIMB) and a
# clear, continuous roof up to the standee. Empty = keep the authored lane.
func _lane_through_exposed_roof() -> Dictionary:
	if not is_inside_tree() or not authored_lane.has("high") or not authored_lane.has("low"):
		return {}
	var space := get_world_3d().direct_space_state
	var a: Vector3 = authored_lane.high
	var b: Vector3 = authored_lane.low
	var candidates: Array = []
	var peer_ids: Array = _players.keys()
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _manager.is_player_alive(peer_id):
			continue
		var feet := player.global_position
		if feet.y - minf(a.y, b.y) < ROOF_TARGET_MIN_HEIGHT:
			continue
		var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.35, feet + Vector3.DOWN * 0.6, 1))
		if support.is_empty() or float(support.normal.y) < 0.9:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.0, feet + Vector3.UP * EXPOSURE_HEIGHT, 1)).is_empty():
			continue
		var along := clampf((feet - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
		var closest := a.lerp(b, along)
		candidates.append([Vector2(feet.x - closest.x, feet.z - closest.z).length(), peer_id, feet, float(support.position.y)])
	candidates.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	for candidate: Array in candidates:
		var feet: Vector3 = candidate[2]
		var roof_y: float = candidate[3]
		var rel := feet - b
		var authored_forward := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		rel.y = 0
		var along_authored := (feet - a).dot(authored_forward)
		if (rel - authored_forward * rel.dot(authored_forward)).length() <= CORRIDOR_HALF_WIDTH and along_authored >= 0.0 and along_authored <= Vector2(b.x - a.x, b.z - a.z).length() + 8.0:
			return {}  # already on the published authored corridor (T3m climb)
		var base_angle := atan2(authored_forward.x, authored_forward.z)
		for index in TARGET_HEADINGS:
			var turn := ceili(index / 2.0) * (1 if index % 2 == 1 else -1)
			var angle := base_angle + turn * TAU / TARGET_HEADINGS
			var forward := Vector3(sin(angle), 0, cos(angle))
			var chosen := _corridor_for(space, feet, roof_y, forward)
			if not chosen.is_empty():
				chosen.target_peer = candidate[1]
				return chosen
	return {}


func _corridor_for(space: PhysicsDirectSpaceState3D, feet: Vector3, roof_y: float, forward: Vector3) -> Dictionary:
	# Walk back from the standee across the roof to its edge.
	var roof_run := 0.0
	while roof_run <= TARGET_MAX_ROOF_RUN:
		var next := _surface_y(space, feet - forward * (roof_run + SAMPLE_STEP), roof_y + 1.0, roof_y - MAX_CLIMB - 1.0)
		if is_nan(next) or absf(next - roof_y) > 0.1:
			break
		roof_run += SAMPLE_STEP
	if roof_run > TARGET_MAX_ROOF_RUN:
		return {}
	var ground_y := _surface_y(space, feet - forward * (roof_run + 0.6), roof_y + 1.0, roof_y - MAX_CLIMB - 1.0)
	if is_nan(ground_y) or roof_y - ground_y < ROOF_TARGET_MIN_HEIGHT or roof_y - ground_y > MAX_CLIMB - 0.3:
		return {}
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	for run_up: float in TARGET_RUN_UPS:
		var start := feet - forward * (roof_run + run_up)
		start.y = ground_y
		# Flat ground for the whole run up to the wall.
		var flat := true
		for step in int((run_up - 0.6) / SAMPLE_STEP):
			var y := _surface_y(space, start + forward * (step * SAMPLE_STEP), ground_y + 1.5, ground_y - 1.0)
			if is_nan(y) or absf(y - ground_y) > 0.25:
				flat = false
				break
		if not flat:
			continue
		var origin := start + Vector3.UP * (RADIUS + 0.05)
		query.transform = Transform3D(Basis(), origin)
		query.motion = Vector3.ZERO
		if not space.intersect_shape(query, 1).is_empty():
			continue
		# The centre rock line (and small drifts off it) must meet the steep
		# wall at the roof edge first, land on the roof and roll clear through
		# the standee.
		var side := Vector3(forward.z, 0, -forward.x)
		var lines_ok := true
		for drift: float in [0.0, -0.2, 0.2]:
			if not _line_reaches_standee(space, query, origin + side * drift, forward, run_up, feet + side * drift, roof_y, ground_y):
				lines_ok = false
				break
		if not lines_ok:
			continue
		var end := feet + forward * TARGET_RUN_PAST
		end.y = roof_y
		return {"chosen": true, "high": start, "low": end, "roof_y": roof_y,
			"length": Vector2(end.x - start.x, end.z - start.z).length(),
			"cover": authored_lane.get("cover", Vector3.ZERO),
			"exits": [end - side * 3.5, end + side * 3.5]}
	return {}


func _line_reaches_standee(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, origin: Vector3, forward: Vector3, run_up: float, feet: Vector3, roof_y: float, ground_y: float) -> bool:
	query.transform = Transform3D(Basis(), origin)
	query.motion = forward * (run_up + 1.0)
	var travel := space.cast_motion(query)
	var hit_at := travel[1] * (run_up + 1.0)
	if travel[1] >= 1.0 or hit_at < run_up - RADIUS - 0.9 or hit_at > run_up - RADIUS + 0.3:
		return false
	var center := origin + forward * hit_at
	query.transform = Transform3D(Basis(), center)
	query.motion = Vector3.ZERO
	var rest := space.get_rest_info(query)
	if rest.is_empty() or float(rest.normal.y) > 0.65:
		return false
	# Same landing rule as the runtime climb, from the same contact projection.
	var base := center + forward * (((rest.point as Vector3) - center).dot(forward))
	var landing := _roof_landing(space, base, forward, roof_y, ground_y)
	if not landing.is_finite():
		return false
	var roll := (feet - landing).dot(forward) + TARGET_RUN_PAST
	query.transform = Transform3D(Basis(), landing)
	query.motion = forward * roll
	if roll <= 0.0 or space.cast_motion(query)[1] < 1.0:
		return false
	for index in int(roll / SAMPLE_STEP):
		var y := _surface_y(space, landing + forward * (index * SAMPLE_STEP), roof_y + 1.0, roof_y - 1.0)
		if (is_nan(y) or absf(y - roof_y) > 0.1) and index * SAMPLE_STEP < roll - TARGET_RUN_PAST + 0.5:
			return false
	return true


func _surface_y(space: PhysicsDirectSpaceState3D, point: Vector3, from_y: float, to_y: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, from_y, point.z), Vector3(point.x, to_y, point.z), 1))
	if hit.is_empty() or float(hit.normal.y) < 0.9:
		return NAN
	return float(hit.position.y)


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
	if lane.get("chosen", false) and not authored_lane.is_empty():
		lane = authored_lane.duplicate(true)


func create_presentation_snapshot() -> Dictionary:
	var positions := PackedVector3Array()
	var rotations := PackedVector3Array()
	for rock in _rocks:
		positions.append(rock.position)
		rotations.append((rock.get_child(1) as Node3D).rotation)
	var snapshot := {"phase": phase, "warning": warning_remaining, "active": active_remaining, "variant": variant,
		"positions": positions, "rotations": rotations}
	if lane.get("chosen", false):
		# Clients must draw the same warned corridor the server will use.
		snapshot.lane_high = lane.high
		snapshot.lane_low = lane.low
		snapshot.lane_roof_y = lane.roof_y
	return snapshot


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
	_apply_snapshot_lane(snapshot)
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


func _apply_snapshot_lane(snapshot: Dictionary) -> void:
	var wanted := authored_lane.duplicate(true) if not authored_lane.is_empty() else lane
	var high: Variant = snapshot.get("lane_high")
	var low: Variant = snapshot.get("lane_low")
	var roof_y: Variant = snapshot.get("lane_roof_y")
	if high is Vector3 and low is Vector3 and (roof_y is float or roof_y is int) and (high as Vector3).is_finite() and (low as Vector3).is_finite() \
			and (high as Vector3).distance_to(low) < 40.0 and is_finite(float(roof_y)):
		wanted = {"chosen": true, "high": high, "low": low, "roof_y": float(roof_y),
			"length": Vector2((low as Vector3).x - (high as Vector3).x, (low as Vector3).z - (high as Vector3).z).length()}
	if wanted.get("high") != lane.get("high") or wanted.get("low") != lane.get("low"):
		lane = wanted
		if is_instance_valid(_warning):
			_warning.free()
		_warning = null


func _physics_process(delta: float) -> void:
	tick(delta)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
