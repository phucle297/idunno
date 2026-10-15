class_name TerrainCollapse
extends Node3D
## Heavy meteors remove real districts. This controller never drains health.

signal warning_started(stage: int)
signal district_removed(district: int)

const NOTICE_TIMES := [120.0, 270.0, 390.0, 510.0]
const WARNING_SECONDS := 30.0
const VOID_Y := -0.8
const DEATH_CAUSE := "Fell into collapsed ground"
const DISTRICT_NAMES := ["NORTHWEST", "NORTH", "NORTHEAST", "WEST", "CENTER", "EAST", "SOUTHWEST", "SOUTH", "SOUTHEAST"]
const TelegraphScene = preload("res://assets/generated/VFX_MeteorTelegraph_v001.tscn")

var removed_mask := 0
var pending := -1
var deadline := 0.0
var stage := 0
var regions: Array[Rect2] = []
var candidate_is_safe: Callable
var surface_height: Callable
var _shapes: Array[Dictionary] = []
var _visuals: Array[Dictionary] = []
var _structures: Array[Dictionary] = []
var _warning: Node3D
var _meteor: Node3D
var _last_visual_pending := -1
var _height_samples: Array[Dictionary] = []
var _height_cursor := 0
var height_query_count := 0


static func map_regions(map_id: String) -> Array[Rect2]:
	# Cuts avoid every authored walkable structure (roofs, stairs, ramps and
	# gangways) so removal never deletes footholds outside its warning.
	var xs := [-56.0, -30.0, 30.0, 56.0] if map_id == "toy_town" else [-32.0, -12.0, 12.0, 32.0]
	var zs := [-56.0, -37.0, 20.0, 56.0] if map_id == "toy_town" else [-32.0, -10.0, 14.0, 32.0]
	var result: Array[Rect2] = []
	for row in 3:
		for column in 3:
			result.append(Rect2(xs[column], zs[row], xs[column + 1] - xs[column], zs[row + 1] - zs[row]))
	return result


func configure(map_id: String, world: Node3D) -> void:
	reset()
	regions = map_regions(map_id)
	_shapes.clear()
	_visuals.clear()
	_structures.clear()
	_cache_world(world)


func _cache_world(node: Node) -> void:
	# Dynamic props fall naturally; never cache their moving transform.
	if node is RigidBody3D:
		return
	if node is BreakableStructure:
		var collision := node.get_node("Collision") as CollisionShape3D
		var bounds: AABB = collision.global_transform * collision.shape.get_debug_mesh().get_aabb()
		_structures.append({"node": node, "mask": _intersections(bounds), "changed": false})
		return # Structure state and terrain visibility have one owner.
	if node is CollisionShape3D and node.shape != null:
		var bounds: AABB = node.global_transform * node.shape.get_debug_mesh().get_aabb()
		_shapes.append({"node": node, "mask": _intersections(bounds), "changed": false, "disabled": node.disabled})
	elif node is GeometryInstance3D:
		var bounds: AABB = node.global_transform * node.get_aabb()
		_visuals.append({"node": node, "mask": _intersections(bounds), "changed": false, "visible": node.visible})
	for child in node.get_children():
		_cache_world(child)


func _intersections(bounds: AABB) -> int:
	var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	var mask := 0
	# Tiny mesh/collision bevels at a district seam do not remove its neighbor.
	rect = rect.grow(-0.001) if minf(rect.size.x, rect.size.y) > 0.002 else rect
	for index in regions.size():
		if regions[index].intersects(rect):
			mask |= 1 << index
	return mask


func reset() -> void:
	for entry: Dictionary in _structures:
		if entry.changed and is_instance_valid(entry.node):
			entry.node.set_terrain_removed(false)
		entry.changed = false
	for entry: Dictionary in _shapes:
		if entry.changed and is_instance_valid(entry.node):
			entry.node.set_deferred("disabled", entry.disabled)
		entry.changed = false
	for entry: Dictionary in _visuals:
		if entry.changed and is_instance_valid(entry.node):
			entry.node.visible = entry.visible
		entry.changed = false
	removed_mask = 0
	pending = -1
	deadline = 0
	stage = 0
	_clear_warning()


func tick(manager: MatchManager, seed_value: int) -> void:
	if not _is_authority() or manager.state != MatchManager.MatchState.ACTIVE or manager.match_duration <= 0:
		return
	if pending >= 0:
		if manager.elapsed_time >= deadline:
			removed_mask |= 1 << pending
			var removed := pending
			pending = -1
			deadline = 0
			stage += 1
			_enforce_removal()
			_clear_warning()
			district_removed.emit(removed)
		return
	if stage >= NOTICE_TIMES.size() or manager.elapsed_time < NOTICE_TIMES[stage] / 600.0 * manager.match_duration:
		return
	var choices := eligible_districts()
	if choices.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + stage * 7919
	pending = choices[rng.randi_range(0, choices.size() - 1)]
	# Even a long server frame cannot skip the published warning.
	deadline = manager.elapsed_time + WARNING_SECONDS / 600.0 * manager.match_duration
	warning_started.emit(stage)


func eligible_districts() -> Array[int]:
	var result: Array[int] = []
	for index in regions.size():
		if removed_mask & (1 << index):
			continue
		if not _remaining_connected(removed_mask | (1 << index)):
			continue
		if candidate_is_safe.is_valid() and not bool(candidate_is_safe.call(regions[index])):
			continue
		result.append(index)
	return result


static func _remaining_connected(mask: int) -> bool:
	var first := -1
	for index in 9:
		if not mask & (1 << index):
			first = index
			break
	if first < 0:
		return false
	var visited := 1 << first
	var queue: Array[int] = [first]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor: int in [current - 3, current + 3, current - 1, current + 1]:
			if neighbor < 0 or neighbor >= 9 or abs(current % 3 - neighbor % 3) + abs(current / 3 - neighbor / 3) != 1:
				continue
			var bit := 1 << neighbor
			if mask & bit or visited & bit:
				continue
			visited |= bit
			queue.append(neighbor)
	return visited == (511 & ~mask)


func _enforce_removal() -> void:
	for entry: Dictionary in _structures:
		if entry.mask & removed_mask and not entry.changed and is_instance_valid(entry.node):
			entry.node.set_terrain_removed(true)
			entry.changed = true
	for entry: Dictionary in _shapes:
		if entry.mask & removed_mask and is_instance_valid(entry.node):
			if not entry.changed:
				entry.changed = true
			# A reset may have queued restoration in this same frame. Always
			# queue removal last, even if the old disabled flag is still true.
			entry.node.set_deferred("disabled", true)
	for entry: Dictionary in _visuals:
		if entry.mask & removed_mask and is_instance_valid(entry.node):
			if not entry.changed:
				entry.changed = true
			entry.node.hide()


func is_void(point: Vector3) -> bool:
	if point.y >= VOID_Y:
		return false
	for index in regions.size():
		if removed_mask & (1 << index) and regions[index].has_point(Vector2(point.x, point.z)):
			return true
	return false


func supports_point(point: Vector3, margin := 0.0, future := false) -> bool:
	var mask := removed_mask | ((1 << pending) if future and pending >= 0 else 0)
	for index in regions.size():
		if mask & (1 << index) and regions[index].grow(margin).has_point(Vector2(point.x, point.z)):
			return false
	return true


func supports_path(start: Vector3, finish: Vector3, margin: float, future := true) -> bool:
	if not supports_point(start, margin, future) or not supports_point(finish, margin, future):
		return false
	var a := Vector2(start.x, start.z)
	var b := Vector2(finish.x, finish.z)
	for index in regions.size():
		if not removed_mask & (1 << index) and not (future and pending == index):
			continue
		var bounds := regions[index].grow(margin)
		var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
		for edge in 4:
			if Geometry2D.segment_intersects_segment(a, b, corners[edge], corners[(edge + 1) % 4]) != null:
				return false
	return true


func remaining_area(area: Rect2, future := false) -> float:
	var value := area.get_area()
	for index in regions.size():
		if removed_mask & (1 << index) or (future and pending == index):
			value -= area.intersection(regions[index]).get_area()
	return maxf(value, 0)


func describe(elapsed: float) -> Dictionary:
	return {"pending": pending, "region_name": DISTRICT_NAMES[pending] + " DISTRICT" if pending >= 0 else "", "remaining": maxf(deadline - elapsed, 0), "bounds": regions[pending] if pending >= 0 else Rect2(), "destroyed_count": stage, "stage": stage}


func create_snapshot() -> PackedFloat32Array:
	return PackedFloat32Array([removed_mask, pending, deadline, stage])


static func snapshot_is_valid(map_id: String, payload: Variant, elapsed: float, duration: float) -> bool:
	if map_id not in ["toy_town", "toy_harbor"]:
		return false
	if not payload is PackedFloat32Array or payload.size() != 4 or not is_finite(elapsed) or not is_finite(duration) or duration <= 0 or elapsed < 0 or elapsed > duration:
		return false
	for value: float in payload:
		if not is_finite(value):
			return false
	var mask := int(payload[0])
	var next := int(payload[1])
	var count := int(payload[3])
	if payload[0] != mask or mask < 0 or mask > 511 or payload[1] != next or next < -1 or next > 8 or payload[3] != count or count < 0 or count > 4:
		return false
	var bits := 0
	for index in 9:
		if mask & (1 << index):
			bits += 1
	if bits != count or not _remaining_connected(mask):
		return false
	if count > 0 and elapsed + 0.01 < (NOTICE_TIMES[count - 1] + WARNING_SECONDS) / 600.0 * duration:
		return false
	if next < 0:
		return payload[2] == 0
	return count < 4 and not mask & (1 << next) and _remaining_connected(mask | (1 << next)) and elapsed + 0.01 >= NOTICE_TIMES[count] / 600.0 * duration and payload[2] >= elapsed - 0.01 and payload[2] <= elapsed + WARNING_SECONDS / 600.0 * duration + 0.01


func apply_snapshot(payload: PackedFloat32Array) -> void:
	# Caller validates map, sequence, shape and clock before mutating anything.
	var previous := removed_mask
	var previous_pending := pending
	if int(payload[0]) & previous != previous:
		reset() # New round: restore exactly the objects this controller removed.
		previous_pending = -1
	removed_mask = int(payload[0])
	pending = int(payload[1])
	deadline = payload[2]
	stage = int(payload[3])
	if pending >= 0 and pending != previous_pending:
		warning_started.emit(stage)
	_enforce_removal() # Breakable snapshots must never resurrect vanished ground.


func present(elapsed: float, duration: float, active: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not active or pending < 0:
		_clear_warning()
		return
	if _last_visual_pending != pending:
		_clear_warning()
		_last_visual_pending = pending
		_warning = Node3D.new()
		_warning.name = "CollapseWarning"
		add_child(_warning)
		var bounds := regions[pending]
		var center := bounds.get_center()
		# Outline at terrain height, with tall sparse posts visible from roofs.
		for side in 4:
			var a := bounds.position if side == 0 else (Vector2(bounds.end.x, bounds.position.y) if side == 1 else (bounds.end if side == 2 else Vector2(bounds.position.x, bounds.end.y)))
			var b := Vector2(bounds.end.x, bounds.position.y) if side == 0 else (bounds.end if side == 1 else (Vector2(bounds.position.x, bounds.end.y) if side == 2 else bounds.position))
			var parts := ceili(a.distance_to(b) / 4)
			for step in parts:
				var point := a.lerp(b, (step + 0.5) / parts)
				var at := Vector3(point.x, 0.1, point.y)
				var dash := _visual_box(_warning, Vector3(0.12, 0.10, a.distance_to(b) / parts * 0.8) if side % 2 else Vector3(a.distance_to(b) / parts * 0.8, 0.10, 0.12), at, Color("ffbf3f"))
				var post: MeshInstance3D
				if step == 0:
					post = _visual_box(_warning, Vector3(0.08, 5, 0.08), at + Vector3.UP * 2.5, Color("ffbf3f"))
				_height_samples.append({"point": at, "dash": dash, "post": post})
		_meteor = TelegraphScene.instantiate() as Node3D
		_meteor.position = Vector3(center.x, 0, center.y)
		_warning.add_child(_meteor)
		_meteor.get_node("WarningFootprint").hide()
	var progress := clampf(1 - (deadline - elapsed) / maxf(WARNING_SECONDS / 600.0 * duration, 0.001), 0, 1)
	var meteor_mesh := _meteor.get_node("Meteor") as Node3D
	meteor_mesh.position.y = lerpf(32, 1, progress)
	meteor_mesh.scale = Vector3.ONE * 5


func _visual_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	instance.mesh = mesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _physics_process(_delta: float) -> void:
	if not surface_height.is_valid():
		return
	for query in 16:
		if _height_cursor >= _height_samples.size():
			break
		var sample: Dictionary = _height_samples[_height_cursor]
		var height := float(surface_height.call(sample.point))
		sample.dash.position.y = height + 0.1
		if is_instance_valid(sample.post):
			sample.post.position.y = height + 2.6
		_height_cursor += 1
		height_query_count += 1


func _clear_warning() -> void:
	if is_instance_valid(_warning):
		_warning.free()
	_warning = null
	_meteor = null
	_last_visual_pending = -1
	_height_samples.clear()
	_height_cursor = 0


func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
