class_name PickupPlacement
extends RefCounted
## T17: one shared, seeded placement pass for every ground pickup (powerups,
## toys and the hot potato). Main owns the instance, gathers the live
## occupancy from all three systems, and the systems only ask for a point.
## Server-only: peers receive the result through the existing snapshots.

## Horizontal centre-to-centre gap between any two live ground pickups.
## Collect radii are 1.1 (powerup) and 1.5 (toy/potato): 1.1 + 1.5 < 3.0, so
## no standing spot reaches two pickups at once.
const PICKUP_MIN_GAP := 3.0
const MAX_SAMPLES := 24
## The down ray must land this close to the authored zone floor; anything
## higher (prop, awning, roof over a street) or lower (hole) is rejected.
const ZONE_HEIGHT_TOLERANCE := 0.15

var zones: Array[AABB] = []
var fallback: Array[Vector3] = []
var is_valid: Callable
var ground_height: Callable
var match_seed := 0
var seeded := false
var _stream_seed := 0
var _zone_area_total := 0.0


func configure(new_zones: Array[AABB], new_fallback: Array[Vector3], valid: Callable, height: Callable) -> void:
	zones = new_zones.duplicate()
	fallback = new_fallback.duplicate()
	is_valid = valid
	ground_height = height
	_zone_area_total = 0.0
	for zone in zones:
		_zone_area_total += maxf(zone.size.x, 0.0) * maxf(zone.size.z, 0.0)


func begin_round(seed_value: int) -> void:
	match_seed = seed_value
	seeded = true
	_stream_seed = MatchClock.derive_seed(seed_value, &"pickup_placement")


## Returns a spawn point, or Vector3.INF when nothing passes (skip the spawn).
func place(family: StringName, sequence: int, occupied: PackedVector3Array) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_stream_seed, family, sequence])
	if _zone_area_total > 0.0:
		for sample in MAX_SAMPLES:
			var zone := _pick_zone(rng.randf() * _zone_area_total)
			var x := zone.position.x + rng.randf() * zone.size.x
			var z := zone.position.z + rng.randf() * zone.size.z
			var point := _surface_point(zone, x, z)
			if point.is_finite() and _accept(point, occupied):
				return point
	# Deterministic fallback: the authored anchors in a seeded order.
	var order: Array[Vector3] = fallback.duplicate()
	for index in range(order.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := order[index]
		order[index] = order[other]
		order[other] = held
	for point in order:
		if _accept(point, occupied):
			return point
	return Vector3.INF


## Index of the zone that holds `point` on its floor, or -1.
func zone_index(point: Vector3) -> int:
	for index in zones.size():
		var zone := zones[index]
		if point.x >= zone.position.x and point.x <= zone.end.x and point.z >= zone.position.z and point.z <= zone.end.z and absf(point.y - zone.position.y) <= ZONE_HEIGHT_TOLERANCE:
			return index
	return -1


static func gap_ok(point: Vector3, occupied: PackedVector3Array) -> bool:
	for other in occupied:
		if Vector2(point.x - other.x, point.z - other.z).length() < PICKUP_MIN_GAP:
			return false
	return true


func _pick_zone(weight: float) -> AABB:
	for zone in zones:
		weight -= zone.size.x * zone.size.z
		if weight <= 0.0:
			return zone
	return zones[zones.size() - 1]


func _surface_point(zone: AABB, x: float, z: float) -> Vector3:
	if not ground_height.is_valid():
		return Vector3.INF
	var y := float(ground_height.call(Vector3(x, zone.position.y, z)))
	if not is_finite(y) or absf(y - zone.position.y) > ZONE_HEIGHT_TOLERANCE:
		return Vector3.INF
	return Vector3(x, y, z)


func _accept(point: Vector3, occupied: PackedVector3Array) -> bool:
	return gap_ok(point, occupied) and is_valid.is_valid() and bool(is_valid.call(point, true))
