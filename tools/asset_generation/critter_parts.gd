extends SceneTree
## T44 A2 critter parts (deterministic, seed 297): clean SurfaceTool meshes that
## reproduce the approved concept sheet (evidence/T44-a2-spike/sheet.png) on the
## KayKit Rogue_Hooded base. No Godot primitive meshes. Lathe / loft / sweep with
## analytic smooth normals and 0..1 UVs.
## Usage: godot --headless --path . --script res://tools/asset_generation/critter_parts.gd
## Coordinates: "spike" model units (front = -Z, the concept sheet framing);
## accessory meshes are baked into character root space (x SPIKE_SCALE).

const SEED := 297
const OUT_DIR := "res://assets/models/critter/parts"
const SPIKE_SCALE := 0.62
const SPECIES := ["bear", "cat", "bunny"]
# 12 catalog slots -> species + pattern (inner ear / tail tip, belly). Slots 0-2 = the sheet colours.
const OUTFITS := [
	["bear", "d9b8a0", "e6d5bb"], ["cat", "d6aeb4", "e8e1d4"], ["bunny", "f0cdd2", "f1e9e2"],
	["bear", "e8c27a", "f3e3b0"], ["cat", "a9c7a1", "e3ecd9"], ["bunny", "c9b6e4", "ece6f5"],
	["bear", "b9cf9a", "e4ecd2"], ["cat", "f2c98a", "f6e7cf"], ["bunny", "f4b6a1", "fbe9df"],
	["bear", "e89c8f", "f6dcd5"], ["cat", "9fc3de", "e2eef7"], ["bunny", "e8d38a", "f7f0d4"],
]


static func part_path(part: String) -> String:
	return "%s/%s.res" % [OUT_DIR, part]


static func part_names() -> Array[String]:
	var names: Array[String] = ["Proxy", "Ellipsoid", "Bead", "Mitten"]
	for index in OUTFITS.size():
		names.append("Ears_%02d" % index)
		names.append("Tail_%02d" % index)
		names.append("Belly_%02d" % index)
	return names


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var total := 0
	for part in part_names():
		var mesh := build(part)
		mesh.resource_name = part
		assert(ResourceSaver.save(mesh, part_path(part)) == OK)
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
		total += tris
		print("PART %s tris=%d surfaces=%d" % [part, tris, mesh.get_surface_count()])
	print("CRITTER_PARTS_OK seed=%d parts=%d tris=%d" % [SEED, part_names().size(), total])
	quit()


# ------------------------------------------------------------------ builders

## Lathe a profile [[radius, y], ...] (bottom pole -> top pole) around Y.
static func _lathe(profile: Array, segments: int, xf: Transform3D, color: Color, tris: Array, phase := 0.0, lump := 0.0) -> void:
	var rows := []
	var n := profile.size()
	for i in n:
		var r: float = profile[i][0]
		var y: float = profile[i][1]
		var prev: Array = profile[maxi(i - 1, 0)]
		var next: Array = profile[mini(i + 1, n - 1)]
		var dr: float = next[0] - prev[0]
		var dy: float = next[1] - prev[1]
		var row := []
		for j in segments + 1:
			var a := TAU * float(j) / segments + phase
			var radial := Vector3(cos(a), 0.0, sin(a))
			var p := radial * r + Vector3(0, y, 0)
			var normal := (radial * dy - Vector3(0, dr, 0)).normalized()
			if normal.length() < 0.5:
				normal = Vector3(0, -1 if i == 0 else 1, 0)
			if lump > 0.0:
				var k := 1.0 + lump * sin(p.x * 31.0 + 1.3) * sin(p.y * 27.0 + 0.7) * sin(p.z * 29.0 + 2.1)
				p = Vector3(p.x * k, (p.y) * k, p.z * k)
			row.append([xf * p, (xf.basis.inverse().transposed() * normal).normalized(), Vector2(float(j) / segments, float(i) / (n - 1))])
		rows.append(row)
	for i in n - 1:
		for j in segments:
			var a: Array = rows[i][j]
			var b: Array = rows[i][j + 1]
			var c: Array = rows[i + 1][j + 1]
			var d: Array = rows[i + 1][j]
			_tri(tris, a, b, c, color)
			_tri(tris, a, c, d, color)


static func _tri(tris: Array, a: Array, b: Array, c: Array, color: Color) -> void:
	var cross: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	if cross.length() < 1e-9:
		return
	# Godot front faces wind clockwise: the geometric normal opposes the outward normal.
	if cross.dot(a[1] + b[1] + c[1]) > 0.0:
		tris.append([a, c, b, color])
	else:
		tris.append([a, b, c, color])


static func _ellipsoid_profile(rings: int) -> Array:
	var profile := []
	for i in rings + 1:
		var t := PI * float(i) / rings
		profile.append([0.5 * sin(t), -0.5 * cos(t)])
	return profile


## Unit-diameter ellipsoid (radius 0.5) like the spike, scaled by `diam`.
static func _ellipsoid(center: Vector3, diam: Vector3, color: Color, tris: Array, rot := Vector3.ZERO, rings := 10, segments := 16, lump := 0.0) -> void:
	var basis := Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(diam)
	_lathe(_ellipsoid_profile(rings), segments, Transform3D(basis, center), color, tris, 0.0, lump)


## Rounded-tip wedge (4-sided like the concept cat ear, softened).
static func _cone(center: Vector3, radius: float, height: float, scale: Vector3, rot: Vector3, color: Color, tris: Array) -> void:
	var profile := [[0.0, -height * 0.5], [radius * 0.92, -height * 0.5], [radius, -height * 0.44]]
	for i in range(1, 8):
		var t := float(i) / 8.0
		profile.append([radius * (1.0 - t) * 0.98 + 0.012 * t, -height * 0.44 + height * 0.92 * t])
	profile.append([0.01, height * 0.49])
	profile.append([0.0, height * 0.5])
	var basis := Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(scale)
	_lathe(profile, 4, Transform3D(basis, center), color, tris, PI * 0.25)


## Capsule (bunny ear): radius r, total height h.
static func _capsule(center: Vector3, r: float, h: float, scale: Vector3, rot: Vector3, color: Color, tris: Array) -> void:
	var half := h * 0.5 - r
	var profile := []
	for i in 4:
		var t := PI * 0.5 * float(i) / 3.0
		profile.append([r * sin(t), -half - r * cos(t)])
	for i in 4:
		var t := PI * 0.5 * float(i) / 3.0
		profile.append([r * cos(t), half + r * sin(t)])
	var basis := Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(scale)
	_lathe(profile, 10, Transform3D(basis, center), color, tris)


## Tapered tube swept along a Catmull-Rom path; rounded closed ends.
static func _sweep(points: Array, r0: float, r1: float, steps: int, tip_from: float, base_color: Color, tip_color: Color, base_tris: Array, tip_tris: Array) -> void:
	var samples := []
	for s in steps + 1:
		var t := float(s) / steps * (points.size() - 1)
		var k := mini(int(t), points.size() - 2)
		var u := t - k
		var p0: Vector3 = points[maxi(k - 1, 0)]
		var p1: Vector3 = points[k]
		var p2: Vector3 = points[k + 1]
		var p3: Vector3 = points[mini(k + 2, points.size() - 1)]
		samples.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u))
	var segs := 10
	var up := Vector3.RIGHT
	var rings := []
	for s in samples.size():
		var c: Vector3 = samples[s]
		var tangent: Vector3 = (samples[mini(s + 1, samples.size() - 1)] - samples[maxi(s - 1, 0)]).normalized()
		var side := tangent.cross(up).normalized()
		up = side.cross(tangent).normalized()
		var f := float(s) / steps
		var r := lerpf(r0, r1, f)
		# Round both ends shut.
		if f < 0.06:
			r *= sqrt(maxf(1.0 - pow((0.06 - f) / 0.06, 2.0), 0.0))
		if f > 0.9:
			r *= sqrt(maxf(1.0 - pow((f - 0.9) / 0.1, 2.0), 0.0))
		var ring := []
		for j in segs + 1:
			var a := TAU * float(j) / segs
			var n := (side * cos(a) + up * sin(a)).normalized()
			ring.append([c + n * r, n, Vector2(float(j) / segs, f)])
		rings.append(ring)
	for s in steps:
		var tip := float(s) / steps >= tip_from
		for j in segs:
			_tri(tip_tris if tip else base_tris, rings[s][j], rings[s][j + 1], rings[s + 1][j + 1], tip_color if tip else base_color)
			_tri(tip_tris if tip else base_tris, rings[s][j], rings[s + 1][j + 1], rings[s + 1][j], tip_color if tip else base_color)


static func _commit(surfaces: Array, origin := Vector3.ZERO) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for index in surfaces.size():
		var tris: Array = surfaces[index]
		if tris.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri: Array in tris:
			for corner in 3:
				var v: Array = tri[corner]
				st.set_color(tri[3])
				st.set_normal(v[1])
				st.set_uv((v[2] as Vector2).clamp(Vector2.ZERO, Vector2.ONE))
				st.add_vertex(v[0] - origin)
		st.index()
		st.commit(mesh)
	return mesh


## Ears/tail/belly are stored relative to the torso lean pivot (root space), so
## the lean tracks rotate them about their own origin.
const ACCESSORY_ORIGIN := Vector3(0.0, 0.603, 0.0)


static func _root(p: Vector3) -> Vector3:
	return p * SPIKE_SCALE


static func build(part: String) -> ArrayMesh:
	var main := []
	var accent := []
	var white := Color.WHITE
	match part:
		"Proxy":
			# Hidden contract proxy (thin bar, top at +0.17, bottom -0.17).
			_lathe([[0.0, -0.17], [0.01, -0.17], [0.01, 0.17], [0.0, 0.17]], 3, Transform3D.IDENTITY, white, main)
			return _commit([main])
		"Ellipsoid":
			_ellipsoid(Vector3.ZERO, Vector3.ONE, white, main, Vector3.ZERO, 10, 16)
			return _commit([main])
		"Bead":
			_ellipsoid(Vector3.ZERO, Vector3.ONE, white, main, Vector3.ZERO, 6, 10)
			return _commit([main])
		"Mitten":
			# Paw mitten with a soft palm pad bump (fitted to hand.* in bone space).
			_ellipsoid(Vector3.ZERO, Vector3.ONE, white, main, Vector3.ZERO, 6, 10)
			_ellipsoid(Vector3(0.0, -0.32, 0.12), Vector3(0.55, 0.3, 0.45), white, main, Vector3.ZERO, 4, 8)
			return _commit([main])
	var index := part.substr(part.length() - 2).to_int()
	var outfit: Array = OUTFITS[index]
	var species: String = outfit[0]
	var inner := Color(outfit[1])
	var belly := Color(outfit[2])
	if part.begins_with("Belly_"):
		_ellipsoid(_root(Vector3(0, 0.86, -0.28)), Vector3(0.52, 0.52, 0.22) * SPIKE_SCALE, belly, main, Vector3.ZERO, 8, 14)
		return _commit([main], ACCESSORY_ORIGIN)
	if part.begins_with("Ears_"):
		for sx in [-1.0, 1.0]:
			match species:
				"bear":
					_ellipsoid(_root(Vector3(sx * 0.33, 2.20, -0.05)), Vector3(0.32, 0.32, 0.20) * SPIKE_SCALE, white, main, Vector3.ZERO, 8, 14)
					_ellipsoid(_root(Vector3(sx * 0.33, 2.21, -0.14)), Vector3(0.18, 0.18, 0.09) * SPIKE_SCALE, inner, accent, Vector3.ZERO, 6, 12)
				"cat":
					_cone(_root(Vector3(sx * 0.27, 2.20, -0.03)), 0.20 * SPIKE_SCALE, 0.36 * SPIKE_SCALE, Vector3(1, 1, 0.55), Vector3(0, 45, -sx * 18.0), white, main)
					_cone(_root(Vector3(sx * 0.27, 2.18, -0.10)), 0.12 * SPIKE_SCALE, 0.26 * SPIKE_SCALE, Vector3(1, 1, 0.4), Vector3(0, 45, -sx * 18.0), inner, accent)
				"bunny":
					_capsule(_root(Vector3(sx * 0.27, 2.30, -0.02)), 0.11 * SPIKE_SCALE, 0.42 * SPIKE_SCALE, Vector3(1, 1, 0.6), Vector3(0, 0, -sx * 14.0), white, main)
					_capsule(_root(Vector3(sx * 0.27, 2.30, -0.08)), 0.06 * SPIKE_SCALE, 0.30 * SPIKE_SCALE, Vector3(1, 1, 0.5), Vector3(0, 0, -sx * 14.0), inner, accent)
		return _commit([main, accent], ACCESSORY_ORIGIN)
	if part.begins_with("Tail_"):
		match species:
			"bear":
				_ellipsoid(_root(Vector3(0, 0.62, 0.42)), Vector3.ONE * 0.30 * SPIKE_SCALE, white, main, Vector3.ZERO, 8, 14)
			"cat":
				var path := []
				for p: Vector3 in [Vector3(0, 0.52, 0.30), Vector3(0, 0.50, 0.58), Vector3(0, 0.60, 0.74), Vector3(0, 0.82, 0.80), Vector3(0, 1.00, 0.72), Vector3(0, 1.08, 0.66)]:
					path.append(_root(p))
				_sweep(path, 0.085 * SPIKE_SCALE, 0.07 * SPIKE_SCALE, 24, 0.82, white, belly, main, accent)
			"bunny":
				_ellipsoid(_root(Vector3(0, 0.60, 0.40)), Vector3.ONE * 0.28 * SPIKE_SCALE, belly, accent, Vector3.ZERO, 10, 16, 0.07)
		return _commit([main, accent], ACCESSORY_ORIGIN)
	return ArrayMesh.new()
