extends SceneTree

# T2 run+jump physics regression (games/idunno acceptance T2.1-T2.6).
# Drives PartyPlayer.apply_movement_input on a fixed physics tick. The tick is
# changed with Engine.physics_ticks_per_second and the controller runs inside
# a physics frame, so move_and_slide and the controller share the same delta.

const Tuning = preload("res://game/player/player_tuning.gd")
const RATES: Array[int] = [30, 60, 144]
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
const WALL_FACE_X := 10.0
const CEILING_BOTTOM := 2.2
const STEP_FACE_X := 5.0

var failures: Array[String] = []
var checks := 0
var player: PartyPlayer
var dt := 1.0 / 60.0
var rate := 60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_world()
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	player.set_camera_yaw(0.0)
	print("T2_ENV physics_engine=%s jump_velocity=%.4f floor_snap_length=%.3f floor_max_angle=%.4f safe_margin=%.4f" % [
		ProjectSettings.get_setting("physics/3d/physics_engine"), Tuning.JUMP_VELOCITY, player.floor_snap_length,
		player.floor_max_angle, player.safe_margin])
	var results := {}
	for tick_rate in RATES:
		Engine.physics_ticks_per_second = tick_rate
		await _await_tick_rate(tick_rate)
		rate = tick_rate
		dt = 1.0 / float(tick_rate)
		print("T2_RATE rate=%d dt=%.6f physics_delta=%.6f in_physics=%s" % [rate, dt, player.get_physics_process_delta_time(), Engine.is_in_physics_frame()])
		_expect(is_equal_approx(player.get_physics_process_delta_time(), dt), "rate %d: engine physics delta must equal the controller delta" % rate)
		results[tick_rate] = _run_rate_suite()
	_check_tick_independence(results)
	Engine.physics_ticks_per_second = 60
	await _await_tick_rate(60)
	rate = 60
	dt = 1.0 / 60.0
	await _test_real_input_pulse_and_hold()
	if failures.is_empty():
		print("RUN_JUMP_PHYSICS_OK checks=%d rates=30,60,144" % checks)
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
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.position = Vector3(0.0, 0.0, LANE_FLAT)


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
	checks += 1
	if not condition:
		failures.append(message)
