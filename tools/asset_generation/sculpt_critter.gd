extends SceneTree
## T44 plush critter sculpt: deterministic, in-repo, no external tools.
## Signed-distance fields (smooth-union ellipsoids / round cones) -> surface
## nets (cell-size per part) -> Laplacian smoothing + SDF re-projection ->
## meshoptimizer decimation (ImporterMesh LODs) -> per-region UV projection.
## Writes assets/models/critter/CHR_Critter_v001.glb (one glTF mesh per part)
## and the fabric normal map. The Godot import extracts every mesh to
## assets/models/critter/meshes/<Part>.res (see the .glb.import).
## Usage: godot --headless --path . --script res://tools/asset_generation/sculpt_critter.gd

const SEED := 297
const OUT_DIR := "res://assets/models/critter"
const GLB_PATH := "res://assets/models/critter/CHR_Critter_v001.glb"
const NORMAL_MAP_PATH := "res://assets/models/critter/textures/T_Fabric_Normal_v001.png"
const NORMAL_MAP_SIZE := 128
# Hood (head) ellipsoid in Torso-local space; the Torso node sits at y = 0.66.
const TORSO_Y := 0.66
const HOOD_CENTER := Vector3(0.0, 0.49, 0.0)
const HOOD_RADII := Vector3(0.34, 0.33, 0.32)
const HEAD_TOP_Y := 0.66 + 0.49 + 0.33
const HEAD_BOTTOM_Y := 0.66 + 0.49 - 0.33
const EARS_ORIGIN := Vector3(0.0, 1.15, 0.0)
const TAIL_ORIGIN := Vector3(0.0, 0.45, 0.0)
const EAR_SINK := 0.05
const PAW_RADIUS := 0.072
const LEG_ROOT_Y := 0.16

# Ear / tail type per catalog slot (plain, cap, hard_hat, backpack, raincoat,
# mechanic, park_ranger, meteor_observer, chef, firefighter, sailor, pilot).
const OUTFIT_EARS := ["bear", "cat", "mouse", "bunny", "frog", "fox", "bear_small", "antenna", "floppy", "cat_tall", "seal", "fox"]
const OUTFIT_TAILS := ["puff", "long", "thin", "puff_small", "stub", "bushy", "stub", "curl", "puff", "curl", "flipper", "bushy"]
const OUTFIT_PATTERN := ["f4e6c8", "202a38", "f2a7b8", "fff7ea", "b9e07a", "ffffff", "8a5a3c", "ffbf3f", "e8e8e8", "ffd23f", "73b7ad", "f06438"]


static func part_names() -> Array[String]:
	var names: Array[String] = ["Body", "Face", "Muzzle", "Eye", "Mouth", "ArmL", "ArmR", "PawL", "PawR", "Leg", "Foot"]
	for index in 12:
		names.append("Belly_%02d" % index)
		names.append("Ears_%02d" % index)
		names.append("Tail_%02d" % index)
	return names


static func mesh_path(part: String) -> String:
	return "%s/meshes/%s.res" % [OUT_DIR, part]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/meshes"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/textures"))
	_write_normal_map()
	var root := Node3D.new()
	root.name = "CHR_Critter_v001"
	var cache := {}
	var total := 0
	for part in part_names():
		var mesh := build_part(part, cache)
		var instance := MeshInstance3D.new()
		instance.name = part
		instance.mesh = mesh
		root.add_child(instance)
		instance.owner = root
		var tris := 0
		for surface in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(surface) / 3
		total += tris
		print("SCULPT part=%s verts=%d tris=%d surfaces=%d" % [part, mesh.surface_get_array_len(0), tris, mesh.get_surface_count()])
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(root, state) == OK)
	assert(document.write_to_filesystem(state, ProjectSettings.globalize_path(GLB_PATH)) == OK)
	root.free()
	print("SCULPT_CRITTER_OK seed=%d parts=%d tris=%d glb=%s" % [SEED, part_names().size(), total, GLB_PATH])
	quit()


# ---------------------------------------------------------------- SDF core

static func _ellipsoid(p: Vector3, c: Vector3, r: Vector3, basis := Basis.IDENTITY) -> float:
	var q := basis.transposed() * (p - c)
	var k0 := (q / r).length()
	var k1 := (q / (r * r)).length()
	if k1 < 1e-9:
		return -minf(r.x, minf(r.y, r.z))
	return k0 * (k0 - 1.0) / k1


static func _round_cone(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var ba := b - a
	var l2 := ba.length_squared()
	var t := clampf((p - a).dot(ba) / l2, 0.0, 1.0)
	return p.distance_to(a + ba * t) - lerpf(ra, rb, t)


static func _smin(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return minf(a, b)
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


static func _smax(a: float, b: float, k: float) -> float:
	return -_smin(-a, -b, k)


## The fused Body (hood-head + torso + belly) in Torso-local space.
static func body_sdf(p: Vector3) -> float:
	var d := _ellipsoid(p, Vector3(0.0, -0.05, 0.0), Vector3(0.29, 0.31, 0.25))
	d = _smin(d, _ellipsoid(p, Vector3(0.0, -0.17, 0.0), Vector3(0.25, 0.15, 0.22)), 0.06)
	d = _smin(d, _ellipsoid(p, HOOD_CENTER, HOOD_RADII), 0.08)
	# Hood opening (face) on -Z, a soft lip rather than a hard cut.
	d = _smax(d, -_ellipsoid(p, Vector3(0.0, 0.46, -0.36), Vector3(0.235, 0.21, 0.13)), 0.025)
	return d


static func hood_surface_point(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	var s := 1.0 / (d / HOOD_RADII).length()
	return HOOD_CENTER + d * s


## Ear frame at the hood surface: origin sunk EAR_SINK along the outward
## normal, Y = ear axis, Z = ear thickness (faces forward/back). Ears-local
## space (Accessories node at EARS_ORIGIN == hood centre in character space).
static func ear_frame(side: float, spread: float, lift: float, tilt: float) -> Transform3D:
	var dir := Vector3(side * spread, lift, 0.10)
	var surface := hood_surface_point(dir) - HOOD_CENTER
	var normal := (surface / (HOOD_RADII * HOOD_RADII)).normalized()
	var axis := (normal + Vector3(0.0, tilt, 0.0)).normalized()
	var thick := Vector3(0.0, 0.0, 1.0)
	var width := axis.cross(thick).normalized()
	thick = width.cross(axis).normalized()
	return Transform3D(Basis(width, axis, thick), surface - normal * EAR_SINK)


static func _ear_shapes(kind: String) -> Dictionary:
	# spread/lift place the ear on the hood; shapes are [center_along_axis, radii(w, len, thick)].
	match kind:
		"bear": return {"spread": 0.72, "lift": 0.62, "tilt": 0.2, "shapes": [[0.08, Vector3(0.085, 0.085, 0.045)]]}
		"bear_small": return {"spread": 0.70, "lift": 0.66, "tilt": 0.3, "shapes": [[0.065, Vector3(0.07, 0.07, 0.04)]]}
		"mouse": return {"spread": 0.80, "lift": 0.55, "tilt": 0.1, "shapes": [[0.10, Vector3(0.115, 0.11, 0.035)]]}
		"cat": return {"spread": 0.62, "lift": 0.74, "tilt": 0.5, "cone": [0.0, 0.17, 0.075, 0.012, 0.035]}
		"cat_tall": return {"spread": 0.58, "lift": 0.78, "tilt": 0.8, "cone": [0.0, 0.21, 0.07, 0.01, 0.035]}
		"fox": return {"spread": 0.64, "lift": 0.72, "tilt": 0.6, "cone": [0.0, 0.22, 0.09, 0.012, 0.04]}
		"bunny": return {"spread": 0.40, "lift": 0.90, "tilt": 1.6, "shapes": [[0.17, Vector3(0.055, 0.20, 0.03)]]}
		"floppy": return {"spread": 0.95, "lift": 0.15, "tilt": -1.4, "shapes": [[0.12, Vector3(0.07, 0.16, 0.03)]]}
		"frog": return {"spread": 0.40, "lift": 0.80, "tilt": 0.6, "shapes": [[0.06, Vector3(0.075, 0.075, 0.075)]]}
		"seal": return {"spread": 0.85, "lift": 0.45, "tilt": 0.0, "shapes": [[0.05, Vector3(0.05, 0.05, 0.03)]]}
		"antenna": return {"spread": 0.45, "lift": 0.85, "tilt": 1.2, "stalk": [0.0, 0.20, 0.018, 0.045]}
	return {}


static func ear_sdf(p: Vector3, kind: String) -> float:
	var spec := _ear_shapes(kind)
	var d := 1e9
	for side in [-1.0, 1.0]:
		var frame := ear_frame(side, spec.spread, spec.lift, spec.tilt)
		var q := frame.affine_inverse() * p
		if spec.has("shapes"):
			for shape: Array in spec.shapes:
				d = minf(d, _ellipsoid(q, Vector3(0.0, shape[0], 0.0), shape[1]))
		elif spec.has("cone"):
			var c: Array = spec.cone
			# Flattened round cone (scale thickness) for pointed cat/fox ears.
			var flat := Vector3(q.x, q.y, q.z * c[2] / c[4])
			d = minf(d, _round_cone(flat, Vector3(0, c[0], 0), Vector3(0, c[1], 0), c[2], c[3]) * (c[4] / c[2]))
		elif spec.has("stalk"):
			var s: Array = spec.stalk
			d = minf(d, _round_cone(q, Vector3(0, s[0], 0), Vector3(0, s[1], 0), s[2], s[2]))
			d = _smin(d, _ellipsoid(q, Vector3(0, s[1], 0), Vector3.ONE * s[3]), 0.02)
	return d


## Inner-ear (pattern) classification in Ears-local space.
static func ear_inner(p: Vector3, n: Vector3, kind: String) -> bool:
	var spec := _ear_shapes(kind)
	for side in [-1.0, 1.0]:
		var frame := ear_frame(side, spec.spread, spec.lift, spec.tilt)
		var q := frame.affine_inverse() * p
		var front := frame.basis.z.dot(n) < -0.2
		var along := q.y > EAR_SINK + 0.012
		if kind == "antenna":
			if q.y > 0.16:
				return true
			continue
		if front and along and absf(q.x) < 0.75 * _ear_width(spec):
			return true
	return false


static func _ear_width(spec: Dictionary) -> float:
	if spec.has("shapes"):
		return (spec.shapes[0][1] as Vector3).x
	if spec.has("cone"):
		return spec.cone[2]
	return 0.05


## Tail path in Tail-local space (Tail node at TAIL_ORIGIN); root sunk in the back.
static func _tail_chain(kind: String) -> Array:
	var root := Vector3(0.0, 0.0, 0.15)
	match kind:
		"puff": return [[root, root + Vector3(0, 0.02, 0.09), 0.085, 0.085]]
		"puff_small": return [[root, root + Vector3(0, 0.01, 0.07), 0.065, 0.065]]
		"stub": return [[root, root + Vector3(0, 0.03, 0.10), 0.06, 0.04]]
		"long": return [[root, root + Vector3(0, -0.02, 0.14), 0.045, 0.035], [root + Vector3(0, -0.02, 0.14), root + Vector3(0, 0.16, 0.24), 0.035, 0.028], [root + Vector3(0, 0.16, 0.24), root + Vector3(0, 0.26, 0.21), 0.028, 0.032]]
		"thin": return [[root, root + Vector3(0, -0.06, 0.18), 0.03, 0.02], [root + Vector3(0, -0.06, 0.18), root + Vector3(0.04, -0.01, 0.30), 0.02, 0.014]]
		"bushy": return [[root, root + Vector3(0, 0.10, 0.12), 0.05, 0.085], [root + Vector3(0, 0.10, 0.12), root + Vector3(0, 0.24, 0.17), 0.085, 0.04]]
		"curl": return [[root, root + Vector3(0, 0.02, 0.12), 0.04, 0.035], [root + Vector3(0, 0.02, 0.12), root + Vector3(0, 0.12, 0.17), 0.035, 0.032], [root + Vector3(0, 0.12, 0.17), root + Vector3(0, 0.17, 0.10), 0.032, 0.03]]
		"flipper": return [[root, root + Vector3(0, -0.05, 0.12), 0.05, 0.035]]
	return []


static func tail_sdf(p: Vector3, kind: String) -> float:
	var d := 1e9
	for seg: Array in _tail_chain(kind):
		d = _smin(d, _round_cone(p, seg[0], seg[1], seg[2], seg[3]), 0.02)
	if kind == "flipper":
		var tip: Vector3 = _tail_chain(kind)[0][1]
		d = _smin(d, _ellipsoid(p, tip + Vector3(0, -0.01, 0.03), Vector3(0.11, 0.025, 0.05)), 0.02)
	return d


static func tail_tip(p: Vector3, kind: String) -> bool:
	var chain := _tail_chain(kind)
	var tip: Vector3 = chain[chain.size() - 1][1]
	var root: Vector3 = chain[0][0]
	var span := 0.0
	for seg: Array in chain:
		span += (seg[1] as Vector3).distance_to(seg[0])
	var reach := maxf(span * 0.38, 0.05)
	return p.distance_to(tip) < reach and p.distance_to(root) > 0.08


# ------------------------------------------------------------ part specs

static func _spec(part: String) -> Dictionary:
	var side := -1.0 if part.ends_with("L") else 1.0
	match part:
		"Body":
			return {"sdf": func(p: Vector3) -> float: return body_sdf(p), "min": Vector3(-0.40, -0.40, -0.38), "max": Vector3(0.40, 0.86, 0.38), "cell": 0.018, "target": 2800, "uv": "body"}
		"Face":
			return {"sdf": func(p: Vector3) -> float: return _ellipsoid(p, Vector3.ZERO, Vector3(0.235, 0.205, 0.12)), "min": Vector3(-0.26, -0.23, -0.15), "max": Vector3(0.26, 0.23, 0.15), "cell": 0.016, "target": 300}
		"Muzzle":
			return {"sdf": func(p: Vector3) -> float: return _smin(_ellipsoid(p, Vector3.ZERO, Vector3(0.075, 0.05, 0.035)), _ellipsoid(p, Vector3(0.0, 0.028, -0.03), Vector3(0.028, 0.02, 0.018)), 0.01), "min": Vector3(-0.09, -0.07, -0.07), "max": Vector3(0.09, 0.07, 0.05), "cell": 0.007, "target": 250,
				"accent": func(p: Vector3, _n: Vector3) -> bool: return _ellipsoid(p, Vector3(0.0, 0.028, -0.03), Vector3(0.028, 0.02, 0.018) * 1.25) < 0.0}
		"Eye":
			return {"sdf": func(p: Vector3) -> float: return _ellipsoid(p, Vector3.ZERO, Vector3(0.03, 0.036, 0.02)), "min": Vector3(-0.04, -0.045, -0.03), "max": Vector3(0.04, 0.045, 0.03), "cell": 0.005, "target": 100}
		"Mouth":
			var pts := [Vector3(-0.03, 0.008, 0), Vector3(-0.015, -0.006, 0), Vector3(0.0, 0.004, 0), Vector3(0.015, -0.006, 0), Vector3(0.03, 0.008, 0)]
			return {"sdf": func(p: Vector3) -> float:
				var d := 1e9
				for i in 4:
					d = minf(d, _round_cone(p, pts[i], pts[i + 1], 0.0055, 0.0055))
				return d, "min": Vector3(-0.045, -0.02, -0.012), "max": Vector3(0.045, 0.02, 0.012), "cell": 0.003, "target": 60}
		"ArmL", "ArmR":
			return {"sdf": func(p: Vector3) -> float: return _round_cone(p, Vector3(0.0, 0.03, 0.0), Vector3(side * 0.10, -0.22, -0.012), 0.072, 0.06), "min": Vector3(-0.2, -0.32, -0.1), "max": Vector3(0.2, 0.12, 0.1), "cell": 0.014, "target": 300}
		"PawL", "PawR":
			return {"sdf": func(p: Vector3) -> float: return _smin(_ellipsoid(p, Vector3.ZERO, Vector3(PAW_RADIUS + 0.004, PAW_RADIUS, PAW_RADIUS)), _ellipsoid(p, Vector3(-side * 0.035, 0.012, -0.045), Vector3(0.03, 0.03, 0.03)), 0.02), "min": Vector3(-0.1, -0.09, -0.1), "max": Vector3(0.1, 0.09, 0.09), "cell": 0.011, "target": 200}
		"Leg":
			return {"sdf": func(p: Vector3) -> float: return _round_cone(p, Vector3(0.0, LEG_ROOT_Y + 0.05, 0.0), Vector3(0.0, -0.15, 0.0), 0.088, 0.078), "min": Vector3(-0.11, -0.25, -0.11), "max": Vector3(0.11, 0.32, 0.11), "cell": 0.014, "target": 260}
		"Foot":
			return {"sdf": func(p: Vector3) -> float: return _smax(_smin(_ellipsoid(p, Vector3(0.0, 0.0, -0.01), Vector3(0.10, 0.09, 0.13)), _ellipsoid(p, Vector3(0.0, 0.03, 0.04), Vector3(0.08, 0.06, 0.07)), 0.03), -(p.y + 0.082), 0.015), "min": Vector3(-0.12, -0.1, -0.16), "max": Vector3(0.12, 0.12, 0.13), "cell": 0.012, "target": 260}
	if part.begins_with("Belly_"):
		return {"sdf": func(p: Vector3) -> float: return maxf(body_sdf(p) - 0.012, _ellipsoid(p, Vector3(0.0, -0.08, -0.24), Vector3(0.165, 0.19, 0.12))), "min": Vector3(-0.2, -0.3, -0.3), "max": Vector3(0.2, 0.14, -0.1), "cell": 0.01, "target": 300, "color_all": true}
	if part.begins_with("Ears_"):
		var kind: String = OUTFIT_EARS[part.trim_prefix("Ears_").to_int()]
		var hood := HOOD_CENTER
		return {"sdf": func(p: Vector3) -> float: return ear_sdf(p, kind), "min": Vector3(-0.56, -0.40, -0.25), "max": Vector3(0.56, 0.62, 0.25), "cell": 0.011 if kind != "antenna" else 0.008, "target": 500,
			"accent": func(p: Vector3, n: Vector3) -> bool: return ear_inner(p, n, kind), "origin": hood}
	if part.begins_with("Tail_"):
		var kind: String = OUTFIT_TAILS[part.trim_prefix("Tail_").to_int()]
		return {"sdf": func(p: Vector3) -> float: return tail_sdf(p, kind), "min": Vector3(-0.16, -0.18, 0.04), "max": Vector3(0.16, 0.36, 0.52), "cell": 0.012, "target": 300,
			"accent": func(p: Vector3, _n: Vector3) -> bool: return tail_tip(p, kind)}
	return {}


static func pattern_color(part: String) -> Color:
	var digits := part.substr(part.length() - 2).to_int()
	return Color(OUTFIT_PATTERN[digits])


# -------------------------------------------------------- mesh building

## Builds one part. `cache` shares geometry between parts with identical
## shapes (belly patches, repeated ear/tail kinds) before recolouring.
static func build_part(part: String, cache := {}) -> ArrayMesh:
	var key := part
	if part.begins_with("Belly_"):
		key = "Belly"
	elif part.begins_with("Ears_"):
		key = "Ears:" + OUTFIT_EARS[part.trim_prefix("Ears_").to_int()]
	elif part.begins_with("Tail_"):
		key = "Tail:" + OUTFIT_TAILS[part.trim_prefix("Tail_").to_int()]
	var spec := _spec(part)
	var tris: Array = cache.get(key, [])
	if tris.is_empty():
		tris = _sculpt(spec)
		cache[key] = tris
	var accent_color := pattern_color(part) if (part.begins_with("Belly_") or part.begins_with("Ears_") or part.begins_with("Tail_")) else Color.WHITE
	var mesh := ArrayMesh.new()
	mesh.resource_name = part
	# surface 0 = main (suit / skin / bead), surface 1 = accent (pattern / nose).
	var groups := [[], []]
	for tri: Array in tris:
		var accent: bool = spec.get("color_all", false) or (spec.has("accent") and (spec.accent as Callable).call((tri[0] + tri[1] + tri[2]) / 3.0, (tri[3] + tri[4] + tri[5]).normalized()))
		groups[1 if accent else 0].append(tri)
	if spec.get("color_all", false):
		groups = [groups[1], []]
	for index in 2:
		if groups[index].is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var color := accent_color if (index == 1 or spec.get("color_all", false)) else Color.WHITE
		for tri: Array in groups[index]:
			var uvs := _triangle_uvs(spec.get("uv", "sphere"), tri)
			for corner in 3:
				st.set_color(color)
				st.set_normal(tri[3 + corner])
				st.set_uv(uvs[corner])
				st.add_vertex(tri[corner])
		st.index()
		st.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "main" if index == 0 else "accent")
	return mesh


static func _sculpt(spec: Dictionary) -> Array:
	var sdf: Callable = spec.sdf
	var h: float = spec.cell
	var lo: Vector3 = spec.min
	var hi: Vector3 = spec.max
	var nx := int(ceil((hi.x - lo.x) / h))
	var ny := int(ceil((hi.y - lo.y) / h))
	var nz := int(ceil((hi.z - lo.z) / h))
	var sx := nx + 1
	var sy := ny + 1
	var values := PackedFloat32Array()
	values.resize(sx * sy * (nz + 1))
	for z in nz + 1:
		for y in sy:
			for x in sx:
				values[x + sx * (y + sy * z)] = sdf.call(lo + Vector3(x, y, z) * h)
	# Surface nets: one vertex per sign-changing cell (mean of edge crossings).
	var cell_vertex := PackedInt32Array()
	cell_vertex.resize(nx * ny * nz)
	cell_vertex.fill(-1)
	var positions := PackedVector3Array()
	var corners := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for z in nz:
		for y in ny:
			for x in nx:
				var v := []
				var inside := 0
				for c: Vector3i in corners:
					var value := values[(x + c.x) + sx * ((y + c.y) + sy * (z + c.z))]
					v.append(value)
					if value < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var sum := Vector3.ZERO
				var count := 0
				for e: Array in edges:
					var a: float = v[e[0]]
					var b: float = v[e[1]]
					if (a < 0.0) == (b < 0.0):
						continue
					var t := a / (a - b)
					sum += Vector3(corners[e[0]]).lerp(Vector3(corners[e[1]]), t)
					count += 1
				cell_vertex[x + nx * (y + ny * z)] = positions.size()
				positions.append(lo + (Vector3(x, y, z) + sum / float(count)) * h)
	# Quads across every sign-changing grid edge shared by four cells.
	var indices := PackedInt32Array()
	var neighbors: Array = []
	neighbors.resize(positions.size())
	for i in positions.size():
		neighbors[i] = {}
	var axes := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	for z in range(1, nz):
		for y in range(1, ny):
			for x in range(1, nx):
				var here := values[x + sx * (y + sy * z)]
				for axis in 3:
					var step: Vector3i = axes[axis]
					var gx := x + step.x
					var gy := y + step.y
					var gz := z + step.z
					if gx > nx or gy > ny or gz > nz:
						continue
					var there := values[gx + sx * (gy + sy * gz)]
					if (here < 0.0) == (there < 0.0):
						continue
					var u: Vector3i = axes[(axis + 1) % 3]
					var w: Vector3i = axes[(axis + 2) % 3]
					var quad := []
					for offset: Vector3i in [Vector3i.ZERO, u, u + w, w]:
						var c := Vector3i(x, y, z) - offset
						if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= nx or c.y >= ny or c.z >= nz:
							quad.clear()
							break
						quad.append(cell_vertex[c.x + nx * (c.y + ny * c.z)])
					if quad.size() != 4 or quad.has(-1):
						continue
					for i in 4:
						neighbors[quad[i]][quad[(i + 1) % 4]] = true
						neighbors[quad[(i + 1) % 4]][quad[i]] = true
					indices.append_array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]])
	# Laplacian smoothing, then re-project onto the SDF surface (no shrink).
	for _iteration in 2:
		var smoothed := positions.duplicate()
		for i in positions.size():
			var keys: Array = neighbors[i].keys()
			if keys.is_empty():
				continue
			var mean := Vector3.ZERO
			for k: int in keys:
				mean += positions[k]
			smoothed[i] = positions[i].lerp(mean / float(keys.size()), 0.5)
		positions = smoothed
	for i in positions.size():
		var p := positions[i]
		var g := _gradient(sdf, p)
		positions[i] = p - g * float(sdf.call(p))
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	for i in positions.size():
		normals[i] = _gradient(sdf, positions[i])
	# Consistent clockwise winding before decimation (open/flipped edges lock the simplifier).
	for t in range(0, indices.size(), 3):
		var a := positions[indices[t]]
		var cross := (positions[indices[t + 1]] - a).cross(positions[indices[t + 2]] - a)
		if cross.dot(normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]) > 0.0:
			var swap := indices[t + 1]
			indices[t + 1] = indices[t + 2]
			indices[t + 2] = swap
	# Decimate to budget with meshoptimizer (ImporterMesh LOD chain).
	var chosen := indices
	if indices.size() / 3 > int(spec.target):
		var importer := ImporterMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		importer.generate_lods(60.0, 25.0, [])
		if OS.has_environment("SCULPT_DEBUG"):
			print("LODS ", indices.size() / 3, " count=", importer.get_surface_lod_count(0))
		for lod in importer.get_surface_lod_count(0):
			var lod_indices := importer.get_surface_lod_indices(0, lod)
			chosen = lod_indices
			if lod_indices.size() / 3 <= int(spec.target) * 1.2:
				break
		# generate_lods may re-order/merge the vertex buffer.
		var lod_arrays := importer.get_surface_arrays(0)
		positions = lod_arrays[Mesh.ARRAY_VERTEX]
		normals = lod_arrays[Mesh.ARRAY_NORMAL]
	var tris := []
	for t in range(0, chosen.size(), 3):
		var a := positions[chosen[t]]
		var b := positions[chosen[t + 1]]
		var c := positions[chosen[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.length() < 1e-9:
			continue
		var na := normals[chosen[t]]
		var nb := normals[chosen[t + 1]]
		var nc := normals[chosen[t + 2]]
		# Godot front faces wind clockwise: geometric normal opposes the outward SDF normal.
		if cross.dot(na + nb + nc) > 0.0:
			tris.append([a, c, b, na, nc, nb])
		else:
			tris.append([a, b, c, na, nb, nc])
	return tris


static func _gradient(sdf: Callable, p: Vector3) -> Vector3:
	var e := 0.0015
	var g := Vector3(
		float(sdf.call(p + Vector3(e, 0, 0))) - float(sdf.call(p - Vector3(e, 0, 0))),
		float(sdf.call(p + Vector3(0, e, 0))) - float(sdf.call(p - Vector3(0, e, 0))),
		float(sdf.call(p + Vector3(0, 0, e))) - float(sdf.call(p - Vector3(0, 0, e))))
	return g.normalized() if g.length() > 1e-12 else Vector3.UP


## UV islands: Body = hood (spherical, left half) + torso (cylindrical, right
## half), seams at back-centre (+Z) and underside. Other parts: spherical.
static func _triangle_uvs(mode: String, tri: Array) -> Array:
	var centroid: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
	var hood := mode == "body" and centroid.y > 0.24
	var uvs := []
	for corner in 3:
		var p: Vector3 = tri[corner]
		var q := p - (HOOD_CENTER if hood else (Vector3(0, -0.05, 0) if mode == "body" else Vector3.ZERO))
		var u := atan2(q.x, -q.z) / TAU + 0.5
		var v := 0.0
		if mode == "body" and not hood:
			v = clampf((0.24 - p.y) / 0.66, 0.0, 1.0)
		else:
			v = acos(clampf(q.normalized().y, -1.0, 1.0)) / PI
		uvs.append(Vector2(u, v))
	var lo := minf(uvs[0].x, minf(uvs[1].x, uvs[2].x))
	var hi := maxf(uvs[0].x, maxf(uvs[1].x, uvs[2].x))
	if hi - lo > 0.5:
		for corner in 3:
			if uvs[corner].x < 0.5:
				uvs[corner].x = 1.0
	for corner in 3:
		var uv: Vector2 = uvs[corner].clamp(Vector2.ZERO, Vector2.ONE)
		if mode == "body":
			uv = Vector2(uv.x * 0.49 + (0.0 if hood else 0.51), uv.y)
		uvs[corner] = uv
	return uvs


## 128 px tiling knit/fleece normal map (seeded noise + rib pattern).
static func _write_normal_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var size := NORMAL_MAP_SIZE
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	var noise := PackedFloat32Array()
	noise.resize(size * size)
	for i in noise.size():
		noise[i] = rng.randf()
	for y in size:
		for x in size:
			var rib := sin(TAU * float(x) * 8.0 / size) * 0.5 + 0.5
			var row := sin(TAU * (float(y) * 16.0 / size + 0.25 * sin(TAU * float(x) * 8.0 / size))) * 0.5 + 0.5
			var n := 0.0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					n += noise[posmod(x + dx, size) + size * posmod(y + dy, size)]
			heights[x + size * y] = rib * 0.45 + row * 0.35 + n / 9.0 * 0.6
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var dx := heights[posmod(x + 1, size) + size * y] - heights[posmod(x - 1, size) + size * y]
			var dy := heights[x + size * posmod(y + 1, size)] - heights[x + size * posmod(y - 1, size)]
			var n := Vector3(-dx * 1.6, -dy * 1.6, 1.0).normalized()
			image.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	assert(image.save_png(ProjectSettings.globalize_path(NORMAL_MAP_PATH)) == OK)
