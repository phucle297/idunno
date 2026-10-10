extends SceneTree

# Deterministic map-load contract: map identity is server-selected, travels in
# every playable snapshot, and lands on each client before the countdown.

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var server: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	server.name = "Server"
	root.add_child(server)
	var client: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	client.name = "Client"
	root.add_child(client)
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	await process_frame
	await process_frame
	# The game boots straight into a solo match; the map-selection contract
	# lives at the lobby boundary.
	server.match_manager.prepare_lobby()
	client.match_manager.prepare_lobby()

	# The playable snapshot is the transport for map identity.
	_expect(server.get_map_id() == "toy_town", "Default map identity must be toy_town")
	var snapshot: Dictionary = server._create_playable_snapshot()
	_expect(String(snapshot.get("map_id", "")) == "toy_town", "Playable snapshot must carry map identity")
	_expect(server.set_map_id("toy_harbor"), "Server must switch maps at the lobby boundary")
	_expect(String(server._create_playable_snapshot().get("map_id", "")) == "toy_harbor", "Snapshot map identity must follow the server selection")

	# A session snapshot loads the map on the client while still in the lobby,
	# which is the "before countdown" boundary.
	_expect(client.get_map_id() == "toy_town", "Client must start on its own default map")
	client._apply_match_snapshot(server._create_playable_snapshot())
	_expect(client.match_manager.state == MatchManager.MatchState.LOBBY, "Map convergence must happen before the countdown")
	_expect(client.get_map_id() == "toy_harbor", "Client must load the server-selected map")
	_expect(client.get_node("Sandbox").get_meta("map_anchors").map_id == "toy_harbor", "Client anchors must follow map identity")
	_expect(client.get_node("Sandbox").get_node_or_null("GangwayWest") != null, "Client must rebuild the selected map geometry")
	_expect(client.tornado.path_presets == client.map_anchors.tornado_paths, "Client hazards must wire to the loaded map anchors")

	# Re-applying the same identity must not rebuild the sandbox.
	var gangway: Node = client.get_node("Sandbox/GangwayWest")
	client._apply_match_snapshot(server._create_playable_snapshot())
	_expect(is_instance_valid(gangway) and gangway == client.get_node("Sandbox/GangwayWest"), "Same map identity must not rebuild the sandbox")

	# Local lobby switching and request validation.
	_expect(server.request_map_change("toy_town"), "Local lobby must accept a map change")
	_expect(server.get_map_id() == "toy_town", "Local map change must apply immediately")
	_expect(not server.request_map_change("not_a_map"), "Invalid map ids must be rejected")
	_expect(not client.request_map_change("not_a_map"), "Invalid map ids must be rejected on clients too")

	# Owner-action path used by dedicated rooms.
	server._network_mode = true
	server._dedicated_server = true
	server._room_owner_id = 2
	server._session_revision = 7
	server.match_manager.register_player(2, "Owner")
	_expect(not server._execute_owner_action(3, "map:toy_harbor", 7), "Non-owner map requests must be rejected")
	_expect(not server._execute_owner_action(2, "map:toy_harbor", 6), "Stale-revision map requests must be rejected")
	_expect(server._execute_owner_action(2, "map:toy_harbor", 7), "Owner map request must reach the server map switch")
	_expect(server.get_map_id() == "toy_harbor", "Owner map request must apply at the lobby boundary")

	# Once the countdown runs, map identity freezes for the round.
	server._network_mode = false
	server.match_manager.register_player(1, "Solo")
	server.match_manager.set_player_ready(1, true)
	server.match_manager.set_player_ready(2, true)
	_expect(server.match_manager.start_match(), "Fixture match must start")
	_expect(not server.request_map_change("toy_town"), "Map identity must freeze after countdown")
	_expect(server.get_map_id() == "toy_harbor", "An active match must not rebuild the map")

	_finish()


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP_IDENTITY_OK checks=%d" % checks)
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
