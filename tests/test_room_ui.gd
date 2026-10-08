extends SceneTree

var checks := 0
var failures: Array[String] = []
var review_size := Vector2i.ZERO
var main: Node
var panel: Panel


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-resolution="):
			var parts := argument.trim_prefix("--review-resolution=").split("x")
			review_size = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	_expect(ProjectSettings.get_setting("network/room_service_url", "") == "https://server.permees.com", "Build must configure the public room service without a launcher")
	var override_url: String = main._argument_value("--room-service-url=")
	_expect(main.room_client.service_url == ("https://server.permees.com" if override_url.is_empty() else override_url), "Explicit development endpoint must override the shipped default")
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.get_node("Player").set_physics_process(false)
	panel = main.get_node("Interface/LobbyPanel")
	main._set_lobby_visible(true)
	await _settle()
	_expect(not main._direct_ip_mode and panel.get_node("RoomId").visible and not panel.get_node("Address").visible, "Room ID must be the default; raw IP must be explicitly opted in")
	_expect(panel.get_node("Password").secret and panel.get_node("RoomIdLabel").text == "ROOM ID", "Room/password fields must be labelled and password masked")
	_expect(root.gui_get_focus_owner() == panel.get_node("RoomId"), "Default lobby must focus room ID")
	for name: String in ["Password", "Host", "Join", "PlayerList", "ConnectionMode", "Close", "RoomId"]:
		await _key(KEY_TAB)
		_expect(root.gui_get_focus_owner() == panel.get_node(name), "Default focus order must reach %s" % name)
	await _capture("default")
	var before: Dictionary = main._create_playable_snapshot().duplicate(true)
	main.room_client.service_url = ""
	panel.get_node("Host").pressed.emit()
	_expect("not configured" in panel.get_node("Status").text and main._create_playable_snapshot() == before, "Missing operator URL must explain the error without removing solo state")
	main.room_client.service_url = "http://192.0.2.1:29800"
	panel.get_node("Host").pressed.emit()
	_expect("requires HTTPS" in panel.get_node("Status").text, "Remote HTTP must never send the optional password")
	main.room_client.service_url = "http://127.0.0.1:29800"
	for id: String in ["", "ab", "a b", "../room"]:
		panel.get_node("RoomId").text = id
		panel.get_node("Join").pressed.emit()
		_expect("3–24" in panel.get_node("Status").text and not main.room_client.busy, "Invalid join ID must be rejected before HTTP")
	panel.get_node("RoomId").text = "FRIENDS-42"
	panel.get_node("Password").text = "é".repeat(65)
	panel.get_node("Host").pressed.emit()
	_expect("128 UTF-8" in panel.get_node("Status").text, "Password byte limit must distinguish multibyte text from character count")
	panel.get_node("Password").clear()
	var expected_errors := {
		"unknown_room": "Room not found", "duplicate_room_id": "already taken",
		"bad_password": "Wrong password", "room_full": "Room is full",
		"incompatible_version": "Build mismatch", "match_in_progress": "Match in progress",
		"rate_limited": "Wait a minute", "service_full": "servers are busy",
		"server_start_failed": "could not start", "server_start_timeout": "startup timed out",
	}
	for code: String in expected_errors:
		main.room_client._completed(HTTPRequest.RESULT_SUCCESS, 409, [], JSON.stringify({"error": code}).to_utf8_buffer())
		_expect(expected_errors[code] in panel.get_node("Status").text, "Service error %s must offer a meaningful retry" % code)
		_expect(not main.room_client.busy and panel.get_node("RoomId").editable and not panel.get_node("Join").disabled and main._create_playable_snapshot() == before, "Lookup failure must unlock retry and preserve gameplay")
	main.room_client._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	_expect("unavailable" in panel.get_node("Status").text, "Transport errors must be retryable")
	await _capture("service-error")
	for invalid: Dictionary in [
		{"protocol": 2, "build": "development"},
		{"protocol": 1, "build": "old"},
		{"protocol": 1, "build": "development", "port": 1},
		{"protocol": 1, "build": "development", "room_id": "VALID", "address": "127.0.0.1", "port": 65536, "token": "token"},
		{"protocol": 1, "build": "development", "room_id": "VALID", "address": "127.0.0.1", "port": 1.5, "token": "token"},
	]:
		main.room_client._completed(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify(invalid).to_utf8_buffer())
		_expect(not main.is_network_session() and main._create_playable_snapshot() == before, "Invalid/incompatible response must not create a UDP connection or reset gameplay")
	main.room_client.busy = true
	main._update_lobby_ui()
	_expect(not panel.get_node("RoomId").editable and panel.get_node("Join").disabled and panel.get_node("ConnectionMode").disabled, "Pending lookup must prevent duplicate/mode-changing requests")
	main._set_lobby_visible(false)
	_expect(not main.room_client.busy and main._create_playable_snapshot() == before, "Closing must cancel lookup without later joining or mutating solo state")
	main._set_lobby_visible(true)
	main._set_direct_ip_mode(true)
	_expect(panel.get_node("Address").visible and not panel.get_node("RoomId").visible and "Unauthenticated" in panel.get_node("Status").text, "Direct IP must retain a visibly labelled development mode")
	await _capture("direct-ip")
	panel.get_node("ConnectionMode").pressed.emit()
	_expect(not main._direct_ip_mode and root.gui_get_focus_owner() == panel.get_node("RoomId"), "Switching back must repair focus and restore room fields")
	# An open UDP sink never returns an ENet handshake: exercise the UI deadline.
	var sink := PacketPeerUDP.new()
	_expect(sink.bind(0, "127.0.0.1") == OK, "Timeout fixture must reserve an unused UDP endpoint")
	main._on_room_ticket_received({"room_id": "FRIENDS-42", "address": "127.0.0.1", "port": sink.get_local_port(), "token": "unused-ticket"})
	_expect(main.is_network_session() and main._room_connection_remaining == 10.0, "Ticket must start a bounded connection attempt")
	main._process(9.9)
	_expect(main.is_network_session(), "Connection must not time out before the deadline")
	main._process(0.2)
	_expect(not main.is_network_session() and main.get_network_player_ids() == [1] and panel.get_node("RoomId").editable and "Request a new ticket" in panel.get_node("Status").text, "Deadline must close ENet and restore solo/fresh-ticket retry")
	sink.close()
	# One production world/light only. A raw transport fixture supplies a real client ID.
	var server_root := Node.new()
	server_root.name = "TransportFixture"
	root.add_child(server_root)
	var server_api := SceneMultiplayer.new()
	set_multiplayer(server_api, server_root.get_path())
	var server := ENetMultiplayerPeer.new()
	_expect(server.create_server(0) == OK, "Review transport must open")
	server_api.multiplayer_peer = server
	main._prepare_offline_player_for_join()
	_expect(main.join_game("127.0.0.1", server.host.get_local_port()) == OK, "Review client must open")
	await _wait_until(func() -> bool: return main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Review client must connect")
	var local_id: int = main.multiplayer.get_unique_id()
	var remote_id := 1234 if local_id != 1234 else 5678
	var manager := MatchManager.new()
	server_root.add_child(manager)
	manager.register_player(local_id, "Local Player")
	manager.register_player(remote_id, "Teal Player")
	manager.set_player_ready(local_id, true)
	manager.set_player_ready(remote_id, true)
	main._room_id = "FRIENDS-42"
	panel.get_node("RoomId").text = "FRIENDS-42"
	for id: int in [local_id, remote_id]:
		main._spawn_network_player(id, "", Vector3(0, 0.05, 7))
		main._player_nodes[id].set_physics_process(false)
	var snapshot: Dictionary = manager.create_authoritative_snapshot()
	snapshot.merge({"dedicated_server": true, "room_owner_id": local_id, "session_revision": 1})
	main._apply_match_snapshot(snapshot)
	main._set_lobby_visible(true)
	_expect(panel.get_node("Start").visible and not panel.get_node("Start").disabled and not panel.get_node("ConnectionMode").visible, "Admitted owner must see enabled start, locked fields and no connection switch")
	_expect("room owner can start" in panel.get_node("Status").text, "Owner status must be explicit")
	await _capture("owner-ready")
	snapshot.room_owner_id = remote_id
	main._apply_match_snapshot(snapshot)
	main._update_lobby_ui()
	_expect(not panel.get_node("Start").visible and "waiting for room owner" in panel.get_node("Status").text, "Guest must wait, not gain Start authority")
	await _capture("guest-ready")
	manager.start_match()
	manager.apply_damage(remote_id, 100.0, "Meteor")
	snapshot = manager.create_authoritative_snapshot()
	snapshot.merge({"dedicated_server": true, "room_owner_id": local_id, "session_revision": 2})
	main._apply_match_snapshot(snapshot)
	_expect(main.get_node("Interface/ResultsPanel/Actions/Rematch").visible, "Owner results must retain session actions")
	await _capture("owner-results")
	snapshot.room_owner_id = remote_id
	main._apply_match_snapshot(snapshot)
	_expect(not main.get_node("Interface/ResultsPanel/Actions/Rematch").visible and "room owner" in main.get_node("Interface/ResultsPanel/Prompt").text.to_lower(), "Guest results must explain owner-only rematch")
	await _capture("guest-results")
	main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 100, 300)
	await create_timer(0.1).timeout
	server.close()
	server_api.multiplayer_peer = null
	await _wait_until(func() -> bool: return not main.is_network_session(), "Actual server loss must recover")
	_expect(panel.visible and panel.get_node("RoomId").editable and panel.get_node("Join").visible and not panel.get_node("Join").disabled and main.get_network_player_ids() == [1], "Room loss must restore editable ID/retry and exactly one offline participant")
	_expect("Room server disconnected" in panel.get_node("Status").text, "Room loss must not instruct users to enter raw IP")
	await _capture("recovery")
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	server_root.free()
	await process_frame
	if failures.is_empty():
		print("ROOM_UI_OK checks=%d resolution=%dx%d" % [checks, root.size.x, root.size.y])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	await _settle()


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _wait_until(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(predicate.call(), message)


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-dir="):
			continue
		_expect(review_size != Vector2i.ZERO, "Captures require explicit review resolution")
		root.size = review_size
		await _settle()
		var surface: Control = main.get_node("Interface/ResultsPanel") if "results" in state else panel
		_expect(surface.is_visible_in_tree(), "Captured surface must actually be visible")
		if surface == panel:
			var bounds := Rect2(Vector2.ZERO, panel.size)
			for name: String in ["RoomId", "Password", "Host", "Join", "Start", "PlayerList", "Status", "ConnectionMode", "Close"]:
				var control: Control = panel.get_node(name)
				if control.is_visible_in_tree():
					_expect(bounds.encloses(control.get_rect()), "Visible %s must fit inside lobby" % name)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_expect(image.get_size() == review_size, "Framebuffer must match requested resolution")
		var path := argument.trim_prefix("--capture-dir=").path_join("room-ui-%s-%dx%d.png" % [state, root.size.x, root.size.y])
		_expect(image.save_png(path) == OK, "Room review capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
