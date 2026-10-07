extends SceneTree

var role := ""
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	if role == "server":
		await _server(main)
	else:
		await _client(main)
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	if failures.is_empty():
		print("DEDICATED_NETWORK_%s_OK checks=%d rematches=5" % [role.to_upper(), checks])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _server(main: Node) -> void:
	_expect(main.get_network_role() == "server", "Server CLI must select playerless dedicated mode")
	await _wait_until(func() -> bool: return main.match_manager.players.size() == 2, "Both clients must register")
	var owner_id: int = main.get_room_owner_id()
	var guest_id := 0
	for id: int in main.match_manager.players:
		if id != owner_id:
			guest_id = id
	_expect(owner_id > 1 and guest_id > 1 and not main.match_manager.players.has(1), "Only clients may participate")
	var origins := {}
	for id: int in main.get_network_player_ids():
		origins[id] = main._player_nodes[id].global_position
	await _wait_until(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "Owner must start the ready server")
	main.disaster_director.cleanup()
	await _wait_until(func() -> bool:
		return main._player_nodes[owner_id].global_position.x - origins[owner_id].x > 0.75 and main._player_nodes[guest_id].global_position.x - origins[guest_id].x > 0.75,
		"Server physics must apply both clients' movement inputs")
	for cycle: int in 6:
		_expect(main.match_manager.apply_damage(guest_id, 100.0, "Dedicated smoke"), "Server must eliminate guest")
		_expect(main.match_manager.state == MatchManager.MatchState.RESULTS and main.match_manager.winner_ids == [owner_id], "Results must identify the actual surviving client")
		if cycle == 5:
			break
		await _wait_until(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "Owner rematch RPC must restart cycle %d" % (cycle + 1))
		main.disaster_director.cleanup()
		_expect(main.match_manager.get_health(guest_id) == 100.0 and main.get_room_owner_id() == owner_id, "Rematch must preserve owner and restore guest")
		# Hold ACTIVE long enough for both clients to observe the new round.
		await create_timer(0.25).timeout
	await create_timer(0.5).timeout
	# Simulate process shutdown: don't run gameplay against a closed server peer.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.multiplayer.multiplayer_peer.close()
	await create_timer(0.6).timeout


func _client(main: Node) -> void:
	await _wait_until(func() -> bool: return main.match_manager.players.size() >= 1 and main.get_room_owner_id() > 1, "Client must receive its initial roster")
	print("DEDICATED_CLIENT_CONNECTED role=%s" % role)
	await _wait_until(func() -> bool: return main.match_manager.players.size() == 2 and main.get_room_owner_id() > 1, "Client must receive dedicated roster")
	var local_id: int = main.multiplayer.get_unique_id()
	_expect(main.can_control_session() == (role == "owner"), "Only first client is room owner")
	main.set_local_ready(true)
	if role == "owner":
		await _wait_until(func() -> bool: return main.match_manager.can_start_match(), "Both clients must ready")
		_expect(main.start_network_match(), "Owner must send start request")
	await _wait_until(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "Client must receive ACTIVE")
	var origin: Vector3 = main._player_nodes[local_id].global_position
	Input.action_press("move_right")
	await _wait_until(func() -> bool: return main._player_nodes[local_id].global_position.x - origin.x > 0.75, "Client must observe authoritative rightward movement, not vertical falling")
	Input.action_release("move_right")
	for cycle: int in 6:
		await _wait_until(func() -> bool: return main.match_manager.state == MatchManager.MatchState.RESULTS, "Client must observe results cycle %d" % cycle)
		_expect(not main.match_manager.players.has(1) and main.match_manager.winner_ids == [main.get_room_owner_id()], "Replicated results must agree with server")
		_expect(main.get_node("Interface/ResultsPanel/Actions/Rematch").visible == (role == "owner"), "Results actions must reflect ownership")
		if cycle == 5:
			break
		if role == "owner":
			# Allow the guest's snapshot to arrive before asking for a rematch.
			await create_timer(0.25).timeout
			_expect(main.restart_network_match(), "Owner must send rematch")
		else:
			_expect(not main.restart_network_match(), "Guest cannot request rematch")
		await _wait_until(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "Client must observe rematch")
	await _wait_until(func() -> bool: return not main.is_network_session(), "Server close must recover client offline lobby")
	_expect(main.get_network_player_ids() == [1] and main.match_manager.players.size() == 1 and main.get_node("Player/Visual").visible, "Recovery must restore solo player")


func _wait_until(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(predicate.call(), message)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
