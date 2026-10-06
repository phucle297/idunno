extends SceneTree

const TIMEOUT_MSEC := 45000
const ProbeScript = preload("res://tests/playable_scale_probe.gd")

var role := ""
var port := 29740
var player_count := 4


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
		elif argument.begins_with("--players="):
			player_count = argument.trim_prefix("--players=").to_int()
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	var probe := ProbeScript.new()
	probe.name = "PlayableScaleProbe"
	probe.configure(role, player_count)
	root.add_child(probe)
	await process_frame
	if role == "server":
		await _run_server(main, probe)
	elif role == "client":
		await _run_client(main, probe)
	else:
		push_error("Expected --role=server or --role=client")
		quit(1)


func _run_server(main: Node, probe: PlayableScaleProbe) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while main.get_network_player_ids().size() != player_count and Time.get_ticks_msec() < deadline:
		await process_frame
	var peer_ids: Array[int] = main.get_network_player_ids()
	var manager := main.get_node("MatchManager") as MatchManager
	var spawn_passed := peer_ids.size() == player_count and manager.players.size() == player_count
	var start_positions := {}
	for peer_id: int in peer_ids:
		var player := _player_for_peer(main, peer_id)
		spawn_passed = spawn_passed and is_instance_valid(player) and player.get_multiplayer_authority() == peer_id
		if is_instance_valid(player):
			start_positions[peer_id] = player.global_position
	main._set_lobby_visible(false)
	Input.action_press("move_left")
	probe.begin_movement.rpc()
	await create_timer(1.5).timeout
	Input.action_release("move_left")
	var movement_passed := true
	for peer_id: int in peer_ids:
		var player := _player_for_peer(main, peer_id)
		movement_passed = movement_passed and is_instance_valid(player) and player.global_position.distance_to(start_positions.get(peer_id, player.global_position)) >= 0.5
	main.set_local_ready(true)
	while not manager.can_start_match() and Time.get_ticks_msec() < deadline:
		await process_frame
	var start_event := InputEventAction.new()
	start_event.action = "ui_accept"
	start_event.pressed = true
	main._unhandled_input(start_event)
	await create_timer(0.5).timeout
	var match_passed := manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == player_count
	var meteor := main.get_node("MeteorShower") as MeteorShower
	meteor.set_process(false)
	var disaster_passed := meteor.start_warning(Vector3(0.0, 0.06, 0.0))
	await create_timer(0.5).timeout
	var damage_events: Array[Dictionary] = []
	for peer_id: int in peer_ids:
		if peer_id != 1:
			damage_events.append({"peer_id": peer_id, "amount": 25.0, "cause": "Playable scale test"})
	var damage_passed := manager.apply_damage_batch(damage_events)
	while not probe.all_clients_responded() and Time.get_ticks_msec() < deadline:
		await process_frame
	for peer_id: int in peer_ids:
		var expected_health := 100.0 if peer_id == 1 else 75.0
		damage_passed = damage_passed and is_equal_approx(manager.get_health(peer_id), expected_health)
	var hud_passed: bool = (
		main.gameplay_hud.get_presented_health() == 100
		and main.gameplay_hud.get_presented_alive_counts() == Vector2i(player_count, player_count)
	)
	var clients_passed := probe.all_clients_passed()
	main.set_process(false)
	main.set_physics_process(false)
	for peer_id: int in peer_ids:
		if peer_id == 1:
			continue
		probe.finish_clients.rpc_id(peer_id)
		while peer_id in main.get_network_player_ids() and Time.get_ticks_msec() < deadline:
			await process_frame
	await process_frame
	var cleanup_passed := _disconnected_registries_are_clean(main, peer_ids)
	var passed := spawn_passed and movement_passed and match_passed and disaster_passed and damage_passed and hud_passed and clients_passed and cleanup_passed
	if passed:
		print("PLAYABLE_SCALE_SERVER_OK players=%d movement=passed match_hud=passed disaster=passed disconnect_cleanup=passed" % player_count)
	else:
		push_error("Playable scale server failed players=%d spawn=%s movement=%s match=%s disaster=%s damage=%s hud=%s clients=%s cleanup=%s ids=%s" % [player_count, spawn_passed, movement_passed, match_passed, disaster_passed, damage_passed, hud_passed, clients_passed, cleanup_passed, main.get_network_player_ids()])
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	await create_timer(0.1).timeout
	quit(0 if passed else 1)


func _run_client(main: Node, probe: PlayableScaleProbe) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (main.get_network_player_ids().size() != player_count or not probe.begin_movement_received) and Time.get_ticks_msec() < deadline:
		await process_frame
	var local_id: int = root.multiplayer.get_unique_id()
	var local_player := _player_for_peer(main, local_id)
	var host_player := _player_for_peer(main, 1)
	var local_start := local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO
	var host_start := host_player.global_position if is_instance_valid(host_player) else Vector3.ZERO
	main._set_lobby_visible(false)
	Input.action_press("move_right")
	await create_timer(1.5).timeout
	Input.action_release("move_right")
	var movement_passed := (
		is_instance_valid(local_player)
		and local_player.global_position.distance_to(local_start) >= 0.5
		and is_instance_valid(host_player)
		and host_player.global_position.distance_to(host_start) >= 0.5
	)
	var manager := main.get_node("MatchManager") as MatchManager
	main.set_local_ready(true)
	var meteor := main.get_node("MeteorShower") as MeteorShower
	while (
		(manager.state != MatchManager.MatchState.ACTIVE or manager.get_health(local_id) != 75.0 or meteor.phase != MeteorShower.Phase.WARNING)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	await process_frame
	var roster_passed: bool = main.get_network_player_ids().size() == player_count and manager.players.size() == player_count
	for peer_id: int in main.get_network_player_ids():
		var player := _player_for_peer(main, peer_id)
		roster_passed = roster_passed and is_instance_valid(player) and player.get_multiplayer_authority() == peer_id
	var ownership_passed := (
		is_instance_valid(local_player)
		and local_player.get_multiplayer_authority() == local_id
		and is_instance_valid(host_player)
		and host_player.get_multiplayer_authority() == 1
	)
	var match_passed: bool = (
		manager.state == MatchManager.MatchState.ACTIVE
		and manager.get_alive_count() == player_count
		and is_equal_approx(manager.get_health(local_id), 75.0)
		and main.gameplay_hud.get_presented_health() == 75
		and main.gameplay_hud.get_presented_alive_counts() == Vector2i(player_count, player_count)
	)
	var disaster_passed: bool = (
		meteor.phase == MeteorShower.Phase.WARNING
		and meteor.active_effect_count() == 1
		and main.gameplay_hud.get_presented_hazards().any(func(line: String) -> bool: return "METEOR" in line)
	)
	var passed: bool = roster_passed and ownership_passed and movement_passed and match_passed and disaster_passed
	probe.acknowledge_validation.rpc_id(1, passed)
	while not probe.finish_received and Time.get_ticks_msec() < deadline:
		await process_frame
	if passed and probe.finish_received:
		print("PLAYABLE_SCALE_CLIENT_OK players=%d peer=%d roster_ownership=passed movement=passed match_hud=passed disaster=passed" % [player_count, local_id])
	else:
		push_error("Playable scale client failed players=%d peer=%d roster=%s ownership=%s movement=%s match=%s disaster=%s finish=%s" % [player_count, local_id, roster_passed, ownership_passed, movement_passed, match_passed, disaster_passed, probe.finish_received])
	main.set_process(false)
	main.set_physics_process(false)
	await create_timer(0.1).timeout
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	await create_timer(0.1).timeout
	quit(0 if passed and probe.finish_received else 1)


func _player_for_peer(main: Node, peer_id: int) -> PartyPlayer:
	return main.get_node_or_null("Player" if peer_id == 1 else "NetworkPlayer%d" % peer_id) as PartyPlayer


func _disconnected_registries_are_clean(main: Node, original_peer_ids: Array[int]) -> bool:
	if main.get_network_player_ids() != [1] or (main.get_node("MatchManager") as MatchManager).players.keys() != [1]:
		return false
	for peer_id: int in original_peer_ids:
		if peer_id == 1:
			continue
		if (
			main.get_node_or_null("NetworkPlayer%d" % peer_id) != null
			or main._movement_inputs.has(peer_id)
			or (main.get_node("GrabManager") as GrabManager)._players.has(peer_id)
			or (main.get_node("MeteorShower") as MeteorShower)._players.has(peer_id)
			or (main.get_node("Flood") as Flood)._players.has(peer_id)
			or (main.get_node("Tornado") as Tornado)._players.has(peer_id)
			or (main.get_node("Earthquake") as Earthquake)._players.has(peer_id)
			or (main.get_node("Lightning") as Lightning)._players.has(peer_id)
			or (main.get_node("Fire") as Fire)._players.has(peer_id)
		):
			return false
	return true
