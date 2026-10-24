extends SceneTree

const TIMEOUT_MSEC := 15000
const ACK_DELAY_MSEC := 1200

var role := ""
var port := 29820
var failures: Array[String] = []
var checks := 0


class FixtureMain extends "res://game/main.gd":
	var fixture_hold_ack := true
	var fixture_depart_after_load := false
	var fixture_departure_released := false
	var fixture_departure_closed := false
	var fixture_active_peers: Array[int] = []
	var fixture_send_stale := false
	var fixture_stale_sender := 0
	var fixture_stale_generation := 0
	var fixture_abort_cleared_readiness := false

	func _abort_map_load() -> void:
		super._abort_map_load()
		fixture_abort_cleared_readiness = match_manager.players.keys().all(func(peer_id: int) -> bool:
			return not match_manager.is_player_ready(peer_id))

	@rpc("authority", "call_remote", "reliable")
	func fixture_release_departure() -> void:
		fixture_departure_released = true

	@rpc("any_peer", "call_remote", "reliable")
	func fixture_stale_sent(generation: int) -> void:
		var sender := multiplayer.get_remote_sender_id()
		if multiplayer.is_server() and match_manager.players.has(sender):
			fixture_stale_sender = sender
			fixture_stale_generation = generation

	@rpc("any_peer", "call_remote", "reliable")
	func fixture_active() -> void:
		var sender := multiplayer.get_remote_sender_id()
		if multiplayer.is_server() and match_manager.players.has(sender) and sender not in fixture_active_peers:
			fixture_active_peers.append(sender)

	func _acknowledge_map_load(generation: int, selected_map: String, connection: int) -> void:
		# Delay only the acknowledgement, not a duplicate of production loading.
		if fixture_depart_after_load:
			# The snapshot check must finish before departure can legitimately
			# cancel the barrier and resume lobby snapshots, even on a fast load.
			while not fixture_departure_released and _map_loading and generation == _map_load_generation and connection == _network_connection_generation and _network_mode:
				await get_tree().process_frame
			if not _map_loading or generation != _map_load_generation or connection != _network_connection_generation or not _network_mode:
				return
			process_mode = Node.PROCESS_MODE_DISABLED
			multiplayer.multiplayer_peer.close()
			fixture_departure_closed = true
			return
		if fixture_send_stale:
			_map_loaded.rpc_id(1, generation - 1, selected_map)
			fixture_stale_sent.rpc_id(1, generation)
		if fixture_hold_ack:
			await get_tree().create_timer(float(ACK_DELAY_MSEC) / 1000.0).timeout
		if not _map_loading or generation != _map_load_generation or connection != _network_connection_generation or not _network_mode:
			return
		_map_loaded.rpc_id(1, generation, selected_map)


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set_script(FixtureMain)
	main.name = "Main"
	main.fixture_send_stale = role == "replacement"
	root.add_child(main)
	await process_frame
	if role == "server":
		await _server(main)
	else:
		await _client(main)
	if is_instance_valid(main):
		main.process_mode = Node.PROCESS_MODE_DISABLED
		if main.multiplayer.multiplayer_peer != null:
			main.multiplayer.multiplayer_peer.close()
		main.free()
	await process_frame
	if failures.is_empty():
		print("MAP_LOADING_NETWORK_%s_OK checks=%d" % [role.to_upper(), checks])
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _server(main: Node) -> void:
	await _wait(func() -> bool: return main.match_manager.players.size() == 2, "two real ENet clients must join")
	await _wait(func() -> bool: return main.get_map_id() == "toy_harbor", "owner must select first map")
	await _wait(func() -> bool: return main._map_loading, "first Start must enter map-loading barrier")
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY, "server stays LOBBY while ACK is held")
	_expect(is_zero_approx(main.match_manager.elapsed_time), "elapsed time stays zero while loading")
	_expect(not main.disaster_director.running, "director stays stopped while loading")
	_expect(not main.request_map_change("toy_town"), "map changes are frozen while loading")
	_expect(not main.request_match_preset("hard"), "preset changes are frozen while loading")
	_expect(not main.set_local_ready(false), "ready changes are frozen while loading")
	_expect(not main.start_network_match(), "second Start is rejected while loading")
	var loading_sequence: int = main._match_snapshot_sequence
	await create_timer(0.1).timeout
	_expect(main._map_loading and main._match_snapshot_sequence == loading_sequence, "held loading does not queue redundant lobby snapshots")
	main.fixture_release_departure.rpc()
	await _wait(func() -> bool: return main.match_manager.players.size() == 1, "departing held client aborts the barrier")
	_expect(not main._map_loading and main.match_manager.state == MatchManager.MatchState.LOBBY, "departure abort returns server to lobby")
	main._update_lobby_ui()
	_expect("Loading cancelled" in main.get_node("Interface/LobbyPanel/Status").text, "cancellation reason survives the normal lobby refresh")
	await _wait(func() -> bool: return main.match_manager.players.size() == 2, "replacement client must join after abort")
	_expect(main.request_map_change("toy_town"), "retry selects the second map after abort")
	await _wait(func() -> bool: return main.get_map_id() == "toy_town", "second map selection replicates")
	for peer_id: int in main.match_manager.players:
		main.match_manager.set_player_ready(peer_id, true)
	_expect(main.start_network_match(), "retry Start is accepted")
	main.fixture_abort_cleared_readiness = false
	main._map_load_deadline = Time.get_ticks_msec() - 1
	await _wait(func() -> bool: return not main._map_loading, "an expired loading deadline cancels through the normal process tick")
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY and is_zero_approx(main.match_manager.elapsed_time) and not main.disaster_director.running, "timeout cannot advance time or hazards")
	_expect(main.fixture_abort_cleared_readiness, "timeout atomically clears readiness before any subsequent Ready RPC")
	for peer_id: int in main.match_manager.players:
		main.match_manager.set_player_ready(peer_id, true)
	_expect(main.start_network_match(), "Start remains available after timeout recovery")
	await _wait(func() -> bool: return main._map_loading, "retry enters a fresh generation")
	var generation: int = main._map_load_generation
	await _wait(func() -> bool: return main.fixture_stale_generation == generation, "registered replacement sends a real stale-generation ACK for the current map")
	_expect(main.fixture_stale_sender in main._map_load_waiting, "stale ACK cannot remove the registered sender from the current barrier")
	_expect(main._map_loading and main.match_manager.state == MatchManager.MatchState.LOBBY, "stale ACK cannot start subsequent generation")
	await _wait(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "retry starts only after replacement ACK")
	_expect(main.get_node("Sandbox").get_meta("map_anchors").map_id == "toy_town", "both map geometries prepare only at accepted Start")
	main.disaster_director.cleanup()
	await _wait(func() -> bool: return main.fixture_active_peers.size() == 2, "both clients must observe ACTIVE before authority teardown")
	print("MAP_LOADING_SERVER_BARRIER_OK held_ack=passed departure_abort=passed stale_ack=passed retry_map=toy_town timeout=passed")


func _client(main: Node) -> void:
	await _wait(func() -> bool: return main.match_manager.players.size() >= 1, "client receives initial roster")
	print("MAP_LOADING_CONNECTED role=%s" % role)
	await _wait(func() -> bool: return main.match_manager.players.size() == 2, "client receives roster")
	if role == "owner":
		_expect(main.request_map_change("toy_harbor"), "owner selects first map")
		main.set_local_ready(true)
		await _wait(func() -> bool: return main.match_manager.can_start_match(), "both peers ready first Start")
		_expect(main.start_network_match(), "owner queues first Start")
		await _wait(func() -> bool: return main.match_manager.players.size() == 1, "owner observes held client departure")
		await _wait(func() -> bool: return main.match_manager.players.size() == 2, "owner observes replacement")
		main.set_local_ready(true)
		await _wait(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "owner observes retry ACTIVE")
	else:
		main.fixture_depart_after_load = role == "departing"
		main.fixture_hold_ack = role != "departing"
		main.set_local_ready(true)
		if role == "departing":
			await _wait(func() -> bool: return main._map_loading, "held client receives loading RPC before disconnect")
			await _wait(func() -> bool: return main.fixture_departure_closed, "held client departs only after the authority's snapshot observation")
		else:
			await _wait(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "replacement ACK permits ACTIVE")
	if role != "departing":
		main.fixture_active.rpc_id(1)
		await _wait(func() -> bool: return not main.is_network_session(), "authority closes only after observing both active clients")
	print("MAP_LOADING_CLIENT_%s_OK" % role.to_upper())


func _wait(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(predicate.call(), message)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
