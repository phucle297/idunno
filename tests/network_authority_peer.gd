extends SceneTree

const TIMEOUT_MSEC := 5000
const ManagerScript = preload("res://game/match_manager.gd")
const GrabManagerScript = preload("res://game/grab_manager.gd")

var role := ""
var port := 29720


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
	var error := peer.create_server(port, 1)
	if error != OK:
		push_error("Unable to create ENet server: %s" % error)
		quit(1)
		return
	root.multiplayer.multiplayer_peer = peer
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while root.multiplayer.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if root.multiplayer.get_peers().is_empty():
		push_error("Server timed out waiting for a client peer")
		quit(1)
		return
	var client_id: int = root.multiplayer.get_peers()[0]
	var passed := _check_authority_matrix(1, client_id, true, false)
	print("NETWORK_AUTHORITY_SERVER_OK local=%d remote=%d" % [root.multiplayer.get_unique_id(), client_id])
	await create_timer(0.25).timeout
	quit(0 if passed else 1)


func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client("127.0.0.1", port)
	if error != OK:
		push_error("Unable to create ENet client: %s" % error)
		quit(1)
		return
	root.multiplayer.multiplayer_peer = peer
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		await process_frame
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		push_error("Client timed out connecting to the server peer")
		quit(1)
		return
	var client_id: int = root.multiplayer.get_unique_id()
	var passed := _check_authority_matrix(1, client_id, false, true)
	print("NETWORK_AUTHORITY_CLIENT_OK local=%d server=1" % client_id)
	await create_timer(0.25).timeout
	quit(0 if passed else 1)


func _check_authority_matrix(
	server_id: int,
	client_id: int,
	expected_server_player: bool,
	expected_client_player: bool
) -> bool:
	var host := Node3D.new()
	root.add_child(host)
	var server_player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	server_player.name = "ServerPlayer"
	server_player.set_multiplayer_authority(server_id)
	host.add_child(server_player)
	var client_player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	client_player.name = "ClientPlayer"
	client_player.set_multiplayer_authority(client_id)
	host.add_child(client_player)
	server_player.set_physics_process(false)
	client_player.set_physics_process(false)
	var server_result: bool = server_player.accepts_local_input()
	var client_result: bool = client_player.accepts_local_input()
	var manager := ManagerScript.new()
	host.add_child(manager)
	var match_mutation_result: bool = manager.register_player(99, "Authority Probe")
	var grab_manager := GrabManagerScript.new()
	host.add_child(grab_manager)
	var grab_player := server_player if role == "server" else client_player
	var grab_registration_result: bool = grab_manager.register_player(root.multiplayer.get_unique_id(), grab_player)
	var body := RigidBody3D.new()
	body.add_to_group("grabbable")
	body.position = Vector3(0.0, 0.4, -1.0)
	host.add_child(body)
	var grab_mutation_result: bool = grab_manager.request_grab(root.multiplayer.get_unique_id(), body)
	var expected_match_mutation := role == "server"
	var passed := (
		server_result == expected_server_player
		and client_result == expected_client_player
		and match_mutation_result == expected_match_mutation
		and grab_registration_result == expected_match_mutation
		and grab_mutation_result == expected_match_mutation
	)
	if not passed:
		push_error(
			"Authority mismatch role=%s server_player=%s client_player=%s match_mutation=%s grab_registration=%s grab_mutation=%s" % [
				role, server_result, client_result, match_mutation_result, grab_registration_result, grab_mutation_result
			]
		)
	host.queue_free()
	return passed
