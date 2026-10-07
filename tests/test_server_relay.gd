extends SceneTree
## Isolate simultaneous ENet departures without gameplay RPCs or scene state.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var relay := "--relay=true" in OS.get_cmdline_user_args()
	var server := SceneMultiplayer.new()
	server.server_relay = relay
	var transport := ENetMultiplayerPeer.new()
	_expect(transport.create_server(0, 3) == OK, "Server must bind")
	server.multiplayer_peer = transport
	var clients: Array[SceneMultiplayer] = []
	for index: int in 3:
		var client := SceneMultiplayer.new()
		var peer := ENetMultiplayerPeer.new()
		_expect(peer.create_client("127.0.0.1", transport.host.get_local_port()) == OK, "Client must connect")
		client.multiplayer_peer = peer
		clients.append(client)
	var deadline := Time.get_ticks_msec() + 5000
	while server.get_peers().size() != 3 and Time.get_ticks_msec() < deadline:
		server.poll()
		for client: SceneMultiplayer in clients:
			client.poll()
		await process_frame
	_expect(server.get_peers().size() == 3, "All three clients must register")
	# Let relay notifications arrive before testing the simultaneous departures.
	for frame: int in 10:
		server.poll()
		for client: SceneMultiplayer in clients:
			client.poll()
		await process_frame
	for client: SceneMultiplayer in clients:
		_expect(client.get_peers().size() == (3 if relay else 1), "Clients should only discover other clients when relay is enabled")
	clients[0].multiplayer_peer.close()
	clients[1].multiplayer_peer.close()
	deadline = Time.get_ticks_msec() + 3000
	while server.get_peers().size() != 1 and Time.get_ticks_msec() < deadline:
		server.poll()
		clients[2].poll()
		await process_frame
	_expect(server.get_peers().size() == 1, "Concurrent departures must remove exactly two clients")
	_expect(clients[2].multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Remaining client must stay connected")
	# Shutdown must not create a second reproduction after the assertions.
	server.multiplayer_peer = null
	for client: SceneMultiplayer in clients:
		client.multiplayer_peer.close()
		client.multiplayer_peer = null
	transport.close()
	if failures.is_empty():
		print("SERVER_RELAY_OK relay=%s concurrent_departures=2 remaining=1" % relay)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
