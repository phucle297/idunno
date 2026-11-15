extends SceneTree
# T3p: Volcano is a ground-only, whole-map lava flow (Owner 2026-11-15 19:10:
# "Only floor, but larger. Maybe can the whole map."). Real toy_town and
# toy_harbor maps, authored districts/anchors. Contract items:
#  (1) sampled in-bounds ground points are covered by full_coverage_time
#      (Town 33.9 s, Harbor 20.9 s) and NOT before the front reaches them;
#  (2) idle players on ShopRoof, WarehouseRoof and every other pad with
#      support >= 1.2 m take 0 Volcano damage over the whole event;
#  (3) a WALKING (4.5 m/s, no sprint) runner leaving at warning start reaches
#      high ground before the front from every spawn_origin / spawn_groups
#      spawn and from indoor Shop, Warehouse, GardenCafe ground, and survives
#      with 0 damage;
#  (4) idle ground players (outdoor and indoor) take damage after the front
#      arrives, and none before it;
#  (5) warning_remaining is 12.0 at every start, no damage during warning,
#      DPS 6.0, HOT_LIFETIME 60, SPREAD_RATE 3.0, SAFE_SUPPORT 1.2.
# The sim is stepped manually (volcano.tick + player.apply_movement_input at
# 60 Hz) so a full 72 s event costs ~1 s of wall time.

const STEP := 1.0 / 60
const Tuning = preload("res://game/player/player_tuning.gd")
const WARNING := 12.0
const MAPS := {
	"toy_town": {"extent": 72.0, "full": 33.9},
	"toy_harbor": {"extent": 32.0, "full": 20.9},
}

var checks := 0
var failures: Array[String] = []
var main
var volcano: Volcano
var player: PartyPlayer
var manager: MatchManager
var summary: Array[String] = []
var event_count := 0


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
	manager = main.match_manager
	volcano = main.volcano
	volcano.set_physics_process(false)
	player = main.get_node("Player")
	player.set_physics_process(false)
	_expect(is_equal_approx(volcano.warning_duration, 12.0), "warning_duration stays 12.0")
	_expect(is_equal_approx(Volcano.DAMAGE_PER_SECOND, 6.0), "DAMAGE_PER_SECOND stays 6.0")
	_expect(is_equal_approx(Volcano.HOT_LIFETIME, 60.0), "HOT_LIFETIME stays 60.0")
	_expect(is_equal_approx(Volcano.SPREAD_RATE, 3.0), "SPREAD_RATE 3.0 (slower than walk 4.5)")
	_expect(is_equal_approx(Volcano.SAFE_SUPPORT, 1.2), "SAFE_SUPPORT 1.2")
	_expect(is_equal_approx(Tuning.WALK_SPEED, 4.5), "Runner speed is walk 4.5 m/s (got %.2f)" % Tuning.WALK_SPEED)
	_expect(Volcano.SPREAD_RATE < Tuning.WALK_SPEED, "Front is slower than walking")
	for map_id: String in MAPS:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var extent: float = MAPS[map_id].extent
		volcano.set_map_extent(extent)
		_expect(absf(volcano.full_coverage_time() - float(MAPS[map_id].full)) < 0.05, "%s full coverage %.2f s ~= contract %.1f s" % [map_id, volcano.full_coverage_time(), MAPS[map_id].full])
		summary.append("%s vent=%s extent=%.0f full=%.2fs" % [map_id, volcano.district_center, extent, volcano.full_coverage_time()])
		await _pads(map_id)
		await _runners(map_id)
		await _idle_ground(map_id)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	for line in summary:
		print("VOLCANO_ROOFTOP ", line)
	if failures.is_empty():
		print("VOLCANO_ROOFTOP_OK checks=%d events=%d maps=2 warning=12.0 dps=6.0 spread=3.0 safe_support=1.2" % [checks, event_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("VOLCANO_ROOFTOP_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)


# ---------------------------------------------------------------- events

func _begin(at: Vector3, label: String) -> bool:
	manager.prepare_lobby()
	manager.set_player_ready(1, true)
	manager.start_match()
	player.reset_for_match(at + Vector3.UP * 0.05)
	player.set_camera_yaw(0.0)
	for step in 20:
		player.apply_movement_input(Vector2.ZERO, false, false, STEP)
		await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + event_count
	event_count += 1
	var started := volcano.start_disaster(rng)
	_expect(started, "%s: volcano starts" % label)
	_expect(volcano.warning_remaining == 12.0, "%s: warning_remaining is 12.0 at start (got %f)" % [label, volcano.warning_remaining])
	return started


func _end() -> void:
	volcano.cleanup()
	main._reset_sandbox()
	manager.prepare_lobby()
	await physics_frame


func _frame(_t: float, input: Vector2, jump := false) -> void:
	player.apply_movement_input(input, false, jump, STEP)
	volcano.tick(STEP)


func _support(feet: Vector3) -> float:
	return float(main.get_map_support_height(feet))


func _top_surface(x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -5, z), 1)
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else -INF


func _hp() -> float:
	return manager.get_health(1)


# ---------------------------------------------------------- (1) + (2) pads

func _pad_points(map_id: String) -> Array:
	var pads: Array = []
	for refuge: Dictionary in main.map_anchors.refuges:
		if refuge.kind == "elevation":
			pads.append([str(refuge.name), refuge.center])
	if map_id == "toy_town":
		pads.append(["TownHallIndoor", Vector3(0, 2, -45)])
		pads.append(["WestTerrace", Vector3(-35, 1.25, -3)])
		pads.append(["EastTerrace", Vector3(35, 1.75, -3)])
		pads.append(["CivicTerrace", Vector3(-14, 2, -42)])
	return pads


func _pads(map_id: String) -> void:
	var first := true
	for pad: Array in _pad_points(map_id):
		var label := "%s/%s" % [map_id, pad[0]]
		var at: Vector3 = pad[1]
		if not await _begin(at, label):
			await _end()
			continue
		var feet := player.global_position
		var support := _support(feet)
		_expect(player.is_on_floor() and support >= Volcano.SAFE_SUPPORT, "%s: standee grounded on pad >= 1.2 m (feet=%s support=%.2f)" % [label, feet, support])
		var ground: Array = _ground_samples(map_id) if first else []
		var t := 0.0
		var early_uncovered := 0
		var early_checked := false
		var covered_at_full := -1
		while volcano.is_active() and t < WARNING + Volcano.HOT_LIFETIME + 1.0:
			_frame(t, Vector2.ZERO)
			t += STEP
			if int(round(t / STEP)) % 60 == 0:
				await physics_frame
			if first and not early_checked and t >= WARNING + volcano.full_coverage_time() * 0.5:
				early_checked = true
				for point: Vector3 in ground:
					if volcano.flow_arrival_time(point) > volcano.flow_elapsed + 0.5:
						_expect(not volcano.flow_covers(point), "%s: point %s not covered before front arrives" % [label, point])
						early_uncovered += 1
			if first and covered_at_full < 0 and t >= WARNING + float(MAPS[map_id].full):
				covered_at_full = 0
				for point: Vector3 in ground:
					if volcano.flow_covers(point):
						covered_at_full += 1
				_expect(covered_at_full == ground.size(), "%s: all %d sampled ground points covered at %.1f s (got %d)" % [label, ground.size(), MAPS[map_id].full, covered_at_full])
		var lost := 100.0 - _hp()
		_expect(lost == 0.0, "%s: elevated pad takes 0 volcano damage (lost %.2f)" % [label, lost])
		_expect(not volcano.is_active(), "%s: event ran its full course (t=%.1f)" % [label, t])
		summary.append("pad %s support=%.2f lost=%.1f event_s=%.1f" % [label, support, lost, t])
		if first:
			summary.append("coverage %s ground_samples=%d covered_at_%.1fs=%d still_uncovered_at_half=%d" % [map_id, ground.size(), MAPS[map_id].full, covered_at_full, early_uncovered])
			_expect(ground.size() >= 50 and early_uncovered > 0, "%s: coverage sample is meaningful (samples=%d, uncovered at half=%d)" % [map_id, ground.size(), early_uncovered])
		first = false
		await _end()


func _ground_samples(map_id: String) -> Array:
	# Every in-bounds grid point whose top surface is floor level (< 1.2 m),
	# including the far corners.
	var extent: float = MAPS[map_id].extent
	var points: Array = []
	var spacing := 6.0 if extent > 40 else 4.0
	var x := -extent + 0.5
	while x <= extent:
		var z := -extent + 0.5
		while z <= extent:
			var top := _top_surface(x, z)
			if top > -1.0 and top < Volcano.SAFE_SUPPORT:
				points.append(Vector3(x, top, z))
			z += spacing
		x += spacing
	for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var cx: float = corner.x * (extent - 0.5)
		var cz: float = corner.y * (extent - 0.5)
		var top := _top_surface(cx, cz)
		if top > -1.0 and top < Volcano.SAFE_SUPPORT:
			points.append(Vector3(cx, top, cz))
	return points


# ------------------------------------------------------------- (3) runners

func _route(name: String) -> Dictionary:
	for route: Dictionary in main.map_anchors.elevation_routes:
		if route.name == name:
			return route
	return {}


func _runner_paths(map_id: String) -> Array:
	var paths: Array = []
	var anchors: Dictionary = main.map_anchors
	if map_id == "toy_town":
		var park := _route("ParkRamp")
		paths.append(["spawn_origin", anchors.spawn_origin, [Vector3(15, 0.05, -1), park.low, park.high, Vector3(15, 2.2, 13)]])
		var garage := _route("GarageRamp")
		paths.append(["indoor_Shop", Vector3(-16, 0.05, -13), [Vector3(-16, 0.05, -6.0), Vector3(-15, 0.05, -4), garage.low, garage.high, Vector3(-15, 2.575, 13)]])
		var west := _route("WestTerraceStairs")
		paths.append(["indoor_GardenCafe", Vector3(-18, 0.05, 44), [Vector3(-18, 0.05, 39.2), Vector3(-21.0, 0.05, 37.9), Vector3(-30, 0.05, 37.6), west.low, west.high, Vector3(-34.5, 1.25, 27)]])
	else:
		var crane := _route("CraneRamp")
		paths.append(["spawn_origin", anchors.spawn_origin, [crane.low, crane.high, Vector3(0, 4.855, -1)]])
		var roof := _route("WarehouseRoofRamp")
		paths.append(["indoor_Warehouse", Vector3(0, 0.05, -18), [Vector3(0, 0.05, -24.6), Vector3(2.7, 0.05, -25.6), Vector3(2.7, 0.05, -30.6), Vector3(0, 0.05, -30.6), roof.low, roof.high, Vector3(0, 4.855, -20)]])
	for group: Dictionary in anchors.spawn_groups:
		var route := _route(str(group.route))
		var waypoints: Array = group.waypoints.duplicate()
		waypoints.append(route.low)
		waypoints.append(route.high)
		var low: Vector3 = route.low
		var high: Vector3 = route.high
		var run := Vector3(high.x - low.x, 0, high.z - low.z).normalized()
		waypoints.append(high + run * 2.0)
		paths.append(["spawn_group_" + str(group.name), group.spawn, waypoints])
	return paths


func _runners(map_id: String) -> void:
	for entry: Array in _runner_paths(map_id):
		var label := "%s/runner/%s" % [map_id, entry[0]]
		var start: Vector3 = entry[1]
		var path: Array = entry[2]
		if not await _begin(start, label):
			await _end()
			continue
		var start_support := _support(player.global_position)
		_expect(player.is_on_floor() and start_support < Volcano.SAFE_SUPPORT, "%s: starts on floor-level ground (support %.2f)" % [label, start_support])
		var index := 0
		var t := 0.0
		var t_safe := -1.0
		var min_margin := INF
		var walked := 0.0
		var hops := 0
		var check := player.global_position
		var previous := player.global_position
		var frame := 0
		while volcano.is_active() and t < WARNING + Volcano.HOT_LIFETIME + 1.0 and manager.is_player_alive(1):
			var feet := player.global_position
			var input := Vector2.ZERO
			if index < path.size():
				var target: Vector3 = path[index]
				var delta := Vector2(target.x - feet.x, target.z - feet.z)
				if delta.length() < 0.6:
					index += 1
				if index < path.size():
					target = path[index]
					input = Vector2(target.x - feet.x, target.z - feet.z).normalized()
			var jump := false
			if frame % 30 == 0 and input != Vector2.ZERO:
				if frame > 0 and Vector2(feet.x - check.x, feet.z - check.z).length() < 0.3:
					jump = true
					hops += 1
				check = feet
			_frame(t, input, jump)
			t += STEP
			frame += 1
			if frame % 60 == 0:
				await physics_frame
			feet = player.global_position
			walked += Vector2(feet.x - previous.x, feet.z - previous.z).length()
			previous = feet
			if player.is_on_floor():
				var support := _support(feet)
				if support >= Volcano.SAFE_SUPPORT:
					if t_safe < 0:
						t_safe = t
				else:
					# Margin between this ground contact and the front's arrival.
					min_margin = minf(min_margin, WARNING + volcano.flow_arrival_time(feet) - t)
		var lost := 100.0 - _hp()
		var end := player.global_position
		var end_support := _support(end)
		_expect(index >= path.size(), "%s: runner completed its route (waypoint %d/%d, at %s)" % [label, index, path.size(), end])
		_expect(t_safe >= 0.0 and t_safe < WARNING + 12.0, "%s: reached >= 1.2 m support (t_safe=%.2f)" % [label, t_safe])
		_expect(min_margin > 0.0, "%s: every ground contact was ahead of the front (min margin %.2f s)" % [label, min_margin])
		_expect(manager.is_player_alive(1) and lost == 0.0, "%s: runner survives with 0 damage (lost %.2f)" % [label, lost])
		_expect(end_support >= Volcano.SAFE_SUPPORT, "%s: runner ends on high ground (support %.2f at %s)" % [label, end_support, end])
		summary.append("runner %s start=%s t_safe=%.2fs walked=%.1fm min_margin=%.2fs hops=%d lost=%.1f end_support=%.2f" % [label, start, t_safe, walked, min_margin, hops, lost, end_support])
		await _end()


# --------------------------------------------------------- (4) idle ground

func _idle_points(map_id: String) -> Array:
	if map_id == "toy_town":
		return [["spawn_origin", main.map_anchors.spawn_origin], ["indoor_Shop", Vector3(-16, 0.05, -13)],
			["indoor_Hall", Vector3(16, 0.05, -13)], ["indoor_GardenCafe", Vector3(-18, 0.05, 44)],
			["street_far_south", Vector3(0, 0.05, 60)], ["outer_walk_corner", Vector3(-66, 0.1, -66)]]
	return [["spawn_origin", main.map_anchors.spawn_origin], ["indoor_Warehouse", Vector3(0, 0.05, -18)],
		["yard_far_corner", Vector3(28, 0.05, -28)]]


func _idle_ground(map_id: String) -> void:
	for entry: Array in _idle_points(map_id):
		var label := "%s/idle/%s" % [map_id, entry[0]]
		var at: Vector3 = entry[1]
		if not await _begin(at, label):
			await _end()
			continue
		var feet := player.global_position
		var support := _support(feet)
		_expect(player.is_on_floor() and support < Volcano.SAFE_SUPPORT, "%s: idle standee on floor-level ground (support %.2f)" % [label, support])
		var arrival := WARNING + volcano.flow_arrival_time(feet)
		var in_vent := absf(feet.x - volcano.district_center.x) <= volcano.district_size.x / 2 and absf(feet.z - volcano.district_center.z) <= volcano.district_size.y / 2
		var t := 0.0
		var hp_warning := -1.0
		var warning_frames := 0
		var hp_before_front := -1.0
		while t < maxf(arrival, WARNING) + 2.0 and manager.is_player_alive(1):
			_frame(t, Vector2.ZERO)
			t += STEP
			if int(round(t / STEP)) % 60 == 0:
				await physics_frame
			if volcano.phase == Volcano.Phase.WARNING:
				hp_warning = _hp()
				warning_frames += 1
			if hp_before_front < 0 and t >= arrival - 0.1:
				hp_before_front = _hp()
		var lost := 100.0 - _hp()
		# HP at the last frame that was still in WARNING (~12 s of frames).
		_expect(warning_frames >= int(WARNING / STEP) - 2 and hp_warning == 100.0, "%s: no damage during the 12 s warning (hp %.2f over %d frames)" % [label, hp_warning, warning_frames])
		if not in_vent:
			_expect(hp_before_front == 100.0, "%s: no damage before the front arrives at %.2f s (hp %.2f)" % [label, arrival, hp_before_front])
		_expect(lost > 0.0, "%s: idle ground player takes damage after front arrives (lost %.2f)" % [label, lost])
		summary.append("idle %s feet=%s support=%.2f front_at=%.2fs warning_hp=%.1f hp_at_front=%.1f lost=%.1f in_vent=%s" % [label, feet, support, arrival, hp_warning, hp_before_front, lost, in_vent])
		await _end()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
