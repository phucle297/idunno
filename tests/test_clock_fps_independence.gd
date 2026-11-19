extends SceneTree
## T11: one seeded match, run at whatever frame rate the caller imposes
## (--max-fps / --busy-ms). Prints CLOCK_EVENT (name, MatchClock tick since the
## match started, elapsed) for every disaster start and the match end. The
## two-frame-rate gate lives in tests/run_clock_fps_check.sh, which compares an
## uncapped run with a throttled/loaded one. Damage is ignored (fixture only)
## so the match always ends at the timeout; match_duration is shortened here,
## never in the game.

const TIMEOUT_MSEC := 240000

var map_id := "toy_town"
var seed := 1101
var duration := 60.0
var busy_ms := 0
var events := 0


class ImmortalManager extends MatchManager:
	func apply_damage_batch(_events: Array[Dictionary]) -> bool:
		return false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map-id="):
			map_id = argument.trim_prefix("--map-id=")
		elif argument.begins_with("--seed="):
			seed = argument.trim_prefix("--seed=").to_int()
		elif argument.begins_with("--duration="):
			duration = argument.trim_prefix("--duration=").to_float()
		elif argument.begins_with("--busy-ms="):
			busy_ms = argument.trim_prefix("--busy-ms=").to_int()
	_run.call_deferred()


func _busy_frame() -> void:
	# Simulated slow PC: burn CPU on every rendered frame (not a sleep).
	var until := Time.get_ticks_usec() + busy_ms * 1000
	while Time.get_ticks_usec() < until:
		pass


func _run() -> void:
	if busy_ms > 0:
		process_frame.connect(_busy_frame)
	var main = load("res://scenes/main.tscn").instantiate()
	main.get_node("MatchManager").set_script(ImmortalManager)
	root.add_child(main)
	await physics_frame
	var manager: MatchManager = main.match_manager
	var director: DisasterDirector = main.disaster_director
	var clock: MatchClock = main.match_clock
	main.set_map_id(map_id)
	if not await main.prepare_gameplay_map():
		push_error("CLOCK_FPS map %s failed to prepare" % map_id)
		quit(1)
		return
	await physics_frame
	manager.match_duration = duration
	manager.set_player_ready(1, true)
	var start_tick := [clock.tick] # boxed: lambdas capture locals by value
	director.disaster_started.connect(func(disaster_name: String, _intensity: int, _active: Array[String]) -> void:
		events += 1
		print("CLOCK_EVENT kind=start name=%s tick=%d elapsed=%.4f" % [disaster_name.replace(" ", "_"), clock.tick - start_tick[0], manager.elapsed_time]))
	# The end is stamped when the match finishes, not when this loop next
	# wakes (a throttled frame runs several physics steps before it).
	var end_stamp := [-1, 0.0]
	manager.match_finished.connect(func(_winners: Array[int]) -> void:
		end_stamp[0] = clock.tick - start_tick[0]
		end_stamp[1] = manager.elapsed_time)
	if not manager.start_match() or not director.start_directing(seed):
		push_error("CLOCK_FPS match did not start")
		quit(1)
		return
	start_tick[0] = clock.tick
	var wall_start := Time.get_ticks_msec()
	var frames := 0
	while manager.state == MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() - wall_start < TIMEOUT_MSEC:
		await process_frame
		frames += 1
	var ended := manager.state == MatchManager.MatchState.RESULTS
	print("CLOCK_EVENT kind=end name=match_end tick=%d elapsed=%.4f" % [end_stamp[0], end_stamp[1]])
	var wall_s := (Time.get_ticks_msec() - wall_start) / 1000.0
	print("CLOCK_FPS_RUN map=%s seed=%d duration=%.1f busy_ms=%d frames=%d wall_s=%.2f avg_fps=%.1f starts=%d ended=%s" % [map_id, seed, duration, busy_ms, frames, wall_s, frames / maxf(wall_s, 0.001), events, ended])
	if ended:
		print("CLOCK_FPS_RUN_OK map=%s" % map_id)
	else:
		push_error("CLOCK_FPS match did not end map=%s" % map_id)
	quit(0 if ended else 1)
