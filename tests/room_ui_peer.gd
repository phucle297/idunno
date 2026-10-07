extends SceneTree

var main: Node
var panel: Panel
var role := ""
var failures: Array[String] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
	_run.call_deferred()


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	panel = main.get_node("Interface/LobbyPanel")
	main._set_lobby_visible(true)
	panel.get_node("RoomId").text = " ui-friends "
	if role == "owner":
		panel.get_node("Password").text = "sample-password"
		panel.get_node("Host").pressed.emit()
	else:
		panel.get_node("Password").text = "wrong"
		panel.get_node("Join").pressed.emit()
		await _wait(func() -> bool: return not main.room_client.busy, "Wrong password lookup must finish")
		_expect("Wrong password" in panel.get_node("Status").text and not main.is_network_session() and main.match_manager.players.has(1), "Real bad-password response must leave solo gameplay and retry available")
		panel.get_node("Password").text = "sample-password"
		panel.get_node("Join").pressed.emit()
	await _wait(func() -> bool: return main.get_room_owner_id() > 1 and main.match_manager.players.has(main.multiplayer.get_unique_id()), "UI discovery must admit into gameplay")
	_expect(main._room_id == "UI-FRIENDS" and panel.get_node("RoomId").text == "UI-FRIENDS" and panel.get_node("Password").text.is_empty(), "Ticket must normalize displayed ID and clear password")
	_expect(main.can_control_session() == (role == "owner") and not panel.get_node("RoomId").editable, "Actual admission must establish owner/guest controls")
	print("ROOM_UI_CONNECTED role=%s" % role)
	panel.get_node("Ready").pressed.emit()
	if role == "owner":
		await _wait(func() -> bool: return main.match_manager.players.size() == 2 and main.match_manager.can_start_match() and not panel.get_node("Start").disabled, "Both clients must ready and refresh the owner Start control")
		_expect(not panel.get_node("Start").disabled, "Ready owner must have an enabled start button")
		panel.get_node("Start").pressed.emit()
	await _wait(func() -> bool: return main.match_manager.state == MatchManager.MatchState.ACTIVE, "Owner UI start must reach authoritative ACTIVE on both clients")
	main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 500, 1500)
	print("ROOM_UI_ACTIVE role=%s" % role)
	await _wait(func() -> bool: return not main.is_network_session(), "Killed room process must recover UI")
	_expect("Room server disconnected" in panel.get_node("Status").text and not panel.get_node("Join").disabled and main.get_network_player_ids() == [1], "Actual room crash must expose ID retry and restore solo")
	# The operator has removed the crashed room; a fresh create/join uses a new ticket.
	if role == "guest":
		await create_timer(0.8).timeout
	panel.get_node("Password").text = "sample-password"
	panel.get_node("Host" if role == "owner" else "Join").pressed.emit()
	await _wait(func() -> bool: return main.get_room_owner_id() > 1 and main.match_manager.players.has(main.multiplayer.get_unique_id()), "Same process must retry via UI and fresh discovery after crash")
	await _wait(func() -> bool: return main.match_manager.players.size() == 2, "Retried room must contain both real clients")
	await create_timer(0.3).timeout
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	if failures.is_empty():
		print("ROOM_UI_PEER_OK role=%s discovery=passed ready_start=passed crash_retry=passed" % role)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _wait(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(predicate.call(), message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
