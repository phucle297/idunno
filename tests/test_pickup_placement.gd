extends SceneTree
## T17: shared pickup placement on the real maps. 50 seeds x 2 maps, ~8:00 of
## scheduled powerup + toy spawns through the real systems and Main's placer,
## plus a ground hot potato respawning through the same placer. Writes a
## per-seed JSON report (PICKUP_REPORT env, default user://).

const SEEDS := 50
const MATCH_SECONDS := 480.0
const STEP := 0.5
const POTATO_EVERY := 40.0

var checks := 0
var failures: Array[String] = []
var report: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(2, 0.05, 7))
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	var manager: MatchManager = main.match_manager
	var summary := {}
	for map_id in ["toy_town", "toy_harbor"]:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		for peer_id: int in manager.players:
			manager.set_player_ready(peer_id, true)
		_expect(manager.start_match(), "%s round starts" % map_id)
		var placement: PickupPlacement = main.pickup_placement
		_expect(placement.zones.size() >= 7 and placement.zones.size() == main.pickup_zone_names.size(), "%s has authored pickup zones" % map_id)
		var firsts: Array = []
		var counts := {"powerup": 0, "toy": 0, "potato": 0, "fallback": 0, "min_gap": INF, "zones": {}}
		for index in SEEDS:
			var seed_value := 1000 + index * 7919
			var events := _simulate(main, map_id, seed_value, true)
			for event: Dictionary in events:
				counts[event.family] += 1
				if float(event.min_gap) >= 0.0:
					counts.min_gap = minf(counts.min_gap, float(event.min_gap))
				counts.zones[event.zone] = int(counts.zones.get(event.zone, 0)) + 1
				if event.zone == "fallback":
					counts.fallback += 1
			firsts.append(_first_of(events, "toy"))
			if index < 5:
				var again := _simulate(main, map_id, seed_value, false)
				_expect(_positions(again) == _positions(events), "%s seed %d replays identical placement" % [map_id, seed_value])
		var differing := 0
		for index in SEEDS - 1:
			if not firsts[index].is_equal_approx(firsts[index + 1]):
				differing += 1
		_expect(differing >= ceili((SEEDS - 1) * 0.9), "%s different seeds differ at first spawn (%d/%d)" % [map_id, differing, SEEDS - 1])
		_check_hazards(main, map_id)
		manager.prepare_lobby()
		summary[map_id] = counts
		print("PICKUP_PLACEMENT_MAP map=%s seeds=%d powerups=%d toys=%d potatoes=%d fallback=%d min_gap=%.2f first_spawn_differs=%d/%d zones=%s" % [map_id, SEEDS, counts.powerup, counts.toy, counts.potato, counts.fallback, counts.min_gap, differing, SEEDS - 1, JSON.stringify(counts.zones)])
	var path := OS.get_environment("PICKUP_REPORT")
	if path.is_empty():
		path = "user://pickup_placement_report.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"min_gap_rule": PickupPlacement.PICKUP_MIN_GAP, "summary": summary, "spawns": report}, " "))
		file.close()
	main.free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("PICKUP_PLACEMENT_OK checks=%d seeds=%d maps=2 spawns=%d report=%s" % [checks, SEEDS, report.size(), ProjectSettings.globalize_path(path)])
		quit(0)
	else:
		for failure in failures.slice(0, 40):
			push_error(failure)
		print("PICKUP_PLACEMENT_FAILURES count=%d" % failures.size())
		quit(1)


func _simulate(main, map_id: String, seed_value: int, record: bool) -> Array:
	var manager: MatchManager = main.match_manager
	var powerups: MatchPowerups = main.powerups
	var toys: ToySabotage = main.toy_sabotage
	var potato: HotPotato = main.hot_potato
	main.disaster_director.last_seed = seed_value
	main.pickup_placement.begin_round(seed_value)
	powerups.begin_round()
	toys.begin_round()
	potato.reset()
	var events: Array = []
	var seen := {}
	var potato_parcel := 0
	var t := 0.0
	var next_potato := 3.0
	var scheduled := {"powerup": 0, "toy": 0}
	while t <= MATCH_SECONDS:
		manager.elapsed_time = t
		if t >= next_potato:
			next_potato += POTATO_EVERY
			potato.phase = HotPotato.Phase.IDLE
			potato_parcel += 1
			var point: Vector3 = main._place_pickup(&"potato", potato_parcel)
			if point.is_finite():
				potato.position_world = point
				potato.phase = HotPotato.Phase.GROUND
				events.append(_event(main, map_id, seed_value, t, "potato", point, record))
		var before_powerup := floori(t / MatchPowerups.SPAWN_INTERVAL)
		powerups.tick(manager, main._player_nodes, seed_value)
		toys.tick(0.0, seed_value)
		for family in ["powerup", "toy"]:
			var list: Array = powerups.pickups if family == "powerup" else toys.pickups
			for pickup: Dictionary in list:
				var key := "%s:%d" % [family, pickup.id]
				if seen.has(key):
					continue
				seen[key] = true
				scheduled[family] += 1
				events.append(_event(main, map_id, seed_value, t, family, pickup.position, record))
				if family == "powerup":
					_expect(int(pickup.kind) in [MatchPowerups.Kind.SPEED, MatchPowerups.Kind.JUMP], "powerup kind mix unchanged")
		t += STEP
	potato.reset()
	# Counts unchanged on an idle map: every scheduled slot spawns (16 powerup
	# slots at 30 s, 32 toy slots from 5 s every 15 s).
	_expect(scheduled.powerup == 16 and scheduled.toy == 32, "%s seed %d spawn counts unchanged (powerups=%d toys=%d)" % [map_id, seed_value, scheduled.powerup, scheduled.toy])
	return events


func _event(main, map_id: String, seed_value: int, t: float, family: String, point: Vector3, record: bool) -> Dictionary:
	var placement: PickupPlacement = main.pickup_placement
	var others := PackedVector3Array()
	var skipped_self := false
	for other in main.live_pickup_positions():
		if not skipped_self and other.is_equal_approx(point):
			skipped_self = true
			continue
		others.append(other)
	var min_gap := INF
	for other in others:
		min_gap = minf(min_gap, Vector2(point.x - other.x, point.z - other.z).length())
	var zone := placement.zone_index(point)
	var zone_name: String = main.pickup_zone_names[zone] if zone >= 0 else ("fallback" if placement.fallback.has(point) else "none")
	var surface := float(main.get_map_surface_height(point))
	var ray_ok := zone < 0 or absf(surface - placement.zones[zone].position.y) <= PickupPlacement.ZONE_HEIGHT_TOLERANCE
	var valid := bool(main._powerup_anchor_is_valid(point, true))
	_expect(PickupPlacement.gap_ok(point, others), "%s seed %d t=%.1f %s gap %.2f < 3.0 at %s" % [map_id, seed_value, t, family, min_gap, point])
	_expect(zone_name != "none" and ray_ok, "%s seed %d %s at %s lies on an authored zone floor or anchor" % [map_id, seed_value, family, point])
	_expect(valid, "%s seed %d %s at %s passes _powerup_anchor_is_valid" % [map_id, seed_value, family, point])
	var event := {"seed": seed_value, "map": map_id, "t": t, "family": family, "pos": [snappedf(point.x, 0.001), snappedf(point.y, 0.001), snappedf(point.z, 0.001)], "min_gap": snappedf(min_gap, 0.001) if is_finite(min_gap) else -1.0, "zone": zone_name, "valid": valid and ray_ok}
	if record:
		report.append(event)
	return event


func _first_of(events: Array, family: String) -> Vector3:
	for event: Dictionary in events:
		if event.family == family:
			return Vector3(event.pos[0], event.pos[1], event.pos[2])
	return Vector3.INF


func _positions(events: Array) -> Array:
	return events.map(func(event: Dictionary) -> String: return "%s@%.1f:%s" % [event.family, event.t, str(event.pos)])


func _check_hazards(main, map_id: String) -> void:
	var point: Vector3 = main.pickup_placement.place(&"hazard_probe", 1, PackedVector3Array())
	_expect(point.is_finite() and main._powerup_anchor_is_valid(point, true), "%s probe point is valid with no hazards" % map_id)
	var ufo: UFO = main.ufo
	ufo.phase = UFO.Phase.ACTIVE
	ufo.beam_position = point + Vector3(1.0, 0, 0)
	_expect(not main._powerup_anchor_is_valid(point, true) and main._powerup_anchor_is_valid(point, false), "%s no spawn inside an active UFO beam (live pickups untouched)" % map_id)
	ufo.phase = UFO.Phase.IDLE
	var bees: BeeSwarm = main.bee_swarm
	bees.phase = BeeSwarm.Phase.ACTIVE
	bees.swarm_position = point + Vector3(0, 0, 2.0)
	_expect(not main._powerup_anchor_is_valid(point, true), "%s no spawn beside an active bee swarm" % map_id)
	bees.phase = BeeSwarm.Phase.IDLE
	_expect(main._powerup_anchor_is_valid(point, true), "%s hazard probe restores" % map_id)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
