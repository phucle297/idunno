extends SceneTree

# T3k: an exposed rooftop standee next to a published Tornado lane must feel
# the Tornado (knockdown/throw or forced off the pad), indoor cover must still
# reduce pull, and the fairness defaults stay unchanged.
# Run: godot --headless --path . --script res://tests/test_tornado_rooftop.gd

const ManagerScript = preload("res://game/session/match_manager.gd")
const TornadoScript = preload("res://game/disasters/tornado.gd")

const SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const REQUIRED_HITS := 8
const PHYSICS_DT := 1.0 / 60.0
const PAD_CENTER := Vector3(-16.0, 4.855, -16.0)
const PAD_SIZE := Vector2(10.0, 8.0)
const OFF_PAD_MIN := 3.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_defaults()
	var hits := 0
	for fixture_seed: int in SEEDS:
		var result: Dictionary = await _run_fixture(fixture_seed)
		var hit := bool(result.knocked) or bool(result.thrown) or bool(result.off_pad_3s)
		if hit:
			hits += 1
		print("TORNADO_ROOFTOP_SEED seed=%d lane_offset=%.2f warning=%.2f min_dist=%.2f peak_hspeed=%.2f max_disp=%.2f knocked=%s thrown=%s off_pad_s=%.2f off_pad_3s=%s hp_loss=n/a hit=%s" % [
			fixture_seed, result.lane_offset, result.warning, result.min_dist, result.peak_hspeed, result.max_disp,
			result.knocked, result.thrown, result.off_pad_time, result.off_pad_3s, hit])
	print("TORNADO_ROOFTOP_FIXTURE hits=%d/%d required=%d" % [hits, SEEDS.size(), REQUIRED_HITS])
	_expect(hits >= REQUIRED_HITS, "Exposed rooftop standee must be hit in >= %d/%d seeds (got %d)" % [REQUIRED_HITS, SEEDS.size(), hits])
	await _check_cover()
	if failures.is_empty():
		print("TORNADO_ROOFTOP_OK checks=%d fixture=%d/%d" % [checks, hits, SEEDS.size()])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("TORNADO_ROOFTOP_FAILED failures=%d fixture=%d/%d" % [failures.size(), hits, SEEDS.size()])
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


func _make_world() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	_add_box(world, Vector3(120.0, 0.4, 120.0), Vector3(0.0, -0.2, 0.0))
	# Roof pad: top surface at PAD_CENTER.y.
	_add_box(world, Vector3(PAD_SIZE.x, 0.4, PAD_SIZE.y), PAD_CENTER - Vector3(0.0, 0.2, 0.0))
	var manager := ManagerScript.new()
	world.add_child(manager)
	var tornado := TornadoScript.new()
	tornado.set_process(false)
	world.add_child(tornado)
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
		"knocked": false, "thrown": false, "off_pad_time": 0.0, "off_pad_3s": false, "max_disp": 0.0}
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
	tornado.cleanup()
	world.queue_free()
	await process_frame


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
