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
		var dead: PartyPlayer = main._player_nodes[guest_id]
		var dead_position := dead.global_position
		await create_timer(0.15).timeout
		_expect(dead.global_position == dead_position and dead.velocity == Vector3.ZERO and not dead.is_knocked_down(), "Server must freeze eliminated capsule despite subsequent client inputs")
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
	_test_camera_snapshot_ownership(main, local_id)
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
		if role == "guest":
			var dead: PartyPlayer = main._player_nodes[local_id]
			var dead_position := dead.global_position
			var jump_sequence: int = main._local_jump_sequence
			main.submit_local_movement_input(Vector2.RIGHT, true, true, true, -0.7)
			_expect(main._local_jump_sequence == jump_sequence, "Dead local input cannot queue a jump for the next rematch")
			# Bypass local controls to exercise authoritative rejection as well.
			main._submit_movement_input.rpc_id(1, Vector2.RIGHT, true, true, true, -0.7, main._local_movement_sequence + 1)
			await create_timer(0.1).timeout
			_expect(dead.global_position == dead_position and dead.velocity == Vector3.ZERO and not dead.visual.visible and not dead.can_grab_objects(), "Eliminated client must stay frozen after forged live input and subsequent snapshots")
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


func _test_camera_snapshot_ownership(main: Node, local_id: int) -> void:
	var remote_id := 0
	for id: int in main.get_network_player_ids():
		if id != local_id:
			remote_id = id
	var local := main._player_nodes[local_id] as PartyPlayer
	var remote := main._player_nodes[remote_id] as PartyPlayer
	var peer_ids := PackedInt32Array([remote_id, local_id])
	var origins := PackedVector3Array([remote.global_position, local.global_position])
	var velocities := PackedVector3Array([remote.velocity, local.velocity])
	var original_yaws := PackedFloat32Array([remote.get_camera_yaw(), local.get_camera_yaw()])
	var original_facing := PackedFloat32Array([remote.get_visual_yaw(), local.get_visual_yaw()])
	var positions := PackedVector3Array([origins[0] + Vector3(0.1, 0, 0), origins[1] + Vector3(0, 0, 0.2)])
	var snapshot_velocities := PackedVector3Array([Vector3(1, 0, 2), Vector3(-2, 0, 1)])
	# Reverse peer order and cross the angle boundary: don't confuse array index with ownership.
	for yaw: float in [0.73, -3.12]:
		local.set_camera_yaw(yaw)
		for _echo in 6:
			main._apply_movement_snapshots(peer_ids, positions, snapshot_velocities, PackedFloat32Array([1.2, -0.41 if yaw > 0 else 3.12]), PackedFloat32Array([-0.7, 0.3]), PackedByteArray([0, 0]))
			_expect(is_equal_approx(local.get_camera_yaw(), yaw) and is_equal_approx(local.camera_pivot.rotation.y, yaw), "Delayed snapshots must not rewind local aim after input stops")
		_expect(is_equal_approx(remote.get_camera_yaw(), 1.2), "Remote camera yaw must still replicate")
		_expect(local.global_position.is_equal_approx(positions[1]) and remote.global_position.is_equal_approx(positions[0]), "Both player positions must remain server-authoritative")
		_expect(local.velocity.is_equal_approx(snapshot_velocities[1]) and remote.velocity.is_equal_approx(snapshot_velocities[0]), "Both velocities must remain server-authoritative")
		_expect(is_equal_approx(local.get_visual_yaw(), 0.3) and is_equal_approx(remote.get_visual_yaw(), -0.7), "Both visual facings must still replicate independently of local camera")
	# Restore synchronous fixture changes before sending real input or ready requests.
	local.set_camera_yaw(original_yaws[1])
	main._apply_movement_snapshots(peer_ids, origins, velocities, original_yaws, original_facing, PackedByteArray([0, 0]))


func _wait_until(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(predicate.call(), message)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
