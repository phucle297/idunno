extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--admission-file="):
			path = argument.trim_prefix("--admission-file=")
	var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if options.get("race_role", "") != "":
		await _run_admission_race(options)
		return
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
		var private_id: String = options.get("private_profile_id", "")
		if not private_id.is_empty() and (private_id in JSON.stringify(main._create_playable_snapshot()) or not main.room_admission.profile_ids.is_empty()):
			push_error("Validated profile identity must remain server-side, not in client snapshots")
			quit(1)
			return
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


func _run_admission_race(options: Dictionary) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	main._prepare_offline_player_for_join()
	if main.join_game(options.address, int(options.port), options.token) != OK:
		push_error("Admission race peer cannot open ENet connection")
		quit(1)
		return
	var role: String = options.race_role
	var stage_dir: String = options.stage_dir
	await _wait_race(func() -> bool:
		return main.get_room_owner_id() > 1 and main.match_manager.players.has(main.multiplayer.get_unique_id()), "%s must finish admission" % role)
	var local_id: int = main.multiplayer.get_unique_id()
	_stage(stage_dir, role + "-admitted")
	if role == "third":
		main.set_local_ready(true)
		_stage(stage_dir, "third-ready")
		await _wait_race(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "third must join the normal Start")
		_stage(stage_dir, "third-active")
	else:
		main.set_local_ready(true)
		await _wait_race(func() -> bool: return main.match_manager.players.get(local_id, {}).get("ready", false), "%s ready must replicate" % role)
		_stage(stage_dir, role + "-ready")
		if role == "owner":
			await _wait_race(func() -> bool: return FileAccess.file_exists(stage_dir.path_join("consume-held")), "third consume must be held before Start")
			await _wait_race(func() -> bool: return main.match_manager.can_start_match(), "owner and guest must be start-ready")
			if not main.start_network_match():
				push_error("Owner Start request must be delivered while admission is held")
				quit(1)
				return
			# Keep the consume request held while the authoritative action is delivered.
			var until := Time.get_ticks_msec() + 500
			while Time.get_ticks_msec() < until:
				if main._map_loading or main.match_manager.state != MatchManager.MatchState.LOBBY or not is_zero_approx(main.match_manager.elapsed_time) or main.disaster_director.running:
					push_error("ADMISSION_RACE_START_ADVANCED_WHILE_CONSUME_HELD")
					quit(1)
					return
				await process_frame
			_stage(stage_dir, "owner-start-blocked")
		await _wait_race(func() -> bool: return FileAccess.file_exists(stage_dir.path_join("consume-released")), "held consume must be released")
		await _wait_race(func() -> bool: return main.match_manager.players.size() == 3, "%s must receive third admitted roster" % role)
		if role == "owner":
			await _wait_race(func() -> bool: return main.match_manager.can_start_match(), "all three admitted peers must be ready")
			if not main.start_network_match():
				push_error("Owner Start must be accepted after admission completes")
				quit(1)
				return
		await _wait_race(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "%s must reach ACTIVE after normal Start" % role)
		_stage(stage_dir, role + "-active")
	await _wait_race(func() -> bool:
		return FileAccess.file_exists(stage_dir.path_join("owner-active")) and FileAccess.file_exists(stage_dir.path_join("guest-active")) and FileAccess.file_exists(stage_dir.path_join("third-active")), "all peers must observe ACTIVE before teardown")
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	print("ROOM_ADMISSION_RACE_%s_OK" % role.to_upper())
	quit(0)


func _wait_race(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not predicate.call():
		push_error(message)
		quit(1)


func _stage(directory: String, name: String) -> void:
	var marker := directory.path_join(name)
	var output := FileAccess.open(marker, FileAccess.WRITE)
	if output == null:
		push_error("Unable to write admission-race stage")
		quit(1)
		return
	output.store_string(name)
