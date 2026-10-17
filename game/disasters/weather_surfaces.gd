class_name WeatherSurfaces
extends Node3D

# Authored, bounded surface patches. Callers supply the actual support height,
# not the highest roof at this X/Z; stacked indoor floors remain distinct.
const MAX_PATCHES := 64
const CONTACT_TOLERANCE := 0.3
const COVER_RAY_HEIGHT := 80.0

@export var accumulation_per_second := 0.05
@export var rain_wetting_per_second := 0.25
@export var melt_per_second := 0.025
@export var drying_per_second := 0.02

var patch_radius := 2.4
var _positions := PackedVector3Array()
var _snow := PackedFloat32Array()
var _wetness := PackedFloat32Array()
var _outlines: Array[PackedVector2Array] = []
var _geometry_dirty := true
var support_height: Callable
var _patch_visuals: Array[MeshInstance3D] = []
var _flakes: Array[MeshInstance3D] = []
var _visual_time := 0.0
var precipitation := ""


func configure_surfaces(positions: PackedVector3Array, radius: float) -> bool:
	if not _can_mutate() or positions.is_empty() or positions.size() > MAX_PATCHES or not is_finite(radius) or radius <= 0.0:
		return false
	for point in positions:
		if not point.is_finite():
			return false
	_positions = positions.duplicate()
	patch_radius = radius
	_rebuild_outlines()
	cleanup()
	return true


func tick(delta: float, raining: bool, snowing: bool, water_level: float) -> void:
	if not _can_mutate() or not is_inside_tree() or not is_finite(delta) or delta <= 0.0 or is_nan(water_level):
		return
	for index in _positions.size():
		var support := _positions[index]
		if support_height.is_valid() and absf(float(support_height.call(support)) - support.y) > CONTACT_TOLERANCE:
			_snow[index] = 0.0
			_wetness[index] = 0.0
			continue
		# Water contact overrides shelter and washes snow away at the surface,
		# not at the player's head or the roof above an indoor patch.
		if water_level >= support.y:
			_snow[index] = 0.0
			_wetness[index] = 1.0
			continue
		var exposed := is_exposed(support)
		var receives_snow := exposed and snowing and not raining
		var melt_rate := maxf(melt_per_second, 0.0)
		var melt_time := minf(delta, _snow[index] / melt_rate) if not receives_snow and melt_rate > 0.0 else 0.0
		var melted := minf(_snow[index], melt_rate * melt_time)
		_snow[index] = clampf(_snow[index] - melted + (maxf(accumulation_per_second, 0.0) * delta if receives_snow else 0.0), 0.0, 1.0)
		var rain := maxf(rain_wetting_per_second, 0.0) * delta if exposed and raining else 0.0
		# Meltwater persists after Snowfall ends. Rain never makes a roofed
		# interior wet; existing water still dries there over time.
		var drying := maxf(drying_per_second, 0.0) * (delta - melt_time) if rain == 0.0 else 0.0
		_wetness[index] = maxf(clampf(_wetness[index] + rain + melted, 0.0, 1.0) - drying, 0.0)


func is_exposed(support: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(support + Vector3.UP * 0.05, support + Vector3.UP * COVER_RAY_HEIGHT, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func sample_surface(point: Vector3) -> Vector2:
	# X = snow, Y = wetness. Outside authored patches/contact returns dry;
	# airborne players and floors above a patch never inherit its traction.
	var result := Vector2.ZERO
	for index in _positions.size():
		var support := _positions[index]
		if absf(point.y - support.y) > CONTACT_TOLERANCE or not _point_in_outline(Vector2(point.x - support.x, point.z - support.z), _outlines[index]):
			continue
		result.x = maxf(result.x, _snow[index])
		result.y = maxf(result.y, _wetness[index])
	return result


func cleanup() -> void:
	_snow.resize(_positions.size())
	_wetness.resize(_positions.size())
	_snow.fill(0.0)
	_wetness.fill(0.0)
	precipitation = ""


func create_presentation_snapshot() -> Dictionary:
	return {
		"positions": _positions.duplicate(),
		"radius": patch_radius,
		"snow": _snow.duplicate(),
		"wetness": _wetness.duplicate(),
		"precipitation": precipitation,
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	if not snapshot.get("positions") is PackedVector3Array or not snapshot.get("snow") is PackedFloat32Array or not snapshot.get("wetness") is PackedFloat32Array:
		return false
	var positions: PackedVector3Array = snapshot.get("positions", PackedVector3Array())
	var snow: PackedFloat32Array = snapshot.get("snow", PackedFloat32Array())
	var wetness: PackedFloat32Array = snapshot.get("wetness", PackedFloat32Array())
	var radius := float(snapshot.get("radius", 0.0))
	if positions.size() > MAX_PATCHES or snow.size() != positions.size() or wetness.size() != positions.size() or not is_finite(radius) or radius <= 0.0:
		return false
	for index in positions.size():
		if not positions[index].is_finite() or not is_finite(snow[index]) or not is_finite(wetness[index]):
			return false
		if snow[index] < 0.0 or snow[index] > 1.0 or wetness[index] < 0.0 or wetness[index] > 1.0:
			return false
	var layout_changed := _positions != positions or patch_radius != radius
	_positions = positions.duplicate()
	_snow = snow.duplicate()
	_wetness = wetness.duplicate()
	patch_radius = radius
	if layout_changed:
		_rebuild_outlines()
	precipitation = String(snapshot.get("precipitation", ""))
	return true


func _process(delta: float) -> void:
	_visual_time += delta
	if _geometry_dirty or _patch_visuals.size() != _positions.size():
		for visual in _patch_visuals:
			visual.free()
		_patch_visuals.clear()
		for index in _positions.size():
			var visual := MeshInstance3D.new()
			visual.mesh = _create_patch_mesh(_outlines[index])
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.22, 0.46, 0.53, 0.38)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.32
			material.metallic = 0.0
			visual.material_override = material
			add_child(visual)
			_patch_visuals.append(visual)
		_geometry_dirty = false
	for index in _positions.size():
		var visual := _patch_visuals[index]
		visual.position = _positions[index] + Vector3.UP * 0.025
		visual.visible = maxf(_snow[index], _wetness[index]) > 0.02
		var material := visual.material_override as StandardMaterial3D
		material.albedo_color = Color(0.22, 0.46, 0.53, 0.38).lerp(Color("f4e6c8"), _snow[index])
		material.roughness = lerpf(0.3, 0.85, _snow[index])
	if _flakes.is_empty() and not _positions.is_empty():
		for index in 64:
			var flake := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.07, 0.18, 0.07)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("f4e6c8")
			mesh.material = material
			flake.mesh = mesh
			add_child(flake)
			_flakes.append(flake)
	for index in _flakes.size():
		var flake := _flakes[index]
		flake.visible = not precipitation.is_empty() and not _positions.is_empty()
		if not flake.visible:
			continue
		var support := _positions[index % _positions.size()]
		flake.visible = is_exposed(support)
		var falling_speed := 6.0 if precipitation == "Rain" else 1.5
		flake.scale = Vector3(0.5, 3.0, 0.5) if precipitation == "Rain" else Vector3.ONE
		flake.position = support + Vector3(sin(index * 2.4) * patch_radius * 0.8, 5.0 - fmod(_visual_time * falling_speed + index * 0.37, 5.0), cos(index * 2.4) * patch_radius * 0.8)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _rebuild_outlines() -> void:
	_outlines.clear()
	_geometry_dirty = true
	for index in _positions.size():
		# The authored support and index deterministically define both the rendered
		# outline and the contact area; snapshots need only replicate that layout.
		var point := _positions[index]
		var seed := absf(sin(point.x * 12.9898 + point.y * 78.233 + point.z * 37.719 + index * 19.19))
		var rotation := seed * TAU
		var major := patch_radius * (0.78 + fmod(seed * 17.0, 0.16))
		var minor := major * (0.76 + fmod(seed * 31.0, 0.18))
		var outline := PackedVector2Array()
		for vertex in 40:
			var angle := TAU * float(vertex) / 40.0
			# Broad, smooth lobes avoid both perfect disks and jagged cut-paper edges.
			var wobble := 0.87 + 0.09 * sin(seed * 97.0 + angle * 3.0) + 0.04 * sin(seed * 43.0 + angle * 5.0)
			outline.append(Vector2(cos(angle) * major * wobble, sin(angle) * minor * wobble).rotated(rotation))
		_outlines.append(outline)


func _point_in_outline(point: Vector2, outline: PackedVector2Array) -> bool:
	var inside := false
	var previous := outline.size() - 1
	for current in outline.size():
		var a := outline[current]
		var b := outline[previous]
		if ((a.y > point.y) != (b.y > point.y)) and point.x <= (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		previous = current
	return inside


func _create_patch_mesh(outline: PackedVector2Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in outline.size():
		var next := (index + 1) % outline.size()
		surface.set_normal(Vector3.UP)
		surface.set_color(Color.WHITE)
		surface.add_vertex(Vector3.ZERO)
		var a := Vector3(outline[index].x, 0.0, outline[index].y)
		var b := Vector3(outline[next].x, 0.0, outline[next].y)
		surface.add_vertex(a * 0.94)
		surface.add_vertex(b * 0.94)
		# A thin feathered shoreline, with the same outer boundary as contact.
		for vertex: Vector3 in [a * 0.94, a, b, a * 0.94, b, b * 0.94]:
			surface.set_color(Color.WHITE if vertex == a * 0.94 or vertex == b * 0.94 else Color(1, 1, 1, 0))
			surface.add_vertex(vertex)
	return surface.commit()
