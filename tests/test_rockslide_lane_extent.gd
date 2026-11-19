extends SceneTree
## T22: a rockslide lane covers its whole path, start to end. Checks
## Rockslide.lane_extent_of / lane_contains on both real maps (authored lane
## incl. its run-out, plus a chosen corridor), then a 50-seed-per-map
## placement probe through Main's seeded placer: 0 pickups inside any lane.
## The probe's lane test is an independent rectangle oracle, not the API.

const SEEDS := 50
const FAMILIES := {"powerup": 16, "toy": 32, "potato": 12}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(2, 0.05, 7))
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	var manager: MatchManager = main.match_manager
	var rs: Rockslide = main.rockslide
	rs.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		for peer_id: int in manager.players:
			manager.set_player_ready(peer_id, true)
		_expect(manager.start_match(), "%s round starts" % map_id)
		main.disaster_director.cleanup()
		rs.set_physics_process(false)
		_check_authored(rs, map_id)
		_check_chosen(rs, map_id)
		_probe(main, rs, map_id)
		rs.cleanup()
		rs.lane = rs.authored_lane.duplicate(true)
		manager.prepare_lobby()
	main.free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("ROCKSLIDE_LANE_EXTENT_OK checks=%d seeds=%d maps=2" % [checks, SEEDS])
		quit(0)
	else:
		for failure in failures.slice(0, 40):
			push_error(failure)
		print("ROCKSLIDE_LANE_EXTENT_FAILURES count=%d checks=%d" % [failures.size(), checks])
		quit(1)


func _check_authored(rs: Rockslide, map_id: String) -> void:
	var lane: Dictionary = rs.authored_lane
	_expect(not lane.is_empty() and not lane.has("length"), "%s authored lane present (no length key)" % map_id)
	var high: Vector3 = lane.high
	var low: Vector3 = lane.low
	var run := Vector2(low.x - high.x, low.z - high.z).length()
	var extent := rs.lane_extent_of(lane)
	var forward: Vector3 = extent.forward
	var side := Vector3(forward.z, 0, -forward.x)
	_expect((extent.start as Vector3).is_equal_approx(high), "%s extent starts at high" % map_id)
	_expect(is_equal_approx(float(extent.length), run + Rockslide.AUTHORED_RUNOUT), "%s authored length = run %.2f + run-out %.1f (got %.2f)" % [map_id, run, Rockslide.AUTHORED_RUNOUT, float(extent.length)])
	_expect(is_equal_approx(float(extent.half_width), Rockslide.CORRIDOR_HALF_WIDTH) and is_equal_approx(Rockslide.CORRIDOR_HALF_WIDTH, 2.4), "%s half width 2.4" % map_id)
	_expect(is_zero_approx(forward.y) and forward.is_normalized(), "%s forward is flat and unit" % map_id)
	_expect(rs.authored_lane.keys().size() == 4 and not rs.authored_lane.has("length"), "%s lane dict unchanged (no new keys)" % map_id)
	var mid := (high + low) * 0.5
	var flat_low := Vector3(low.x, high.y, low.z)
	var inside := {"high": high, "mid": mid, "low": low, "run-out": flat_low + forward * (Rockslide.AUTHORED_RUNOUT - 0.5),
		"mid side 2.3": mid + side * 2.3, "mid 10 m up": mid + Vector3.UP * 10.0}
	for key: String in inside:
		_expect(rs.lane_contains(inside[key], 0.0), "%s authored lane contains %s %s" % [map_id, key, inside[key]])
		_expect(rs.lane_contains(inside[key], 1.1), "%s authored lane (margin 1.1) contains %s" % [map_id, key])
	var outside := {"before high": high - forward * 0.5, "past end": flat_low + forward * (Rockslide.AUTHORED_RUNOUT + 0.5),
		"mid side 2.6": mid + side * 2.6, "mid other side 2.6": mid - side * 2.6}
	for key: String in outside:
		_expect(not rs.lane_contains(outside[key], 0.0), "%s authored lane excludes %s %s" % [map_id, key, outside[key]])
	_expect(rs.lane_contains(flat_low + forward * (Rockslide.AUTHORED_RUNOUT + 1.0), 1.1), "%s margin grows the end" % map_id)
	_expect(not rs.lane_contains(flat_low + forward * (Rockslide.AUTHORED_RUNOUT + 1.2), 1.1), "%s just past end + margin excluded" % map_id)
	_expect(not rs.lane_contains(mid + side * (2.4 + 1.1 + 0.1), 1.1), "%s wider than 2.4 + margin excluded" % map_id)
	_expect(rs.lane_contains(mid + side * (2.4 + 1.0), 1.1), "%s inside 2.4 + margin" % map_id)
	_expect(not rs.is_active() and rs.lane_contains(mid, 0.0), "%s authored lane checked while idle" % map_id)


func _chosen_lane(center: Vector3) -> Dictionary:
	# Runs along +x (a different heading than the authored +z lanes).
	var high := center + Vector3(-6, 0, 0)
	var low := center + Vector3(6, 0, 0)
	return {"chosen": true, "high": high, "low": low, "roof_y": center.y, "length": 12.0}


func _check_chosen(rs: Rockslide, map_id: String) -> void:
	var center := Vector3(0, 0, 40) if map_id == "toy_town" else Vector3(-10, 0, 20)
	var chosen := _chosen_lane(center)
	_expect(not rs.lane_contains(center, 0.0), "%s chosen-lane fixture is away from the authored lane" % map_id)
	var extent := rs.lane_extent_of(chosen)
	_expect(is_equal_approx(float(extent.length), 12.0) and (extent.forward as Vector3).is_equal_approx(Vector3.RIGHT), "%s chosen extent uses lane.length, no run-out" % map_id)
	rs.lane = chosen
	_expect(not rs.lane_contains(center, 0.0), "%s chosen lane ignored while idle" % map_id)
	rs.phase = Rockslide.Phase.ACTIVE
	for x: float in [-6.0, 0.0, 6.0]:
		_expect(rs.lane_contains(center + Vector3(x, 0, 0), 0.0), "%s active chosen lane contains x%+.0f" % [map_id, x])
	_expect(rs.lane_contains(center + Vector3(0, 0, 2.3), 0.0), "%s chosen lane contains side 2.3" % map_id)
	_expect(not rs.lane_contains(center + Vector3(6.5, 0, 0), 0.0), "%s chosen lane ends at its length" % map_id)
	_expect(not rs.lane_contains(center + Vector3(7.2, 0, 0), 1.1), "%s chosen lane just past end + margin excluded" % map_id)
	_expect(not rs.lane_contains(center + Vector3(0, 0, 3.6), 1.1), "%s chosen lane wider than 2.4 + margin excluded" % map_id)
	_expect(rs.lane_contains(rs.authored_lane.high, 0.0), "%s authored lane still checked while a chosen lane runs" % map_id)
	rs.phase = Rockslide.Phase.IDLE
	rs.lane = rs.authored_lane.duplicate(true)


## Independent oracle: flat rectangle from high along high->low, length
## `length`, half width 2.4, height ignored. margin 0 = inside the lane.
func _in_rect(point: Vector3, high: Vector3, low: Vector3, length: float) -> bool:
	var forward := Vector3(low.x - high.x, 0, low.z - high.z).normalized()
	var rel := Vector3(point.x - high.x, 0, point.z - high.z)
	var along := rel.dot(forward)
	return along >= 0.0 and along <= length and (rel - forward * along).length() <= 2.4


func _probe(main, rs: Rockslide, map_id: String) -> void:
	var high: Vector3 = rs.authored_lane.high
	var low: Vector3 = rs.authored_lane.low
	var authored_len := Vector2(low.x - high.x, low.z - high.z).length() + 8.0
	# How much pickup-zone floor the authored lane overlaps (0.5 m grid).
	var overlap := 0
	for zone: AABB in main.pickup_placement.zones:
		var x := zone.position.x
		while x <= zone.end.x:
			var z := zone.position.z
			while z <= zone.end.z:
				if _in_rect(Vector3(x, 0, z), high, low, authored_len):
					overlap += 1
				z += 0.5
			x += 0.5
	var placed := 0
	var hits_authored := 0
	var hits_chosen := 0
	var chosen_placed := 0
	for index in SEEDS:
		var seed_value := 1000 + index * 7919
		main.pickup_placement.begin_round(seed_value)
		var first := Vector3.INF
		for family: String in FAMILIES:
			for sequence in range(1, FAMILIES[family] + 1):
				var point: Vector3 = main._place_pickup(StringName(family), sequence, seed_value)
				if not point.is_finite():
					continue
				placed += 1
				if not first.is_finite():
					first = point
				if _in_rect(point, high, low, authored_len):
					hits_authored += 1
					failures.append("%s seed %d %s#%d inside authored lane at %s" % [map_id, seed_value, family, sequence, point])
		# A chosen corridor through this seed's first pickup, while the slide runs.
		if first.is_finite():
			var chosen := _chosen_lane(first)
			rs.lane = chosen
			rs.phase = Rockslide.Phase.ACTIVE
			for sequence in range(1, 33):
				var p: Vector3 = main._place_pickup(&"toy", 500 + sequence, seed_value)
				if not p.is_finite():
					continue
				chosen_placed += 1
				if _in_rect(p, chosen.high, chosen.low, 12.0) or _in_rect(p, high, low, authored_len):
					hits_chosen += 1
					failures.append("%s seed %d toy#%d inside active lane at %s" % [map_id, seed_value, 500 + sequence, p])
			rs.phase = Rockslide.Phase.IDLE
			rs.lane = rs.authored_lane.duplicate(true)
	_expect(placed > SEEDS * 50, "%s probe placed pickups (%d)" % [map_id, placed])
	_expect(chosen_placed > SEEDS * 20, "%s probe placed pickups beside chosen lanes (%d)" % [map_id, chosen_placed])
	print("T22_LANE_PROBE map=%s seeds=%d placed=%d hits_authored=%d chosen_placed=%d hits_active_lane=%d zone_grid_points_in_authored_lane=%d authored_x=%.1f" % [map_id, SEEDS, placed, hits_authored, chosen_placed, hits_chosen, overlap, high.x])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
