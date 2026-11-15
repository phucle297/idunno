extends SceneTree

# T2 run+jump physics regression (games/idunno acceptance T2.1-T2.6).
# Hard pass criteria run at the shipping 60 Hz tick (Owner, 2026-11-14).
# 30 Hz and 144 Hz are measured and printed as T2_INFO only, never asserted.
# Drives PartyPlayer.apply_movement_input on a fixed physics tick. The tick is
# changed with Engine.physics_ticks_per_second and the controller runs inside
# a physics frame, so move_and_slide and the controller share the same delta.

const Tuning = preload("res://game/player/player_tuning.gd")
const RATES: Array[int] = [30, 60, 144]
const ASSERTED_RATE := 60
const APEX_MIN := 1.25
const APEX_MAX := 1.45
const APEX_PAIR_DELTA := 0.05
const RATE_TOLERANCE := 0.05
const FORWARD := Vector2(1.0, 0.0)

const LANE_FLAT := 0.0
const LANE_LEDGE := 20.0
const LANE_STEP_30 := 40.0
const LANE_STEP_35 := 55.0
const LANE_TILES := 70.0
const LANE_WALL := 90.0
const LANE_CEILING := 110.0
const LANE_SWEEP_BASE := 1000.0 # straight lips: placement * 100 + height index * 10
const LANE_ANGLED := 2000.0 # wide lips for oblique approaches: placement * 100
const LANE_STAIRS := 3000.0 # placement * 20
const LANE_TALL_BASE := 560.0 # lanes 50 m apart (40 m wide)
const LANE_RAMP_BASE := 700.0
const SWEEP_HEIGHTS: Array[float] = [0.10, 0.15, 0.165, 0.20, 0.222, 0.25, 0.28, 0.30]
const TALL_HEIGHTS: Array[float] = [0.32, 0.35]
const SWEEP_OFFSETS := 12 # start positions 1 cm apart (covers a full sprint tick, 0.108 m)
# World placements of every probe fixture (face x shift, lane z shift): results
# of contact queries depend on world coordinates, so one placement is not enough.
const PLACEMENTS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.37, 2.13), Vector2(-1.613, -3.271), Vector2(7.049, 0.5)]
const APPROACH_ANGLES: Array[float] = [0.0, 15.0, 30.0, 45.0, 60.0, 75.0]
const ANGLED_HEIGHTS: Array[float] = [0.222, 0.30]
# Forward-pop cap: one tick may not move further than its own horizontal motion.
const POP_CAP_RATIO := 1.02
const FLICKER_HEIGHTS: Array[float] = [0.222, 0.30]
const FLICKER_ANGLES: Array[float] = [0.0, 30.0, 45.0, 60.0]
const FLICKER_TICKS := 180
const STAIR_RISER := 0.25
const STAIR_TREAD := 0.35
const STAIR_COUNT := 5
const RAMP_ANGLES: Array[float] = [20.0, 40.0]
const RAMP_HEIGHT := 3.0
# Mean sprint horizontal speed on the ramp fixture, measured with this same
# fixture on main ccc1f2f (no step-up, floor_constant_speed unset), 60 Hz.
# Re-measured on main in the a4 session (games/idunno/qa/T2-a4-main-slope-ccc1f2f8.log);
# the a3 value 6.5287 for 40_down was stale. Parity is to 4 decimals (m/s).
const SLOPE_REFERENCE := {"20_up": 5.7396, "20_down": 6.5181, "40_up": 3.8144, "40_down": 6.5311}
const SLOPE_TOLERANCE := 0.0001
const WALL_FACE_X := 10.0
const CEILING_BOTTOM := 2.2
const STEP_FACE_X := 5.0

var failures: Array[String] = []
var checks := 0
var player: PartyPlayer
var dt := 1.0 / 60.0
var rate := 60
var asserting := true
var info_misses: Array[String] = []
var max_step_rise := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_world()
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	player.set_camera_yaw(0.0)
	print("PHYSICS_ENGINE=%s" % ProjectSettings.get_setting("physics/3d/physics_engine"))
	print("T2_ENV physics_engine=%s jump_velocity=%.4f floor_snap_length=%.3f floor_max_angle=%.4f safe_margin=%.4f" % [
		ProjectSettings.get_setting("physics/3d/physics_engine"), Tuning.JUMP_VELOCITY, player.floor_snap_length,
		player.floor_max_angle, player.safe_margin])
	var results := {}
	for tick_rate in RATES:
		Engine.physics_ticks_per_second = tick_rate
		await _await_tick_rate(tick_rate)
		rate = tick_rate
		asserting = tick_rate == ASSERTED_RATE
		dt = 1.0 / float(tick_rate)
		print("T2_RATE rate=%d dt=%.6f physics_delta=%.6f in_physics=%s" % [rate, dt, player.get_physics_process_delta_time(), Engine.is_in_physics_frame()])
		_expect(is_equal_approx(player.get_physics_process_delta_time(), dt), "rate %d: engine physics delta must equal the controller delta" % rate)
		results[tick_rate] = _run_rate_suite()
	asserting = false
	_check_tick_independence(results)
	asserting = true
	Engine.physics_ticks_per_second = 60
	await _await_tick_rate(60)
	rate = 60
	dt = 1.0 / 60.0
	await _test_real_input_pulse_and_hold()
	print("T2_INFO_SUMMARY not_asserted_misses=%d (30/144 Hz and cross-rate comparisons)" % info_misses.size())
	if failures.is_empty():
		print("RUN_JUMP_PHYSICS_OK checks=%d asserted_rate=60 info_rates=30,144" % checks)
		quit(0)
	else:
		for failure in failures:
			print("T2_FAIL %s" % failure)
		for failure in failures:
			push_error(failure)
		print("RUN_JUMP_PHYSICS_FAILED failures=%d checks=%d" % [failures.size(), checks])
		quit(1)


func _await_tick_rate(tick_rate: int) -> void:
	for frame in 30:
		await physics_frame
		if is_equal_approx(player.get_physics_process_delta_time(), 1.0 / float(tick_rate)):
			await physics_frame
			return


# --- fixture -----------------------------------------------------------------

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "T2World"
	root.add_child(world)
	for lane in [LANE_FLAT, LANE_LEDGE, LANE_STEP_30, LANE_STEP_35, LANE_WALL, LANE_CEILING]:
		_add_box(world, Vector3(50.0, -0.1, lane), Vector3(200.0, 0.2, 10.0))
	# 1.0 m tall platform; its edge is at x = 0.
	_add_box(world, Vector3(-10.0, 0.5, LANE_LEDGE), Vector3(20.0, 1.0, 10.0))
	# Square steps starting at x = STEP_FACE_X.
	_add_box(world, Vector3(STEP_FACE_X + 10.0, 0.15, LANE_STEP_30), Vector3(20.0, 0.30, 10.0))
	_add_box(world, Vector3(STEP_FACE_X + 10.0, 0.175, LANE_STEP_35), Vector3(20.0, 0.35, 10.0))
	# Floor made only of adjacent 1.0 m tiles (separate bodies => seams).
	for ix in range(-5, 60):
		for iz in range(-1, 2):
			_add_box(world, Vector3(float(ix) + 0.5, -0.1, LANE_TILES + float(iz)), Vector3(1.0, 0.2, 1.0))
	# Solid wall: 1.0 m thick, 3 m tall.
	_add_box(world, Vector3(WALL_FACE_X + 0.5, 1.5, LANE_WALL), Vector3(1.0, 3.0, 10.0))
	# Low ceiling slab: bottom at CEILING_BOTTOM.
	_add_box(world, Vector3(14.0, CEILING_BOTTOM + 0.25, LANE_CEILING), Vector3(12.0, 0.5, 10.0))
	for p in PLACEMENTS.size():
		var face := STEP_FACE_X + PLACEMENTS[p].x
		for index in SWEEP_HEIGHTS.size():
			var lane := LANE_SWEEP_BASE + 100.0 * p + 10.0 * index + PLACEMENTS[p].y
			_add_box(world, Vector3(face + 50.0, -0.1, lane), Vector3(200.0, 0.2, 10.0))
			_add_box(world, Vector3(face + 10.0, SWEEP_HEIGHTS[index] * 0.5, lane), Vector3(20.0, SWEEP_HEIGHTS[index], 10.0))
		for index in ANGLED_HEIGHTS.size():
			var lane := LANE_ANGLED + 100.0 * p + 40.0 * index + PLACEMENTS[p].y
			_add_box(world, Vector3(face + 50.0, -0.1, lane), Vector3(200.0, 0.2, 36.0))
			_add_box(world, Vector3(face + 10.0, ANGLED_HEIGHTS[index] * 0.5, lane), Vector3(20.0, ANGLED_HEIGHTS[index], 36.0))
		var stairs := LANE_STAIRS + 20.0 * p + PLACEMENTS[p].y
		_add_box(world, Vector3(face + 50.0, -0.1, stairs), Vector3(200.0, 0.2, 10.0))
		for index in STAIR_COUNT:
			var top := STAIR_RISER * float(index + 1)
			_add_box(world, Vector3(face + STAIR_TREAD * index + 10.0, top * 0.5, stairs), Vector3(20.0, top, 10.0))
	for index in TALL_HEIGHTS.size():
		var lane := LANE_TALL_BASE + 50.0 * index
		_add_box(world, Vector3(50.0, -0.1, lane), Vector3(200.0, 0.2, 40.0))
		_add_box(world, Vector3(STEP_FACE_X + 10.0, TALL_HEIGHTS[index] * 0.5, lane), Vector3(20.0, TALL_HEIGHTS[index], 40.0))
	for index in RAMP_ANGLES.size():
		_add_ramp(world, LANE_RAMP_BASE + 10.0 * index, deg_to_rad(RAMP_ANGLES[index]))
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.position = Vector3(0.0, 0.0, LANE_FLAT)


# Floor, then a ramp rising along +X from x = STEP_FACE_X to RAMP_HEIGHT, then
# a plateau. Only the buried bottom end of the slab is extended (no ridge).
func _add_ramp(parent: Node3D, lane: float, angle: float) -> void:
	_add_box(parent, Vector3(0.0, -0.1, lane), Vector3(80.0, 0.2, 10.0))
	var run := RAMP_HEIGHT / tan(angle)
	var length := RAMP_HEIGHT / sin(angle)
	var thickness := 0.4
	var normal := Vector3(-sin(angle), cos(angle), 0.0)
	var along := Vector3(cos(angle), sin(angle), 0.0)
	var body := StaticBody3D.new()
	body.position = Vector3(STEP_FACE_X + run * 0.5, RAMP_HEIGHT * 0.5, lane) - normal * thickness * 0.5 - along * 0.15
	body.rotation.z = angle
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length + 0.3, thickness, 10.0)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	_add_box(parent, Vector3(STEP_FACE_X + run + 10.0, RAMP_HEIGHT * 0.5 - 0.0005, lane), Vector3(20.0, RAMP_HEIGHT, 10.0))


func _add_box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


# --- controller helpers --------------------------------------------------------

func _reset(position: Vector3) -> void:
	player.movement_buff = Vector2.ZERO
	player.global_position = position
	player.velocity = Vector3.ZERO
	player._coyote_remaining = 0.0
	player._jump_buffer_remaining = 0.0
	player.set_camera_yaw(0.0)
	for index in maxi(5, int(round(0.1 / dt))):
		player.apply_movement_input(Vector2.ZERO, false, false, dt)


# One controller tick. Returns what happened, including whether a jump fired.
func _tick(input_2d: Vector2, sprinting: bool, jump_pressed: bool) -> Dictionary:
	var buffer_before := float(player._jump_buffer_remaining)
	var before := player.global_position
	player.apply_movement_input(input_2d, sprinting, jump_pressed, dt)
	var buffer_after := float(player._jump_buffer_remaining)
	var fired := buffer_after == 0.0 and float(player._coyote_remaining) == 0.0 and (jump_pressed or buffer_before > dt + 1e-6)
	var moved := player.global_position - before
	return {
		"fired": fired,
		"floor": player.is_on_floor(),
		"y": player.global_position.y,
		"vy": player.velocity.y,
		"hspeed": Vector2(moved.x, moved.z).length() / dt,
		"vh": Vector2(player.velocity.x, player.velocity.z).length(),
		"x": player.global_position.x,
	}


func _ticks(seconds: float) -> int:
	return int(round(seconds / dt))


# Accelerate on the floor, jump once, keep holding input; measure the arc.
func _jump_arc(label: String, input_2d: Vector2, sprinting: bool, lane: float) -> Dictionary:
	_reset(Vector3(-30.0, 0.0, lane))
	for index in _ticks(0.6):
		_tick(input_2d, sprinting, false)
	var takeoff_y := player.global_position.y
	var takeoff_x := player.global_position.x
	var takeoff_hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var jump := _tick(input_2d, sprinting, true)
	var takeoff_vy := float(jump.vy)
	var fires := 1 if bool(jump.fired) else 0
	var apex := float(jump.y)
	var left_ground := not bool(jump.floor)
	var landed_tick := -1
	var x_after_1s := NAN
	var trace: Array[String] = ["t=0 y=%.3f vy=%.3f floor=%s fired=%s" % [jump.y, jump.vy, jump.floor, jump.fired]]
	for index in range(1, _ticks(2.0) + 1):
		var step := _tick(input_2d, sprinting, false)
		if bool(step.fired):
			fires += 1
		if index <= 3:
			trace.append("t=%d y=%.3f vy=%.3f floor=%s" % [index, step.y, step.vy, step.floor])
		if not bool(step.floor):
			left_ground = true
		apex = maxf(apex, float(step.y))
		if index == _ticks(1.0):
			x_after_1s = player.global_position.x
		if left_ground and bool(step.floor) and landed_tick < 0:
			landed_tick = index
	var result := {
		"apex": apex - takeoff_y,
		"takeoff_vy": takeoff_vy,
		"takeoff_hspeed": takeoff_hspeed,
		"fires": fires,
		"left_ground": left_ground,
		"landed_tick": landed_tick,
		"disp_1s": x_after_1s - takeoff_x,
	}
	print("T2_JUMP rate=%d case=%s takeoff_vy=%.4f takeoff_hspeed=%.3f apex=%.4f fires=%d left_ground=%s landed_s=%.3f disp_1s=%.3f first_ticks=[%s]" % [
		rate, label, takeoff_vy, takeoff_hspeed, result.apex, fires, left_ground, landed_tick * dt, result.disp_1s, ", ".join(trace)])
	return result


# --- suites --------------------------------------------------------------------

func _run_rate_suite() -> Dictionary:
	var summary := {}
	var idle := _jump_arc("idle", Vector2.ZERO, false, LANE_FLAT)
	var walk := _jump_arc("walk", FORWARD, false, LANE_FLAT)
	var sprint := _jump_arc("sprint", FORWARD, true, LANE_FLAT)
	for entry: Array in [["idle", idle], ["walk", walk], ["sprint", sprint]]:
		var name: String = entry[0]
		var arc: Dictionary = entry[1]
		_expect(float(arc.takeoff_vy) > 7.3, "T2.1 rate %d %s: takeoff vy %.3f must be > 7.3" % [rate, name, arc.takeoff_vy])
		_expect(bool(arc.left_ground), "T2.1 rate %d %s: jump must leave the ground" % [rate, name])
		_expect(float(arc.apex) > APEX_MIN and float(arc.apex) < APEX_MAX, "T2.1 rate %d %s: apex %.4f must be in (%.2f, %.2f)" % [rate, name, arc.apex, APEX_MIN, APEX_MAX])
		_expect(int(arc.fires) == 1, "T2.1 rate %d %s: exactly one jump must fire (got %d)" % [rate, name, arc.fires])
		_expect(int(arc.landed_tick) > 0 and int(arc.landed_tick) * dt <= 2.0, "T2.1 rate %d %s: must land within 2 s" % [rate, name])
	_expect(absf(float(sprint.apex) - float(idle.apex)) <= APEX_PAIR_DELTA, "T2.1 rate %d: |sprint apex %.4f - idle apex %.4f| must be <= %.2f" % [rate, sprint.apex, idle.apex, APEX_PAIR_DELTA])
	_expect(absf(float(walk.apex) - float(idle.apex)) <= APEX_PAIR_DELTA, "T2.1 rate %d: |walk apex %.4f - idle apex %.4f| must be <= %.2f" % [rate, walk.apex, idle.apex, APEX_PAIR_DELTA])
	_expect(float(sprint.takeoff_hspeed) > Tuning.SPRINT_SPEED - 0.05, "T2.1 rate %d: sprint jump must take off at full sprint speed (%.3f)" % [rate, sprint.takeoff_hspeed])
	summary.idle_apex = idle.apex
	summary.sprint_apex = sprint.apex
	summary.sprint_disp_1s = sprint.disp_1s
	_test_coyote(summary)
	_test_buffer()
	_test_landing_speed()
	summary.merge(_test_step(LANE_STEP_30, 0.30, true))
	_test_step(LANE_STEP_35, 0.35, false)
	summary.merge(_test_tile_seams())
	_test_wall_clipping()
	_test_ceiling_and_drop()
	if rate == ASSERTED_RATE:
		_test_step_robustness()
		_test_floor_flicker()
		_test_slope_speed()
	return summary


func _test_coyote(_summary: Dictionary) -> void:
	for sprinting in [false, true]:
		for entry: Array in [[0.10, true], [0.13, false]]:
			var press_after: float = entry[0]
			var should_fire: bool = entry[1]
			_reset(Vector3(-8.0, 1.0, LANE_LEDGE))
			var left_tick := -1
			var fired := false
			var fired_at := -1.0
			var press_tick := -1
			for index in _ticks(3.0):
				var press := left_tick >= 0 and index - left_tick == int(round(press_after / dt))
				if press:
					press_tick = index
				var step := _tick(FORWARD, sprinting, press)
				if bool(step.fired):
					fired = true
					fired_at = (index - left_tick) * dt
				if left_tick < 0 and not bool(step.floor):
					left_tick = index
				if press_tick >= 0 and index > press_tick + _ticks(0.3):
					break
			var label := "sprint" if sprinting else "walk"
			print("T2_COYOTE rate=%d move=%s press_after=%.3f actual_press=%.4f fired=%s fired_at=%.4f" % [
				rate, label, press_after, (press_tick - left_tick) * dt if press_tick >= 0 else -1.0, fired, fired_at])
			_expect(left_tick >= 0, "T2.2 rate %d %s: must walk off the 1.0 m ledge" % [rate, label])
			_expect(fired == should_fire, "T2.2 coyote rate %d %s: press %.2f s after leaving floor must %s" % [rate, label, press_after, "fire" if should_fire else "not fire"])


func _test_buffer() -> void:
	# Reference flight to find the landing tick.
	_reset(Vector3(0.0, 0.0, LANE_FLAT))
	_tick(Vector2.ZERO, false, true)
	var landing := -1
	for index in range(1, _ticks(2.0)):
		var step := _tick(Vector2.ZERO, false, false)
		if bool(step.floor):
			landing = index
			break
	_expect(landing > 0, "T2.2 buffer rate %d: reference jump must land" % rate)
	for entry: Array in [[0.10, true], [0.13, false]]:
		var lead: float = entry[0]
		var should_fire: bool = entry[1]
		_reset(Vector3(0.0, 0.0, LANE_FLAT))
		_tick(Vector2.ZERO, false, true)
		var press_tick := landing - int(round(lead / dt))
		var second_fire := -1
		for index in range(1, landing + _ticks(0.3)):
			var step := _tick(Vector2.ZERO, false, index == press_tick)
			if bool(step.fired) and second_fire < 0:
				second_fire = index
		var fired := second_fire >= 0
		var within := fired and second_fire >= landing and (second_fire - press_tick) * dt <= Tuning.JUMP_BUFFER_TIME + dt * 0.5 + 1e-6
		print("T2_BUFFER rate=%d lead=%.3f landing_tick=%d press_tick=%d fire_tick=%d" % [rate, lead, landing, press_tick, second_fire])
		if should_fire:
			_expect(within, "T2.2 buffer rate %d: press %.2f s before landing must fire on landing within the 0.12 s buffer" % [rate, lead])
		else:
			_expect(not fired, "T2.2 buffer rate %d: press %.2f s before landing must not fire" % [rate, lead])
	# Pressing repeatedly while airborne (coyote expired) never double-jumps mid-air.
	_reset(Vector3(0.0, 0.0, LANE_FLAT))
	_tick(Vector2.ZERO, false, true)
	var air_fires := 0
	for index in range(1, landing - _ticks(0.2)):
		if bool(_tick(Vector2.ZERO, false, index % 3 == 0).fired):
			air_fires += 1
	_expect(air_fires == 0, "T2.2 rate %d: mid-air presses must not fire an air jump (got %d)" % [rate, air_fires])


func _test_landing_speed() -> void:
	_reset(Vector3(-30.0, 0.0, LANE_FLAT))
	for index in _ticks(0.6):
		_tick(FORWARD, true, false)
	_tick(FORWARD, true, true)
	var airborne := false
	var landed := -1
	var min_after := INF
	var final_speed := 0.0
	for index in _ticks(2.0):
		var step := _tick(FORWARD, true, false)
		if not bool(step.floor):
			airborne = true
		elif airborne and landed < 0:
			landed = index
		if landed >= 0 and index > landed:
			min_after = minf(min_after, float(step.hspeed))
			final_speed = float(step.hspeed)
			if index - landed >= _ticks(0.25):
				break
	print("T2_LANDING rate=%d landed_tick=%d min_hspeed_first_0.25s=%.3f speed_at_0.25s=%.3f" % [rate, landed, min_after, final_speed])
	_expect(landed > 0 and final_speed >= 6.2, "T2.4 rate %d: horizontal speed 0.25 s after landing %.3f must be >= 6.2" % [rate, final_speed])


func _test_step(lane: float, height: float, required: bool) -> Dictionary:
	var out := {}
	for sprinting in [false, true]:
		var target := Tuning.SPRINT_SPEED if sprinting else Tuning.WALK_SPEED
		_reset(Vector3(STEP_FACE_X - 6.0, 0.0, lane))
		var min_speed := INF
		var climbed := false
		var stalled_ticks := 0
		var stall := 0
		var ever_airborne_up := false
		for index in _ticks(2.5):
			var step := _tick(FORWARD, sprinting, false)
			var x := float(step.x)
			# Measure through the step: from 0.5 m before the face to 1.0 m past it.
			if x > STEP_FACE_X - Tuning.CAPSULE_RADIUS - 0.5 and x < STEP_FACE_X + 1.0:
				min_speed = minf(min_speed, float(step.hspeed))
				if float(step.hspeed) < 0.05:
					stall += 1
					stalled_ticks = maxi(stalled_ticks, stall)
				else:
					stall = 0
			if x > STEP_FACE_X + 0.5 and float(step.y) > height - 0.02 and bool(step.floor):
				climbed = true
			if float(step.vy) > 3.0:
				ever_airborne_up = true
		var label := "sprint" if sprinting else "walk"
		var fraction := min_speed / target if min_speed < INF else 0.0
		print("T2_STEP rate=%d height=%.2f move=%s climbed=%s min_hspeed=%.3f fraction_of_target=%.3f max_zero_speed_ticks=%d final_y=%.3f final_x=%.3f launched=%s" % [
			rate, height, label, climbed, min_speed, fraction, stalled_ticks, player.global_position.y, player.global_position.x, ever_airborne_up])
		if required:
			_expect(climbed, "T2.4 step rate %d %s: must climb a %.2f m step without jumping" % [rate, label, height])
			_expect(fraction >= 0.8, "T2.4 step rate %d %s: speed through the %.2f m step must stay >= 80%% of target (got %.3f)" % [rate, label, height, fraction])
			_expect(not ever_airborne_up, "T2.4 step rate %d %s: stepping must not launch the player upward" % [rate, label])
			out["step_%s_fraction" % label] = fraction
	return out


# QA-style criterion: worst single-tick horizontal speed (position delta / dt)
# within 1 m of the face, after acceleration, must stay >= 80% of target.
func _climb_once(face_x: float, lane: float, height: float, sprinting: bool, heading_deg: float, start_back: float) -> Dictionary:
	var heading := deg_to_rad(heading_deg)
	var input_2d := Vector2(cos(heading), sin(heading))
	var target := Tuning.SPRINT_SPEED if sprinting else Tuning.WALK_SPEED
	_reset(Vector3(face_x - start_back * cos(heading), 0.0, lane - start_back * sin(heading)))
	var min_ratio := INF
	var max_ratio := 0.0
	var zero_ticks := 0
	var off_floor := 0
	var max_vy := 0.0
	var max_rise := 0.0
	for index in _ticks(3.0):
		var y_before := player.global_position.y
		var step := _tick(input_2d, sprinting, false)
		max_vy = maxf(max_vy, player.velocity.y)
		max_rise = maxf(max_rise, float(step.y) - y_before)
		var x := float(step.x)
		if index >= _ticks(0.5) and x > face_x - 1.0 and x < face_x + 1.0:
			min_ratio = minf(min_ratio, float(step.hspeed) / target)
			max_ratio = maxf(max_ratio, float(step.hspeed) / target)
			if float(step.hspeed) < 0.05:
				zero_ticks += 1
			if not bool(step.floor):
				off_floor += 1
		if x > face_x + 1.5:
			break
	return {"ratio": min_ratio, "pop": max_ratio, "zero": zero_ticks, "off_floor": off_floor, "max_vy": max_vy, "max_rise": max_rise,
		"y": player.global_position.y, "x": player.global_position.x, "floor": player.is_on_floor()}


func _sweep_case(tag: String, face_x: float, lane: float, height: float, sprinting: bool, angle: float) -> Dictionary:
	var label := "sprint" if sprinting else "walk"
	var out := {"worst": INF, "bad": 0, "not_climbed": 0, "max_off": 0, "pop": 0.0, "rise": 0.0}
	for offset in SWEEP_OFFSETS:
		var back := 4.0 + 0.01 * offset
		var r := _climb_once(face_x, lane, height, sprinting, angle, back)
		out.worst = minf(float(out.worst), float(r.ratio))
		out.max_off = maxi(int(out.max_off), int(r.off_floor))
		out.pop = maxf(float(out.pop), float(r.pop))
		out.rise = maxf(float(out.rise), float(r.max_rise))
		max_step_rise = maxf(max_step_rise, float(r.max_rise))
		if float(r.ratio) < 0.8 or int(r.zero) > 0 or float(r.max_vy) >= 1.0:
			out.bad = int(out.bad) + 1
			print("T2_%s_SLOW height=%.3f angle=%d move=%s face_x=%.3f lane=%.3f start_back=%.2f ratio=%.3f zero=%d max_vy=%.3f" % [tag, height, int(angle), label, face_x, lane, back, r.ratio, r.zero, r.max_vy])
		if absf(float(r.y) - height) > 0.02 or not bool(r.floor):
			out.not_climbed = int(out.not_climbed) + 1
			print("T2_%s_NOT_CLIMBED height=%.3f angle=%d move=%s face_x=%.3f lane=%.3f start_back=%.2f final_y=%.4f floor=%s" % [tag, height, int(angle), label, face_x, lane, back, r.y, r.floor])
	return out


func _test_step_robustness() -> void:
	var max_pop := 0.0
	# Heights x walk/sprint x 12 start offsets x world placements, straight approach.
	for p in PLACEMENTS.size():
		var face := STEP_FACE_X + PLACEMENTS[p].x
		for index in SWEEP_HEIGHTS.size():
			var height := SWEEP_HEIGHTS[index]
			var lane := LANE_SWEEP_BASE + 100.0 * p + 10.0 * index + PLACEMENTS[p].y
			for sprinting in [false, true]:
				var label := "sprint" if sprinting else "walk"
				var r := _sweep_case("STEP_SWEEP", face, lane, height, sprinting, 0.0)
				max_pop = maxf(max_pop, float(r.pop))
				print("T2_STEP_SWEEP placement=%d height=%.3f move=%s starts=%d below_80pct=%d not_climbed=%d worst_ratio=%.3f max_off_floor_ticks=%d max_tick_ratio=%.3f" % [p, height, label, SWEEP_OFFSETS, r.bad, r.not_climbed, r.worst, r.max_off, r.pop])
				_expect(int(r.bad) == 0, "T2.4 sweep p%d %.3f m %s: %d/%d start offsets drop below 80%% / stall / launch (worst %.3f)" % [p, height, label, r.bad, SWEEP_OFFSETS, r.worst])
				_expect(int(r.not_climbed) == 0, "T2.4 sweep p%d %.3f m %s: %d/%d start offsets do not end on the step" % [p, height, label, r.not_climbed, SWEEP_OFFSETS])
				_expect(int(r.max_off) == 0, "T2.4 sweep p%d %.3f m %s: must stay on the floor through the step (%d off ticks)" % [p, height, label, r.max_off])
	# Oblique approaches 0-75 deg on wide lips.
	for p in PLACEMENTS.size():
		var face := STEP_FACE_X + PLACEMENTS[p].x
		for index in ANGLED_HEIGHTS.size():
			var lane := LANE_ANGLED + 100.0 * p + 40.0 * index + PLACEMENTS[p].y
			for angle in APPROACH_ANGLES:
				for sprinting in [false, true]:
					var label := "sprint" if sprinting else "walk"
					var r := _sweep_case("STEP_ANGLE", face, lane, ANGLED_HEIGHTS[index], sprinting, angle)
					max_pop = maxf(max_pop, float(r.pop))
					print("T2_STEP_ANGLE placement=%d angle=%d height=%.3f move=%s starts=%d below_80pct=%d not_climbed=%d worst_ratio=%.3f max_off_floor_ticks=%d max_tick_ratio=%.3f" % [p, int(angle), ANGLED_HEIGHTS[index], label, SWEEP_OFFSETS, r.bad, r.not_climbed, r.worst, r.max_off, r.pop])
					_expect(int(r.bad) == 0 and int(r.not_climbed) == 0, "T2.4 p%d %.3f m lip at %d deg %s: %d slow, %d not climbed of %d (worst %.3f)" % [p, ANGLED_HEIGHTS[index], int(angle), label, r.bad, r.not_climbed, SWEEP_OFFSETS, r.worst])
	# Stairs: 5 x 0.25 m risers, 0.35 m treads, every placement.
	for p in PLACEMENTS.size():
		var face := STEP_FACE_X + PLACEMENTS[p].x
		var lane := LANE_STAIRS + 20.0 * p + PLACEMENTS[p].y
		for sprinting in [false, true]:
			var label := "sprint" if sprinting else "walk"
			var target := Tuning.SPRINT_SPEED if sprinting else Tuning.WALK_SPEED
			var worst := INF
			var bad := 0
			var not_top := 0
			for offset in SWEEP_OFFSETS:
				_reset(Vector3(face - 4.0 - 0.01 * offset, 0.0, lane))
				var min_ratio := INF
				var off_floor := 0
				var stair_end := face + STAIR_TREAD * STAIR_COUNT + 0.5
				for index in _ticks(3.0):
					var step := _tick(FORWARD, sprinting, false)
					if index >= _ticks(0.5) and float(step.x) > face - 1.0 and float(step.x) < stair_end:
						min_ratio = minf(min_ratio, float(step.hspeed) / target)
						max_pop = maxf(max_pop, float(step.hspeed) / target)
						if not bool(step.floor):
							off_floor += 1
				worst = minf(worst, min_ratio)
				if min_ratio < 0.8 or off_floor > 0:
					bad += 1
					print("T2_STAIRS_SLOW placement=%d move=%s start_back=%.2f ratio=%.3f off_floor=%d" % [p, label, 4.0 + 0.01 * offset, min_ratio, off_floor])
				if absf(player.global_position.y - STAIR_RISER * STAIR_COUNT) > 0.02:
					not_top += 1
			print("T2_STAIRS placement=%d risers=%dx%.2f tread=%.2f move=%s starts=%d below_80pct_or_off_floor=%d not_top=%d worst_ratio=%.3f" % [p, STAIR_COUNT, STAIR_RISER, STAIR_TREAD, label, SWEEP_OFFSETS, bad, not_top, worst])
			_expect(bad == 0 and not_top == 0, "T2.4 stairs p%d %s: %d slow/off-floor, %d not at top of %d starts (worst %.3f)" % [p, label, bad, not_top, SWEEP_OFFSETS, worst])
	print("T2_POP_CAP max_tick_distance_over_tick_motion=%.4f cap=%.2f" % [max_pop, POP_CAP_RATIO])
	print("T2_RISE_CAP max_rise_per_tick_m=%.4f cap=%.3f" % [max_step_rise, Tuning.STEP_HEIGHT + 0.005])
	_expect(max_step_rise <= Tuning.STEP_HEIGHT + 0.005, "T2.4 vertical pop: one tick rose %.4f m (cap %.3f)" % [max_step_rise, Tuning.STEP_HEIGHT + 0.005])
	_expect(max_pop <= POP_CAP_RATIO, "T2.4 forward pop: one tick moved %.3fx its own horizontal motion (cap %.2f)" % [max_pop, POP_CAP_RATIO])
	# Too tall: still blocked, straight and at 45/75 deg, walk and sprint.
	for index in TALL_HEIGHTS.size():
		for angle in [0.0, 45.0, 75.0]:
			for sprinting in [false, true]:
				var r := _climb_once(STEP_FACE_X, LANE_TALL_BASE + 50.0 * index, TALL_HEIGHTS[index], sprinting, angle, 3.0)
				var label := "sprint" if sprinting else "walk"
				print("T2_STEP_TALL height=%.2f angle=%d move=%s final_y=%.4f" % [TALL_HEIGHTS[index], int(angle), label, r.y])
				_expect(float(r.y) < 0.05, "T2.4 %.2f m lip at %d deg %s must stay blocked (y %.4f)" % [TALL_HEIGHTS[index], int(angle), label, r.y])


# T2.4 floor flicker: on a walk/sprint up onto a lip and along its flat top,
# is_on_floor() must never drop for a tick and no landed signal may fire
# (QA a2/a3 flicker headings + the a3 p3 0.222 m 30 deg miss), every
# placement, 12 start offsets. Every tick after the reset is counted.
func _test_floor_flicker() -> void:
	var landings := [0]
	var sink_ticks := 0
	var max_top_dy := 0.0
	var on_landed := func(_height: float) -> void: landings[0] += 1
	player.landed.connect(on_landed)
	for p in PLACEMENTS.size():
		var face := STEP_FACE_X + PLACEMENTS[p].x
		for index in FLICKER_HEIGHTS.size():
			var height := FLICKER_HEIGHTS[index]
			var lane := LANE_ANGLED + 100.0 * p + 40.0 * index + PLACEMENTS[p].y
			for angle in FLICKER_ANGLES:
				var heading := deg_to_rad(angle)
				var input_2d := Vector2(cos(heading), sin(heading))
				for sprinting in [false, true]:
					var label := "sprint" if sprinting else "walk"
					var worst_off := 0
					var worst_land := 0
					var not_on_top := 0
					for offset in SWEEP_OFFSETS:
						var back := 4.0 + 0.01 * offset
						_reset(Vector3(face - back * cos(heading), 0.0, lane - back * sin(heading)))
						landings[0] = 0
						var off := 0
						var first_off := -1
						for tick in FLICKER_TICKS:
							var y_before := player.global_position.y
							var step := _tick(input_2d, sprinting, false)
							if _sinking():
								sink_ticks += 1
							if y_before > height - 0.02 and float(step.y) > height - 0.06:
								max_top_dy = maxf(max_top_dy, absf(float(step.y) - y_before))
							if not bool(step.floor):
								off += 1
								if first_off < 0:
									first_off = tick
						var on_top := absf(player.global_position.y - height) <= 0.02 and player.is_on_floor()
						if off > 0 or landings[0] > 0 or not on_top:
							print("T2_FLICKER_MISS placement=%d height=%.3f angle=%d move=%s start_back=%.2f off_floor_ticks=%d first_off_tick=%d landed_signals=%d final_y=%.4f floor=%s" % [p, height, int(angle), label, back, off, first_off, landings[0], player.global_position.y, player.is_on_floor()])
						worst_off = maxi(worst_off, off)
						worst_land = maxi(worst_land, landings[0])
						if not on_top:
							not_on_top += 1
					print("T2_FLICKER placement=%d height=%.3f angle=%d move=%s starts=%d max_off_floor_ticks=%d max_landed_signals=%d not_on_top=%d" % [p, height, int(angle), label, SWEEP_OFFSETS, worst_off, worst_land, not_on_top])
					_expect(worst_off == 0 and worst_land == 0 and not_on_top == 0, "T2.4 flicker p%d %.3f m %d deg %s: %d off-floor ticks, %d landed signals, %d not on top (of %d starts)" % [p, height, int(angle), label, worst_off, worst_land, not_on_top, SWEEP_OFFSETS])
	player.landed.disconnect(on_landed)
	print("T2_FLICKER_TOP_DY max_abs_dy_on_top_m=%.4f cap=0.05" % max_top_dy)
	_expect(max_top_dy <= 0.05, "T2.4 flat lip top: one tick moved %.4f m vertically (cap 0.05)" % max_top_dy)
	# Info only (main's move_and_slide snap sink is out of T2 scope): ticks on
	# which a capsule 2 cm smaller than the player's overlaps the world.
	print("T2_FLICKER_SINK_INFO (not asserted) ticks_overlapping_2cm=%d runs=%d" % [sink_ticks, PLACEMENTS.size() * FLICKER_HEIGHTS.size() * FLICKER_ANGLES.size() * 2 * SWEEP_OFFSETS])


func _sinking() -> bool:
	var capsule := player.collider.shape as CapsuleShape3D
	var shape := CapsuleShape3D.new()
	shape.radius = capsule.radius - 0.02
	shape.height = capsule.height - 0.04
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = shape
	parameters.transform = player.collider.global_transform
	parameters.collision_mask = player.collision_mask
	parameters.exclude = [player.get_rid()]
	return not player.get_world_3d().direct_space_state.intersect_shape(parameters, 1).is_empty()


func _test_slope_speed() -> void:
	for index in RAMP_ANGLES.size():
		var angle := RAMP_ANGLES[index]
		var lane := LANE_RAMP_BASE + 10.0 * index
		var run := RAMP_HEIGHT / tan(deg_to_rad(angle))
		var up := _ramp_mean_speed(Vector3(STEP_FACE_X - 4.0, 0.0, lane), FORWARD, run)
		var down := _ramp_mean_speed(Vector3(STEP_FACE_X + run + 3.0, RAMP_HEIGHT, lane), -FORWARD, run)
		var key_up := "%d_up" % int(angle)
		var key_down := "%d_down" % int(angle)
		print("T2_SLOPE angle=%d sprint_up_mean_h=%.4f sprint_down_mean_h=%.4f ref_up=%s ref_down=%s" % [int(angle), up, down, SLOPE_REFERENCE.get(key_up, "unset"), SLOPE_REFERENCE.get(key_down, "unset")])
		for entry: Array in [[key_up, up], [key_down, down]]:
			_expect(SLOPE_REFERENCE.has(entry[0]), "slope reference %s must be recorded" % entry[0])
			if SLOPE_REFERENCE.has(entry[0]):
				var ref := float(SLOPE_REFERENCE[entry[0]])
				_expect(absf(float(entry[1]) - ref) <= SLOPE_TOLERANCE, "slope %s: sprint speed %.4f must match main %.4f within 0.0001 m/s" % [entry[0], entry[1], ref])


func _ramp_mean_speed(start: Vector3, input_2d: Vector2, run: float) -> float:
	_reset(start)
	var total := 0.0
	var samples := 0
	for index in _ticks(4.0):
		var step := _tick(input_2d, true, false)
		var x := float(step.x)
		if index >= _ticks(0.5) and x > STEP_FACE_X + 0.6 and x < STEP_FACE_X + run - 0.6:
			total += float(step.hspeed)
			samples += 1
	return total / float(samples) if samples > 0 else NAN


func _test_tile_seams() -> Dictionary:
	_reset(Vector3(0.0, 0.0, LANE_TILES))
	var start_x := player.global_position.x
	var min_speed := INF
	var max_dy := 0.0
	var off_floor := 0
	for index in _ticks(3.0):
		var step := _tick(FORWARD, true, false)
		if index * dt >= 0.5:
			min_speed = minf(min_speed, float(step.hspeed))
			max_dy = maxf(max_dy, absf(float(step.y)))
			if not bool(step.floor):
				off_floor += 1
	var distance := player.global_position.x - start_x
	print("T2_SEAMS rate=%d distance_3s=%.3f min_hspeed=%.3f max_abs_dy=%.4f off_floor_ticks=%d" % [rate, distance, min_speed, max_dy, off_floor])
	_expect(min_speed >= 6.2, "T2.4 seams rate %d: sprint speed across 1 m tiles %.3f must stay >= 6.2" % [rate, min_speed])
	_expect(off_floor == 0, "T2.4 seams rate %d: is_on_floor must stay true across tile seams (%d off ticks)" % [rate, off_floor])
	_expect(max_dy <= 0.05, "T2.4 seams rate %d: vertical hitch %.4f must be <= 0.05 m" % [rate, max_dy])
	return {"seam_distance": distance}


func _test_wall_clipping() -> void:
	var limit_x := WALL_FACE_X - Tuning.CAPSULE_RADIUS + 0.05 + player.safe_margin
	for buffed in [false, true]:
		_reset(Vector3(WALL_FACE_X - 6.0, 0.0, LANE_WALL))
		if buffed:
			player.movement_buff = Vector2(MatchPowerups.Kind.SPEED, 60.0)
		var max_x := -INF
		for index in _ticks(2.0):
			_tick(FORWARD, true, false)
			max_x = maxf(max_x, player.global_position.x)
		var label := "buffed" if buffed else "unbuffed"
		print("T2_WALL rate=%d %s max_x=%.4f limit_x=%.4f final_x=%.4f" % [rate, label, max_x, limit_x, player.global_position.x])
		_expect(max_x <= limit_x, "T2.5 wall rate %d %s: capsule must not penetrate the wall (max x %.4f > %.4f)" % [rate, label, max_x, limit_x])
		# Sprint-jump into the same wall.
		_reset(Vector3(WALL_FACE_X - 5.0, 0.0, LANE_WALL))
		if buffed:
			player.movement_buff = Vector2(MatchPowerups.Kind.SPEED, 60.0)
		max_x = -INF
		for index in _ticks(0.3):
			_tick(FORWARD, true, false)
		_tick(FORWARD, true, true)
		for index in _ticks(2.0):
			_tick(FORWARD, true, false)
			max_x = maxf(max_x, player.global_position.x)
		print("T2_WALL_JUMP rate=%d %s max_x=%.4f final_y=%.4f floor=%s" % [rate, label, max_x, player.global_position.y, player.is_on_floor()])
		_expect(max_x <= limit_x, "T2.5 wall jump rate %d %s: no tunneling (max x %.4f)" % [rate, label, max_x])
		_expect(player.global_position.y >= -0.05 and player.is_on_floor(), "T2.5 wall jump rate %d %s: feet must end on the floor" % [rate, label])


func _test_ceiling_and_drop() -> void:
	# Start under the slab (x 8..20) so the jump goes straight into it.
	_reset(Vector3(9.5, 0.0, LANE_CEILING))
	for index in _ticks(0.3):
		_tick(FORWARD, true, false)
	var max_head := -INF
	_tick(FORWARD, true, true)
	for index in _ticks(2.0):
		_tick(FORWARD, true, false)
		max_head = maxf(max_head, player.global_position.y + Tuning.STANDING_HEIGHT)
	print("T2_CEILING rate=%d max_head_y=%.4f ceiling=%.2f final_y=%.4f floor=%s" % [rate, max_head, CEILING_BOTTOM, player.global_position.y, player.is_on_floor()])
	_expect(max_head <= CEILING_BOTTOM + 0.05, "T2.5 ceiling rate %d: head %.4f must not pass the low ceiling" % [rate, max_head])
	_expect(player.global_position.y >= -0.05 and player.is_on_floor(), "T2.5 ceiling rate %d: must land on the floor" % rate)
	_reset(Vector3(-20.0, 0.0, LANE_FLAT))
	player.global_position.y = 3.0
	player.velocity = Vector3.ZERO
	for index in _ticks(1.5):
		_tick(Vector2.ZERO, false, false)
	print("T2_DROP rate=%d height=3.0 final_y=%.4f floor=%s" % [rate, player.global_position.y, player.is_on_floor()])
	_expect(player.is_on_floor() and absf(player.global_position.y) <= 0.05, "T2.5 drop rate %d: 3 m drop must land on the floor (y %.4f)" % [rate, player.global_position.y])


func _check_tick_independence(results: Dictionary) -> void:
	var reference: Dictionary = results[60]
	for tick_rate in RATES:
		var current: Dictionary = results[tick_rate]
		for key in ["idle_apex", "sprint_apex", "sprint_disp_1s", "seam_distance"]:
			var ref := float(reference[key])
			var value := float(current[key])
			var ratio := absf(value - ref) / absf(ref) if ref != 0.0 else INF
			print("T2_RATE_COMPARE rate=%d metric=%s value=%.4f ref60=%.4f rel_diff=%.4f" % [tick_rate, key, value, ref, ratio])
			_expect(ratio <= RATE_TOLERANCE, "T2.6 rate %d: %s %.4f must be within 5%% of 60 Hz %.4f" % [tick_rate, key, value, ref])


# Real Input path at 60 Hz: PartyPlayer._physics_process samples the action.
func _test_real_input_pulse_and_hold() -> void:
	player.global_position = Vector3(-10.0, 0.0, LANE_FLAT)
	player.velocity = Vector3.ZERO
	player.movement_buff = Vector2.ZERO
	player._jump_buffer_remaining = 0.0
	player.set_physics_process(true)
	for frame in 10:
		await physics_frame
	await process_frame
	# Press and release inside one idle frame, between two physics ticks.
	Input.action_press("jump")
	Input.action_release("jump")
	var max_vy := -INF
	for frame in 6:
		await physics_frame
		max_vy = maxf(max_vy, player.velocity.y)
	print("T2_PULSE sub_tick_press max_vy=%.3f" % max_vy)
	_expect(max_vy > 5.0, "T2.2: a press released before the next physics tick must still jump (max vy %.3f)" % max_vy)
	for frame in 150:
		await physics_frame
	_expect(player.is_on_floor(), "T2.2: player must land after the pulse jump")
	# Hold jump for 2 s: exactly one jump.
	Input.action_press("jump")
	var previous_vy := player.velocity.y
	var kicks := 0
	for frame in 120:
		await physics_frame
		if player.velocity.y > 5.0 and previous_vy <= 5.0:
			kicks += 1
		previous_vy = player.velocity.y
	Input.action_release("jump")
	print("T2_HOLD held_2s jump_kicks=%d" % kicks)
	_expect(kicks == 1, "T2.2: holding jump for 2 s must fire exactly one jump (got %d)" % kicks)
	player.set_physics_process(false)


func _expect(condition: bool, message: String) -> void:
	if not asserting:
		if not condition:
			info_misses.append(message)
			print("T2_INFO (not asserted) %s" % message)
		return
	checks += 1
	if not condition:
		failures.append(message)
