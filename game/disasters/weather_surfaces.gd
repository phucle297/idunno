class_name WeatherSurfaces
extends Node3D
## Continuous weather field. Contact samples the actual floor/cover, not a decal.
## Only accumulation and bounded local overrides replicate; particles are cosmetic.

const CONTACT_TOLERANCE := 0.3
const COVER_RAY_HEIGHT := 80.0
const DEEP_SNOW_THRESHOLD := 0.55
const ICE_SNOW_THRESHOLD := 0.08
const MAX_LOCAL_AREAS := 32
const MAX_RESIDUALS := 128
# Compatibility budget for callers that reserve weather sampling capacity.
const MAX_PATCHES := MAX_RESIDUALS
const HEIGHT_STEP := 1.0
const SurfaceShader = preload("res://game/disasters/weather_surface.gdshader")

@export var accumulation_per_second := 0.05
@export var rain_wetting_per_second := 0.25
@export var melt_per_second := 0.025
@export var drying_per_second := 0.02

var support_height: Callable
var precipitation := ""
var _extent := 72.0
var _surface := Vector2.ZERO
var _water_level := -INF
var _flood_wash_level := -INF
var _flood_residual_wetness := 0.0
var _melt_areas: Array[Vector4] = []
var _residuals: Array[Dictionary] = [] # x/z/y support, snow/wetness: bounded actual contacts.
var _puddle_spots := PackedVector3Array()
var _puddle_moisture := PackedFloat32Array()
var _electric := PackedVector2Array() # warning seconds, active seconds per puddle
var _presentation_enabled := false
var _material: ShaderMaterial
var _height_image: Image
var _height_texture: ImageTexture
var _height_dirty := true
var _height_cursor := 0
var _world: Node3D
var _puddle_visuals: Array[MeshInstance3D] = []
var _flakes: Array[MeshInstance3D] = []
var _flake_supports := PackedVector3Array()
var _particle_refresh := 0.0
var _visual_time := 0.0
var _footprints: Array[MeshInstance3D] = []
var _footprint_ages: Array[float] = []
var _last_footprints: Dictionary = {}


func configure_world(world: Node3D, extent: float, puddles: PackedVector3Array) -> bool:
	if not is_instance_valid(world) or not is_finite(extent) or extent <= 0.0 or extent > 80.0 or puddles.size() > MAX_LOCAL_AREAS:
		return false
	for point in puddles:
		if not point.is_finite():
			return false
	_world = world
	_extent = extent
	_puddle_spots = puddles.duplicate()
	_puddle_moisture.resize(puddles.size())
	_puddle_moisture.fill(0.0)
	_presentation_enabled = not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless"
	if not _presentation_enabled:
		cleanup()
		return true
	_material = ShaderMaterial.new()
	_material.shader = SurfaceShader
	_material.set_shader_parameter("extent", extent)
	var size := int(ceil(extent * 2.0 / HEIGHT_STEP)) + 1
	_height_image = Image.create(size, size, false, Image.FORMAT_RF)
	# Unknown pixels are sheltered until their budgeted geometry query finishes.
	_height_image.fill(Color(100.0, 0, 0))
	_height_texture = ImageTexture.create_from_image(_height_image)
	_material.set_shader_parameter("sky_height", _height_texture)
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		register_surface_mesh(mesh)
	for visual in _puddle_visuals:
		visual.free()
	_puddle_visuals.clear()
	for index in puddles.size():
		var visual := MeshInstance3D.new()
		visual.mesh = _puddle_mesh(index)
		visual.position = puddles[index] + Vector3.UP * 0.035
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.18
		visual.material_override = material
		add_child(visual)
		_puddle_visuals.append(visual)
	cleanup()
	invalidate_cover()
	return true


func configure_surfaces(positions: PackedVector3Array, radius: float) -> bool:
	# Transitional public API for callers from the former patch layout. Positions
	# now establish only the bounded world extent; they never create weather discs.
	if positions.is_empty() or not is_finite(radius) or radius <= 0.0:
		return false
	var extent := radius
	for point in positions:
		if not point.is_finite():
			return false
		extent = maxf(extent, maxf(absf(point.x), absf(point.z)) + radius)
	var world := get_parent().get_node_or_null("Sandbox") as Node3D if is_instance_valid(get_parent()) else null
	return configure_world(world if world != null else get_parent() as Node3D, extent, PackedVector3Array())


func register_surface_mesh(mesh: MeshInstance3D) -> bool:
	# Dynamic terrain (including a newly spawned volcano) opts into the same
	# continuous overlay without rebuilding the world or querying every frame.
	if not is_instance_valid(mesh) or mesh.mesh == null or mesh.get_parent() is RigidBody3D:
		return false
	if _presentation_enabled and _material != null:
		mesh.material_overlay = _material
	return true


func invalidate_cover() -> void:
	# Restart only after a completed pass. Repeated moving-cover changes cannot
	# starve the far end of the map. Contact always queries real current geometry.
	if not _height_dirty:
		_height_cursor = 0
	_height_dirty = true
	_particle_refresh = 0.0


func tick(delta: float, raining: bool, snowing: bool, water_level: float) -> void:
	if not _can_mutate() or not is_finite(delta) or delta <= 0.0 or is_nan(water_level):
		return
	_water_level = water_level
	if water_level != -INF:
		_flood_wash_level = maxf(_flood_wash_level, water_level)
		_flood_residual_wetness = 1.0
		for index in _puddle_moisture.size():
			if _puddle_spots[index].y <= water_level:
				_puddle_moisture[index] = 1.0
	var receives_snow := snowing and not raining
	var melt_rate := maxf(melt_per_second, 0.0)
	var melt_time := minf(delta, _surface.x / melt_rate) if not receives_snow and melt_rate > 0.0 else 0.0
	var melted := minf(_surface.x, melt_rate * melt_time)
	_surface.x = clampf(_surface.x - melted + (maxf(accumulation_per_second, 0.0) * delta if receives_snow else 0.0), 0.0, 1.0)
	var rain := maxf(rain_wetting_per_second, 0.0) * delta if raining else 0.0
	var drying := maxf(drying_per_second, 0.0) * (delta - melt_time) if rain == 0.0 else 0.0
	_surface.y = maxf(clampf(_surface.y + rain + melted, 0.0, 1.0) - drying, 0.0)
	if water_level == -INF:
		_flood_residual_wetness = maxf(0.0, _flood_residual_wetness - maxf(drying_per_second, 0.0) * delta)
		for index in _puddle_moisture.size():
			_puddle_moisture[index] = maxf(0.0, _puddle_moisture[index] - maxf(drying_per_second, 0.0) * delta * 0.35)
	for index in range(_residuals.size() - 1, -1, -1):
		var residual: Dictionary = _residuals[index]
		var residual_melt := minf(float(residual.snow), melt_rate * delta) if not receives_snow else 0.0
		residual.snow = clampf(float(residual.snow) - residual_melt + (maxf(accumulation_per_second, 0.0) * delta if receives_snow else 0.0), 0.0, 1.0)
		residual.wetness = maxf(0.0, float(residual.wetness) + residual_melt - maxf(drying_per_second, 0.0) * delta)
		if residual.snow <= 0.0 and residual.wetness <= 0.0:
			_residuals.remove_at(index)
		else:
			_residuals[index] = residual
	for index in _electric.size():
		var state := _electric[index]
		var warning_step := minf(delta, state.x)
		state.x -= warning_step
		state.y = maxf(0.0, state.y - (delta - warning_step))
		_electric[index] = state if _puddle_moisture[index] >= 0.35 or _surface.y >= 0.35 else Vector2.ZERO


func is_exposed(support: Vector3) -> bool:
	if not is_inside_tree() or not support.is_finite():
		return false
	var query := PhysicsRayQueryParameters3D.create(support + Vector3.UP * 0.05, support + Vector3.UP * COVER_RAY_HEIGHT, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func is_precipitation_visible(landing: Vector3, height: float) -> bool:
	# A roof ABOVE the rendered drop must also hide it, not just roofs between
	# its landing and current position. This is the original indoor-particle bug.
	return height > 0.0 and is_finite(height) and is_exposed(landing) and is_exposed(landing + Vector3.UP * height)


func sample_surface(point: Vector3) -> Vector2:
	if not point.is_finite() or absf(point.x) > _extent or absf(point.z) > _extent:
		return Vector2.ZERO
	if support_height.is_valid() and absf(float(support_height.call(point)) - point.y) > CONTACT_TOLERANCE:
		return Vector2.ZERO
	if _water_level >= point.y:
		return Vector2(0, 1)
	var residual := _residual_at(point)
	if not is_exposed(point):
		return residual
	var result := _surface
	if point.y <= _flood_wash_level:
		result = Vector2(0, maxf(result.y, _flood_residual_wetness))
	for area in _melt_areas:
		if Vector3(point.x - area.x, point.y - area.y, point.z - area.z).length() < area.w:
			result = Vector2(0, maxf(result.y, 1.0))
			break
	result.y = minf(result.y, 1.0)
	_store_residual(point, result)
	return result


func movement_surface(point: Vector3) -> Dictionary:
	var surface := sample_surface(point)
	return {"wet": surface.y, "snow": surface.x,
		"deep_snow": surface.x >= DEEP_SNOW_THRESHOLD,
		"ice": surface.x >= ICE_SNOW_THRESHOLD and surface.x < DEEP_SNOW_THRESHOLD and surface.y >= 0.15,
		"puddle": _puddle_at(point) >= 0 and surface.y >= 0.35 and surface.x < ICE_SNOW_THRESHOLD}


func melt_snow_at(point: Vector3, radius: float, amount: float = 1.0) -> void:
	if not _can_mutate() or not point.is_finite() or not is_finite(radius) or not is_finite(amount) or radius <= 0.0 or amount <= 0.0 or _surface.x <= 0.0:
		return
	for index in _melt_areas.size():
		var area := _melt_areas[index]
		if Vector3(area.x, area.y, area.z).distance_to(point) < 0.5:
			area.w = maxf(radius, area.w)
			_melt_areas[index] = area
			return
	if _melt_areas.size() < MAX_LOCAL_AREAS:
		_melt_areas.append(Vector4(point.x, point.y, point.z, radius))
	var current := sample_surface(point)
	_store_residual(point, Vector2(maxf(0.0, current.x - minf(amount, 1.0)), minf(1.0, current.y + minf(amount, 1.0))))


func electrify_puddle(point: Vector3) -> bool:
	if not _can_mutate() or _surface.y < 0.35:
		return false
	var start := _puddle_at(point)
	if start < 0:
		return false
	var connected: Array[int] = [start]
	for index in connected:
		_electric[index] = Vector2(1.2, 2.0)
		for other in _puddle_spots.size():
			if other not in connected and _puddle_spots[index].distance_to(_puddle_spots[other]) < 3.0:
				connected.append(other)
	return true


func is_electrified(point: Vector3) -> bool:
	var index := _puddle_at(point)
	return index >= 0 and _electric[index].x <= 0.0 and _electric[index].y > 0.0 and sample_surface(point).y >= 0.35


func _puddle_at(point: Vector3) -> int:
	for index in _puddle_spots.size():
		var spot := _puddle_spots[index]
		if absf(point.y - spot.y) <= CONTACT_TOLERANCE and Vector2(point.x - spot.x, point.z - spot.z).length_squared() <= 1.8:
			return index
	return -1


func _residual_at(point: Vector3) -> Vector2:
	for entry in _residuals:
		if Vector3(float(entry.x), float(entry.y), float(entry.z)).distance_to(point) <= CONTACT_TOLERANCE:
			return Vector2(float(entry.snow), float(entry.wetness))
	return Vector2.ZERO


func _store_residual(point: Vector3, state: Vector2) -> void:
	if not _can_mutate():
		return
	for index in _residuals.size():
		var entry: Dictionary = _residuals[index]
		if Vector3(float(entry.x), float(entry.y), float(entry.z)).distance_to(point) <= CONTACT_TOLERANCE:
			entry.snow = state.x
			entry.wetness = state.y
			_residuals[index] = entry
			return
	if _residuals.size() >= MAX_RESIDUALS:
		_residuals.pop_front()
	_residuals.append({"x": point.x, "y": point.y, "z": point.z, "snow": state.x, "wetness": state.y})


func cleanup() -> void:
	_surface = Vector2.ZERO
	_water_level = -INF
	_flood_wash_level = -INF
	_flood_residual_wetness = 0.0
	_melt_areas.clear()
	_residuals.clear()
	_electric.resize(_puddle_spots.size())
	_electric.fill(Vector2.ZERO)
	precipitation = ""
	_last_footprints.clear()
	for visual in _footprints:
		visual.free()
	_footprints.clear()
	_footprint_ages.clear()


func create_presentation_snapshot() -> Dictionary:
	return {"snow": PackedFloat32Array([_surface.x]), "wetness": PackedFloat32Array([_surface.y]),
		"water": _water_level, "wash_level": _flood_wash_level, "wash_wetness": _flood_residual_wetness,
		"melt": _melt_areas.duplicate(), "residuals": _residuals.duplicate(true), "puddles": _puddle_moisture.duplicate(), "electric": _electric.duplicate(), "precipitation": precipitation}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	if not snapshot.get("snow") is PackedFloat32Array or not snapshot.get("wetness") is PackedFloat32Array or not snapshot.get("electric") is PackedVector2Array or not snapshot.get("melt") is Array or not snapshot.get("residuals") is Array or not snapshot.get("puddles") is PackedFloat32Array:
		return false
	var snow: PackedFloat32Array = snapshot.snow
	var wet: PackedFloat32Array = snapshot.wetness
	var electric: PackedVector2Array = snapshot.electric
	var melt: Array = snapshot.melt
	var residuals: Array = snapshot.residuals
	var puddles: PackedFloat32Array = snapshot.puddles
	if snow.size() != 1 or wet.size() != 1 or not is_finite(snow[0]) or not is_finite(wet[0]) or snow[0] < 0 or snow[0] > 1 or wet[0] < 0 or wet[0] > 1 or electric.size() != _puddle_spots.size() or puddles.size() != _puddle_spots.size() or melt.size() > MAX_LOCAL_AREAS or residuals.size() > MAX_RESIDUALS:
		return false
	if not snapshot.get("water") is float or not snapshot.get("wash_level") is float or not snapshot.get("wash_wetness") is float or is_nan(float(snapshot.water)) or is_nan(float(snapshot.wash_level)) or not is_finite(float(snapshot.wash_wetness)) or snapshot.wash_wetness < 0 or snapshot.wash_wetness > 1 or String(snapshot.get("precipitation", "invalid")) not in ["", "Rain", "Snowfall"]:
		return false
	for state in electric:
		if not state.is_finite() or state.x < 0 or state.x > 1.2 or state.y < 0 or state.y > 2.0:
			return false
	for area in melt:
		if not area is Vector4 or not area.is_finite() or area.w <= 0 or area.w > 30:
			return false
	for value in puddles:
		if not is_finite(value) or value < 0 or value > 1:
			return false
	for entry in residuals:
		if not entry is Dictionary or not entry.has_all(["x", "y", "z", "snow", "wetness"]):
			return false
		for key in ["x", "y", "z", "snow", "wetness"]:
			if not is_finite(float(entry[key])):
				return false
		if entry.snow < 0 or entry.snow > 1 or entry.wetness < 0 or entry.wetness > 1:
			return false
	_surface = Vector2(snow[0], wet[0])
	_water_level = snapshot.water
	_flood_wash_level = snapshot.wash_level
	_flood_residual_wetness = snapshot.wash_wetness
	_electric = electric.duplicate()
	_melt_areas.assign(melt)
	_residuals.assign(residuals)
	_puddle_moisture = puddles.duplicate()
	precipitation = snapshot.precipitation
	return true


func leave_footprint(peer_id: int, point: Vector3) -> void:
	if sample_surface(point).x < 0.15 or (_last_footprints.has(peer_id) and point.distance_to(_last_footprints[peer_id]) < 0.7):
		return
	_last_footprints[peer_id] = point
	if _footprints.size() >= 64:
		_footprints.pop_front().free()
		_footprint_ages.pop_front()
	var visual := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.18, 0.32)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b2c9ce")
	mesh.material = material
	visual.mesh = mesh
	visual.position = point + Vector3.UP * 0.035
	add_child(visual)
	_footprints.append(visual)
	_footprint_ages.append(0.0)


func _process(delta: float) -> void:
	if not _presentation_enabled:
		return
	_visual_time += delta
	if _material != null:
		_update_cover_texture()
		_material.set_shader_parameter("snow", _surface.x)
		_material.set_shader_parameter("wetness", _surface.y)
		_material.set_shader_parameter("melt_count", _melt_areas.size())
		var areas := PackedVector4Array(_melt_areas)
		areas.resize(MAX_LOCAL_AREAS)
		_material.set_shader_parameter("melt_areas", areas)
	for index in _puddle_visuals.size():
		var spot := _puddle_spots[index]
		var surface := sample_surface(spot)
		var visual := _puddle_visuals[index]
		visual.visible = surface.y > 0.1 and surface.x < DEEP_SNOW_THRESHOLD
		var state := _electric[index]
		var color := Color(0.18, 0.48, 0.58, minf(0.58, surface.y))
		if state.y > 0:
			color = Color(0.72, 0.57, 1.0, 0.65 if state.x <= 0 else 0.3 + 0.25 * sin(_visual_time * 12))
		(visual.material_override as StandardMaterial3D).albedo_color = color
	for index in range(_footprints.size() - 1, -1, -1):
		_footprint_ages[index] += delta
		if _footprint_ages[index] > 5.0 or _surface.x < 0.08:
			_footprints[index].free()
			_footprints.remove_at(index)
			_footprint_ages.remove_at(index)
	_update_precipitation(delta)


func _update_cover_texture() -> void:
	if not _height_dirty or not is_instance_valid(_world):
		return
	var size := _height_image.get_width()
	var end := mini(_height_cursor + 1024, size * size)
	for index in range(_height_cursor, end):
		var x := index % size
		var z := index / size
		var point := Vector3(float(x) * HEIGHT_STEP - _extent, 60, float(z) * HEIGHT_STEP - _extent)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 80, 1))
		_height_image.set_pixel(x, z, Color(float(hit.position.y) if not hit.is_empty() else -100.0, 0, 0))
	_height_cursor = end
	_height_texture.update(_height_image)
	if end == size * size:
		_height_dirty = false
		_height_cursor = 0


func _update_precipitation(delta: float) -> void:
	if _flakes.is_empty():
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.12, 0.055)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("e5f2f4")
		mesh.material = material
		for index in 128:
			var flake := MeshInstance3D.new()
			flake.mesh = mesh
			flake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(flake)
			_flakes.append(flake)
		_flake_supports.resize(_flakes.size())
	var camera := get_viewport().get_camera_3d()
	var center := camera.global_position if is_instance_valid(camera) else Vector3.ZERO
	_particle_refresh -= delta
	if _particle_refresh <= 0 and not precipitation.is_empty():
		_particle_refresh = 0.25
		for index in _flakes.size():
			var point := Vector3(center.x + sin(index * 2.39996) * sqrt(float(index) / 128.0) * 24.0, 60, center.z + cos(index * 2.39996) * sqrt(float(index) / 128.0) * 24.0)
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 80, 1))
			_flake_supports[index] = hit.position if not hit.is_empty() else Vector3(point.x, -20, point.z)
	for index in _flakes.size():
		var flake := _flakes[index]
		flake.visible = not precipitation.is_empty()
		if not flake.visible:
			continue
		var height := 10.0 - fmod(_visual_time * (8.0 if precipitation == "Rain" else 1.8) + index * 0.37, 10.0)
		flake.position = _flake_supports[index] + Vector3.UP * height
		flake.scale = Vector3(0.6, 4, 0.6) if precipitation == "Rain" else Vector3.ONE
		flake.visible = is_precipitation_visible(_flake_supports[index], height)


func _puddle_mesh(seed: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 40:
		for vertex in [Vector2.ZERO, _puddle_vertex(index, seed), _puddle_vertex((index + 1) % 40, seed)]:
			surface.set_normal(Vector3.UP)
			surface.set_color(Color.WHITE if vertex == Vector2.ZERO else Color(1, 1, 1, 0.5))
			surface.add_vertex(Vector3(vertex.x, 0, vertex.y))
	return surface.commit()


func _puddle_vertex(index: int, seed: int) -> Vector2:
	var angle := TAU * float(index) / 40.0
	return Vector2(cos(angle), sin(angle)) * (1.35 + 0.16 * sin(angle * 3 + seed) + 0.09 * cos(angle * 5 - seed))


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
