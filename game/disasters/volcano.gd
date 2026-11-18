class_name Volcano
extends Node3D

enum Phase { IDLE, WARNING, ACTIVE }
const SURFACE_COUNT := 9
const HOT_LIFETIME := 60.0
const DAMAGE_PER_SECOND := 6.0
const CONTACT_TOLERANCE := 0.22
# Ground lava flow (T3p, Owner 2026-11-15 19:10: "Only floor, but larger.
# Maybe can the whole map."). After the warning, lava spreads from the vent
# (the district crater) across the whole map floor. Only floor-level support
# burns: anything at or above SAFE_SUPPORT (terraces, docks, decks, roofs) is
# a safe refuge. The front is slower than walking (4.5 m/s), so a runner who
# leaves at the warning can always outpace it.
const SPREAD_RATE := 3.0
const SAFE_SUPPORT := 1.2
const DEFAULT_MAP_HALF_EXTENT := 72.0
const FLOW_HEIGHT := 0.06
const FLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 center;
uniform float radius = 0.0;
uniform float preview = 0.0;
uniform float vent_radius = 9.0;
uniform float glow = 1.0;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float d = distance(world_position.xz, center.xz);
	if (preview > 0.5) {
		// Warning: amber edges pulse outward from the vent, showing where
		// and how the flow will spread. No lava is down yet.
		float ring = vent_radius + mod(TIME * 3.0, 24.0);
		float band = 1.0 - smoothstep(0.0, 0.45, abs(d - ring));
		float rim = 1.0 - smoothstep(0.0, 0.3, abs(d - vent_radius));
		float alpha = max(band * 0.8, rim * 0.95);
		if (alpha < 0.02) {
			discard;
		}
		ALBEDO = vec3(1.0, 0.72, 0.22);
		ALPHA = alpha;
	} else {
		if (d > radius) {
			discard;
		}
		float edge = 1.0 - smoothstep(0.0, 2.5, radius - d);
		float ripple = 0.5 + 0.5 * sin(d * 1.3 - TIME * 2.0);
		vec3 crust = vec3(0.70, 0.20, 0.05);
		vec3 molten = vec3(1.0, 0.60, 0.12);
		ALBEDO = mix(crust, molten, max(edge, ripple * 0.4)) * mix(0.45, 1.0, glow);
		ALPHA = 0.93;
	}
}
"""

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
var map_half_extent := DEFAULT_MAP_HALF_EXTENT
var flow_elapsed := 0.0
var flow_heat := 0.0
var _extent_set := false
var _flow: MultiMeshInstance3D
var _flow_material: ShaderMaterial
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


func set_map_extent(half_extent: float) -> void:
	# Same contract as Flood.set_map_extent: the square floor the flow covers.
	map_half_extent = maxf(half_extent, 1.0)
	_extent_set = true
	if is_instance_valid(_flow):
		_flow.free()
		_flow = null
		_update_flow_visual()


func get_map_extent() -> float:
	# Explicit setter wins; otherwise follow the hosting map (main.gd exposes
	# get_map_half_extent) so Harbor's 32 m floor is not drawn past its edge.
	if not _extent_set and get_parent() != null and get_parent().has_method("get_map_half_extent"):
		return float(get_parent().call("get_map_half_extent"))
	return map_half_extent


func flow_radius() -> float:
	return SPREAD_RATE * flow_elapsed


func flow_arrival_time(point: Vector3) -> float:
	# Seconds after ACTIVE starts until the front reaches this XZ point.
	return Vector2(point.x - district_center.x, point.z - district_center.z).length() / SPREAD_RATE


func full_coverage_time() -> float:
	var extent := get_map_extent()
	var farthest := 0.0
	for corner: Vector2 in [Vector2(extent, extent), Vector2(-extent, extent), Vector2(extent, -extent), Vector2(-extent, -extent)]:
		farthest = maxf(farthest, corner.distance_to(Vector2(district_center.x, district_center.z)))
	return farthest / SPREAD_RATE


func flow_covers(point: Vector3) -> bool:
	# The molten floor has reached this XZ point and is still hot.
	var extent := get_map_extent()
	if phase != Phase.ACTIVE or flow_heat <= 0 or absf(point.x) > extent or absf(point.z) > extent:
		return false
	return Vector2(point.x - district_center.x, point.z - district_center.z).length() <= flow_radius()


func _on_lava_floor(feet: Vector3) -> bool:
	# Standing on map floor or an indoor ground floor (support below
	# SAFE_SUPPORT). Elevated pads, roofs and airborne points never burn.
	var support := float(support_height.call(feet)) if support_height.is_valid() else feet.y
	return absf(support - feet.y) <= CONTACT_TOLERANCE and support < SAFE_SUPPORT


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
	flow_elapsed = 0.0
	flow_heat = HOT_LIFETIME
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
	var column := index % 3
	var row := index / 3
	# Every neighboring shelf uses the same rim vertex.  The old independent
	# shoulder drops left visible vertical seams and read as stacked boxes.
	# These authored values keep the crater asymmetrical without client noise.
	var rims := [
		[0.08, 0.16, 0.11, 0.06, 0.14, 0.42, 0.31, 0.12, 0.09, 0.28, 0.35, 0.15, 0.05, 0.10, 0.07, 0.04],
		[0.07, 0.12, 0.18, 0.09, 0.16, 0.34, 0.45, 0.13, 0.10, 0.39, 0.27, 0.17, 0.04, 0.08, 0.12, 0.05],
	]
	var rim: Array = rims[variant]
	var points := PackedVector3Array([Vector3(0, height, 0)])
	for corner in 4:
		var grid_x := column + (1 if corner == 1 or corner == 2 else 0)
		var grid_y := row + (1 if corner >= 2 else 0)
		var shoulder := float(rim[grid_y * 4 + grid_x])
		# The perimeter meets all four access ramps at exactly their top height.
		# Even a small raised lip blocks a capsule without an automatic step-up.
		if grid_x == 0 or grid_x == 3 or grid_y == 0 or grid_y == 3:
			shoulder = 0.08
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
	_update_flow_visual()
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
			# The shared rim carries the actual support.  Do not give every tile
			# its own vertical plinth: those repeated side walls created the
			# stacked rectangular terrain seen from the gameplay camera.
			for triangle: Array in [[points[0], a, b]]:
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
		# Four static triangles per tile, matching the visible faceted support.
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
		body.position = Vector3(point.x, district_center.y, point.z)
		_terrain.add_child(body)
		_add_hot_fissure(body, points, index)
	_add_outer_bank_skirt()
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
		material.albedo_color = Color("9d4a35")
		mesh.material = material
		visual.mesh = mesh
		ramp.add_child(visual)
		ramp.transform = Transform3D(Basis(x, y, z), (low + high) * 0.5 - y * 0.05)
		_terrain.add_child(ramp)
	_update_materials()


func _add_hot_fissure(body: StaticBody3D, points: PackedVector3Array, index: int) -> void:
	if index not in [0, 2, 4, 6, 8]:
		return
	var edge := (index + variant) % 4 + 1
	var outer := points[edge].lerp(points[edge % 4 + 1], 0.55)
	var mid := points[0].lerp(outer, 0.58)
	var width := Vector3(outer.z - points[0].z, 0, points[0].x - outer.x).normalized() * 0.12
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [points[0] + width + Vector3.UP * 0.012, points[0] - width + Vector3.UP * 0.012, mid + Vector3.UP * 0.012, mid + Vector3.UP * 0.012, outer - width + Vector3.UP * 0.012, outer + width + Vector3.UP * 0.012]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
	var visual := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff8a32")
	material.emission_enabled = true
	material.emission = Color("f06438")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.mesh = surface.commit()
	visual.material_override = material
	body.add_child(visual)


func _add_outer_bank_skirt() -> void:
	var skirt := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in SURFACE_COUNT:
		var column := index % 3
		var row := index / 3
		var point := centers[index]
		var profile := _profiles[index]
		for side in 4:
			if (side == 0 and row != 0) or (side == 1 and column != 2) or (side == 2 and row != 2) or (side == 3 and column != 0):
				continue
			var a := Vector3(point.x + profile[side + 1].x, district_center.y + profile[side + 1].y, point.z + profile[side + 1].z)
			var next := (side + 1) % 4 + 1
			var b := Vector3(point.x + profile[next].x, district_center.y + profile[next].y, point.z + profile[next].z)
			var bottom_a := Vector3(a.x, district_center.y - 0.05, a.z)
			var bottom_b := Vector3(b.x, district_center.y - 0.05, b.z)
			for triangle: Array in [[a, bottom_a, bottom_b], [a, bottom_b, b]]:
				var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
				for vertex: Vector3 in triangle:
					surface.set_normal(normal)
					surface.add_vertex(vertex)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9d4a35")
	material.roughness = 0.9
	skirt.mesh = surface.commit()
	skirt.material_override = material
	_terrain.add_child(skirt)


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
		return "VOLCANO — lava floods the ground in %.0fs — climb a roof, terrace or dock" % ceilf(warning_remaining)
	if phase == Phase.WARNING and feet.y < SAFE_SUPPORT:
		return "VOLCANO — lava floods the ground in %.0fs — climb a roof, terrace or dock" % ceilf(warning_remaining)
	var index := surface_at(feet)
	if index >= 0 and heat[index] > 0:
		return "HOT GROUND — %.0fs heat left — move off this support" % ceilf(heat[index])
	if phase == Phase.ACTIVE and flow_heat > 0 and feet.y < SAFE_SUPPORT:
		if flow_covers(feet):
			return "LAVA FLOW — %.0fs left — climb a roof, terrace or dock" % ceilf(flow_heat)
		var extent := get_map_extent()
		if absf(feet.x) <= extent and absf(feet.z) <= extent:
			return "LAVA SPREADING — reaches you in %.0fs — climb high" % ceilf(maxf(flow_arrival_time(feet) - flow_elapsed, 0))
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
	# The open floor flow cools with weather like an exposed shelf.
	var flow_rate := 4.0 if conditions.get("snow", false) else (3.0 if conditions.get("rain", false) else 1.0)
	var flow_time := minf(remaining, flow_heat / flow_rate)
	flow_heat = maxf(flow_heat - remaining * flow_rate, 0)
	flow_elapsed += remaining
	var water := float(conditions.get("water", -INF))
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
		if index < 0:
			# Floor lava only: never roofs or pads at/above SAFE_SUPPORT, and
			# a player standing in flood water is not touching the lava.
			if flow_time > 0 and water < feet.y and flow_covers(feet) and _on_lava_floor(feet):
				events.append({"peer_id": id, "amount": DAMAGE_PER_SECOND * flow_time, "cause": "Lava flow"})
			continue
		if hot_times[index] <= 0:
			continue
		if support_height.is_valid() and absf(float(support_height.call(feet)) - _surface_height(index, feet)) > CONTACT_TOLERANCE:
			continue
		events.append({"peer_id": id, "amount": DAMAGE_PER_SECOND * hot_times[index], "cause": "Volcanic ground"})
	active_remaining = flow_heat
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
		var bank := index % 3 != 1 and index / 3 != 1
		_materials[index].albedo_color = (Color("ad4935") if bank else Color("e35a32")) if heat[index] > 20 else (Color("d9b77e") if heat[index] > 0 else Color("49566a"))
	if is_instance_valid(_warning):
		(_warning.get_child(_warning.get_child_count() - 1) as Label3D).text = "VOLCANO — LAVA FLOOD IN %.0fs — CLIMB HIGH" % ceilf(warning_remaining) if phase == Phase.WARNING else ("LAVA FLOW — CLIMB HIGH — %.0fs" % ceilf(active_remaining) if is_active() else "COOLED CRATER — SAFE TO CROSS")
	_update_flow_visual()


func _update_flow_visual() -> void:
	# One map-sized quad; the shader draws the molten disc (or, during the
	# warning, the outward-pulsing preview edge). MultiMeshInstance3D keeps it
	# out of the weather overlay registration of volcano MeshInstance3Ds.
	var show := phase == Phase.WARNING or (phase == Phase.ACTIVE and flow_heat > 0)
	if not show:
		if is_instance_valid(_flow):
			_flow.visible = false
		return
	if not is_instance_valid(_flow):
		var extent := get_map_extent()
		var plane := PlaneMesh.new()
		plane.size = Vector2(extent * 2, extent * 2)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = plane
		multimesh.instance_count = 1
		multimesh.set_instance_transform(0, Transform3D(Basis(), Vector3(0, FLOW_HEIGHT, 0)))
		if _flow_material == null:
			var shader := Shader.new()
			shader.code = FLOW_SHADER
			_flow_material = ShaderMaterial.new()
			_flow_material.shader = shader
		_flow = MultiMeshInstance3D.new()
		_flow.name = "LavaFlow"
		_flow.multimesh = multimesh
		_flow.material_override = _flow_material
		_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_flow)
	_flow.visible = true
	_flow_material.set_shader_parameter("center", district_center)
	_flow_material.set_shader_parameter("vent_radius", district_size.length() / 2)
	_flow_material.set_shader_parameter("preview", 1.0 if phase == Phase.WARNING else 0.0)
	_flow_material.set_shader_parameter("radius", flow_radius())
	_flow_material.set_shader_parameter("glow", clampf(flow_heat / 20.0, 0.0, 1.0))


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
	flow_elapsed = 0.0
	flow_heat = 0.0
	if is_instance_valid(_flow):
		_flow.free()
	_flow = null
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
		"district": district_id, "variant": variant, "mutated": mutated, "heat": heat.duplicate(),
		"flow": flow_elapsed, "flow_heat": flow_heat}


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
	var flow := float(snapshot.get("flow", 0.0))
	var flow_hot := float(snapshot.get("flow_heat", 0.0))
	if not is_finite(flow) or flow < 0 or not is_finite(flow_hot) or flow_hot < 0 or flow_hot > HOT_LIFETIME:
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
	flow_elapsed = flow
	flow_heat = flow_hot
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
