extends SceneTree
## T37: where rockslide rocks really roll vs the T22 no-pickup lane shape.
## Both real maps, seeds 0..59: the seeded match is set up as in the T22 lane
## probe, the director forces a Rockslide (try_start_disaster), then every
## physics step the server's rocks (Rockslide._rocks) are read until cleanup.
## Each non-stopped rock's post-move center is measured against
## lane_extent_of(<lane that slide used>): along, lateral offset (height
## ignored) and lane kind (chosen / authored). Clients mirror the server, so
## only the server is recorded. Test-only: no game hook.
## excess = max(-along, along - length, offset - half_width, 0).
## PASS: max excess <= 0.15 m (one 9 m/s step at 60 Hz) with >= 50 slides per map.
## T37 A2: chosen lanes happen live when an alive player stands exposed >= 1.5 m
## up (roofs/decks reached by ramps; Rockslide.start_disaster ->
## _lane_through_exposed_roof). Per map, seeds 0..59 also force a chosen lane:
## a seeded random exposed standee anywhere on the map's raised surfaces
## (player 2, kept still) is retried until the slide would publish a chosen
## corridor, then the same recording runs. >= 50 chosen slides per map.

const SEEDS := 60
const MIN_SLIDES := 50
const MAX_EXCESS := 0.15
const STEP := 1.0 / 60
const MAX_STEPS := 900
const FAMILIES := {"powerup": 16, "toy": 32, "potato": 12}
const STANDEE_TRIES := 600

var failures: Array[String] = []
# Diagnostics only (defaults are the gate): --t37-seeds=N, --t37-await-every=K.
var seed_count := SEEDS
# Rocks move by move_and_collide against static map bodies, so the steps need
# not wait for real-time physics frames; awaiting every 30 steps keeps the run
# short (a 4-seed diag gave identical numbers with 1 and 0: evidence T37).
var await_every := 30


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--t37-seeds="):
			seed_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--t37-await-every="):
			await_every = maxi(int(arg.get_slice("=", 1)), 0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.disaster_director.set_physics_process(false)
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(2, 0.05, 7))
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	var manager: MatchManager = main.match_manager
	var director: DisasterDirector = main.disaster_director
	var rs: Rockslide = main.rockslide
	rs.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var stats := {"authored": _new_stats(), "chosen": _new_stats()}
		var slides := 0
		for seed_value in seed_count:
			var kind := await _measure_seed(main, manager, director, rs, seed_value, stats)
			if kind != "":
				slides += 1
		if slides < MIN_SLIDES:
			failures.append("%s only %d/%d slides started (need >= %d)" % [map_id, slides, SEEDS, MIN_SLIDES])
		var standee: PartyPlayer = main._player_nodes[2]
		var home := standee.global_position
		var configs := {}
		var chosen_slides := 0
		for seed_value in seed_count:
			var kind := await _measure_seed(main, manager, director, rs, seed_value, stats, standee, configs)
			if kind == "chosen":
				chosen_slides += 1
		standee.global_position = home
		standee.velocity = Vector3.ZERO
		if chosen_slides < MIN_SLIDES:
			failures.append("%s only %d/%d forced chosen slides (need >= %d)" % [map_id, chosen_slides, seed_count, MIN_SLIDES])
		var surfaces := {}
		for key: String in configs:
			surfaces[key.get_slice("|", 0)] = int(surfaces.get(key.get_slice("|", 0), 0)) + 1
		print("T37_CHOSEN_CONFIGS map=%s forced_slides=%d distinct_corridors=%d by_roof_y=%s" % [map_id, chosen_slides, configs.size(), surfaces])
		for kind: String in ["authored", "chosen"]:
			_report(map_id, kind, stats[kind])
		print("T37_PATHS_MAP map=%s slides=%d seeds=%d authored_high=%s authored_low=%s" % [map_id, slides, seed_count, rs.authored_lane.high, rs.authored_lane.low])
		rs.cleanup()
		rs.lane = rs.authored_lane.duplicate(true)
		manager.prepare_lobby()
	main.free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("ROCKSLIDE_PATHS_OK seeds=%d maps=2 max_excess=%.2f" % [SEEDS, MAX_EXCESS])
		quit(0)
	else:
		for failure in failures.slice(0, 40):
			push_error(failure)
		print("ROCKSLIDE_PATHS_FAILURES count=%d" % failures.size())
		quit(1)


func _new_stats() -> Dictionary:
	return {"slides": 0, "samples": 0, "lateral": 0.0, "lateral_seed": -1, "along": 0.0, "along_seed": -1,
		"worst": 0.0, "worst_seed": -1, "worst_detail": "", "end_gap": -INF, "side_gap": -INF, "stops": {"player": 0, "cover": 0, "end": 0, "none": 0}}


## One seeded match + one forced slide. Returns the lane kind used, or "".
## With `standee`, a seeded exposed standee is placed first so the slide uses a
## chosen corridor; returns "" (and records a failure) if none is found.
func _measure_seed(main, manager: MatchManager, director: DisasterDirector, rs: Rockslide, seed_value: int, stats: Dictionary,
		standee: PartyPlayer = null, configs: Dictionary = {}) -> String:
	director.cleanup()
	rs.cleanup()
	manager.prepare_lobby()
	for peer_id: int in manager.players:
		manager.set_player_ready(peer_id, true)
	if not manager.start_match():
		failures.append("%s seed %d match did not start" % [main.map_id, seed_value])
		return ""
	director.cleanup()
	rs.set_physics_process(false)
	# Seeded match as in the T22 lane probe: seeded placement round, seeded director.
	main.pickup_placement.begin_round(seed_value)
	for family: String in FAMILIES:
		for sequence in range(1, FAMILIES[family] + 1):
			main._place_pickup(StringName(family), sequence, seed_value)
	# Rockslide needs 90 s of match time and intensity 2 (120 s).
	manager.elapsed_time = 150.0
	if standee != null and not _place_chosen_standee(main, rs, standee, seed_value):
		failures.append("%s seed %d no exposed standee gives a chosen corridor in %d tries" % [main.map_id, seed_value, STANDEE_TRIES])
		return ""
	if not director.start_directing(seed_value, 0) or not director.try_start_disaster("Rockslide"):
		failures.append("%s seed %d rockslide did not start" % [main.map_id, seed_value])
		return ""
	var used: Dictionary = rs.lane.duplicate(true)
	var kind := "chosen" if used.get("chosen", false) else "authored"
	if standee != null:
		if kind != "chosen":
			failures.append("%s seed %d forced standee did not give a chosen slide" % [main.map_id, seed_value])
		var heading := rad_to_deg(atan2((used.low as Vector3).x - (used.high as Vector3).x, (used.low as Vector3).z - (used.high as Vector3).z))
		configs["%.2f|%.0f|%.1f,%.1f" % [float(used.get("roof_y", 0.0)), heading, (used.high as Vector3).x, (used.high as Vector3).z]] = true
	var extent := rs.lane_extent_of(used)
	var start: Vector3 = extent.start
	var forward: Vector3 = extent.forward
	var length := float(extent.length)
	var half := float(extent.half_width)
	var s: Dictionary = stats[kind]
	s.slides += 1
	var steps := 0
	while rs.is_active() and steps < MAX_STEPS:
		rs.tick(STEP)
		steps += 1
		if await_every > 0 and steps % await_every == 0:
			await physics_frame
		if not rs.is_active():
			break
		var all_stopped := rs._rocks.size() >= Rockslide.MAX_ROCKS
		for rock in rs._rocks:
			if rock.get_meta("stopped", false):
				continue
			all_stopped = false
			var rel := rock.position - start
			rel.y = 0
			var along := rel.dot(forward)
			var offset := (rel - forward * along).length()
			var lat_x := maxf(offset - half, 0.0)
			var along_x := maxf(maxf(-along, along - length), 0.0)
			s.samples += 1
			# Signed closest approach to each edge (negative = still inside).
			s.end_gap = maxf(s.end_gap, along - length)
			s.side_gap = maxf(s.side_gap, offset - half)
			if lat_x > s.lateral:
				s.lateral = lat_x
				s.lateral_seed = seed_value
			if along_x > s.along:
				s.along = along_x
				s.along_seed = seed_value
			if maxf(lat_x, along_x) > s.worst:
				s.worst = maxf(lat_x, along_x)
				s.worst_seed = seed_value
				s.worst_detail = "step=%d rock=%d pos=%s vel=%s along=%.3f offset=%.3f climbed=%s lane_high=%s lane_low=%s roof_y=%s" % [
					steps, rs._rocks.find(rock), rock.position, rock.velocity, along, offset, rock.get_meta("climbed", false),
					used.high, used.low, used.get("roof_y", "-")]
		# Every rock spawned and at rest: nothing else moves before cleanup.
		if all_stopped and rs.phase == Rockslide.Phase.ACTIVE:
			break
	for rock in rs._rocks:
		var reason := "none"
		if rock.get_meta("stopped", false):
			var rel := rock.position - start
			rel.y = 0
			var along := rel.dot(forward)
			reason = "end" if along > length - 0.5 or (rel - forward * along).length() > half - 0.1 else ("player" if rock.velocity != Vector3.ZERO else "cover")
		s.stops[reason] += 1
	rs.cleanup()
	director.cleanup()
	return kind


## Seeded random points on raised (>= 1.5 m), flat, open-sky surfaces anywhere
## on the map; keep the first one the live corridor search accepts.
func _place_chosen_standee(main, rs: Rockslide, standee: PartyPlayer, seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37000 + seed_value
	var half: float = main.get_map_half_extent()
	var space := rs.get_world_3d().direct_space_state
	var low_y := minf((rs.authored_lane.high as Vector3).y, (rs.authored_lane.low as Vector3).y)
	for attempt in STANDEE_TRIES:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -1, z), 1))
		if hit.is_empty() or float(hit.normal.y) < 0.9 or float(hit.position.y) - low_y < Rockslide.ROOF_TARGET_MIN_HEIGHT:
			continue
		standee.global_position = (hit.position as Vector3) + Vector3.UP * 0.05
		standee.velocity = Vector3.ZERO
		if not rs._lane_through_exposed_roof().is_empty():
			return true
	return false


func _report(map_id: String, kind: String, s: Dictionary) -> void:
	if int(s.slides) == 0:
		print("T37_PATHS map=%s kind=%s slides=0 N/A" % [map_id, kind])
		return
	print("T37_PATHS map=%s kind=%s slides=%d samples=%d max_lateral_excess=%.3f (seed %d) max_along_excess=%.3f (seed %d) worst=%.3f seed=%d max(along-length)=%.2f max(offset-half_width)=%.2f stops=%s" % [
		map_id, kind, s.slides, s.samples, s.lateral, s.lateral_seed, s.along, s.along_seed, s.worst, s.worst_seed,
		s.end_gap, s.side_gap, s.stops])
	if float(s.worst) > 0.0:
		print("T37_PATHS_WORST map=%s kind=%s seed=%d %s" % [map_id, kind, s.worst_seed, s.worst_detail])
	if int(s.samples) == 0:
		failures.append("%s %s: slides ran but no moving rock was sampled" % [map_id, kind])
	if float(s.worst) > MAX_EXCESS:
		failures.append("%s %s rock center %.3f m outside the lane shape (lateral %.3f seed %d, along %.3f seed %d; limit %.2f)" % [
			map_id, kind, s.worst, s.lateral, s.lateral_seed, s.along, s.along_seed, MAX_EXCESS])
