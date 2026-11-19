extends SceneTree

# T3k: an exposed rooftop standee next to a published Tornado lane must feel
# the Tornado (knockdown/throw or forced off the pad), indoor cover must still
# reduce pull, and the fairness defaults stay unchanged.
# T3q: an exposed idle roof camper who stays in the core for lift_time is
# carried off the nearest lip (real ShopRoof / WarehouseRoof, >= 7/10 seeds
# pressured: off the pad onto lower ground and/or fall HP); covered, ground
# and pre-commit side-step standees are never carried.
# Run: godot --headless --path . --script res://tests/test_tornado_rooftop.gd

const ManagerScript = preload("res://game/session/match_manager.gd")
const TornadoScript = preload("res://game/disasters/tornado.gd")

const SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const REQUIRED_HITS := 8
const PHYSICS_DT := 1.0 / 60.0
const PAD_CENTER := Vector3(-16.0, 4.855, -16.0)
const PAD_SIZE := Vector2(10.0, 8.0)
const OFF_PAD_MIN := 3.0
const REAL_ROOF := {"toy_town": "ShopRoof", "toy_harbor": "WarehouseRoof"}
const REAL_INDOOR := {"toy_town": "Shop", "toy_harbor": "Warehouse"}
const REAL_REQUIRED := 7
const LOWER_GROUND_DROP := 1.0
# Fall HP needs main.gd's landed -> "Fall" path; all HP lost during a Tornado-
# only event (no other disaster runs) is that Tornado's carry/throw fall.
var real_summary: Array[String] = []
var has_carry_api := false

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_defaults()
	var probe := TornadoScript.new()
	has_carry_api = "carry_count" in probe
	probe.free()
	print("TORNADO_ROOFTOP_API carry_api=%s" % has_carry_api)
	var hits := 0
	for fixture_seed: int in SEEDS:
		var result: Dictionary = await _run_fixture(fixture_seed)
		var hit := bool(result.knocked) or bool(result.thrown) or bool(result.off_pad_3s)
		if hit:
			hits += 1
		print("TORNADO_ROOFTOP_SEED seed=%d lane_offset=%.2f warning=%.2f min_dist=%.2f peak_hspeed=%.2f max_disp=%.2f knocked=%s thrown=%s carried=%s off_pad_s=%.2f off_pad_3s=%s hp_loss=n/a hit=%s" % [
			fixture_seed, result.lane_offset, result.warning, result.min_dist, result.peak_hspeed, result.max_disp,
			result.knocked, result.thrown, result.carried, result.off_pad_time, result.off_pad_3s, hit])
	print("TORNADO_ROOFTOP_FIXTURE hits=%d/%d required=%d" % [hits, SEEDS.size(), REQUIRED_HITS])
	_expect(hits >= REQUIRED_HITS, "Exposed rooftop standee must be hit in >= %d/%d seeds (got %d)" % [REQUIRED_HITS, SEEDS.size(), hits])
	await _check_cover()
	await _check_ground_not_carried()
	await _check_side_step_escape()
	await _check_real_maps()
	if failures.is_empty():
		print("TORNADO_ROOFTOP_OK checks=%d fixture=%d/%d real=%s" % [checks, hits, SEEDS.size(), " ".join(real_summary)])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("TORNADO_ROOFTOP_FAILED failures=%d fixture=%d/%d real=%s" % [failures.size(), hits, SEEDS.size(), " ".join(real_summary)])
		quit(1)


func _check_defaults() -> void:
	var fresh := TornadoScript.new()
	_expect(is_equal_approx(fresh.warning_duration, 3.0), "warning_duration default must stay 3.0")
	_expect(is_equal_approx(fresh.influence_radius, 8.0), "influence_radius default must stay 8.0")
	_expect(is_equal_approx(fresh.core_radius, 2.0), "core_radius default must stay 2.0")
	_expect(is_equal_approx(fresh.travel_speed, 2.0), "travel_speed default must stay 2.0")
	_expect(is_equal_approx(fresh.pull_acceleration_max, 13.0), "pull_acceleration_max default must stay 13.0")
	_expect(is_equal_approx(fresh.player_speed_cap, 8.0), "player_speed_cap default must stay 8.0")
	_expect(is_equal_approx(fresh.prop_force_max, 220.0), "prop_force_max default must stay 220.0")
	_expect(is_equal_approx(fresh.lift_time, 0.75), "lift_time default must stay 0.75")
	_expect(is_equal_approx(fresh.throw_speed, 8.0), "throw_speed default must stay 8.0")
	_expect(is_equal_approx(fresh.cover_multiplier, 0.25), "cover_multiplier default must stay 0.25")
	fresh.free()


func _make_world(pad_size: Vector2 = PAD_SIZE) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	_add_box(world, Vector3(120.0, 0.4, 120.0), Vector3(0.0, -0.2, 0.0))
	# Roof pad: top surface at PAD_CENTER.y.
	_add_box(world, Vector3(pad_size.x, 0.4, pad_size.y), PAD_CENTER - Vector3(0.0, 0.2, 0.0))
	var manager := ManagerScript.new()
	world.add_child(manager)
	var tornado := TornadoScript.new()
	world.add_child(tornado)
	# T3q: disable _process after entering the tree (set before add_child is
	# re-enabled on ready, which made the fixture tick the Tornado twice).
	tornado.set_process(false)
	tornado.set_physics_process(false)
	tornado.configure(manager)
	return {"world": world, "manager": manager, "tornado": tornado}


func _run_fixture(fixture_seed: int) -> Dictionary:
	var setup := _make_world()
	var world: Node3D = setup.world
	var manager = setup.manager
	var tornado = setup.tornado
	var standee := _add_player(world, "RoofStandee", PAD_CENTER + Vector3(0.0, 0.05, 0.0))
	_expect(manager.register_player(1, standee.name), "Seed %d standee must register with match" % fixture_seed)
	_expect(manager.set_player_ready(1, true), "Seed %d standee must ready" % fixture_seed)
	_expect(tornado.register_player(1, standee), "Seed %d standee must register with Tornado" % fixture_seed)
	_expect(manager.start_match(), "Seed %d match must start" % fixture_seed)
	for frame in 30:
		await physics_frame
		standee.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
	_expect(_on_pad(standee.global_position), "Seed %d standee must settle on the pad" % fixture_seed)
	# Fixture lane: ground-level path whose line passes horizontally within
	# influence_radius (but outside the core) of the pad centre, like the
	# authored map lanes that pass 6-7.2 m from ShopRoof / WarehouseRoof.
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture_seed
	var angle := rng.randf_range(0.0, TAU)
	var lane_offset := rng.randf_range(tornado.core_radius + 1.0, tornado.influence_radius - 0.5)
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	var normal := Vector3(-direction.z, 0.0, direction.x)
	var pad_ground := Vector3(PAD_CENTER.x, 0.0, PAD_CENTER.z)
	var lane_mid := pad_ground + normal * lane_offset
	var lane_a := lane_mid - direction * 20.0
	var lane_b := lane_mid + direction * 20.0
	tornado.set_path_presets([[lane_a, lane_b], [lane_b, lane_a]])
	var warning := [-1.0]
	tornado.warning_started.connect(func(_start: Vector3, duration: float) -> void: warning[0] = duration)
	_expect(tornado.start_disaster(rng), "Seed %d Tornado must start from the fixture lane" % fixture_seed)
	_expect(is_equal_approx(warning[0], 3.0), "Seed %d published warning must be 3.0 s" % fixture_seed)
	var result := {"lane_offset": lane_offset, "warning": warning[0], "min_dist": INF, "peak_hspeed": 0.0,
		"knocked": false, "thrown": false, "carried": false, "off_pad_time": 0.0, "off_pad_3s": false, "max_disp": 0.0}
	var settled := standee.global_position
	var off_pad_run := 0.0
	var guard := 0
	while tornado.phase != TornadoScript.Phase.IDLE and guard < 60 * 60:
		guard += 1
		await physics_frame
		var throws_before: int = tornado.throw_count
		tornado.tick(PHYSICS_DT)
		standee.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
		if tornado.phase == TornadoScript.Phase.ACTIVE or tornado.phase == TornadoScript.Phase.IDLE:
			var offset: Vector3 = tornado.global_position - standee.global_position
			result.min_dist = minf(result.min_dist, Vector2(offset.x, offset.z).length())
		result.peak_hspeed = maxf(result.peak_hspeed, Vector2(standee.velocity.x, standee.velocity.z).length())
		var moved := standee.global_position - settled
		result.max_disp = maxf(result.max_disp, Vector2(moved.x, moved.z).length())
		if standee.is_knocked_down():
			result.knocked = true
		if tornado.throw_count > throws_before:
			result.thrown = true
		if has_carry_api and tornado.was_carried(1):
			result.carried = true
		if _on_pad(standee.global_position):
			off_pad_run = 0.0
		else:
			off_pad_run += PHYSICS_DT
			result.off_pad_time = maxf(result.off_pad_time, off_pad_run)
	# Forced off for >= 3 s: an off-pad episode that started at least 3 s
	# before the event ended counts (the standee never tries to climb back).
	result.off_pad_3s = result.off_pad_time >= OFF_PAD_MIN
	tornado.cleanup()
	world.queue_free()
	await process_frame
	return result


func _check_cover() -> void:
	var setup := _make_world()
	var world: Node3D = setup.world
	var manager = setup.manager
	var tornado = setup.tornado
	# Covered elevated standee (indoor mezzanine volume) and an exposed one at
	# the same 5 m distance from the funnel on the other side.
	var covered_pos := PAD_CENTER + Vector3(0.0, 0.05, 0.0)
	var exposed_pos := PAD_CENTER + Vector3(0.0, 0.05, 10.0)
	var covered := _add_player(world, "CoveredStandee", covered_pos)
	var exposed := _add_player(world, "ExposedStandee", exposed_pos)
	tornado.add_cover_volume(AABB(PAD_CENTER + Vector3(-PAD_SIZE.x / 2.0, -1.0, -PAD_SIZE.y / 2.0), Vector3(PAD_SIZE.x, 4.0, PAD_SIZE.y)))
	_expect(tornado.is_position_covered(covered.global_position), "Cover fixture must mark the indoor standee covered")
	_expect(not tornado.is_position_covered(exposed.global_position), "Cover fixture must leave the comparison standee exposed")
	for index in 2:
		var player: PartyPlayer = [covered, exposed][index]
		_expect(manager.register_player(index + 1, player.name), "Cover standee %d must register with match" % (index + 1))
		_expect(manager.set_player_ready(index + 1, true), "Cover standee %d must ready" % (index + 1))
	_expect(tornado.register_player(1, covered), "Covered standee must register with Tornado")
	_expect(manager.start_match(), "Cover match must start")
	var lane_a := Vector3(PAD_CENTER.x - 20.0, 0.0, PAD_CENTER.z + 5.0)
	var lane_b := Vector3(PAD_CENTER.x + 20.0, 0.0, PAD_CENTER.z + 5.0)
	tornado.set_path_presets([[lane_a, lane_b]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_expect(tornado.start_disaster(rng), "Cover Tornado must start")
	var unchanged: bool = tornado.start_position.is_equal_approx(Vector3(lane_a.x, 0.0, lane_a.z)) or tornado.start_position.is_equal_approx(Vector3(lane_b.x, 0.0, lane_b.z))
	_expect(unchanged, "A covered standee must not pull the Tornado lane onto itself")
	tornado.tick(tornado.warning_duration + 0.01)
	_expect(tornado.phase == TornadoScript.Phase.ACTIVE, "Cover Tornado must activate after 3.0 s")
	_expect(tornado.register_player(2, exposed), "Exposed comparison standee must register with Tornado")
	tornado.global_position = Vector3(PAD_CENTER.x, 0.0, PAD_CENTER.z + 5.0)
	covered.velocity = Vector3.ZERO
	exposed.velocity = Vector3.ZERO
	tornado._apply_forces(0.1)
	var covered_speed := covered.velocity.length()
	var exposed_speed := exposed.velocity.length()
	print("TORNADO_ROOFTOP_COVER covered_speed=%.3f exposed_speed=%.3f ratio=%.3f covered_knocked=%s lane_shifted=%s" % [
		covered_speed, exposed_speed, covered_speed / maxf(exposed_speed, 0.0001), covered.is_knocked_down(), not unchanged])
	_expect(exposed_speed > 0.0 and covered_speed <= exposed_speed * (tornado.cover_multiplier + 0.01), "Indoor cover must still reduce pull to the cover multiplier")
	_expect(not covered.is_knocked_down(), "A covered standee must not be knocked down by the outer pull")
	# T3q: a covered standee sitting in the core well past lift_time is never
	# carried (core effects need multiplier >= 1).
	tornado.global_position = Vector3(covered.global_position.x, 0.0, covered.global_position.z)
	for step in 20:
		tornado._apply_forces(0.1)
	var covered_carried: bool = has_carry_api and (tornado.was_carried(1) or tornado.is_carrying(1))
	print("TORNADO_ROOFTOP_COVER_CORE covered_in_core_s=2.0 covered_carried=%s covered_knocked=%s" % [covered_carried, covered.is_knocked_down()])
	_expect(has_carry_api, "Tornado must expose the T3q carry API (carry_count / was_carried / is_carrying)")
	_expect(not covered_carried, "A covered standee in the core must not be carried")
	_expect(not covered.is_knocked_down(), "A covered standee in the core must not be knocked down")
	tornado.cleanup()
	world.queue_free()
	await process_frame


# T3q: a ground standee (not on a roof) is never the bend target and never
# carried, even with the authored core crossing it for the whole lift_time.
func _check_ground_not_carried() -> void:
	var setup := _make_world()
	var world: Node3D = setup.world
	var manager = setup.manager
	var tornado = setup.tornado
	var ground_pos := Vector3(PAD_CENTER.x, 0.05, PAD_CENTER.z + 12.0)
	var ground := _add_player(world, "GroundStandee", ground_pos)
	_expect(manager.register_player(1, ground.name), "Ground standee must register with match")
	_expect(manager.set_player_ready(1, true), "Ground standee must ready")
	_expect(tornado.register_player(1, ground), "Ground standee must register with Tornado")
	_expect(manager.start_match(), "Ground match must start")
	for frame in 30:
		await physics_frame
		ground.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
	# Lane 1.5 m beside the ground standee (core crosses it) and close enough
	# to the roof pad that a bend would be possible if it were a roof camper.
	var lane_a := Vector3(ground_pos.x - 20.0, 0.0, ground_pos.z + 1.5)
	var lane_b := Vector3(ground_pos.x + 20.0, 0.0, ground_pos.z + 1.5)
	tornado.set_path_presets([[lane_a, lane_b]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_expect(tornado.start_disaster(rng), "Ground Tornado must start")
	var unchanged: bool = tornado.start_position.is_equal_approx(Vector3(lane_a.x, 0.0, lane_a.z)) or tornado.start_position.is_equal_approx(Vector3(lane_b.x, 0.0, lane_b.z))
	var core_time := 0.0
	var guard := 0
	while tornado.phase != TornadoScript.Phase.IDLE and guard < 60 * 40:
		guard += 1
		await physics_frame
		tornado.tick(PHYSICS_DT)
		ground.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
		if tornado.phase == TornadoScript.Phase.ACTIVE:
			var offset: Vector3 = tornado.global_position - ground.global_position
			if Vector2(offset.x, offset.z).length() <= tornado.core_radius:
				core_time += PHYSICS_DT
	var carried: bool = has_carry_api and tornado.was_carried(1)
	# Direct commit attempt on a grounded standee must also refuse.
	tornado.start_position = Vector3(lane_a.x, 0.0, lane_a.z)
	tornado.end_position = Vector3(lane_b.x, 0.0, lane_b.z)
	var direct_commit: bool = has_carry_api and tornado._commit_carry(1, ground)
	print("TORNADO_ROOFTOP_GROUND lane_shifted=%s core_s=%.2f throws=%d carry_count=%d carried=%s direct_commit=%s" % [
		not unchanged, core_time, tornado.throw_count, tornado.carry_count if has_carry_api else -1, carried, direct_commit])
	_expect(unchanged, "A ground standee must not bend the Tornado lane onto itself")
	_expect(not carried and not direct_commit, "A ground standee must never be roof-carried")
	tornado.cleanup()
	world.queue_free()
	await process_frame


# T3q: a roof standee who leaves the core before lift_time is not carried.
# (a) walks out of the published lane during the 3.0 s warning; (b) enters
# the core, then is moved out of it before lift_time (stand-in for a side-step;
# the core's knockdown blocks input, so (b) is a teleport).
func _check_side_step_escape() -> void:
	var pad := Vector2(18.0, 14.0)
	for variant in ["warning_walk", "pre_commit_exit"]:
		var setup := _make_world(pad)
		var world: Node3D = setup.world
		var manager = setup.manager
		var tornado = setup.tornado
		var standee := _add_player(world, "StepStandee", PAD_CENTER + Vector3(0.0, 0.05, 0.0))
		_expect(manager.register_player(1, standee.name), "%s standee must register" % variant)
		_expect(manager.set_player_ready(1, true), "%s standee must ready" % variant)
		_expect(tornado.register_player(1, standee), "%s standee must register with Tornado" % variant)
		_expect(manager.start_match(), "%s match must start" % variant)
		for frame in 30:
			await physics_frame
			standee.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
		# Lane along x through the pad centre (core crosses the idle standee).
		var lane_a := Vector3(PAD_CENTER.x - 24.0, 0.0, PAD_CENTER.z)
		var lane_b := Vector3(PAD_CENTER.x + 24.0, 0.0, PAD_CENTER.z)
		tornado.set_path_presets([[lane_a, lane_b]])
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		_expect(tornado.start_disaster(rng), "%s Tornado must start" % variant)
		var exit_exposure := -1.0
		var max_exposure_after_exit := 0.0
		var guard := 0
		var walk_frames := 0
		while tornado.phase != TornadoScript.Phase.IDLE and guard < 60 * 40:
			guard += 1
			await physics_frame
			tornado.tick(PHYSICS_DT)
			var input := Vector2.ZERO
			if variant == "warning_walk" and tornado.phase == TornadoScript.Phase.WARNING and walk_frames < 60:
				# Walk ~5 m (+z) out of the published 2 m core during the warning.
				input = Vector2(0.0, 1.0)
				walk_frames += 1
			standee.apply_movement_input(input, false, false, PHYSICS_DT)
			var exposure: float = float(tornado._core_exposure.get(1, 0.0))
			if variant == "pre_commit_exit" and exit_exposure < 0.0 and exposure > 0.3:
				exit_exposure = exposure
				standee.global_position = Vector3(standee.global_position.x, standee.global_position.y, PAD_CENTER.z + 6.0)
				standee.velocity = Vector3.ZERO
			elif exit_exposure >= 0.0 or variant == "warning_walk":
				max_exposure_after_exit = maxf(max_exposure_after_exit, exposure)
		var carried: bool = has_carry_api and tornado.was_carried(1)
		var on_pad := standee.global_position.y >= PAD_CENTER.y - 0.5 \
			and absf(standee.global_position.x - PAD_CENTER.x) <= pad.x / 2.0 \
			and absf(standee.global_position.z - PAD_CENTER.z) <= pad.y / 2.0
		print("TORNADO_ROOFTOP_SIDESTEP variant=%s exit_exposure=%.2f max_exposure_after=%.2f carried=%s thrown=%d end=(%.2f,%.2f,%.2f) on_pad=%s" % [
			variant, exit_exposure, max_exposure_after_exit, carried, tornado.throw_count,
			standee.global_position.x, standee.global_position.y, standee.global_position.z, on_pad])
		if variant == "pre_commit_exit":
			_expect(exit_exposure > 0.0 and exit_exposure < tornado.lift_time, "pre_commit_exit standee must enter the core before leaving it")
		_expect(max_exposure_after_exit < tornado.lift_time, "%s standee must never reach lift_time in the core" % variant)
		_expect(not carried, "%s standee must not be carried" % variant)
		_expect(on_pad, "%s standee must still be on the pad" % variant)
		tornado.cleanup()
		world.queue_free()
		await process_frame


# T3q acceptance on the real maps: idle exposed camper at the roof refuge
# centre, Tornado started by start_disaster(seed) with main.gd's presets,
# terrain check, cover volumes and surface height.
func _check_real_maps() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.disaster_director.set_physics_process(false)
	main.match_manager.set_process(false)
	var tornado = main.tornado
	tornado.set_process(false)
	tornado.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id: String in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var roof := _refuge(main, REAL_ROOF[map_id])
		var indoor := _refuge(main, REAL_INDOOR[map_id])
		print("TORNADO_REAL_MAP map=%s anchors_map=%s roof=%s roof_center=%s indoor=%s presets=%d registered=%s landed_connected=%s" % [
			map_id, str(main.map_anchors.get("map_id", "?")), REAL_ROOF[map_id], str(roof.get("center", "missing")),
			str(indoor.get("center", "missing")), tornado.path_presets.size(), tornado._players.has(1),
			player.landed.get_connections().size() > 0])
		_expect(not roof.is_empty(), "%s must hold the %s refuge" % [map_id, REAL_ROOF[map_id]])
		if roof.is_empty():
			continue
		if not tornado._players.has(1):
			tornado.register_player(1, player)
		var roof_feet: Vector3 = roof.center
		var pressured := 0
		for seed_value: int in SEEDS:
			var result: Dictionary = await _real_seed(main, tornado, player, roof_feet, seed_value)
			if bool(result.pressured):
				pressured += 1
			print("TORNADO_REAL_SEED map=%s seed=%d preset=%d lane_shift=%.2f lane_gap=%.2f min_dist=%.2f carried=%s thrown=%s off_pad_lower=%s end=(%.2f,%.2f,%.2f) hp_loss=%.1f pressured=%s" % [
				map_id, seed_value, result.preset, result.lane_shift, result.lane_gap, result.min_dist, result.carried, result.thrown,
				result.off_pad_lower, result.end.x, result.end.y, result.end.z, result.hp_loss, result.pressured])
		real_summary.append("%s:%d/%d" % [map_id, pressured, SEEDS.size()])
		print("TORNADO_REAL_PRESSURE map=%s roof=%s pressured=%d/%d required=%d" % [map_id, REAL_ROOF[map_id], pressured, SEEDS.size(), REAL_REQUIRED])
		_expect(pressured >= REAL_REQUIRED, "%s idle %s camper must be pressured in >= %d/%d seeds (got %d)" % [map_id, REAL_ROOF[map_id], REAL_REQUIRED, SEEDS.size(), pressured])
		# Covered indoor camper on the real map: not targeted, not carried.
		if not indoor.is_empty():
			var indoor_result: Dictionary = await _real_seed(main, tornado, player, indoor.center, SEEDS[0])
			var covered: bool = tornado.is_position_covered(indoor.center)
			print("TORNADO_REAL_COVERED map=%s indoor=%s covered=%s lane_shift=%.2f carried=%s off_pad_lower=%s hp_loss=%.1f" % [
				map_id, REAL_INDOOR[map_id], covered, indoor_result.lane_shift, indoor_result.carried, indoor_result.off_pad_lower, indoor_result.hp_loss])
			_expect(covered, "%s indoor refuge must be a cover volume" % map_id)
			_expect(indoor_result.lane_shift < 0.01, "%s covered indoor camper must not bend the lane" % map_id)
			_expect(not bool(indoor_result.carried), "%s covered indoor camper must not be carried" % map_id)
	main.match_manager.prepare_lobby()
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame


func _real_seed(main, tornado, player: PartyPlayer, feet: Vector3, seed_value: int) -> Dictionary:
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(feet)
	player.global_position = feet
	player.velocity = Vector3.ZERO
	for frame in 20:
		await physics_frame
		player.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
	var settled := player.global_position
	var hp_before: float = main.match_manager.get_health(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var started: bool = tornado.start_disaster(rng)
	var result := {"preset": tornado.path_preset_index, "lane_shift": 0.0, "min_dist": INF, "carried": false, "thrown": false,
		"off_pad_lower": false, "end": settled, "hp_loss": 0.0, "pressured": false}
	var lane_gap := INF
	if started:
		var authored: Array = tornado.path_presets[tornado.path_preset_index]
		result.lane_shift = _lane_distance(authored, tornado.start_position, tornado.end_position)
		lane_gap = _segment_gap(tornado.start_position, tornado.end_position, settled)
	result["lane_gap"] = lane_gap
	# A published lane whose footprint never comes within influence_radius of
	# the camper cannot touch them: skip simulating its full length.
	if started and lane_gap > tornado.influence_radius + 1.0:
		started = false
	var throws_before: int = tornado.throw_count
	var grounded_low := 0.0
	var guard := 0
	while started and tornado.phase != TornadoScript.Phase.IDLE and guard < 60 * 45:
		guard += 1
		await physics_frame
		tornado.tick(PHYSICS_DT)
		if not main.match_manager.is_player_alive(1):
			break
		player.apply_movement_input(Vector2.ZERO, false, false, PHYSICS_DT)
		if tornado.phase == TornadoScript.Phase.ACTIVE:
			var offset: Vector3 = tornado.global_position - player.global_position
			result.min_dist = minf(result.min_dist, Vector2(offset.x, offset.z).length())
		if tornado.throw_count > throws_before:
			result.thrown = true
		if has_carry_api and tornado.was_carried(1):
			result.carried = true
		if player.is_on_floor() and player.global_position.y < settled.y - LOWER_GROUND_DROP:
			grounded_low += PHYSICS_DT
			result.off_pad_lower = true
		# Done once the camper has landed low and settled, or the core is
		# far past and nothing is carrying them.
		var far: bool = result.min_dist < INF and Vector2(tornado.global_position.x - player.global_position.x, tornado.global_position.z - player.global_position.z).length() > tornado.influence_radius + 2.0 and result.min_dist < tornado.influence_radius
		var carrying: bool = has_carry_api and tornado.is_carrying(1)
		if grounded_low >= 0.5 or (far and not carrying and player.is_on_floor()):
			break
	await process_frame
	await process_frame
	result.end = player.global_position
	result.hp_loss = hp_before - float(main.match_manager.get_health(1))
	result.pressured = bool(result.off_pad_lower) or float(result.hp_loss) > 0.0
	tornado.cleanup()
	main.match_manager.prepare_lobby()
	return result


func _segment_gap(a: Vector3, b: Vector3, point: Vector3) -> float:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var p2 := Vector2(point.x, point.z)
	var lane := b2 - a2
	var t := clampf((p2 - a2).dot(lane) / maxf(lane.length_squared(), 0.0001), 0.0, 1.0)
	return p2.distance_to(a2 + lane * t)


func _lane_distance(authored: Array, start: Vector3, end: Vector3) -> float:
	var a: Vector3 = authored[0]
	var b: Vector3 = authored[1]
	var forward := Vector2(start.x - a.x, start.z - a.z).length() + Vector2(end.x - b.x, end.z - b.z).length()
	var backward := Vector2(start.x - b.x, start.z - b.z).length() + Vector2(end.x - a.x, end.z - a.z).length()
	return minf(forward, backward) * 0.5


func _refuge(main, refuge_name: String) -> Dictionary:
	for refuge: Dictionary in main.map_anchors.get("refuges", []):
		if str(refuge.get("name", "")) == refuge_name:
			return refuge
	return {}


func _on_pad(position: Vector3) -> bool:
	return position.y >= PAD_CENTER.y - 0.5 \
		and absf(position.x - PAD_CENTER.x) <= PAD_SIZE.x / 2.0 \
		and absf(position.z - PAD_CENTER.z) <= PAD_SIZE.y / 2.0


func _add_box(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	parent.add_child(body)


func _add_player(parent: Node3D, player_name: String, position: Vector3) -> PartyPlayer:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	player.name = player_name
	player.position = position
	parent.add_child(player)
	player.set_physics_process(false)
	return player


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
