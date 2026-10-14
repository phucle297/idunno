extends SceneTree

const TIMEOUT_MSEC := 45000
const ProbeScript = preload("res://tests/playable_scale_probe.gd")

var role := ""
var port := 29740
var player_count := 4
var map_id := "toy_town"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
		elif argument.begins_with("--players="):
			player_count = argument.trim_prefix("--players=").to_int()
		elif argument.begins_with("--map-id="):
			map_id = argument.trim_prefix("--map-id=")
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	if role == "server":
		main.set_map_id(map_id)
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


func _run_results_legs(main: Node, probe: PlayableScaleProbe, peer_ids: Array[int], manager: MatchManager, spectator_id: int, deadline: int) -> Dictionary:
	main.disaster_director.cleanup()
	manager.players[1].name = "Named host, not a client-side default"
	for index: int in range(peer_ids.size() - 1, 1, -1):
		manager.players[peer_ids[index]].name = "Toy %02d" % index
		manager.tick_match(1.0)
		manager.apply_damage(peer_ids[index], 100.0, "Ranked result %d" % index)
	main._process(0.0)
	var table: VBoxContainer = main.get_node("Interface/ResultsPanel/Table")
	var expected_order: Array = [1]
	expected_order.append_array(peer_ids.slice(2))
	expected_order.append(spectator_id)
	var results_passed: bool = table.list.get_children().map(func(row: Node) -> int: return int(row.name)) == expected_order
	results_passed = results_passed and not main.gameplay_hud.health_card.visible and not main.gameplay_hud.get_node("AlivePill").visible and main.get_node("Interface/ResultsPanel/Actions/Rematch").visible and main.get_node("Interface/ResultsPanel/Actions/Lobby").visible
	probe.compare_results.rpc(_result_cells(main))
	while probe.results_checks.size() < player_count - 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	results_passed = results_passed and probe.results_checks.size() == player_count - 1 and not probe.results_checks.values().has(false)
	# Five owner-driven rematches: every restart must restore roster, health
	# and prop structure and clear transient emote/shove state on all peers.
	var rematch_passed := true
	for rematch_index in 5:
		rematch_passed = rematch_passed and main.restart_network_match()
		await create_timer(0.5).timeout
		probe.begin_rematch_check.rpc(rematch_index)
		var server_rematch_ok := manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == player_count
		for peer_id: int in peer_ids:
			server_rematch_ok = server_rematch_ok and is_equal_approx(manager.get_health(peer_id), 100.0)
		for prop: Node in get_nodes_in_group("network_prop"):
			server_rematch_ok = server_rematch_ok and prop is RigidBody3D
		server_rematch_ok = server_rematch_ok and get_nodes_in_group("network_prop").size() == 3
		rematch_passed = rematch_passed and server_rematch_ok
		while (probe.rematch_acks.get(rematch_index, {}) as Dictionary).size() < player_count - 1 and Time.get_ticks_msec() < deadline:
			await process_frame
		var cycle_acks: Dictionary = probe.rematch_acks.get(rematch_index, {})
		if not server_rematch_ok or cycle_acks.size() != player_count - 1 or cycle_acks.values().has(false):
			print("PLAYABLE_SCALE_REMATCH_DIAGNOSTIC cycle=%d server_ok=%s state=%d alive=%d props=%d acks=%s deadline_remaining_msec=%d" % [
				rematch_index, server_rematch_ok, manager.state, manager.get_alive_count(), get_nodes_in_group("network_prop").size(),
				cycle_acks, deadline - Time.get_ticks_msec()])
		rematch_passed = rematch_passed and cycle_acks.size() == player_count - 1 and not cycle_acks.values().has(false)
		# End each cycle in RESULTS so the next restart exercises the gate.
		for peer_id: int in peer_ids:
			manager.apply_damage(peer_id, 100.0, "Rematch cycle %d" % rematch_index)
		while manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		await create_timer(0.3).timeout
	var lobby_return_passed: bool = main.return_to_lobby()
	while probe.lobby_checks.size() < player_count - 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	lobby_return_passed = lobby_return_passed and probe.lobby_checks.size() == player_count - 1 and not probe.lobby_checks.values().has(false) and manager.state == MatchManager.MatchState.LOBBY and not manager.can_start_match()
	return {"results": results_passed, "rematch": rematch_passed, "lobby": lobby_return_passed}


func _run_server(main: Node, probe: PlayableScaleProbe) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var transport := main.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var admission_throttle_min := {}
	var admission_loss_end := {}
	var sample_admission := func() -> void:
		for peer_id: int in main.get_network_player_ids():
			if peer_id == 1:
				continue
			var packet_peer := transport.get_peer(peer_id)
			admission_throttle_min[peer_id] = minf(admission_throttle_min.get(peer_id, 32.0), packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE))
			admission_loss_end[peer_id] = packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
	process_frame.connect(sample_admission)
	while main.get_network_player_ids().size() != player_count and Time.get_ticks_msec() < deadline:
		await process_frame
	# Spawn RPCs can arrive before the authoritative match roster. Movement is
	# intentionally neutral until that roster confirms the local player is alive.
	while probe.movement_ready.size() != player_count - 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	process_frame.disconnect(sample_admission)
	for peer_id: int in admission_throttle_min:
		var packet_peer := transport.get_peer(peer_id)
		print("SCALE_ADMISSION peer=%d throttle_min=%s loss_end=%s throttle_limit=%s interval=%s deceleration=%s" % [peer_id, admission_throttle_min[peer_id], admission_loss_end.get(peer_id, -1.0), packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT), packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL), packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION)])
	var peer_ids: Array[int] = main.get_network_player_ids()
	var manager := main.get_node("MatchManager") as MatchManager
	var spawn_passed := peer_ids.size() == player_count and manager.players.size() == player_count and probe.movement_ready.size() == player_count - 1
	var start_positions := {}
	for peer_id: int in peer_ids:
		var player := _player_for_peer(main, peer_id)
		spawn_passed = spawn_passed and is_instance_valid(player) and player.get_multiplayer_authority() == peer_id
		if is_instance_valid(player):
			start_positions[peer_id] = player.global_position
	main._set_lobby_visible(false)
	var throttle_min := {}
	for peer_id: int in peer_ids:
		if peer_id != 1:
			throttle_min[peer_id] = transport.get_peer(peer_id).get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)
	var sample_throttle := func() -> void:
		for peer_id: int in throttle_min:
			throttle_min[peer_id] = minf(throttle_min[peer_id], transport.get_peer(peer_id).get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE))
	process_frame.connect(sample_throttle)
	var movement_wall_start := Time.get_ticks_msec()
	var movement_physics_start := Engine.get_physics_frames()
	var movement_snapshot_start: int = main._match_snapshot_sequence
	Input.action_press("move_left")
	probe.begin_movement.rpc()
	await create_timer(1.5).timeout
	Input.action_release("move_left")
	process_frame.disconnect(sample_throttle)
	print("SCALE_TRANSPORT_WINDOW wall_msec=%d physics_frames=%d lobby_snapshot_sends=%d" % [Time.get_ticks_msec() - movement_wall_start, Engine.get_physics_frames() - movement_physics_start, main._match_snapshot_sequence - movement_snapshot_start])
	for peer_id: int in throttle_min:
		var packet_peer := transport.get_peer(peer_id)
		print("SCALE_TRANSPORT peer=%d throttle_min=%s throttle_end=%s loss=%s rtt=%s baseline_rtt=%s variance=%s" % [peer_id, throttle_min[peer_id], packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE), packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS), packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME), packet_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME), packet_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME_VARIANCE)])
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
	# Solo ranked sessions cannot start anywhere in the product: the
	# ready-up auto-start needs two players and start_network_match()
	# rejects fewer than two. The 1-player scenario asserts those guards
	# and the lobby's rejection of in-match-only actions instead of a
	# match lifecycle.
	var match_passed: bool
	var disaster_passed: bool
	var damage_passed: bool
	var hud_passed: bool
	if player_count == 1:
		match_passed = manager.state == MatchManager.MatchState.LOBBY and not main.start_network_match()
		var solo_meteor := main.get_node("MeteorShower") as MeteorShower
		solo_meteor.set_process(false)
		var solo_lightning := main.get_node("Lightning") as Lightning
		solo_lightning.set_process(false)
		disaster_passed = not solo_meteor.start_warning(Vector3(0.0, 0.06, 0.0)) and not solo_lightning.start_warning(Vector3(4.0, 0.06, 4.0))
		damage_passed = not manager.apply_damage_batch([{"peer_id": 1, "amount": 25.0, "cause": "Playable scale test"}])
		hud_passed = true
	else:
		match_passed = manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == player_count
		var meteor := main.get_node("MeteorShower") as MeteorShower
		meteor.set_process(false)
		var meteor_rng := RandomNumberGenerator.new()
		meteor_rng.seed = 8105
		disaster_passed = meteor.start_disaster(meteor_rng) and meteor.active_effect_count() >= (2 if map_id == "toy_town" else 1)
		var lightning := main.get_node("Lightning") as Lightning
		lightning.set_process(false)
		disaster_passed = disaster_passed and lightning.start_warning(Vector3(4.0, 0.06, 4.0))
		var fire := main.get_node("Fire") as Fire
		var quake := main.get_node("Earthquake") as Earthquake
		fire.set_process(false)
		quake.set_process(false)
		# Synthetic snapshot stress beyond the director's two-disaster limit;
		# the HUD still intentionally presents its bounded priority chips.
		disaster_passed = disaster_passed and fire.start_warning(0) and quake.start_warning()
		main.rain.set_process(false)
		main.snowfall.set_process(false)
		main.rockslide.set_physics_process(false)
		disaster_passed = disaster_passed and main.rain.start_disaster(meteor_rng) and main.snowfall.start_disaster(meteor_rng) and main.rockslide.start_disaster(meteor_rng)
		main.snowfall.tick(5)
		main.tick_weather(20)
		main.rockslide.tick(5)
		main.rockslide.tick(0.01)
		await create_timer(0.5).timeout
		var damage_events: Array[Dictionary] = []
		for peer_id: int in peer_ids:
			if peer_id != 1:
				damage_events.append({"peer_id": peer_id, "amount": 25.0, "cause": "Playable scale test"})
		damage_passed = manager.apply_damage_batch(damage_events)
		while not probe.all_clients_responded() and Time.get_ticks_msec() < deadline:
			await process_frame
		for peer_id: int in peer_ids:
			var expected_health := 100.0 if peer_id == 1 else 75.0
			damage_passed = damage_passed and is_equal_approx(manager.get_health(peer_id), expected_health)
		hud_passed = (
			main.gameplay_hud.get_presented_health() == 100
			and main.gameplay_hud.get_presented_alive_counts() == Vector2i(player_count, player_count)
		)
	var clients_passed := probe.all_clients_passed()
	# Integrated chaos gauntlet: independent loose prop and selected escape
	# route's in-session structure, both emotes and the included shove.
	var medium_prop: RigidBody3D = null
	for prop: Node in get_nodes_in_group("network_prop"):
		if prop is RigidBody3D and is_equal_approx((prop as RigidBody3D).mass, 12.0):
			medium_prop = prop
	var holder := _player_for_peer(main, 1)
	var escape_step := main.get_node_or_null("Sandbox/EscapeStep") as StaticBody3D
	var prop_escape_passed := is_instance_valid(escape_step) and is_instance_valid(medium_prop) and is_instance_valid(holder)
	if prop_escape_passed:
		medium_prop.global_position = Vector3(23.2, 0.4, 14.5)
		holder.global_position = Vector3(23.2, 0.75, 14.5)
		var mount_distance := Vector2(holder.global_position.x - escape_step.global_position.x, holder.global_position.z - escape_step.global_position.z).length()
		# Measured boost contract (feasibility suite): the crate at the route
		# base lifts the player to within jump reach of the 1.7m step; the
		# physical route playout is test_prop_role_feasibility's boost_route.
		prop_escape_passed = mount_distance < 1.5 and absf(escape_step.global_position.x - 21.9) < 0.1 and holder.global_position.y > 0.5
		holder.reset_for_match(Vector3(0.0, 0.05, 7.0))
	elif map_id == "toy_harbor":
		# Harbor has cargo ramps, not Town's optional crate-boost mount.
		# Its actual walk-only route playout remains in test_map_variety.
		prop_escape_passed = is_instance_valid(medium_prop) and is_instance_valid(holder) and main.map_anchors.elevation_routes.size() >= 4
	var emote_passed := is_instance_valid(holder)
	for emote_id: int in [PartyPlayer.EMOTE_WAVE, PartyPlayer.EMOTE_CHEER]:
		if emote_id == PartyPlayer.EMOTE_CHEER:
			# The 1.5s request cooldown is part of the contract: pace the
			# second round past it instead of hiding the rejection.
			await create_timer(1.6).timeout
		holder.request_emote(emote_id)
		if player_count == 1:
			# Emotes are in-match only: the solo lobby must reject them.
			emote_passed = emote_passed and holder.get_emote_id() == 0
			continue
		emote_passed = emote_passed and holder.get_emote_id() == emote_id
		probe.begin_emote_check.rpc(1, emote_id)
		await create_timer(0.3).timeout
		holder.cancel_emote()
		emote_passed = emote_passed and holder.get_emote_id() == 0
		await create_timer(0.1).timeout
	while probe.emote_checks.size() < 2 * (player_count - 1) and Time.get_ticks_msec() < deadline:
		await process_frame
	emote_passed = emote_passed and probe.emote_checks.size() == 2 * (player_count - 1) and not probe.emote_checks.values().has(false)
	var shove_manager := main.get_node("ShoveManager") as ShoveManager
	var shove_passed := true
	if player_count >= 2:
		var victim := _player_for_peer(main, peer_ids[1])
		holder.reset_for_match(Vector3(0.0, 0.05, 7.0))
		victim.reset_for_match(Vector3(-1.5, 0.05, 7.0))
		holder.set_camera_yaw(atan2(1.5, 0.0))
		probe.begin_shove_check.rpc(peer_ids[1])
		shove_passed = shove_manager.request_shove(1)
		await create_timer(0.4).timeout
		shove_passed = (
			shove_passed
			and shove_manager.get_last_shove_sequence(peer_ids[1]) == 1
			and shove_manager.is_protected(peer_ids[1])
			and victim.global_position.distance_to(shove_manager.get_last_shove_origin(peer_ids[1])) > 0.15
		)
		while probe.shove_checks.size() < player_count - 1 and Time.get_ticks_msec() < deadline:
			await process_frame
		shove_passed = shove_passed and probe.shove_checks.size() == player_count - 1 and not probe.shove_checks.values().has(false)
	else:
		shove_passed = not shove_manager.request_shove(1)
	var chaos_passed := prop_escape_passed and emote_passed and shove_passed
	var spectator_id: int = peer_ids[1] if player_count >= 2 else 0
	print("SCALE_SPECTATOR_TARGET players=%d peer_ids=%s target=%d" % [player_count, peer_ids, spectator_id])
	var spectators_passed := true
	if player_count >= 2:
		manager.apply_damage(spectator_id, 100.0, "Spectator scale test")
		probe.begin_spectator_check.rpc(spectator_id)
		while probe.spectator_results.size() < player_count - 1 and Time.get_ticks_msec() < deadline:
			await process_frame
		spectators_passed = probe.spectator_results.size() == player_count - 1 and not probe.spectator_results.values().has(false)
	var results_passed := true
	var rematch_passed := true
	var lobby_return_passed := true
	if player_count >= 2:
		# Solo sessions never reach RESULTS (they cannot start), so the
		# results/rematch/lobby-return legs run from two players up.
		var legs: Dictionary = await _run_results_legs(main, probe, peer_ids, manager, spectator_id, deadline)
		results_passed = legs["results"]
		rematch_passed = legs["rematch"]
		lobby_return_passed = legs["lobby"]
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
	var passed := results_passed and lobby_return_passed and rematch_passed and chaos_passed and spectators_passed and spawn_passed and movement_passed and match_passed and disaster_passed and damage_passed and hud_passed and clients_passed and cleanup_passed
	if passed:
		if player_count == 1:
			print("CHAOS_SCENARIO_OK players=1 prop_escape=passed emotes=rejected_in_lobby shove=no_target_rejected hazards_overlap=rejected_in_lobby rematches=0 owner_disconnect_transfer=dedicated_suite")
			print("PLAYABLE_SCALE_SERVER_OK players=1 lobby_guards=passed solo_start_blocked=passed in_match_actions_rejected=passed disconnect_cleanup=passed")
		else:
			print("CHAOS_SCENARIO_OK players=%d prop_escape=passed emotes=2 shove=passed hazards_overlap=%s rematches=5 owner_disconnect_transfer=dedicated_suite" % [player_count, "death_spectating" if player_count >= 3 else "death_results"])
			print("NETWORK_RESULTS_SCALE_OK players=%d exact_rankings_and_cells=passed" % player_count)
			print("NETWORK_SPECTATOR_SCALE_OK players=%d eliminated_client=%s living_clients=%s presentation_authority=passed" % [player_count, "death_results" if player_count == 2 else "passed", "not_applicable" if player_count == 2 else "passed"])
			print("PLAYABLE_SCALE_SERVER_OK players=%d movement=passed match_hud=passed disaster=passed disconnect_cleanup=passed" % player_count)
	else:
		push_error("Playable scale server failed players=%d spawn=%s movement=%s match=%s disaster=%s chaos=%s escape=%s emote=%s shove=%s rematch=%s results=%s lobby=%s spectators=%s damage=%s hud=%s clients=%s cleanup=%s ids=%s" % [player_count, spawn_passed, movement_passed, match_passed, disaster_passed, chaos_passed, prop_escape_passed, emote_passed, shove_passed, rematch_passed, results_passed, lobby_return_passed, spectators_passed, damage_passed, hud_passed, clients_passed, cleanup_passed, main.get_network_player_ids()])
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	await create_timer(0.1).timeout
	quit(0 if passed else 1)


func _run_client(main: Node, probe: PlayableScaleProbe) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (main.get_network_player_ids().size() != player_count or main.match_manager.players.size() != player_count) and Time.get_ticks_msec() < deadline:
		await process_frame
	probe.acknowledge_movement_ready.rpc_id(1)
	while not probe.begin_movement_received and Time.get_ticks_msec() < deadline:
		await process_frame
	var local_id: int = root.multiplayer.get_unique_id()
	var local_player := _player_for_peer(main, local_id)
	var host_player := _player_for_peer(main, 1)
	var local_start := local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO
	var host_start := host_player.global_position if is_instance_valid(host_player) else Vector3.ZERO
	var acknowledged_start: int = local_player._last_movement_ack if is_instance_valid(local_player) else -1
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
	if not movement_passed:
		print("PLAYABLE_SCALE_MOVEMENT_DIAGNOSTIC peer=%d local_start=%s local_end=%s host_start=%s host_end=%s" % [
			local_id, local_start, local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO,
			host_start, host_player.global_position if is_instance_valid(host_player) else Vector3.ZERO])
		var registered_host: PartyPlayer = main._player_nodes.get(1)
		print("PLAYABLE_SCALE_MOVEMENT_STATE peer=%d local_sequence=%d host_fixture=%s host_registered=%s registered_host_position=%s lobby_visible=%s state=%d" % [
			local_id, main._local_movement_sequence, host_player.get_path() if is_instance_valid(host_player) else NodePath(),
			registered_host.get_path() if is_instance_valid(registered_host) else NodePath(),
			registered_host.global_position if is_instance_valid(registered_host) else Vector3.ZERO,
			main.get_node("Interface/LobbyPanel").visible, main.match_manager.state])
		print("PLAYABLE_SCALE_MOVEMENT_DELIVERY peer=%d acknowledged_start=%d acknowledged_end=%d host_alive=%s roster_ids=%s" % [
			local_id, acknowledged_start, local_player._last_movement_ack if is_instance_valid(local_player) else -1,
			main.match_manager.is_player_alive(1), main.get_network_player_ids()])
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
		and main.get_map_id() == map_id
		and meteor.active_effect_count() >= (2 if map_id == "toy_town" else 1)
		and meteor.active_effect_count() == meteor.strike_points.size()
		and (main.get_node("Fire") as Fire).phase == Fire.Phase.WARNING
		and (main.get_node("Earthquake") as Earthquake).phase == Earthquake.Phase.WARNING
		and not (main.get_node("Earthquake") as Earthquake).fracture_positions.is_empty()
		and main.gameplay_hud.get_presented_hazards().any(func(line: String) -> bool: return "METEOR" in line)
		and (main.get_node("Lightning") as Lightning).phase == Lightning.Phase.WARNING
		and main.rain.phase == Precipitation.Phase.WARNING
		and main.snowfall.phase == Precipitation.Phase.ACTIVE
		and main.weather_surfaces.create_presentation_snapshot().snow.has(1.0)
		and main.weather_surfaces.precipitation == "Snowfall"
		and main.rockslide.phase == Rockslide.Phase.ACTIVE
		and main.rockslide._remote_rocks.size() == 1
	)
	if not disaster_passed:
		print("SCALE_HAZARDS_DIAGNOSTIC map=%s expected=%s meteor=%d effects=%d points=%d fire=%d quake=%d fractures=%d hud=%s" % [main.get_map_id(), map_id, meteor.phase, meteor.active_effect_count(), meteor.strike_points.size(), (main.get_node("Fire") as Fire).phase, (main.get_node("Earthquake") as Earthquake).phase, (main.get_node("Earthquake") as Earthquake).fracture_positions.size(), main.gameplay_hud.get_presented_hazards()])
	var passed: bool = roster_passed and ownership_passed and movement_passed and match_passed and disaster_passed
	probe.acknowledge_validation.rpc_id(1, passed)
	var local_shove_manager := main.get_node("ShoveManager") as ShoveManager
	var chaos_observed := true
	for emote_id: int in [PartyPlayer.EMOTE_WAVE, PartyPlayer.EMOTE_CHEER]:
		while (probe.emote_target == 0 or probe.emote_expected_id != emote_id) and Time.get_ticks_msec() < deadline:
			await process_frame
		var emote_seen := false
		var emote_cleared := false
		while Time.get_ticks_msec() < deadline:
			await process_frame
			var target := _player_for_peer(main, probe.emote_target)
			if is_instance_valid(target):
				if target.get_emote_id() == emote_id:
					emote_seen = true
				elif emote_seen:
					emote_cleared = true
					break
		chaos_observed = chaos_observed and emote_seen and emote_cleared
		probe.acknowledge_emote.rpc_id(1, emote_id, emote_seen and emote_cleared)
	while (probe.shove_victim == 0 or local_shove_manager.get_last_shove_sequence(probe.shove_victim) < 1) and Time.get_ticks_msec() < deadline:
		await process_frame
	var shove_observed := false
	var shove_victim := _player_for_peer(main, probe.shove_victim)
	if is_instance_valid(shove_victim):
		var shove_origin: Vector3 = local_shove_manager.get_last_shove_origin(probe.shove_victim)
		var shove_window_end := Time.get_ticks_msec() + 500
		while Time.get_ticks_msec() < shove_window_end:
			await process_frame
			if is_instance_valid(shove_victim) and shove_victim.global_position.distance_to(shove_origin) > 0.15:
				shove_observed = local_shove_manager.is_protected(probe.shove_victim)
				if shove_observed:
					break
	chaos_observed = chaos_observed and shove_observed
	probe.acknowledge_shove.rpc_id(1, shove_observed)
	while (probe.spectator_peer_id == 0 or manager.is_player_alive(probe.spectator_peer_id)) and Time.get_ticks_msec() < deadline:
		await process_frame
	main._update_spectator_ui()
	var hud: GameplayHud = main.gameplay_hud
	var spectator_passed := true
	if player_count == 2:
		# Last-player-standing ends a two-player match on the first
		# elimination, so the eliminated client's contract is the results
		# presentation. Live spectator cycling starts at three players.
		spectator_passed = manager.state == MatchManager.MatchState.RESULTS and not hud.health_card.visible and manager.get_cause_of_death(local_id) == "Spectator scale test"
	elif local_id == probe.spectator_peer_id:
		spectator_passed = manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == player_count - 1
		var snapshot: Dictionary = main._create_playable_snapshot().duplicate(true)
		var card_visible: bool = hud.spectator_card.visible
		var health_hidden: bool = not hud.health_card.visible
		var target_id: int = main.spectator_controller.current_target_id
		var label_text: String = hud.spectating_label.text
		var next_enabled: bool = not hud.spectator_next.disabled
		spectator_passed = spectator_passed and card_visible and health_hidden and target_id == 1 and label_text == "Host" and next_enabled
		main._cycle_spectator(1)
		var cycled_target: int = main.spectator_controller.current_target_id
		var cycle_clean: bool = main._create_playable_snapshot() == snapshot
		var cause: String = manager.get_cause_of_death(local_id)
		spectator_passed = spectator_passed and cycled_target != 1 and cycle_clean and cause == "Spectator scale test"
		if not spectator_passed:
			print("SCALE_SPECTATOR_DIAGNOSTIC peer=%d state=%d alive=%d card=%s health=%s target=%d label=%s next=%s cycled=%d cycle_clean=%s cause=%s" % [local_id, manager.state, manager.get_alive_count(), card_visible, health_hidden, target_id, label_text, next_enabled, cycled_target, cycle_clean, cause])
	else:
		spectator_passed = manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == player_count - 1 and not hud.spectator_card.visible and hud.health_card.visible and is_equal_approx(manager.get_health(local_id), 75.0)
		if not spectator_passed:
			print("SCALE_SPECTATOR_ELSE_DIAGNOSTIC peer=%d expected=%d state=%d alive=%d card=%s health=%.1f" % [local_id, probe.spectator_peer_id, manager.state, manager.get_alive_count(), hud.spectator_card.visible, manager.get_health(local_id)])
	passed = passed and spectator_passed
	probe.acknowledge_spectator.rpc_id(1, spectator_passed)
	while (probe.expected_results.is_empty() or manager.state != MatchManager.MatchState.RESULTS) and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var before: Dictionary = manager.create_authoritative_snapshot().duplicate(true)
	var results_passed: bool = _result_cells(main) == probe.expected_results and not hud.health_card.visible and not hud.get_node("AlivePill").visible and not main.get_node("Interface/ResultsPanel/Actions/Rematch").visible and not main.get_node("Interface/ResultsPanel/Actions/Lobby").visible
	results_passed = results_passed and not main.restart_network_match() and not main.return_to_lobby() and manager.create_authoritative_snapshot() == before
	passed = passed and results_passed
	probe.acknowledge_results.rpc_id(1, results_passed)
	for rematch_index in 5:
		while not probe.rematch_acks.has(rematch_index) and Time.get_ticks_msec() < deadline:
			await process_frame
		await create_timer(0.2).timeout
		var rematch_ok := manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == player_count
		for peer_id: int in manager.players:
			rematch_ok = rematch_ok and is_equal_approx(manager.get_health(peer_id), 100.0)
		var host_copy := _player_for_peer(main, 1)
		rematch_ok = rematch_ok and is_instance_valid(host_copy) and host_copy.get_emote_id() == 0 and local_player.get_emote_id() == 0
		var surfaces: Dictionary = main.weather_surfaces.create_presentation_snapshot()
		rematch_ok = rematch_ok and not main.rain.is_active() and not main.snowfall.is_active() and not main.rockslide.is_active() and main.rockslide._remote_rocks.is_empty()
		for snow: float in surfaces.snow:
			rematch_ok = rematch_ok and snow == 0.0
		for wetness: float in surfaces.wetness:
			rematch_ok = rematch_ok and wetness == 0.0
		probe.acknowledge_rematch.rpc_id(1, rematch_index, rematch_ok)
	while manager.state != MatchManager.MatchState.LOBBY and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var lobby_return_passed: bool = manager.state == MatchManager.MatchState.LOBBY and main.get_node("Interface/LobbyPanel").visible and not main.get_node("Interface/ResultsPanel").visible and not main.spectator_controller.active and local_player.visual.visible and manager.get_health(local_id) == 100.0 and not manager.is_player_ready(local_id) and not main.disaster_director.running
	passed = passed and lobby_return_passed
	probe.acknowledge_lobby.rpc_id(1, lobby_return_passed)
	while not probe.finish_received and Time.get_ticks_msec() < deadline:
		await process_frame
	if passed and chaos_observed and probe.finish_received:
		print("PLAYABLE_SCALE_CLIENT_OK players=%d peer=%d roster_ownership=passed movement=passed match_hud=passed disaster=passed chaos_observation=passed emotes=2 shove=%s rematches=5" % [player_count, local_id, "observed" if player_count >= 2 else "not_applicable"])
	else:
		push_error("Playable scale client failed players=%d peer=%d roster=%s ownership=%s movement=%s match=%s disaster=%s chaos=%s spectator=%s results=%s lobby=%s finish=%s" % [player_count, local_id, roster_passed, ownership_passed, movement_passed, match_passed, disaster_passed, chaos_observed, spectator_passed, results_passed, lobby_return_passed, probe.finish_received])
	main.set_process(false)
	main.set_physics_process(false)
	await create_timer(0.1).timeout
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	await create_timer(0.1).timeout
	quit(0 if passed and probe.finish_received else 1)


func _player_for_peer(main: Node, peer_id: int) -> PartyPlayer:
	return main.get_node_or_null("Player" if peer_id == 1 else "NetworkPlayer%d" % peer_id) as PartyPlayer


func _result_cells(main: Node) -> Array:
	var result: Array = []
	for row: Control in main.get_node("Interface/ResultsPanel/Table").list.get_children():
		var cells: Array = [int(row.name)]
		for cell: Label in row.get_children():
			cells.append(cell.text)
		result.append(cells)
	return result


func _disconnected_registries_are_clean(main: Node, original_peer_ids: Array[int]) -> bool:
	if main.get_network_player_ids() != [1] or (main.get_node("MatchManager") as MatchManager).players.keys() != [1]:
		return false
	for peer_id: int in original_peer_ids:
		if peer_id == 1:
			continue
		if (
			main.get_node_or_null("NetworkPlayer%d" % peer_id) != null
			or main._movement_inputs.has(peer_id)
			or (main.get_node("MeteorShower") as MeteorShower)._players.has(peer_id)
			or (main.get_node("Flood") as Flood)._players.has(peer_id)
			or (main.get_node("Tornado") as Tornado)._players.has(peer_id)
			or (main.get_node("Earthquake") as Earthquake)._players.has(peer_id)
			or (main.get_node("Lightning") as Lightning)._players.has(peer_id)
			or (main.get_node("Fire") as Fire)._players.has(peer_id)
			or main.rockslide._players.has(peer_id)
		):
			return false
	return true
