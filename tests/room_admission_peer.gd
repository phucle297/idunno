extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--admission-file="):
			path = argument.trim_prefix("--admission-file=")
	var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	main._prepare_offline_player_for_join()
	var error: Error = main.join_game(options.address, int(options.port), options.get("token", ""))
	if error != OK:
		push_error("Unable to open admission test connection")
		quit(1)
		return
	var admitted := false
	var deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		if main.get_room_owner_id() > 1 and main.match_manager.players.has(main.multiplayer.get_unique_id()):
			admitted = true
			break
		if not main.is_network_session():
			break
		await process_frame
	var expected: bool = options.get("accepted", true)
	if admitted == expected:
		print("ROOM_ADMISSION_PEER_OK admitted=%s" % admitted)
	else:
		push_error("Admission result differs from expected accepted=%s" % expected)
	if not expected and main.is_network_session():
		push_error("Rejected admission must recover to offline mode")
		quit(1)
		return
	if options.has("retry_token"):
		main._prepare_offline_player_for_join()
		if main.join_game(options.address, int(options.port), options.retry_token) != OK:
			quit(1)
			return
		deadline = Time.get_ticks_msec() + 7000
		while Time.get_ticks_msec() < deadline and main.get_room_owner_id() == 0:
			await process_frame
		if main.get_room_owner_id() <= 1 or not main.match_manager.players.has(main.multiplayer.get_unique_id()):
			push_error("Valid retry after admission rejection must register")
			quit(1)
			return
		print("ROOM_ADMISSION_RETRY_OK")
	if admitted:
		# Prove this is a gameplay participant, not just a transport handshake.
		main.set_local_ready(true)
		await create_timer(1.2).timeout
		if not main.match_manager.players[main.multiplayer.get_unique_id()].ready:
			push_error("Admitted peer cannot ready")
			quit(1)
			return
		if options.get("start", false):
			deadline = Time.get_ticks_msec() + 6000
			while Time.get_ticks_msec() < deadline and (main.match_manager.players.size() < 2 or not main.match_manager.can_start_match()):
				await process_frame
			if not main.start_network_match():
				push_error("Owner start request must be accepted after both clients ready")
				quit(1)
				return
			deadline = Time.get_ticks_msec() + 3000
			while Time.get_ticks_msec() < deadline and main.match_manager.state != MatchManager.MatchState.ACTIVE:
				await process_frame
			if main.match_manager.state != MatchManager.MatchState.ACTIVE:
				push_error("Admitted owner cannot start")
				quit(1)
				return
			print("ROOM_ADMISSION_ACTIVE_OK")
			await create_timer(4.0).timeout
		elif options.has("hold"):
			await create_timer(float(options.hold)).timeout
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	quit(0 if admitted == expected else 1)
