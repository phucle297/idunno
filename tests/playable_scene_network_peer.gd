extends SceneTree

const TIMEOUT_MSEC := 10000
const PlayerScene = preload("res://scenes/player.tscn")

var role := ""
var port := 29730


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	if role == "server":
		await _run_server(main)
	elif role == "client":
		await _run_client(main)
	else:
		push_error("Expected --role=server or --role=client")
		quit(1)


func _run_server(main: Node) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while main.get_network_player_ids().size() != 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	var peer_ids: Array[int] = main.get_network_player_ids()
	var client_id := _non_server_peer_id(peer_ids)
	var client_player := main.get_node_or_null("NetworkPlayer%d" % client_id) as PartyPlayer
	var host_player := main.get_node("Player") as PartyPlayer
	var manager := main.get_node("MatchManager") as MatchManager
	var spawn_passed: bool = (
		main.is_network_session()
		and main.get_network_role() == "host"
		and peer_ids == [1, client_id]
		and manager.players.size() == 2
		and manager.players.has(client_id)
		and is_instance_valid(client_player)
		and client_player.get_multiplayer_authority() == client_id
	)
	var host_spawn := host_player.global_position
	var client_spawn := client_player.global_position if is_instance_valid(client_player) else Vector3.ZERO
	Input.action_press("move_left")
	while (
		is_instance_valid(client_player)
		and (host_player.global_position - host_spawn).length() < 1.0
		and Time.get_ticks_msec() < deadline
	):
		await physics_frame
	Input.action_release("move_left")
	while (
		is_instance_valid(client_player)
		and (client_player.global_position - client_spawn).length() < 1.0
		and Time.get_ticks_msec() < deadline
	):
		await physics_frame
	var movement_passed: bool = (
		(host_player.global_position - host_spawn).length() >= 1.0
		and is_instance_valid(client_player)
		and (client_player.global_position - client_spawn).length() >= 1.0
	)
	for peer_id: int in peer_ids:
		manager.set_player_ready(peer_id, true)
	var match_started := manager.start_match()
	await create_timer(0.4).timeout
	var active_passed := match_started and manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == 2
	var nonlethal_passed := manager.apply_damage(client_id, 25.0, "Network test")
	await create_timer(0.5).timeout
	nonlethal_passed = nonlethal_passed and is_equal_approx(manager.get_health(client_id), 75.0) and manager.get_alive_count() == 2
	var lethal_passed := manager.apply_damage(client_id, 75.0, "Network test")
	await create_timer(0.5).timeout
	lethal_passed = (
		lethal_passed
		and is_zero_approx(manager.get_health(client_id))
		and not manager.is_player_alive(client_id)
		and manager.get_alive_count() == 1
		and manager.state == MatchManager.MatchState.RESULTS
	)
	while main.get_network_player_ids().size() != 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var cleanup_passed: bool = (
		main.get_network_player_ids() == [1]
		and manager.players.size() == 1
		and not manager.players.has(client_id)
		and main.get_node_or_null("NetworkPlayer%d" % client_id) == null
		and _registries_accept_removed_peer(main, client_id)
	)
	var passed: bool = spawn_passed and movement_passed and active_passed and nonlethal_passed and lethal_passed and cleanup_passed
	if passed:
		print("PLAYABLE_NETWORK_SERVER_OK spawned=2 authoritative_movement=passed match_health=passed elimination=passed remaining=1 disconnected_peer=%d" % client_id)
	else:
		push_error("Playable server validation failed spawn=%s movement=%s active=%s nonlethal=%s lethal=%s cleanup=%s ids=%s players=%s" % [spawn_passed, movement_passed, active_passed, nonlethal_passed, lethal_passed, cleanup_passed, main.get_network_player_ids(), manager.players.keys()])
	quit(0 if passed else 1)


func _run_client(main: Node) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while main.get_network_player_ids().size() != 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	var local_id: int = root.multiplayer.get_unique_id()
	var local_player := main.get_node_or_null("NetworkPlayer%d" % local_id) as PartyPlayer
	var host_player := main.get_node("Player") as PartyPlayer
	var spawn_passed: bool = (
		main.is_network_session()
		and main.get_network_role() == "client"
		and local_id > 1
		and main.get_network_player_ids() == [1, local_id]
		and host_player.get_multiplayer_authority() == 1
		and is_instance_valid(local_player)
		and local_player.get_multiplayer_authority() == local_id
		and not (host_player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current
		and (local_player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current
	)
	var host_spawn := host_player.global_position
	var local_spawn := local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO
	Input.action_press("move_right")
	while (
		is_instance_valid(local_player)
		and (
			(local_player.global_position - local_spawn).length() < 1.0
			or (host_player.global_position - host_spawn).length() < 1.0
		)
		and Time.get_ticks_msec() < deadline
	):
		await physics_frame
	Input.action_release("move_right")
	var movement_passed: bool = (
		is_instance_valid(local_player)
		and (local_player.global_position - local_spawn).length() >= 1.0
		and (host_player.global_position - host_spawn).length() >= 1.0
	)
	var manager := main.get_node("MatchManager") as MatchManager
	while (
		(manager.state != MatchManager.MatchState.ACTIVE or manager.get_health(local_id) != 100.0)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	var active_passed := manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == 2
	while manager.get_health(local_id) != 75.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var nonlethal_passed := (
		manager.get_health(local_id) == 75.0
		and manager.get_alive_count() == 2
		and (main.get_node("Interface/Health") as Label).text == "HP  75"
		and (main.get_node("Interface/Alive") as Label).text == "ALIVE  2 / 2"
	)
	while manager.is_player_alive(local_id) and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var lethal_passed: bool = (
		manager.state == MatchManager.MatchState.RESULTS
		and manager.get_health(local_id) == 0.0
		and manager.get_alive_count() == 1
		and not local_player.visual.visible
		and main.spectator_controller.active
		and (main.get_node("Interface/Health") as Label).text == "HP  0"
		and (main.get_node("Interface/Alive") as Label).text == "ALIVE  1 / 2"
	)
	var passed: bool = spawn_passed and movement_passed and active_passed and nonlethal_passed and lethal_passed
	if passed:
		print("PLAYABLE_NETWORK_CLIENT_OK local=%d players=2 observed_host_and_local_movement=passed match_health_hud=passed elimination_spectating=passed" % local_id)
	else:
		push_error("Playable client validation failed spawn=%s movement=%s active=%s nonlethal=%s lethal=%s local=%d ids=%s" % [spawn_passed, movement_passed, active_passed, nonlethal_passed, lethal_passed, local_id, main.get_network_player_ids()])
	await create_timer(0.25).timeout
	quit(0 if passed else 1)


func _registries_accept_removed_peer(main: Node, peer_id: int) -> bool:
	var replacement := PlayerScene.instantiate() as PartyPlayer
	replacement.name = "CleanupProbe"
	main.add_child(replacement)
	var manager := main.get_node("MatchManager") as MatchManager
	var grab_manager := main.get_node("GrabManager") as GrabManager
	var meteor := main.get_node("MeteorShower") as MeteorShower
	var flood := main.get_node("Flood") as Flood
	var tornado := main.get_node("Tornado") as Tornado
	var passed: bool = (
		manager.register_player(peer_id, "Cleanup Probe")
		and grab_manager.register_player(peer_id, replacement)
		and meteor.register_player(peer_id, replacement)
		and flood.register_player(peer_id, replacement)
		and tornado.register_player(peer_id, replacement)
	)
	grab_manager.unregister_player(peer_id)
	meteor.unregister_player(peer_id)
	flood.unregister_player(peer_id)
	tornado.unregister_player(peer_id)
	manager.unregister_player(peer_id)
	replacement.queue_free()
	return passed


func _non_server_peer_id(peer_ids: Array[int]) -> int:
	for peer_id: int in peer_ids:
		if peer_id != 1:
			return peer_id
	return 0
