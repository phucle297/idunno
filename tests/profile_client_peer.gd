extends SceneTree
## Driven by the real-service Python fixture, with disposable credentials only.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--room-lifecycle" in OS.get_cmdline_user_args():
		await _run_room()
		return
	var client = (load("res://game/session/profile_client.gd") as GDScript).new()
	var expected_failure := false
	var opening := "--open-pending" in OS.get_cmdline_user_args()
	var owned_count := ToyCharacterVisual.starter_ids().size()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-service-url="):
			client.service_url = argument.trim_prefix("--profile-service-url=")
		elif argument.begins_with("--profile-file="):
			client.credential_path = argument.trim_prefix("--profile-file=")
		elif argument == "--expect-failure":
			expected_failure = true
		elif argument.begins_with("--owned-count="):
			owned_count = argument.trim_prefix("--owned-count=").to_int()
	if client.credential_path.is_empty():
		quit(1)
		return
	var outcome: Dictionary = {}
	client.profile_received.connect(func(profile: Dictionary) -> void: outcome["profile"] = profile)
	client.box_opened.connect(func(receipt: Dictionary) -> void: outcome["opened"] = receipt)
	client.failed.connect(func(message: String) -> void: outcome["failure"] = message)
	root.add_child(client)
	client.ensure_profile()
	var deadline := Time.get_ticks_msec() + 12000
	while outcome.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := outcome.has("failure") if expected_failure else outcome.has("profile")
	if passed and not expected_failure:
		var profile: Dictionary = outcome.profile
		passed = not profile.has("credential") and not profile.has("credential_hash") and profile.owned.size() == owned_count and (profile.pending.size() == 1 if opening else profile.pending.is_empty())
		if passed and opening:
			client.open_box(profile.pending[0].box_id)
			while not outcome.has("opened") and not outcome.has("failure") and Time.get_ticks_msec() < deadline:
				await process_frame
			passed = outcome.has("opened") and not outcome.opened.has("credential")
			if passed:
				outcome.erase("profile")
				client.ensure_profile()
				while not outcome.has("profile") and not outcome.has("failure") and Time.get_ticks_msec() < deadline:
					await process_frame
				passed = outcome.has("profile") and outcome.opened.cosmetic_id in outcome.profile.owned and outcome.profile.pending.is_empty()
				if passed:
					print("PROFILE_CLIENT_OPEN_OK")
		if passed:
			print("PROFILE_CLIENT_PEER_OK profile_id=%s equipped=%s" % [profile.profile_id, profile.equipped])
	elif passed:
		print("PROFILE_CLIENT_REJECTED_OK")
	if not passed:
		push_error("Profile client did not produce the expected safe outcome")
	client.cancel()
	client.free()
	await process_frame
	quit(0 if passed else 1)


func _run_room() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	main.room_client.service_url = main._argument_value("--profile-service-url=")
	main.room_client.profile_client.credential_path = main._argument_value("--profile-file=")
	var outcome: Dictionary = {}
	main.room_client.profile_client.profile_received.connect(func(profile: Dictionary) -> void: outcome["profile"] = profile)
	main.room_client.ticket_received.connect(func(ticket: Dictionary) -> void: outcome["ticket"] = ticket)
	main.room_client.failed.connect(func(message: String) -> void: outcome["failure"] = message)
	var panel: Panel = main.get_node("Interface/LobbyPanel")
	main._set_lobby_visible(true)
	panel.get_node("RoomId").text = "PROFILE-RESTART"
	panel.get_node("Join" if main._has_argument("--join-room") else "Host").pressed.emit()
	var deadline := Time.get_ticks_msec() + 15000
	while not outcome.has("failure") and Time.get_ticks_msec() < deadline:
		if main.is_network_session() and main.get_room_owner_id() > 1 and main.match_manager.players.has(main.multiplayer.get_unique_id()):
			break
		await process_frame
	var expected_failure: bool = main._has_argument("--expect-failure")
	var passed: bool
	if expected_failure:
		passed = outcome.has("failure") and not outcome.has("ticket") and not main.room_client.busy and not main.is_network_session() and main.get_network_player_ids() == [1] and main.get_node("Player").accepts_local_input() and panel.get_node("RoomId").editable
		if passed:
			print("ROOM_PROFILE_REJECTED_OK solo=preserved retry=available")
	else:
		passed = outcome.has("profile") and outcome.has("ticket") and main.is_network_session() and main.get_room_owner_id() > 1 and main.match_manager.players.has(main.multiplayer.get_unique_id())
		if passed:
			var profile: Dictionary = outcome.profile
			passed = not profile.has("credential") and not outcome.ticket.has("profile_id") and main.room_admission.profile_ids.is_empty() and not profile.profile_id in JSON.stringify(main._create_playable_snapshot())
		if passed:
			# Ticket is a secret: disposable private file, never stdout/arguments.
			var path: String = main._argument_value("--profile-report=")
			var file := FileAccess.open(path, FileAccess.WRITE)
			passed = file != null
			if passed:
				passed = FileAccess.set_unix_permissions(path, 384) == OK
				if passed:
					file.store_string(JSON.stringify(outcome))
					file.flush()
					passed = file.get_error() == OK
				file.close()
		if passed:
			main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 500, 1500)
			print("ROOM_PROFILE_CONNECTED_OK")
		if passed and main._has_argument("--hold-room"):
			deadline = Time.get_ticks_msec() + 15000
			while main.is_network_session() and Time.get_ticks_msec() < deadline:
				await process_frame
			passed = not main.is_network_session() and main.get_network_player_ids() == [1] and panel.get_node("RoomId").editable and "Room server disconnected" in panel.get_node("Status").text
			if passed:
				print("ROOM_PROFILE_SERVICE_LOSS_OK solo=restored retry=available")
	if not passed:
		push_error("Integrated profile/room client did not produce the expected safe outcome")
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	quit(0 if passed else 1)
