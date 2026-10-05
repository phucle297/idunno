extends SceneTree

const TIMEOUT_MSEC := 10000
const ProbeScript = preload("res://tests/four_client_match_probe.gd")

var role := ""
var port := 29721


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	_run.call_deferred()


func _run() -> void:
	if role == "server":
		await _run_server()
	elif role == "client":
		await _run_client()
	else:
		push_error("Expected --role=server or --role=client")
		quit(1)


func _run_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 4)
	if error != OK:
		push_error("Unable to create four-client ENet server: %s" % error)
		quit(1)
		return
	root.multiplayer.multiplayer_peer = peer
	var probe := ProbeScript.new()
	probe.name = "MatchProbe"
	probe.configure("server")
	root.add_child(probe)
	probe.create_server_state()
	root.multiplayer.peer_connected.connect(func(peer_id: int) -> void:
		if not probe.register_server_player(peer_id):
			push_error("Unable to register connected peer %d" % peer_id)
	)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while not probe.all_clients_validated() and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := probe.all_clients_validated()
	if passed:
		print("FOUR_CLIENT_MATCH_SERVER_OK clients=4 alive=4 hazards=2")
	else:
		push_error("Server timed out or received a failed four-client snapshot acknowledgement")
	quit(0 if passed else 1)


func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", port)
	if error != OK:
		push_error("Unable to create four-client ENet client: %s" % error)
		quit(1)
		return
	root.multiplayer.multiplayer_peer = peer
	var probe := ProbeScript.new()
	probe.name = "MatchProbe"
	probe.configure("client")
	root.add_child(probe)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		await process_frame
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		push_error("Client timed out connecting to the four-client server")
		quit(1)
		return
	var local_manager := preload("res://game/match_manager.gd").new()
	root.add_child(local_manager)
	var rejected_client_mutation: bool = not local_manager.register_player(999, "Client Injection")
	probe.submit_ready.rpc_id(1)
	while not probe.client_passed and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := probe.client_passed and rejected_client_mutation
	if passed:
		print("FOUR_CLIENT_MATCH_CLIENT_OK peer=%d players=4 alive=4 hazards=2" % root.multiplayer.get_unique_id())
	else:
		push_error("Client did not validate the authoritative four-player match snapshot")
	await create_timer(0.1).timeout
	quit(0 if passed else 1)
