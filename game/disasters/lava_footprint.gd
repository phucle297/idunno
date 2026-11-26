class_name LavaFootprint
extends RefCounted
# T47 (Owner playtest 2026-11-26): one lava footprint for draw AND damage.
# A 1 m grid baked once per map prep from the real collision floor:
#  - floor_y: the support a player standing there has (ray from
#    SAFE_SUPPORT + 0.35 m, same start as get_map_support_height); lava is
#    eligible only where that support is below SAFE_SUPPORT (roofs, terraces
#    and pads are never drawn or burned). NAN = not eligible.
#  - site_bad: crater-site rule (no floor, something overhead, or ground
#    outside [-0.02, 0.15] m: kerbs, steps, decks, prop tops, water, void).
# Pure helpers here pick the random crater site and the early lava zones from
# seeded RNGs so the server and a same-seed replay always agree.

const CELL := 1.0
const ELIGIBLE_BELOW := 1.2 # == Volcano.SAFE_SUPPORT
const SUPPORT_RAY_START := 1.55 # SAFE_SUPPORT + 0.35
const TOP_RAY_START := 40.0
const RAY_END := -20.0
# Authored paving is a render-only mesh up to ~0.03 m above the collision floor;
# tiles ride 0.06 m above the floor so lava is never hidden under paving.
const TILE_LIFT := 0.06
const SITE_LATTICE := 2.0
const SITE_RAMP := 1.5
const SITE_MARGIN := 2.0
const SITE_EDGE := 2.0
const SITE_BAD_MAX := 0.12
const SITE_SPAWN_CLEARANCE := 14.0
const SITE_GROUND_MIN := -0.02
const SITE_GROUND_MAX := 0.15
const ZONE_CRATER_MARGIN := 2.0
const MAX_ZONES := 4

var extent := 0.0
var size := 0
var floor_y := PackedFloat32Array()
var ground_y := PackedFloat32Array()
var site_bad := PackedByteArray()
var baked := false
## Identity transforms (12 floats each) of every eligible tile, for the flood.
var flood_buffer := PackedFloat32Array()
var flood_count := 0
var revision := 0
var _rebake_row := -1


func setup(half_extent: float) -> void:
	extent = maxf(half_extent, 1.0)
	size = int(round(extent * 2 / CELL))
	floor_y.resize(size * size)
	floor_y.fill(NAN)
	ground_y.resize(size * size)
	ground_y.fill(NAN)
	site_bad.resize(size * size)
	site_bad.fill(1)
	baked = false
	flood_buffer = PackedFloat32Array()
	flood_count = 0
	_rebake_row = -1
	revision += 1


func cell_center(i: int, j: int) -> Vector2:
	return Vector2(-extent + (i + 0.5) * CELL, -extent + (j + 0.5) * CELL)


func cell_index(x: float, z: float) -> int:
	var i := int(floor((x + extent) / CELL))
	var j := int(floor((z + extent) / CELL))
	if i < 0 or j < 0 or i >= size or j >= size:
		return -1
	return j * size + i


static func _ray(space: PhysicsDirectSpaceState3D, x: float, z: float, from_y: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, RAY_END, z), 1)
	var hit := space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else NAN


func bake_rows(space: PhysicsDirectSpaceState3D, from_row: int, to_row: int, with_sites := true) -> void:
	for j in range(maxi(from_row, 0), mini(to_row, size)):
		for i in size:
			var c := cell_center(i, j)
			var index := j * size + i
			var support := _ray(space, c.x, c.y, SUPPORT_RAY_START)
			floor_y[index] = support if not is_nan(support) and support < ELIGIBLE_BELOW else NAN
			if not with_sites:
				continue
			ground_y[index] = support
			var top := _ray(space, c.x, c.y, TOP_RAY_START)
			var bad := is_nan(support) or is_nan(top) or top - support > 0.01 \
				or support < SITE_GROUND_MIN or support > SITE_GROUND_MAX
			site_bad[index] = 1 if bad else 0


func finish_bake() -> void:
	flood_buffer = PackedFloat32Array()
	flood_count = 0
	for j in size:
		for i in size:
			var y := floor_y[j * size + i]
			if is_nan(y):
				continue
			var c := cell_center(i, j)
			flood_buffer.append_array([1, 0, 0, c.x, 0, 1, 0, y + TILE_LIFT, 0, 0, 1, c.y])
			flood_count += 1
	baked = true
	revision += 1


## Lazy, chunked re-bake of the floor after a geometry change (terrain
## collapse). Never at erupt: callers spread it over frames.
func invalidate() -> void:
	if baked:
		_rebake_row = 0


func rebake_step(space: PhysicsDirectSpaceState3D, rows := 16) -> bool:
	if _rebake_row < 0:
		return false
	bake_rows(space, _rebake_row, _rebake_row + rows, false)
	_rebake_row += rows
	if _rebake_row >= size:
		_rebake_row = -1
		finish_bake()
	return true


func is_eligible(point: Vector3) -> bool:
	if not baked:
		return true
	var index := cell_index(point.x, point.z)
	return index >= 0 and not is_nan(floor_y[index])


func tile_height(point: Vector3, fallback: float) -> float:
	if not baked:
		return fallback
	var index := cell_index(point.x, point.z)
	return floor_y[index] + TILE_LIFT if index >= 0 and not is_nan(floor_y[index]) else NAN


# ---------------------------------------------------------------- crater

static func site_half(crater: Vector2) -> Vector2:
	return crater / 2 + Vector2.ONE * (SITE_RAMP + SITE_MARGIN)


## Every statically valid crater centre on the 2 m lattice (deterministic
## order): bad cells <= 12% over footprint + ramp + margin (cells past the map
## edge are not counted) and none under the shelves + ramps, footprint +
## margin inside the map extent - 2 m, centre >= 14 m from every spawn.
func valid_sites(crater: Vector2, spawns: Array) -> PackedVector2Array:
	var sites := PackedVector2Array()
	if not baked:
		return sites
	var stride := size + 1
	var sat := PackedInt32Array()
	sat.resize(stride * stride)
	for j in size:
		var row := 0
		for i in size:
			row += site_bad[j * size + i]
			sat[(j + 1) * stride + i + 1] = sat[j * stride + i + 1] + row
	var half := site_half(crater)
	# Crater footprint + 2 m margin stays inside extent - 2 m.
	var limit := Vector2(extent - SITE_EDGE - crater.x / 2 - SITE_MARGIN, extent - SITE_EDGE - crater.y / 2 - SITE_MARGIN)
	var kx := int(floor(limit.x / SITE_LATTICE))
	var kz := int(floor(limit.y / SITE_LATTICE))
	for a in range(-kx, kx + 1):
		for b in range(-kz, kz + 1):
			var centre := Vector2(a * SITE_LATTICE, b * SITE_LATTICE)
			var near := false
			for spawn: Vector3 in spawns:
				if centre.distance_to(Vector2(spawn.x, spawn.z)) < SITE_SPAWN_CLEARANCE:
					near = true
					break
			if near:
				continue
			var window := _window_bad(sat, stride, centre, half)
			if window.y <= 0 or float(window.x) / window.y > SITE_BAD_MAX:
				continue
			# The shelves and ramps themselves must be clear: a lamp post, tree
			# or prop inside them would poke through the crater and block the
			# walk-through crossing (T47 A1 check: no clipping, else fallback).
			if _window_bad(sat, stride, centre, crater / 2 + Vector2.ONE * SITE_RAMP).x > 0:
				continue
			sites.append(centre)
	return sites


func _window_bad(sat: PackedInt32Array, stride: int, centre: Vector2, half: Vector2) -> Vector2i:
	# (bad cells, total cells) whose centres lie within centre ± half.
	var i0 := clampi(int(ceil((centre.x - half.x + extent) / CELL - 0.5)), 0, size)
	var i1 := clampi(int(floor((centre.x + half.x + extent) / CELL - 0.5)) + 1, 0, size)
	var j0 := clampi(int(ceil((centre.y - half.y + extent) / CELL - 0.5)), 0, size)
	var j1 := clampi(int(floor((centre.y + half.y + extent) / CELL - 0.5)) + 1, 0, size)
	if i1 <= i0 or j1 <= j0:
		return Vector2i(0, 0)
	return Vector2i(sat[j1 * stride + i1] - sat[j0 * stride + i1] - sat[j1 * stride + i0] + sat[j0 * stride + i0], (i1 - i0) * (j1 - j0))


## Mean ground height of the good cells under the crater footprint.
func site_ground(centre: Vector2, crater: Vector2, fallback: float) -> float:
	var total := 0.0
	var count := 0
	var half := crater / 2
	for j in range(int(floor((centre.y - half.y + extent) / CELL)), int(ceil((centre.y + half.y + extent) / CELL))):
		for i in range(int(floor((centre.x - half.x + extent) / CELL)), int(ceil((centre.x + half.x + extent) / CELL))):
			if i < 0 or j < 0 or i >= size or j >= size:
				continue
			var index := j * size + i
			if site_bad[index] == 0:
				total += ground_y[index]
				count += 1
	return total / count if count > 0 else fallback


# ----------------------------------------------------------------- zones

static func rect_distance(point: Vector2, centre: Vector2, half: Vector2) -> float:
	var d := Vector2(maxf(absf(point.x - centre.x) - half.x, 0), maxf(absf(point.y - centre.y) - half.y, 0))
	return d.length()


## K zone discs (x, z, r) on eligible floor, fully inside the map, centres
## >= 2r apart, never touching the crater footprint + ramp grown 2 m. Never
## conditioned on player positions.
func pick_zones(seed_value: int, count: int, radius: float, crater_centre: Vector2, crater: Vector2) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var keep_out := crater / 2 + Vector2.ONE * (SITE_RAMP + ZONE_CRATER_MARGIN)
	var candidates := PackedVector2Array()
	var cells := maxi(size, int(round(extent * 2 / CELL)))
	for j in cells:
		for i in cells:
			var c := cell_center(i, j)
			if absf(c.x) > extent - radius or absf(c.y) > extent - radius:
				continue
			if baked and is_nan(floor_y[j * size + i]):
				continue
			if rect_distance(c, crater_centre, keep_out) <= radius:
				continue
			candidates.append(c)
	var zones := PackedFloat32Array()
	if candidates.is_empty():
		return zones
	var chosen: Array[Vector2] = []
	for attempt in 64 * maxi(count, 1):
		if chosen.size() >= mini(count, MAX_ZONES):
			break
		var c := candidates[rng.randi_range(0, candidates.size() - 1)]
		var spaced := true
		for other in chosen:
			if other.distance_to(c) < 2 * radius:
				spaced = false
				break
		if spaced:
			chosen.append(c)
	for c in chosen:
		zones.append_array([c.x, c.y, radius])
	return zones
