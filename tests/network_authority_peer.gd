extends SceneTree

const TIMEOUT_MSEC := 5000
const ManagerScript = preload("res://game/match_manager.gd")
const GrabManagerScript = preload("res://game/grab_manager.gd")
const MeteorScript = preload("res://game/meteor_shower.gd")
const FloodScript = preload("res://game/flood.gd")
const TornadoScript = preload("res://game/tornado.gd")
const EarthquakeScript = preload("res://game/earthquake.gd")
const LightningScript = preload("res://game/lightning.gd")
const FireScript = preload("res://game/fire.gd")
const DirectorScript = preload("res://game/disaster_director.gd")

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
	if role == "server":
		manager.set_player_ready(99, true)
		manager.start_match()
	var grab_manager := GrabManagerScript.new()
	host.add_child(grab_manager)
	var grab_player := server_player if role == "server" else client_player
	var grab_registration_result: bool = grab_manager.register_player(root.multiplayer.get_unique_id(), grab_player)
	var body := RigidBody3D.new()
	body.add_to_group("grabbable")
	body.position = Vector3(0.0, 0.4, -1.0)
	host.add_child(body)
	var grab_mutation_result: bool = grab_manager.request_grab(root.multiplayer.get_unique_id(), body)
	var meteor := MeteorScript.new()
	host.add_child(meteor)
	meteor.configure(manager)
	var meteor_registration_result: bool = meteor.register_player(99, grab_player)
	var meteor_mutation_result: bool = meteor.start_warning(Vector3.ZERO)
	var flood := FloodScript.new()
	host.add_child(flood)
	flood.configure(manager)
	var flood_registration_result: bool = flood.register_player(99, grab_player)
	var flood_mutation_result: bool = flood.start_warning()
	if flood_mutation_result:
		flood.tick(flood.warning_duration)
	var flood_interaction_result: bool = flood.electrify_at(Vector3(0.0, flood.start_level, 0.0))
	var tornado := TornadoScript.new()
	host.add_child(tornado)
	tornado.configure(manager)
	var tornado_registration_result: bool = tornado.register_player(99, grab_player)
	var tornado_mutation_result: bool = tornado.start_warning(Vector3.ZERO, Vector3.RIGHT * 4.0)
	var earthquake := EarthquakeScript.new()
	host.add_child(earthquake)
	earthquake.configure(manager)
	var earthquake_registration_result: bool = earthquake.register_player(99, grab_player)
	var earthquake_mutation_result: bool = earthquake.start_warning()
	var lightning := LightningScript.new()
	host.add_child(lightning)
	lightning.configure(manager)
	var lightning_registration_result: bool = lightning.register_player(99, grab_player)
	var lightning_mutation_result: bool = lightning.start_warning(Vector3.ZERO)
	var fire := FireScript.new()
	host.add_child(fire)
	fire.configure(manager)
	var fire_registration_result: bool = fire.register_player(99, grab_player)
	var fire_mutation_result: bool = fire.start_warning(0)
	var fire_interaction_result: bool = fire.set_wind_active(true)
	var director := DirectorScript.new()
	host.add_child(director)
	var director_configuration_result: bool = director.configure(manager)
	var director_registration_result: bool = director.register_disaster(meteor)
	var director_mutation_result: bool = director.start_directing(297)
	var expected_match_mutation := role == "server"
	var passed := (
		server_result == expected_server_player
		and client_result == expected_client_player
		and match_mutation_result == expected_match_mutation
		and grab_registration_result == expected_match_mutation
		and grab_mutation_result == expected_match_mutation
		and meteor_registration_result == expected_match_mutation
		and meteor_mutation_result == expected_match_mutation
		and flood_registration_result == expected_match_mutation
		and flood_mutation_result == expected_match_mutation
		and flood_interaction_result == expected_match_mutation
		and tornado_registration_result == expected_match_mutation
		and tornado_mutation_result == expected_match_mutation
		and earthquake_registration_result == expected_match_mutation
		and earthquake_mutation_result == expected_match_mutation
		and lightning_registration_result == expected_match_mutation
		and lightning_mutation_result == expected_match_mutation
		and fire_registration_result == expected_match_mutation
		and fire_mutation_result == expected_match_mutation
		and fire_interaction_result == expected_match_mutation
		and director_configuration_result == expected_match_mutation
		and director_registration_result == expected_match_mutation
		and director_mutation_result == expected_match_mutation
	)
	if not passed:
		push_error(
			"Authority mismatch role=%s server_player=%s client_player=%s match_mutation=%s grab_registration=%s grab_mutation=%s meteor_registration=%s meteor_mutation=%s flood_registration=%s flood_mutation=%s flood_interaction=%s tornado_registration=%s tornado_mutation=%s earthquake_registration=%s earthquake_mutation=%s lightning_registration=%s lightning_mutation=%s fire_registration=%s fire_mutation=%s fire_interaction=%s director_configuration=%s director_registration=%s director_mutation=%s" % [
				role, server_result, client_result, match_mutation_result, grab_registration_result, grab_mutation_result, meteor_registration_result, meteor_mutation_result, flood_registration_result, flood_mutation_result, flood_interaction_result, tornado_registration_result, tornado_mutation_result, earthquake_registration_result, earthquake_mutation_result, lightning_registration_result, lightning_mutation_result, fire_registration_result, fire_mutation_result, fire_interaction_result, director_configuration_result, director_registration_result, director_mutation_result
			]
		)
	host.queue_free()
	return passed
