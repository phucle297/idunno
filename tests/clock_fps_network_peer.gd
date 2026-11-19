extends SceneTree
## T11 online half of tests/run_clock_fps_check.sh: one real-ENet host and one
## client play the same seeded short match while the caller throttles one side
## (--max-fps / --busy-ms). The server prints CLOCK_EVENT (name, MatchClock tick
## since start, elapsed) per disaster start and the match end; the client prints
## CLIENT_EVENT for each disaster it first sees active and for the match end
## it receives, from snapshots only. Fixture-only: damage ignored, the
## director seed is pinned, match_duration shortened; no game code changes.

const TIMEOUT_MSEC := 240000

var role := ""
var map_id := "toy_town"
var seed := 1101
var duration := 60.0
var busy_ms := 0


class ImmortalManager extends MatchManager:
	func apply_damage_batch(_events: Array[Dictionary]) -> bool:
		return false


class SeededDirector extends DisasterDirector:
	var pinned_seed := -1

	func start_directing(seed: int = -1, salt: int = -1) -> bool:
		return super(pinned_seed if seed < 0 else seed, salt)


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--map-id="):
			map_id = argument.trim_prefix("--map-id=")
		elif argument.begins_with("--seed="):
			seed = argument.trim_prefix("--seed=").to_int()
		elif argument.begins_with("--duration="):
			duration = argument.trim_prefix("--duration=").to_float()
		elif argument.begins_with("--busy-ms="):
			busy_ms = argument.trim_prefix("--busy-ms=").to_int()
	_run.call_deferred()


func _busy_frame() -> void:
	var until := Time.get_ticks_usec() + busy_ms * 1000
	while Time.get_ticks_usec() < until:
		pass


func _run() -> void:
	if busy_ms > 0:
		process_frame.connect(_busy_frame)
	var main = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"
	main.get_node("MatchManager").set_script(ImmortalManager)
	main.get_node("DisasterDirector").set_script(SeededDirector)
	(main.get_node("DisasterDirector") as SeededDirector).pinned_seed = seed
	root.add_child(main)
	if role == "server":
		main.set_map_id(map_id)
	await process_frame
	var ok := false
	if role == "server":
		ok = await _server(main)
	elif role == "client":
		ok = await _client(main)
	else:
		push_error("Expected --role=server or --role=client")
	var frames_note := "role=%s busy_ms=%d" % [role, busy_ms]
	if ok:
		print("CLOCK_FPS_NET_%s_OK map=%s %s" % [role.to_upper(), map_id, frames_note])
	else:
		push_error("CLOCK_FPS_NET %s failed map=%s" % [role, map_id])
	main.process_mode = Node.PROCESS_MODE_DISABLED
	if main.multiplayer.multiplayer_peer != null:
		main.multiplayer.multiplayer_peer.close()
		main.multiplayer.multiplayer_peer = null
	main.free()
	await create_timer(0.1).timeout
	quit(0 if ok else 1)


func _server(main: Node) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var manager: MatchManager = main.match_manager
	var director: DisasterDirector = main.disaster_director
	var clock: MatchClock = main.match_clock
	var start_tick := [0]
	manager.state_changed.connect(func(state: MatchManager.MatchState) -> void:
		if state == MatchManager.MatchState.ACTIVE:
			manager.match_duration = duration
			start_tick[0] = clock.tick
			print("CLOCK_NET_START tick0=%d elapsed=%.4f" % [clock.tick, manager.elapsed_time]))
	director.disaster_started.connect(func(disaster_name: String, _intensity: int, _active: Array[String]) -> void:
		print("CLOCK_EVENT kind=start name=%s tick=%d elapsed=%.4f" % [disaster_name.replace(" ", "_"), clock.tick - start_tick[0], manager.elapsed_time]))
	# Stamped when the match finishes, not when the loop below next wakes.
	var end_stamp := [-1, 0.0]
	manager.match_finished.connect(func(_winners: Array[int]) -> void:
		end_stamp[0] = clock.tick - start_tick[0]
		end_stamp[1] = manager.elapsed_time)
	while main.get_network_player_ids().size() != 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while not manager.can_start_match() and Time.get_ticks_msec() < deadline:
		await process_frame
	var start := InputEventAction.new()
	start.action = "ui_accept"
	start.pressed = true
	main._unhandled_input(start)
	while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	while manager.state == MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	var ended := manager.state == MatchManager.MatchState.RESULTS
	print("CLOCK_EVENT kind=end name=match_end tick=%d elapsed=%.4f" % [end_stamp[0], end_stamp[1]])
	print("DISASTER_SEED seed=%d" % director.last_seed)
	# Let the final snapshots reach the client before the host goes away.
	var linger := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < linger:
		await process_frame
	return ended and director.last_seed == seed


func _client(main: Node) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var manager: MatchManager = main.match_manager
	var hazards: Array[Node] = [main.meteor_shower, main.flood, main.tornado, main.earthquake, main.lightning, main.fire,
		main.rain, main.snowfall, main.rockslide, main.bee_swarm, main.ufo, main.volcano]
	var was_active := {}
	while (main.get_network_player_ids().size() != 2 or manager.players.size() != 2) and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	for hazard in hazards:
		was_active[hazard] = hazard.is_active()
	while manager.state == MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		for hazard in hazards:
			var active: bool = hazard.is_active()
			if active and not was_active[hazard]:
				var metadata: Dictionary = hazard.get_disaster_metadata()
				print("CLIENT_EVENT kind=start name=%s elapsed=%.4f" % [String(metadata.get("name", hazard.name)).replace(" ", "_"), manager.elapsed_time])
			was_active[hazard] = active
		await process_frame
	var ended := manager.state == MatchManager.MatchState.RESULTS
	print("CLIENT_EVENT kind=end name=match_end elapsed=%.4f" % manager.elapsed_time)
	return ended
