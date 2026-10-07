extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._set_direct_ip_mode(true)
	var server_root := Node.new()
	server_root.name = "TestServer"
	root.add_child(server_root)
	var server_api := SceneMultiplayer.new()
	set_multiplayer(server_api, server_root.get_path())
	var server := ENetMultiplayerPeer.new()
	_expect(server.create_server(0) == OK, "Fixture server must bind an ephemeral UDP port")
	var port := server.host.get_local_port()
	server_api.multiplayer_peer = server
	main._prepare_offline_player_for_join()
	_expect(main.join_game("127.0.0.1", port) == OK, "Client join must start")
	main._update_lobby_ui()
	_expect(main.get_node("Interface/LobbyPanel/Ready").disabled and not main.get_node("Interface/LobbyPanel/Start").visible, "Joining must not enable readiness or expose host start")
	_expect("Joining" in main.get_node("Interface/LobbyPanel/Status").text, "Pending connection must retain a joining status rather than claiming readiness")
	_expect(not main.get_node("Interface/ResultsPanel").visible, "Joining from solo play must clear the results caused by removing the last offline participant")
	await _capture("joining")
	var deadline := Time.get_ticks_msec() + 5000
	while main.multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Client must complete the real ENet handshake")
	_expect(not main.flood._can_mutate() and not main.match_manager._can_mutate(), "Connected clients must not gain local gameplay authority")
	# Abrupt server shutdown can require ENet's timeout rather than a close packet.
	# Keep that timeout inside this fixture's five-second recovery deadline.
	main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 100, 300)
	# Allow MultiplayerAPI to observe the connection before closing its server.
	await create_timer(0.1).timeout
	server.close()
	server_api.multiplayer_peer = null
	deadline = Time.get_ticks_msec() + 5000
	while main.is_network_session() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check_offline_lobby(main, "server disconnect")
	# The same client can retry; unavailable-port failure must recover as well.
	main._prepare_offline_player_for_join()
	_expect(main.join_game("127.0.0.1", port) == OK, "Retry must start without duplicate signal connections")
	var client: ENetMultiplayerPeer = main.multiplayer.multiplayer_peer
	client.get_peer(1).set_timeout(1, 100, 300)
	deadline = Time.get_ticks_msec() + 5000
	while main.is_network_session() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check_offline_lobby(main, "connection failure")
	_expect("Connection failed" in main.get_node("Interface/LobbyPanel/Status").text, "A failed join must leave an actionable error")
	await _capture("connection-failed")
	_expect(server.create_server(0) == OK, "Fixture server must restart for a successful retry")
	server_api.multiplayer_peer = server
	main._prepare_offline_player_for_join()
	_expect(main.join_game("127.0.0.1", server.host.get_local_port()) == OK, "Client must retry successfully after failure")
	deadline = Time.get_ticks_msec() + 5000
	while main.multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Retry must establish a real connection")
	main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 100, 300)
	await create_timer(0.1).timeout
	main._spawn_network_player(2, "Remote Player", Vector3(4, 0, 4))
	main.flood.apply_presentation_snapshot({"phase": Flood.Phase.HOLDING, "water_level": 1.0, "electrified_remaining": 2.0})
	server.close()
	server_api.multiplayer_peer = null
	deadline = Time.get_ticks_msec() + 5000
	while main.is_network_session() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check_offline_lobby(main, "repeated disconnect")
	_expect(main.get_network_player_ids() == [1], "Disconnect must clear remote player nodes, not just the ENet peer")
	await create_timer(0.1).timeout
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer = null
	main.free()
	server_root.free()
	await process_frame
	if failures.is_empty():
		print("SESSION_LIFECYCLE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _check_offline_lobby(main: Node, context: String) -> void:
	_expect(not main.is_network_session() and main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "%s must replace the inactive ENet peer with offline multiplayer" % context)
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY and main.match_manager.players.keys() == [1], "%s must restore exactly one offline lobby player" % context)
	for component: Node in [main.get_node("GrabManager"), main.meteor_shower, main.flood, main.tornado, main.earthquake, main.lightning, main.fire]:
		_expect(component._players.keys() == [1] and component._can_mutate(), "%s must restore offline registry/authority for %s" % [context, component.name])
	_expect(main.get_node("Player").accepts_local_input(), "%s must restore local input authority" % context)
	_expect(main.get_node("Interface/LobbyPanel").visible, "%s must leave recovery controls accessible" % context)
	main._update_lobby_ui()
	_expect(main.get_node("Interface/LobbyPanel/Address").editable and main.get_node("Interface/LobbyPanel/Join").visible, "%s must restore editable fields and retry controls" % context)
	_expect(not main.disaster_director.running and main.flood.phase == Flood.Phase.IDLE, "%s must not continue stale server hazards" % context)


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await process_frame
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("lobby-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Lifecycle review capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
