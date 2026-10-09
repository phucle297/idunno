extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
var checks := 0
var failures: Array[String] = []
var peers: Array[Node] = []
var review_size := Vector2i.ZERO


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-resolution="):
			var dimensions := argument.trim_prefix("--review-resolution=").split("x")
			review_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	_run.call_deferred()


func _make_peer(label: String) -> Node:
	var container := Node3D.new()
	container.name = label
	root.add_child(container)
	set_multiplayer(SceneMultiplayer.new(), container.get_path())
	var main := MainScene.instantiate()
	main.name = "Main"
	container.add_child(main)
	# This fixture tests real ENet session control, not shared-world physics.
	# Separate copies spatially and disable movement/prop broadcasts.
	main.position.x = peers.size() * 200.0
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.get_node("Player").set_physics_process(false)
	peers.append(main)
	return main


func _run() -> void:
	var server := _make_peer("Server")
	_expect(server.host_game(0, 3, true) == OK, "Dedicated server must bind an ephemeral port")
	await process_frame
	_expect(not (server.multiplayer as SceneMultiplayer).server_relay, "Dedicated rooms must not relay client-to-client traffic")
	_expect(server.get_network_role() == "server" and server.match_manager.players.is_empty() and server.get_network_player_ids().is_empty(), "Dedicated server must have no phantom participant")
	_expect(server.get_room_owner_id() == 0 and not server.can_control_session() and not server.set_local_ready(true), "Server is not the room owner or a ready player")
	_expect(not server.get_node("Player/Visual").visible and server.get_node("Player/CollisionShape3D").disabled and not server.get_node("Player/CameraPivot/SpringArm3D/Camera3D").current, "Placeholder must have no mesh, collider or camera")
	for component: Node in [server.get_node("GrabManager"), server.meteor_shower, server.flood, server.tornado, server.earthquake, server.lightning, server.fire]:
		_expect(component._players.is_empty(), "%s must not register a server player" % component.name)
	_expect(not server.start_network_match(), "Empty dedicated lobby cannot start")
	var port: int = server.multiplayer.multiplayer_peer.host.get_local_port()
	var clients: Array[Node] = []
	var ids: Array[int] = []
	for index: int in 3:
		var client := _make_peer("Client%d" % index)
		client._prepare_offline_player_for_join()
		_expect(client.join_game("127.0.0.1", port) == OK, "Client %d must start ENet join" % index)
		await _wait_until(func() -> bool: return client.match_manager.players.size() == index + 1 and client.get_room_owner_id() > 1, "Client %d must receive the dedicated roster" % index)
		clients.append(client)
		ids.append(client.multiplayer.get_unique_id())
		_expect(server.get_room_owner_id() == ids[0], "First connected player owns the room")
	await _wait_until(func() -> bool: return clients[0].match_manager.players.size() == 3, "Full roster must reach every client")
	_expect(server.multiplayer.get_peers().size() == 3 and server.match_manager.players.size() == 3, "Dedicated capacity includes three clients, not two plus a host")
	# Collider disabling is deferred to the physics boundary, not immediate on snapshot receipt.
	await physics_frame
	await process_frame
	_expect(not server._execute_owner_action(ids[0], "start", server._session_revision), "Owner cannot start an unready roster")
	for client: Node in clients:
		_expect(client.multiplayer.get_peers() == PackedInt32Array([1]), "Transport must expose only authority while gameplay snapshots retain all players")
		_expect(not client.match_manager.players.has(1) and not client.get_network_player_ids().has(1), "Clients must not retain peer 1 in roster or scene registry")
		_expect(not client.get_node("Player/Visual").visible and client.get_node("Player/CollisionShape3D").disabled, "Clients must disable their placeholder body")
		client.set_local_ready(true)
	await _wait_until(func() -> bool: return clients[0].match_manager.can_start_match() and server.match_manager.can_start_match(), "Readiness must reach server and owner")
	var owner := clients[0]
	var guest := clients[1]
	_expect(owner.can_control_session() and not guest.can_control_session(), "Only the owner can control the session")
	owner._update_lobby_ui()
	guest._update_lobby_ui()
	_expect(owner.get_node("Interface/LobbyPanel/Start").visible and not owner.get_node("Interface/LobbyPanel/Start").disabled and not guest.get_node("Interface/LobbyPanel/Start").visible, "Start control must belong only to the ready owner")
	var roster: ScrollContainer = owner.get_node("Interface/LobbyPanel/PlayerList")
	_expect(roster.rows[ids[0]].get_node("Content/Identity/Markers").text == "OWNER · YOU", "Roster must identify owner without claiming a host player")
	await _capture(owner, "owner-ready")
	await _capture(guest, "guest-ready")
	var lobby_revision: int = owner._session_revision
	guest._request_session_action.rpc_id(1, "start", lobby_revision)
	await create_timer(0.2).timeout
	_expect(server.match_manager.state == MatchManager.MatchState.LOBBY and not guest.start_network_match(), "Forged guest start RPC must fail on server, not just in UI")
	_expect(not server._execute_owner_action(ids[0], "unknown", lobby_revision), "Unknown owner actions must be rejected")
	_expect(owner.start_network_match(), "Owner must queue a start request")
	await _wait_until(func() -> bool: return server.match_manager.state == MatchManager.MatchState.ACTIVE and guest.match_manager.state == MatchManager.MatchState.ACTIVE, "Owner RPC must start authoritative match")
	_expect(server.match_manager.get_alive_count() == 3 and not server.match_manager.players.has(1), "Alive count must contain clients only")
	_expect(not server._execute_owner_action(ids[0], "lobby", server._session_revision), "Owner cannot return ACTIVE match to lobby")
	server.disaster_director.cleanup()
	for cycle: int in 5:
		server.match_manager.tick_match(server.match_manager.match_duration)
		await _wait_until(func() -> bool: return owner.match_manager.state == MatchManager.MatchState.RESULTS and guest.match_manager.state == MatchManager.MatchState.RESULTS, "Results must reach both clients")
		_expect(owner.match_manager.winner_ids.size() == 3 and not owner.match_manager.winner_ids.has(1), "Timeout winners cannot include the server")
		if cycle == 0:
			_expect(owner.get_node("Interface/ResultsPanel/Actions/Rematch").visible and not guest.get_node("Interface/ResultsPanel/Actions/Rematch").visible, "Only owner results expose session actions")
			await _capture(owner, "owner-results")
			await _capture(guest, "guest-results")
		var results_revision: int = owner._session_revision
		guest._request_session_action.rpc_id(1, "rematch", results_revision)
		owner._request_session_action.rpc_id(1, "rematch", lobby_revision)
		await create_timer(0.15).timeout
		_expect(server.match_manager.state == MatchManager.MatchState.RESULTS, "Non-owner and prior-round rematch RPCs must not mutate results")
		_expect(owner.restart_network_match(), "Owner must queue rematch %d" % (cycle + 1))
		await _wait_until(func() -> bool: return owner.match_manager.state == MatchManager.MatchState.ACTIVE and server.match_manager.state == MatchManager.MatchState.ACTIVE, "Rematch must return to ACTIVE")
		_expect(not server._execute_owner_action(ids[0], "rematch", results_revision), "Duplicate results request must be rejected after rematch")
		_expect(server.match_manager.get_alive_count() == 3 and server.match_manager.get_health(ids[1]) == 100.0 and server.get_room_owner_id() == ids[0], "Rematch must restore players without changing ownership")
		server.disaster_director.cleanup()
	# Owner leaves while two other survivors remain: match must continue.
	server.disaster_director.start_directing()
	var old_revision: int = server._session_revision
	owner.multiplayer.multiplayer_peer.close()
	owner._on_server_disconnected()
	await _wait_until(func() -> bool: return server.get_room_owner_id() == ids[1] and guest.get_room_owner_id() == ids[1], "Ownership must transfer and replicate")
	_expect(server.match_manager.state == MatchManager.MatchState.ACTIVE and server.disaster_director.running and server.match_manager.get_alive_count() == 2, "Owner departure must not end a match with two survivors")
	_expect(not server._execute_owner_action(ids[0], "start", server._session_revision) and not server._execute_owner_action(ids[1], "start", old_revision), "Departed owner and old ownership revision must be rejected")
	server.disaster_director.cleanup()
	var late := _make_peer("LateClient")
	late._prepare_offline_player_for_join()
	_expect(late.join_game("127.0.0.1", port) == OK, "Late-client connection must start")
	await _wait_until(func() -> bool: return not late.is_network_session(), "Active-match join must reject and recover rather than leave a ghost")
	_expect(server.match_manager.players.size() == 2 and server.get_network_player_ids().size() == 2 and server.get_room_owner_id() == ids[1], "Rejected join must not alter participants or owner")
	server.match_manager.tick_match(server.match_manager.match_duration)
	await _wait_until(func() -> bool: return guest.match_manager.state == MatchManager.MatchState.RESULTS, "New owner must receive results")
	# Transfer again in RESULTS: the formerly waiting client must gain actions.
	guest.multiplayer.multiplayer_peer.close()
	guest._on_server_disconnected()
	var last := clients[2]
	await _wait_until(func() -> bool: return last.get_room_owner_id() == ids[2] and last.match_manager.players.size() == 1, "Results ownership transfer must replicate")
	_expect(last.get_node("Interface/ResultsPanel/Actions/Rematch").visible and last.get_node("Interface/ResultsPanel/Prompt").text == "PRESS ENTER TO REMATCH", "Results must refresh actions when owner changes without state change")
	await _capture(last, "transferred-owner-results")
	_expect(last.return_to_lobby(), "New owner must queue return-to-lobby")
	await _wait_until(func() -> bool: return last.match_manager.state == MatchManager.MatchState.LOBBY and server.match_manager.state == MatchManager.MatchState.LOBBY, "Owner lobby request must reset authoritative match")
	_expect(not server.match_manager.is_player_ready(ids[2]) and server.match_manager.get_health(ids[2]) == 100.0 and not server.disaster_director.running, "Lobby must reset health/readiness/disasters")
	last.multiplayer.multiplayer_peer.close()
	last._on_server_disconnected()
	await _wait_until(func() -> bool: return server.match_manager.players.is_empty(), "Last disconnect must clear registries")
	_expect(server.get_room_owner_id() == 0 and server.get_network_player_ids().is_empty(), "Empty server must clear owner without creating a host")
	for component: Node in [server.get_node("GrabManager"), server.meteor_shower, server.flood, server.tornado, server.earthquake, server.lightning, server.fire]:
		_expect(component._players.is_empty(), "Last disconnect must clear %s registry" % component.name)
	# Asymmetric peer IDs prove transfer uses connection order, not smallest ID.
	_expect(server._spawn_server_network_player(90, "First", Vector3.ZERO), "Transfer fixture must register owner")
	_expect(server._spawn_server_network_player(8, "Second", Vector3.ZERO), "Transfer fixture must register second")
	_expect(server._spawn_server_network_player(2, "Third", Vector3.ZERO), "Transfer fixture must register third")
	server._room_owner_id = 90
	server._on_network_peer_disconnected(90)
	_expect(server.get_room_owner_id() == 8, "Oldest remaining connection must win over lower numeric peer ID")
	server._on_network_peer_disconnected(8)
	server._on_network_peer_disconnected(2)
	# All disconnected clients recover an actionable, visible offline player.
	await _wait_until(func() -> bool: return not last.is_network_session(), "Disconnected client must restore offline state")
	_expect(last.get_network_player_ids() == [1] and last.get_node("Player").process_mode == Node.PROCESS_MODE_INHERIT and last.get_node("Player/Visual").visible, "Recovery must re-enable placeholder as the solo player")
	for main: Node in peers:
		main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	for main: Node in peers:
		main.multiplayer.multiplayer_peer.close()
		main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		var container := main.get_parent()
		set_multiplayer(null, container.get_path())
		container.free()
	await process_frame
	if failures.is_empty():
		print("DEDICATED_SERVER_OK checks=%d clients=3 rematches=5 owner_transfer=active_and_results real_enet=passed" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _wait_until(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(predicate.call(), message)


func _capture(main: Node, state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-dir="):
			continue
		_expect(review_size != Vector2i.ZERO, "Rendered review requires explicit --review-resolution")
		for candidate: Node in peers:
			candidate.get_node("Interface").visible = candidate == main
			# Directional lights ignore the copies' spatial separation.
			candidate.get_node("Sun").visible = candidate == main
		var local_id: int = main.multiplayer.get_unique_id()
		main._player_nodes[local_id].get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
		# Late fixture initialization reapplies window settings; restore requested review size.
		root.size = review_size
		for frame: int in 4:
			await process_frame
		_expect(root.size == review_size, "Capture must retain the requested review resolution")
		_expect(main.get_node("Interface/LobbyPanel" if "ready" in state else "Interface/ResultsPanel").is_visible_in_tree(), "Captured state must actually be visible")
		await RenderingServer.frame_post_draw
		var path := argument.trim_prefix("--capture-dir=").path_join("dedicated-%s-%dx%d.png" % [state, root.size.x, root.size.y])
		var image := root.get_texture().get_image()
		_expect(image.get_size() == review_size, "Saved framebuffer must match requested resolution")
		_expect(image.save_png(path) == OK, "Dedicated review capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
