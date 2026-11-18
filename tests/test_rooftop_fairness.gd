extends SceneTree

# T3h fairness lock: Flood and weather still respect roofs (new test only).
# Harder rooftop pressure must not be "solved" by flooding the high roof early
# or by punching Rain/Snow through roofs. Uses the shipped toy_town and
# toy_harbor geometry built by scenes/main.tscn; no product code is changed.
#
# DESIGN.md claims under test (quoted verbatim, line numbers at main ccc1f2f8):
#   L92  "Ground level is 0 m; intermediate platforms are 2.0–2.5 m; roofs are
#         approximately 4.5 m and 6 m."
#   L180 "Start with a warning of 6 s, rise toward 3.5 m over approximately
#         35 s, hold briefly, then drain during recovery. The 6 m roof remains
#         above initial flood, but other hazards make it unsafe."
#   L174 "Cover rules must match visible roof geometry."
# T3-plan.md fairness gate: "rain/snow do not penetrate roofs".
#
# Run: godot --headless --path . --script res://tests/test_rooftop_fairness.gd
# Prints ROOFTOP_FAIRNESS_OK and exits 0 on success; every case is logged.

const PEER_ID := 1
const DT := 1.0 / 60.0
const HIGH_ROOF_MIN := 4.5 # DESIGN L92: roofs approximately 4.5 m and 6 m
const SIX_M_ROOF_MIN := 5.5 # "approximately 6 m"
const SLAB_MIN_CLEARANCE := 2.0 # a cover slab at least 2 m above the floor
const GRID_STEP := 2

var checks := 0
var failures: Array[String] = []
var main: Node
var player: PartyPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	for hazard in [main.rain, main.snowfall, main.fire, main.flood]:
		hazard.set_process(false)
	player = main.get_node("Player")
	player.set_physics_process(false)
	var flood: Flood = main.flood
	# Production defaults must still be the DESIGN L180 numbers this lock is about.
	_expect(is_equal_approx(flood.warning_duration, 6.0) and is_equal_approx(flood.target_level, 3.5) and is_equal_approx(flood.rise_duration, 35.0),
		"Flood production defaults match DESIGN L180 (warning=%.2f target=%.2f rise=%.2f)" % [flood.warning_duration, flood.target_level, flood.rise_duration])
	_log("CASE flood_defaults warning=%.2f start=%.2f target=%.2f rise=%.2f hold=%.2f drain=%.2f grace=%.2f" % [flood.warning_duration, flood.start_level,
		flood.target_level, flood.rise_duration, flood.hold_duration, flood.drain_duration, flood.breathing_grace])
	var six_m_maps: Array[String] = []
	for map_id: String in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		if not await main.prepare_gameplay_map():
			failures.append("map %s failed to prepare" % map_id)
			continue
		await physics_frame
		await physics_frame
		_start_match()
		var roofs := _high_roofs(map_id)
		var tallest := 0.0
		for roof: Dictionary in roofs:
			tallest = maxf(tallest, float(roof.surface_y))
		if tallest >= SIX_M_ROOF_MIN:
			six_m_maps.append(map_id)
		_log("MAP %s high_roofs=%d tallest_roof=%.3f six_m_roof=%s" % [map_id, roofs.size(), tallest, str(tallest >= SIX_M_ROOF_MIN)])
		_expect(not roofs.is_empty(), "%s has authored high roofs (>= %.1f m)" % [map_id, HIGH_ROOF_MIN])
		for pattern in [Flood.RisePattern.STEADY, Flood.RisePattern.SURGE]:
			for roof: Dictionary in roofs:
				_flood_case(map_id, roof, pattern)
		_weather_case(map_id)
		# Non-vacuous control last (it can kill the player): ground gets flooded.
		_flood_ground_control(map_id)
	# DESIGN L180 names "the 6 m roof"; at least one shipped map must have it.
	_expect(not six_m_maps.is_empty(), "A ~6 m roof (>= %.1f m) exists on a shipped map (DESIGN L92/L180)" % SIX_M_ROOF_MIN)
	_log("SUMMARY six_m_roof_maps=%s" % str(six_m_maps))
	main.flood.cleanup()
	main.rain.cleanup()
	main.snowfall.cleanup()
	main.weather_surfaces.cleanup()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("ROOFTOP_FAIRNESS_OK checks=%d maps=2" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ROOFTOP_FAIRNESS_FAILED failures=%d checks=%d" % [failures.size(), checks])
		quit(1)


func _start_match() -> void:
	var manager: MatchManager = main.match_manager
	manager.prepare_lobby()
	manager.set_player_ready(PEER_ID, true)
	_expect(manager.start_match() or manager.state == MatchManager.MatchState.ACTIVE, "match starts")
	_expect(manager.state == MatchManager.MatchState.ACTIVE, "match is ACTIVE")
	manager.elapsed_time = 20.0
	main.disaster_director.cleanup()
	main.flood.cleanup()
	main.rain.cleanup()
	main.snowfall.cleanup()


# Every authored elevation refuge and elevation-route landing on the built map
# whose measured walkable top is a DESIGN roof (>= 4.5 m). Heights are measured
# on the real collision, not copied from the anchor table.
func _high_roofs(map_id: String) -> Array[Dictionary]:
	var anchors: Dictionary = main.map_anchors
	var result: Array[Dictionary] = []
	var seen: Array[Vector3] = []
	var candidates: Array[Dictionary] = []
	for refuge: Dictionary in anchors.refuges:
		var center: Vector3 = refuge.center
		var measured := float(main.get_map_support_height(center))
		_log("ANCHOR %s refuge %s kind=%s anchor_y=%.3f measured_y=%.3f above_peak_3.5=%s" % [map_id, refuge.name, refuge.kind, center.y, measured, str(measured > 3.5)])
		if String(refuge.kind) == "elevation":
			candidates.append({"name": "refuge:" + String(refuge.name), "point": center, "surface_y": measured})
	for route: Dictionary in anchors.elevation_routes:
		var high: Vector3 = route.high
		var measured := float(main.get_map_support_height(high))
		_log("ANCHOR %s route %s high_y=%.3f measured_y=%.3f" % [map_id, route.name, high.y, measured])
		candidates.append({"name": "route_top:" + String(route.name), "point": high, "surface_y": measured})
	for candidate: Dictionary in candidates:
		var point: Vector3 = candidate.point
		var surface_y := float(candidate.surface_y)
		# Must be real walkable collision at the authored height (within 0.35 m).
		if absf(surface_y - point.y) > 0.35 or surface_y < HIGH_ROOF_MIN:
			continue
		var feet := Vector3(point.x, surface_y, point.z)
		var duplicate := false
		for other in seen:
			if other.distance_to(feet) < 0.5:
				duplicate = true
		if duplicate:
			continue
		seen.append(feet)
		result.append({"name": candidate.name, "feet": feet, "surface_y": surface_y})
	return result


func _flood_case(map_id: String, roof: Dictionary, pattern: int) -> void:
	var flood: Flood = main.flood
	var manager: MatchManager = main.match_manager
	_start_match()
	var feet: Vector3 = roof.feet
	player.global_position = feet
	if not flood._players.has(PEER_ID):
		flood.register_player(PEER_ID, player)
	var hp_before := float(manager.players[PEER_ID].health)
	var head_y := float(player.get_head_sample_position().y)
	_expect(flood.start_warning(), "%s %s: Flood starts" % [map_id, roof.name])
	flood.rise_pattern = pattern
	var max_level := -INF
	var feet_flooded := false
	var head_submerged := false
	var max_submerged := 0.0
	var level_at_10s_rise := NAN
	var ticks := 0
	var limit := int((flood.warning_duration + flood.rise_duration + flood.hold_duration + flood.drain_duration + 5.0) / DT)
	var rising_elapsed := 0.0
	while flood.is_active() and ticks < limit:
		flood.tick(DT)
		ticks += 1
		player.global_position = feet # physics is off; the camper stays put
		if flood.phase == Flood.Phase.RISING:
			rising_elapsed += DT
			if is_nan(level_at_10s_rise) and rising_elapsed >= 10.0:
				level_at_10s_rise = flood.water_level
		max_level = maxf(max_level, flood.water_level)
		feet_flooded = feet_flooded or flood.is_position_flooded(feet)
		head_submerged = head_submerged or flood.water_level >= head_y
		max_submerged = maxf(max_submerged, flood.get_submerged_time(PEER_ID))
	var hp_after := float(manager.players[PEER_ID].health)
	var label := "%s %s pattern=%s" % [map_id, roof.name, "SURGE" if pattern == Flood.RisePattern.SURGE else "STEADY"]
	_log("CASE flood_roof %s feet_y=%.3f head_y=%.3f peak=%.3f clearance=%.3f feet_flooded=%s head_submerged=%s max_submerged_s=%.3f hp=%.1f->%.1f ticks=%d finished=%s" % [
		label, feet.y, head_y, max_level, feet.y - max_level, str(feet_flooded), str(head_submerged), max_submerged, hp_before, hp_after, ticks, str(not flood.is_active())])
	_expect(not flood.is_active(), "%s: Flood completes its cycle" % label)
	_expect(is_equal_approx(max_level, flood.target_level), "%s: initial Flood peaks exactly at 3.5 m (got %.3f)" % [label, max_level])
	_expect(feet.y > max_level, "%s: roof top %.3f stays above initial Flood peak %.3f" % [label, feet.y, max_level])
	_expect(not feet_flooded, "%s: roof is never reported flooded" % label)
	_expect(not head_submerged and max_submerged == 0.0, "%s: camper's head never submerged" % label)
	_expect(is_equal_approx(hp_before, hp_after) and manager.is_player_alive(PEER_ID), "%s: no Flood damage on the roof" % label)
	flood.cleanup()


func _flood_ground_control(map_id: String) -> void:
	var flood: Flood = main.flood
	var manager: MatchManager = main.match_manager
	_start_match()
	var feet: Vector3 = main.get_map_spawn_origin()
	feet.y = main.get_map_support_height(feet)
	player.global_position = feet
	var hp_before := float(manager.players[PEER_ID].health)
	_expect(flood.start_warning(), "%s ground control: Flood starts" % map_id)
	var flooded := false
	var ticks := 0
	while flood.is_active() and ticks < 4000 and manager.is_player_alive(PEER_ID):
		flood.tick(DT)
		ticks += 1
		player.global_position = feet
		flooded = flooded or flood.is_position_flooded(feet)
	var hp_after := float(manager.players[PEER_ID].health) if manager.is_player_alive(PEER_ID) else 0.0
	_log("CASE flood_ground_control %s feet=%s flooded=%s hp=%.1f->%.1f alive=%s ticks=%d" % [map_id, str(feet), str(flooded), hp_before, hp_after, str(manager.is_player_alive(PEER_ID)), ticks])
	_expect(flooded and hp_after < hp_before, "%s ground control: same Flood does flood and damage the ground (test is not vacuous)" % map_id)
	flood.cleanup()


# Every grid cell whose indoor/ground floor has a collision slab >= 2 m above it
# (measured downward from the sky) must be sheltered for weather, and every
# cell with nothing above its walkable top must be exposed.
func _weather_case(map_id: String) -> void:
	var weather: WeatherSurfaces = main.weather_surfaces
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var extent := int(main.get_map_half_extent())
	var covered: Array[Vector3] = []
	var open_tops: Array[Vector3] = []
	var covered_exposed: Array[Vector3] = []
	var open_sheltered: Array[Vector3] = []
	var skipped_solid := 0
	for x in range(-extent + 1, extent, GRID_STEP):
		for z in range(-extent + 1, extent, GRID_STEP):
			var top_y := float(main.get_map_surface_height(Vector3(x, 0, z)))
			var top := Vector3(x, top_y, z)
			var floor_point := Vector3(x, 0.05, z)
			floor_point.y = main.get_map_support_height(floor_point)
			var probe := PhysicsPointQueryParameters3D.new()
			probe.position = floor_point + Vector3.UP * 0.9
			probe.collision_mask = 1
			if not space.intersect_point(probe, 1).is_empty():
				skipped_solid += 1
				continue
			if top_y - floor_point.y >= SLAB_MIN_CLEARANCE:
				covered.append(floor_point)
				if weather.is_exposed(floor_point):
					covered_exposed.append(floor_point)
			elif absf(top_y - floor_point.y) < 0.05:
				open_tops.append(top)
				if not weather.is_exposed(top):
					open_sheltered.append(top)
	_log("CASE weather_cover_grid %s step=%dm covered_cells=%d covered_but_exposed=%d open_cells=%d open_but_sheltered=%d skipped_inside_solid=%d" % [
		map_id, GRID_STEP, covered.size(), covered_exposed.size(), open_tops.size(), open_sheltered.size(), skipped_solid])
	for point in covered_exposed.slice(0, 10):
		_log("  LEAK %s covered floor reported exposed at %s" % [map_id, str(point)])
	for point in open_sheltered.slice(0, 10):
		_log("  NOTE %s open top reported sheltered at %s" % [map_id, str(point)])
	_expect(covered.size() >= 10, "%s: grid finds roofed floor cells (%d)" % [map_id, covered.size()])
	_expect(covered_exposed.is_empty(), "%s: is_exposed is false under every roof slab (%d leaks)" % [map_id, covered_exposed.size()])
	_expect(open_sheltered.is_empty(), "%s: open tops stay exposed (%d sheltered)" % [map_id, open_sheltered.size()])
	# Named roofed shelters (authored refuges of kind shelter under a roof).
	var named_roofed := 0
	for refuge: Dictionary in main.map_anchors.refuges:
		if String(refuge.kind) != "shelter":
			continue
		var center: Vector3 = refuge.center
		var floor_point := Vector3(center.x, center.y + 0.05, center.z)
		floor_point.y = main.get_map_support_height(floor_point)
		var top_y := float(main.get_map_surface_height(center))
		var roofed := top_y - floor_point.y >= SLAB_MIN_CLEARANCE
		var exposed := weather.is_exposed(floor_point)
		_log("CASE shelter_cover %s %s floor_y=%.3f roof_top_y=%.3f roofed=%s is_exposed=%s" % [map_id, refuge.name, floor_point.y, top_y, str(roofed), str(exposed)])
		if roofed:
			named_roofed += 1
			_expect(not exposed, "%s %s: floor under roof slab is not exposed" % [map_id, refuge.name])
			for height in [0.5, 2.0, 6.0]:
				_expect(not weather.is_precipitation_visible(floor_point, height), "%s %s: no precipitation drawn indoors (h=%.1f)" % [map_id, refuge.name, height])
	_expect(named_roofed >= 1, "%s: at least one authored roofed shelter" % map_id)
	# Live Rain then Snow through main.tick_weather: no indoor wetting/accumulation.
	_start_match()
	weather.cleanup()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var roof_samples: Array[Vector3] = []
	for roof: Dictionary in _high_roofs(map_id):
		if weather.is_exposed(roof.feet):
			roof_samples.append(roof.feet)
	_expect(main.rain.start_disaster(rng), "%s: Rain starts" % map_id)
	main.rain.tick(main.rain.warning_duration)
	_expect(main.rain.phase == Precipitation.Phase.ACTIVE, "%s: Rain is ACTIVE" % map_id)
	for _step in 8:
		main.tick_weather(0.5)
	# Authored outdoor puddle discs (WeatherSurfaces._puddle_at, ~1.35 m radius)
	# can reach under a low bridge edge next to an exposed puddle centre. That
	# water is the outdoor puddle's, not rain through cover; such cells are
	# listed, kept to the puddle footprint, and never allowed under a roofed
	# shelter. Every other covered cell must stay completely dry.
	var wet_indoor := 0
	var puddle_edge := 0
	for point in covered:
		var state := weather.sample_surface(point)
		if state == Vector2.ZERO:
			continue
		var puddle: int = weather._puddle_at(point)
		var spot: Vector3 = weather._puddle_spots[puddle] if puddle >= 0 else Vector3.INF
		var outdoor_puddle := puddle >= 0 and state.x == 0.0 and weather.is_exposed(spot) and not _in_roofed_shelter(point)
		_log("  WET %s covered %s state=%s is_exposed=%s puddle=%d puddle_spot=%s puddle_spot_exposed=%s in_roofed_shelter=%s -> %s" % [map_id, str(point), str(state),
			str(weather.is_exposed(point)), puddle, str(spot), str(puddle >= 0 and weather.is_exposed(spot)), str(_in_roofed_shelter(point)),
			"outdoor puddle edge under non-roof cover (documented)" if outdoor_puddle else "LEAK"])
		if outdoor_puddle:
			puddle_edge += 1
		else:
			wet_indoor += 1
	var wet_roofs := roof_samples.filter(func(point: Vector3) -> bool: return weather.sample_surface(point).y >= 0.99).size()
	_log("CASE rain_indoor %s rain_s=4.0 covered_cells=%d covered_wet_leaks=%d covered_outdoor_puddle_edge=%d exposed_roofs=%d exposed_roofs_wet=%d" % [map_id, covered.size(), wet_indoor, puddle_edge, roof_samples.size(), wet_roofs])
	_expect(not roof_samples.is_empty() and wet_roofs == roof_samples.size(), "%s: Rain does wet the exposed roofs (control)" % map_id)
	_expect(wet_indoor == 0, "%s: Rain wets no roofed floor cell outside an exposed outdoor puddle (%d wet)" % [map_id, wet_indoor])
	_expect(puddle_edge <= 2, "%s: outdoor puddle overhang under cover stays a bounded edge (%d cells)" % [map_id, puddle_edge])
	main.rain.cleanup()
	weather.cleanup()
	_expect(main.snowfall.start_disaster(rng), "%s: Snowfall starts" % map_id)
	main.snowfall.tick(main.snowfall.warning_duration)
	_expect(main.snowfall.phase == Precipitation.Phase.ACTIVE, "%s: Snowfall is ACTIVE" % map_id)
	for _step in 40:
		main.tick_weather(0.5)
	var snowy_indoor := _count_bad(covered, func(state: Vector2) -> bool: return state.x > 0.0 or state.y > 0.0)
	var snowy_roofs := roof_samples.filter(func(point: Vector3) -> bool: return weather.sample_surface(point).x > 0.5).size()
	var deep_indoor := 0
	for point in covered:
		var surface: Dictionary = weather.movement_surface(point)
		if bool(surface.deep_snow) or bool(surface.ice):
			deep_indoor += 1
	_log("CASE snow_indoor %s snow_s=20.0 covered_cells=%d covered_snow_or_wet=%d covered_deep_or_ice=%d exposed_roofs=%d exposed_roofs_snowy=%d" % [
		map_id, covered.size(), snowy_indoor, deep_indoor, roof_samples.size(), snowy_roofs])
	_expect(snowy_roofs == roof_samples.size(), "%s: Snow accumulates on exposed roofs (control)" % map_id)
	_expect(snowy_indoor == 0 and deep_indoor == 0, "%s: Snow accumulates on no roofed floor cell (%d / %d)" % [map_id, snowy_indoor, deep_indoor])
	main.snowfall.cleanup()
	weather.cleanup()


func _in_roofed_shelter(point: Vector3) -> bool:
	# Inside the footprint of an authored roofed shelter (refuge kind "shelter").
	for refuge: Dictionary in main.map_anchors.refuges:
		if String(refuge.kind) != "shelter":
			continue
		var center: Vector3 = refuge.center
		var exits: Array = refuge.exits
		var half_z := 0.0
		for exit_point: Vector3 in exits:
			half_z = maxf(half_z, absf(exit_point.z - center.z))
		if absf(point.z - center.z) <= half_z and absf(point.x - center.x) <= half_z and absf(point.y - center.y) <= 1.0:
			return true
	return false


func _count_bad(points: Array[Vector3], is_bad: Callable) -> int:
	var count := 0
	for point in points:
		if is_bad.call(main.weather_surfaces.sample_surface(point)):
			count += 1
	return count


func _log(line: String) -> void:
	print("T3H " + line)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("T3H FAIL " + message)
