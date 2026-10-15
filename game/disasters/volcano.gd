class_name Volcano
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }
const SURFACE_COUNT := 9
const HOT_LIFETIME := 60.0
const DAMAGE_PER_SECOND := 6.0
const CONTACT_TOLERANCE := 0.22

@export var warning_duration := 12.0
var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var mutated := false
var district_id := ""
var variant := 0
var heat := PackedFloat32Array()
var centers := PackedVector3Array()
var district_center := Vector3.ZERO
var district_size := Vector2.ONE
var environment: Callable
var support_height: Callable
var exposed: Callable
var _manager: MatchManager
var _players: Dictionary = {}
var _terrain: Node3D
var _warning: Node3D
var _materials: Array[StandardMaterial3D] = []
var _profiles: Array[PackedVector3Array] = []


func configure(manager: MatchManager) -> void:
	_manager = manager


func set_district(id: String, center: Vector3, size: Vector2) -> void:
	cleanup()
	district_id = id
	district_center = center
	district_size = size
	heat.resize(SURFACE_COUNT)
	heat.fill(0)


func get_disaster_metadata() -> Dictionary:
	return {"name": "Volcano", "difficulty": 2, "minimum_match_time": 120.0,
		"incompatible_disasters": ["Tornado", "Earthquake", "Meteor Shower", "Lightning", "Fire", "Rockslide", "Bee Swarm", "UFO"],
		"combination_tags": ["terrain", "heat"]}


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
	if not _can_mutate() or is_active() or mutated or district_id.is_empty() or not is_instance_valid(_manager) or _manager.state != MatchManager.MatchState.ACTIVE:
		return false
	variant = rng.randi_range(0, 1)
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = HOT_LIFETIME
	_show_warning()
	return true


func is_active() -> bool:
	# Residual heat reserves the director slot until the last support cools.
	return phase != Phase.IDLE


func _surface_center(index: int) -> Vector3:
	var column := index % 3
	var row := index / 3
	var bank := column != 1 and row != 1
	var heights := [1.05, 0.10, 1.20, 0.12, 0.14, 0.10, 1.30, 0.12, 1.10]
	var height: float = heights[index] + (variant * 0.2 if bank else 0.0)
	return district_center + Vector3((column - 1) * district_size.x / 3, height, (row - 1) * district_size.y / 3)


func _surface_profile(index: int, height: float) -> PackedVector3Array:
	var half := district_size / 6
	var bank := index % 3 != 1 and index / 3 != 1
	# Unequal shoulders make broad, readable rock facets, not noisy pebbles.
	# Crossing tiles meet at the same 8cm rim; their small crowns remain walkable.
	var drops := [0.30, 0.50, 0.18, 0.38]
	var points := PackedVector3Array([Vector3(0, height, 0)])
	for corner in 4:
		var shoulder := height - float(drops[(corner + index + variant) % 4]) if bank else 0.08
		points.append(Vector3(-half.x if corner == 0 or corner == 3 else half.x, shoulder, -half.y if corner < 2 else half.y))
	return points


func _surface_height(index: int, feet: Vector3) -> float:
	var local := feet - Vector3(centers[index].x, district_center.y, centers[index].z)
	var normalized := Vector2(local.x / (district_size.x / 6), local.z / (district_size.y / 6))
	var side := 0 if normalized.y <= -absf(normalized.x) else (1 if normalized.x >= absf(normalized.y) else (2 if normalized.y >= absf(normalized.x) else 3))
	var points := _profiles[index]
	var normal := (points[(side + 1) % 4 + 1] - points[0]).cross(points[side + 1] - points[0])
	return district_center.y + points[0].y - (normal.x * local.x + normal.z * local.z) / normal.y


func _erupt() -> void:
	mutated = true
	heat.fill(HOT_LIFETIME)
	phase = Phase.ACTIVE
	_build_terrain()
	# A warned player who ignored evacuation is placed atop the changed
	# support, never embedded inside a newly raised bank. No launch impulse.
	for player: Node3D in _players.values():
		if not is_instance_valid(player):
			continue
		var index := surface_at(player.global_position, false)
		if index >= 0 and player.global_position.y >= district_center.y - CONTACT_TOLERANCE:
			player.global_position.y = maxf(player.global_position.y, _surface_height(index, player.global_position) + 0.02)


func _build_terrain() -> void:
	if is_instance_valid(_terrain):
		return
	_terrain = Node3D.new()
	add_child(_terrain)
	centers.clear()
	_materials.clear()
	_profiles.clear()
	for index in SURFACE_COUNT:
		var point := _surface_center(index)
		centers.append(point)
		var body := StaticBody3D.new()
		body.name = "VolcanicShelf%d" % index
		var points := _surface_profile(index, point.y - district_center.y)
		_profiles.append(points)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in 4:
			var a := points[side + 1]
			var b := points[(side + 1) % 4 + 1]
			var bottom_a := Vector3(a.x, -0.05, a.z)
			var bottom_b := Vector3(b.x, -0.05, b.z)
			for triangle: Array in [[points[0], a, b], [a, bottom_a, bottom_b], [a, bottom_b, b]]:
				var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
				for vertex: Vector3 in triangle:
					surface.set_normal(normal)
					surface.add_vertex(vertex)
		var mesh := surface.commit()
		var visual := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.roughness = 0.85
		_materials.append(material)
		visual.mesh = mesh
		visual.material_override = material
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		# Twelve static triangles per tile, matching the visible faceted support.
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
		body.position = Vector3(point.x, district_center.y, point.z)
		_terrain.add_child(body)
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var extent := district_size.x / 2 if direction.x != 0 else district_size.y / 2
		var width := district_size.y / 3 if direction.x != 0 else district_size.x / 3
		var low := district_center + direction * (extent + 1.5) - Vector3.UP * 0.08
		var high := district_center + direction * (extent - 0.05) + Vector3.UP * 0.08
		var z := low.direction_to(high)
		var x := Vector3.UP.cross(z).normalized()
		var y := z.cross(x).normalized()
		var ramp := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, 0.1, low.distance_to(high))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		ramp.add_child(collision)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("f4e6c8")
		mesh.material = material
		visual.mesh = mesh
		ramp.add_child(visual)
		ramp.transform = Transform3D(Basis(x, y, z), (low + high) * 0.5 - y * 0.05)
		_terrain.add_child(ramp)
	_update_materials()


func surface_at(feet: Vector3, require_contact := true) -> int:
	# Shared edges belong to an actual contacted shelf, never a safe seam
	# or a neighboring bank above the player's current support.
	for index in centers.size():
		var center := centers[index]
		if absf(feet.x - center.x) > district_size.x / 6 or absf(feet.z - center.z) > district_size.y / 6:
			continue
		if not require_contact or absf(feet.y - _surface_height(index, feet)) <= CONTACT_TOLERANCE:
			return index
	return -1


func get_escape_context(feet: Vector3) -> String:
	if phase == Phase.WARNING and absf(feet.x - district_center.x) <= district_size.x / 2 and absf(feet.z - district_center.z) <= district_size.y / 2:
		return "VOLCANO — evacuate the outlined district; two crossing exits"
	var index := surface_at(feet)
	if index >= 0 and heat[index] > 0:
		return "HOT GROUND — %.0fs heat left — move off this support" % ceilf(heat[index])
	return ""


func tick(delta: float) -> void:
	if not _can_mutate() or not is_active() or not is_finite(delta) or delta <= 0:
		return
	if _manager.state != MatchManager.MatchState.ACTIVE:
		cleanup()
		return
	var remaining := delta
	if phase == Phase.WARNING:
		var warning_step := minf(remaining, warning_remaining)
		warning_remaining -= warning_step
		remaining -= warning_step
		if warning_remaining <= 0:
			_erupt()
	if phase != Phase.ACTIVE:
		return
	var conditions: Dictionary = environment.call() if environment.is_valid() else {}
	var hot_times := PackedFloat32Array()
	for index in SURFACE_COUNT:
		var rate := 1.0
		var point := centers[index]
		if float(conditions.get("water", -INF)) >= point.y:
			rate = 10.0
		elif exposed.is_valid() and bool(exposed.call(point)):
			rate = 4.0 if conditions.get("snow", false) else (3.0 if conditions.get("rain", false) else 1.0)
		hot_times.append(minf(remaining, heat[index] / rate))
		heat[index] = maxf(heat[index] - remaining * rate, 0)
	var events: Array[Dictionary] = []
	for id: int in _players:
		var player := _players[id] as PartyPlayer
		if not is_instance_valid(player) or not _manager.is_player_alive(id) or not player.is_on_floor():
			continue
		var feet := player.global_position
		var index := surface_at(feet)
		if index < 0 or hot_times[index] <= 0:
			continue
		if support_height.is_valid() and absf(float(support_height.call(feet)) - _surface_height(index, feet)) > CONTACT_TOLERANCE:
			continue
		events.append({"peer_id": id, "amount": DAMAGE_PER_SECOND * hot_times[index], "cause": "Volcanic ground"})
	active_remaining = heat[0]
	for value in heat:
		active_remaining = maxf(active_remaining, value)
	if active_remaining <= 0:
		phase = Phase.IDLE
	_update_materials()
	# Damage can synchronously end the match and clear terrain. Resolve last.
	if not events.is_empty():
		_manager.apply_damage_batch(events)


func _update_materials() -> void:
	for index in _materials.size():
		_materials[index].albedo_color = Color("f06438") if heat[index] > 20 else (Color("d9b77e") if heat[index] > 0 else Color("49566a"))
	if is_instance_valid(_warning):
		(_warning.get_child(_warning.get_child_count() - 1) as Label3D).text = "VOLCANO — EVACUATE %.0fs" % ceilf(warning_remaining) if phase == Phase.WARNING else ("HOT GROUND — %.0fs" % ceilf(active_remaining) if is_active() else "COOLED CRATER — SAFE TO CROSS")


func _show_warning() -> void:
	if is_instance_valid(_warning):
		return
	_warning = Node3D.new()
	add_child(_warning)
	for side in 4:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(district_size.x, 0.06, 0.18) if side < 2 else Vector3(0.18, 0.06, district_size.y)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffbf3f")
		mesh.material = material
		visual.mesh = mesh
		visual.position = district_center + (Vector3(0, 0.1, district_size.y * (side - 0.5)) if side < 2 else Vector3(district_size.x * (side - 2.5), 0.1, 0))
		_warning.add_child(visual)
	var label := Label3D.new()
	label.position = district_center + Vector3(0, 2.8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.012
	_warning.add_child(label)
	_update_materials()


func cleanup() -> void:
	phase = Phase.IDLE
	warning_remaining = 0
	active_remaining = 0
	mutated = false
	variant = 0
	heat.resize(SURFACE_COUNT)
	heat.fill(0)
	centers.clear()
	_materials.clear()
	_profiles.clear()
	if is_instance_valid(_terrain):
		_terrain.free()
	_terrain = null
	if is_instance_valid(_warning):
		_warning.free()
	_warning = null


func create_presentation_snapshot() -> Dictionary:
	return {"phase": phase, "warning": warning_remaining, "active": active_remaining,
		"district": district_id, "variant": variant, "mutated": mutated, "heat": heat.duplicate()}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if _can_mutate():
		return false
	if snapshot.is_empty():
		cleanup()
		return true
	if not snapshot.get("heat") is PackedFloat32Array:
		return false
	var values: PackedFloat32Array = snapshot.get("heat", PackedFloat32Array())
	if snapshot.get("district", "") != district_id or values.size() != SURFACE_COUNT:
		return false
	for value in values:
		if not is_finite(value) or value < 0 or value > HOT_LIFETIME:
			return false
	var changed := bool(snapshot.get("mutated", false))
	var new_variant := clampi(int(snapshot.get("variant", 0)), 0, 1)
	if mutated != changed or variant != new_variant:
		cleanup()
	phase = clampi(int(snapshot.get("phase", 0)), 0, 2)
	warning_remaining = maxf(float(snapshot.get("warning", 0)), 0)
	active_remaining = maxf(float(snapshot.get("active", 0)), 0)
	variant = new_variant
	mutated = changed
	heat = values.duplicate()
	if mutated:
		_build_terrain()
	if is_active() or mutated:
		_show_warning()
	_update_materials()
	return true


func _physics_process(delta: float) -> void:
	tick(delta)
	_update_materials()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
