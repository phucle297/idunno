extends SceneTree
## T19: toy pickup kinds follow a seeded per-match shuffle bag. Pure, no map.

const SEEDS := 60
const KIND_COUNT := 16
## PickupPlacement.place(&"toy", slot) for seed 4242 on a fixed synthetic
## fixture, pinned on base ad072407 (pre-T19). The kind shuffle must not move them.
const PINNED := [Vector3(-13.6330, 0.0000, -1.5904), Vector3(5.0529, 0.0000, -2.8533), Vector3(-10.1968, 0.0000, 15.5760), Vector3(19.2199, 0.0000, -7.1480), Vector3(-16.4694, 0.0000, -4.0085), Vector3(-5.3448, 0.0000, 14.7050), Vector3(9.3019, 3.0000, 13.1958), Vector3(-2.4244, 0.0000, 0.3893), Vector3(13.9038, 3.0000, 10.5824), Vector3(0.1457, 0.0000, -19.7367), Vector3(3.0075, 0.0000, 14.6682), Vector3(13.0223, 0.0000, -10.7744), Vector3(-12.4229, 0.0000, -15.3645), Vector3(-10.6026, 0.0000, -7.3912), Vector3(-8.2931, 0.0000, -11.0415), Vector3(10.8027, 0.0000, 5.1954), Vector3(-2.7258, 0.0000, -16.1973), Vector3(-19.2257, 0.0000, 5.5374), Vector3(17.9473, 0.0000, 9.2178), Vector3(16.0968, 0.0000, -0.7594), Vector3(-6.7210, 0.0000, 6.3712)]

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(ToySabotage.KINDS.size() == KIND_COUNT, "catalog size known to this test")
	var declared: Array[String] = []
	for kind: String in ToySabotage.KINDS.keys():
		declared.append(kind)
	var toys := ToySabotage.new()
	var other := ToySabotage.new()
	# 1. Same seed -> identical sequence (slots 0-47), via the spawn path helper.
	for seed_value in [1, 77, 123456789]:
		var first := _sequence(toys, seed_value, 48)
		var again := _sequence(other, seed_value, 48)
		_expect(first == again, "seed %d replays identical kinds 0-47" % seed_value)
		_expect(first.slice(0, 16) == ToySabotage.kind_order(seed_value, 0), "seed %d slot kinds == kind_order pass 0" % seed_value)
	# 2. Distinctness over seeds 1-60.
	var orders := {}
	var slot0 := {}
	var declared_hits := 0
	var slot0_list: Array[String] = []
	for seed_value in range(1, SEEDS + 1):
		var order := ToySabotage.kind_order(seed_value, 0)
		orders[",".join(order)] = true
		slot0[order[0]] = int(slot0.get(order[0], 0)) + 1
		slot0_list.append(order[0])
		if order == declared:
			declared_hits += 1
		_expect(order != ToySabotage.kind_order(seed_value, 1), "seed %d pass 0 != pass 1" % seed_value)
	var max_slot0 := 0
	for kind: String in slot0:
		max_slot0 = maxi(max_slot0, int(slot0[kind]))
	_expect(orders.size() >= 55, "distinct first orders %d/%d >= 55" % [orders.size(), SEEDS])
	_expect(max_slot0 <= 10, "max slot-0 repeats %d <= 10" % max_slot0)
	_expect(declared_hits == 0, "declaration order seen %d times" % declared_hits)
	# 3. Bag: every 16-block is a permutation; 48 slots -> 3 of each.
	for seed_value in range(1, SEEDS + 1):
		var seq := _sequence(toys, seed_value, 48)
		var totals := {}
		for block in 3:
			var part := seq.slice(block * KIND_COUNT, (block + 1) * KIND_COUNT)
			var sorted_part := part.duplicate()
			sorted_part.sort()
			var sorted_declared := declared.duplicate()
			sorted_declared.sort()
			_expect(sorted_part == sorted_declared, "seed %d block %d is a permutation" % [seed_value, block])
			for kind: String in part:
				totals[kind] = int(totals.get(kind, 0)) + 1
		var all_three := totals.size() == KIND_COUNT
		for kind: String in totals:
			all_three = all_three and int(totals[kind]) == 3
		_expect(all_three, "seed %d: each kind 3x in 48 slots" % seed_value)
	# 4. Placement unaffected: pinned positions + the placer sees the same args.
	var placement := PickupPlacement.new()
	var zones: Array[AABB] = [AABB(Vector3(-20, 0, -20), Vector3(40, 1, 40)), AABB(Vector3(6, 3, 6), Vector3(8, 1, 8))]
	var no_fallback: Array[Vector3] = []
	placement.configure(zones, no_fallback, func(_point: Vector3, _ground: bool) -> bool: return true, func(point: Vector3) -> float: return 3.0 if (point.y >= 2.0 and point.x >= 6 and point.x <= 14 and point.z >= 6 and point.z <= 14) else 0.0)
	placement.begin_round(4242)
	var occupied := PackedVector3Array()
	for slot in PINNED.size():
		var point := placement.place(&"toy", slot, occupied)
		_expect(point.is_equal_approx(PINNED[slot]) or point.distance_to(PINNED[slot]) < 0.001, "placement slot %d unchanged (%s vs %s)" % [slot, point, PINNED[slot]])
		occupied.append(point)
		if occupied.size() > 6:
			occupied.remove_at(0)
	var calls: Array = []
	toys.anchors = [Vector3.ZERO]
	toys.placer = func(family: StringName, slot: int, seed_value: int) -> Vector3:
		calls.append([family, slot, seed_value])
		return Vector3(slot, 0, seed_value % 7)
	for slot in 20:
		toys.pickups.clear()
		toys._spawn(10.0, 4242, slot)
		_expect(toys.pickups.size() == 1 and toys.pickups[0].position == Vector3(slot, 0, 4242 % 7), "spawn slot %d keeps placer position" % slot)
		_expect(toys.pickups.size() == 1 and toys.pickups[0].kind == ToySabotage.kind_order(4242, floori(slot / 16.0))[slot % 16], "spawn slot %d kind from bag" % slot)
		_expect(calls.size() == slot + 1 and calls[slot] == [&"toy", slot, 4242], "placer args slot %d unchanged" % slot)
	toys.free()
	other.free()
	if failures.is_empty():
		print("TOY_KIND_ORDER_SLOT0 %s" % ",".join(slot0_list))
		print("TOY_KIND_ORDER_OK checks=%d seeds=%d distinct=%d max_slot0=%d declared=%d" % [checks, SEEDS, orders.size(), max_slot0, declared_hits])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _sequence(toys: ToySabotage, seed_value: int, count: int) -> Array[String]:
	var out: Array[String] = []
	for slot in count:
		out.append(toys._kind_for_spawn(slot, seed_value))
	return out


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
