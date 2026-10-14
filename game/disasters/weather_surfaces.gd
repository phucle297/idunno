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
		if absf(point.y - support.y) > CONTACT_TOLERANCE or Vector2(point.x - support.x, point.z - support.z).length() > patch_radius:
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
	_positions = positions.duplicate()
	_snow = snow.duplicate()
	_wetness = wetness.duplicate()
	patch_radius = radius
	precipitation = String(snapshot.get("precipitation", ""))
	return true


func _process(delta: float) -> void:
	_visual_time += delta
	if _patch_visuals.size() != _positions.size():
		for visual in _patch_visuals:
			visual.free()
		_patch_visuals.clear()
		for point in _positions:
			var visual := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = patch_radius
			mesh.bottom_radius = patch_radius
			mesh.height = 0.025
			mesh.radial_segments = 24
			visual.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("42b8e8")
			material.roughness = 0.8
			visual.material_override = material
			add_child(visual)
			_patch_visuals.append(visual)
	for index in _positions.size():
		var visual := _patch_visuals[index]
		visual.position = _positions[index] + Vector3.UP * 0.025
		visual.visible = maxf(_snow[index], _wetness[index]) > 0.02
		var material := visual.material_override as StandardMaterial3D
		material.albedo_color = Color("42b8e8").lerp(Color("f4e6c8"), _snow[index])
		material.roughness = lerpf(0.25, 0.85, _snow[index])
		# Full footprint from first wetting: shrinking the disk would lie about contact.
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
