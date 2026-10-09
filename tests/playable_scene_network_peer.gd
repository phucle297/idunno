extends SceneTree

const TIMEOUT_MSEC := 20000
const PlayerScene = preload("res://scenes/player.tscn")

var role := ""
var port := 29730
var capture_path := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
		elif argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
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
	main._update_lobby_ui()
	var lobby: Panel = main.get_node("Interface/LobbyPanel")
	var lobby_passed: bool = lobby.visible and lobby.get_node("Start").visible and lobby.get_node("Start").disabled and not main.gameplay_hud.health_card.visible
	main._set_lobby_visible(false)
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
	main.set_local_ready(true)
	while not manager.can_start_match() and Time.get_ticks_msec() < deadline:
		await process_frame
	main._update_lobby_ui()
	lobby_passed = lobby_passed and not lobby.get_node("Start").disabled and "host can start" in lobby.get_node("Status").text
	var start_event := InputEventAction.new()
	start_event.action = "ui_accept"
	start_event.pressed = true
	main._unhandled_input(start_event)
	await create_timer(0.4).timeout
	var active_passed := (
		manager.state == MatchManager.MatchState.ACTIVE
		and manager.get_alive_count() == 2
		and (main.get_node("DisasterDirector") as DisasterDirector).running
	)
	var pause_time: float = manager.elapsed_time
	main.pause_settings.open_pause()
	Input.action_press("move_right")
	await create_timer(0.35).timeout
	Input.action_release("move_right")
	active_passed = active_passed and not paused and manager.elapsed_time > pause_time + 0.2 and main._movement_inputs[1].direction == Vector2.ZERO and host_player.local_input_blocked
	main.pause_settings.back()
	print("NETWORK_HOST_PAUSE_OK=%s" % active_passed)
	var grab_manager := main.get_node("GrabManager") as GrabManager
	var shared_prop := main._network_prop(1) as RigidBody3D
	shared_prop.freeze = true
	shared_prop.global_position = host_player.get_grab_origin() + host_player.get_grab_direction() * 1.0
	shared_prop.freeze = false
	var prop_replication_passed := grab_manager.request_grab(1, shared_prop)
	await create_timer(1.0).timeout
	prop_replication_passed = prop_replication_passed and int(shared_prop.get_meta("grab_owner_peer_id", 0)) == 1
	grab_manager.release_grab(1)
	shared_prop.freeze = true
	shared_prop.global_position = client_player.get_grab_origin() + client_player.get_grab_direction()
	shared_prop.linear_velocity = Vector3.ZERO
	shared_prop.freeze = false
	while grab_manager.get_grab_owner(shared_prop) != client_id and Time.get_ticks_msec() < deadline:
		await process_frame
	prop_replication_passed = prop_replication_passed and grab_manager.get_grab_owner(shared_prop) == client_id and shared_prop.get_collision_exceptions().has(client_player) and not shared_prop.get_collision_exceptions().has(host_player)
	while grab_manager.get_grab_owner(shared_prop) != 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	shared_prop.freeze = true
	shared_prop.global_position = host_player.get_grab_origin() + host_player.get_grab_direction()
	shared_prop.linear_velocity = Vector3.ZERO
	shared_prop.freeze = false
	prop_replication_passed = prop_replication_passed and grab_manager.request_grab(1, shared_prop)
	await create_timer(0.3).timeout
	host_player.apply_knockdown(Vector3(2.0, 1.0, 0.0))
	await create_timer(0.7).timeout
	var ragdoll_replication_passed := host_player.is_knocked_down() and host_player.ragdoll_body_count() == 11
	var meteor := main.get_node("MeteorShower") as MeteorShower
	meteor.set_process(false)
	var meteor_started := meteor.start_warning(Vector3(0.0, 0.06, 3.0))
	await create_timer(0.4).timeout
	meteor.cleanup()
	await create_timer(0.3).timeout
	var lightning := main.get_node("Lightning") as Lightning
	lightning.set_process(false)
	var lightning_started := lightning.start_warning(Vector3(4.0, 0.06, 4.0))
	await create_timer(0.4).timeout
	lightning.cleanup()
	await create_timer(0.3).timeout
	var fire := main.get_node("Fire") as Fire
	fire.set_process(false)
	var fire_started := fire.start_warning(7)
	await create_timer(0.4).timeout
	fire.cleanup()
	await create_timer(0.3).timeout
	var flood := main.get_node("Flood") as Flood
	var tornado := main.get_node("Tornado") as Tornado
	flood.set_process(false)
	tornado.set_process(false)
	var flood_started := flood.start_warning()
	flood.tick(flood.warning_duration)
	flood.tick(flood.rise_duration * 0.45)
	var electric_lightning_started := lightning.start_warning(Vector3(0.0, 0.06, 0.0))
	lightning.tick(lightning.warning_duration)
	var electric_combination_passed := flood.electrified_remaining > 0.0
	await create_timer(0.5).timeout
	lightning.cleanup()
	flood.cleanup()
	await create_timer(0.3).timeout
	var combination_fire_started := fire.start_warning(6)
	fire.tick(fire.warning_duration)
	var tornado_started := tornado.start_warning(Vector3(-7.0, 0.0, 5.0), Vector3(9.0, 0.0, 5.0))
	tornado.tick(tornado.warning_duration)
	tornado.tick(1.6)
	var wind_combination_passed := fire.wind_active and fire.burning_debris_count() == 1
	await create_timer(0.5).timeout
	fire.cleanup()
	tornado.cleanup()
	await create_timer(0.3).timeout
	var earthquake := main.get_node("Earthquake") as Earthquake
	earthquake.set_process(false)
	var earthquake_started := earthquake.start_warning()
	earthquake.tick(earthquake.warning_duration)
	await create_timer(0.5).timeout
	var disasters_passed := (
		meteor_started
		and lightning_started
		and fire_started
		and flood_started
		and electric_lightning_started
		and electric_combination_passed
		and combination_fire_started
		and tornado_started
		and wind_combination_passed
		and earthquake_started
		and earthquake.phase == Earthquake.Phase.ACTIVE
	)
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
		and (main.get_node("Interface/ResultsPanel") as Panel).visible
		and main.get_node("Interface/ResultsPanel/Table").rows[client_id].get_node("Outcome").text == "Network test"
	)
	var rematch_passed := true
	for rematch_index: int in 5:
		var old_prop := main._network_prop(1) as RigidBody3D
		old_prop.freeze = true
		old_prop.global_position = host_player.get_grab_origin() + host_player.get_grab_direction()
		old_prop.freeze = false
		rematch_passed = grab_manager.request_grab(1, old_prop) and rematch_passed
		rematch_passed = rematch_passed and main.restart_network_match()
		var new_prop := main._network_prop(1) as RigidBody3D
		rematch_passed = rematch_passed and not is_instance_valid(old_prop) and grab_manager.get_held_body(1) == null and not new_prop.has_meta("grab_owner_peer_id") and new_prop.get_collision_exceptions().is_empty()
		await create_timer(0.3).timeout
		rematch_passed = (
			rematch_passed
			and manager.state == MatchManager.MatchState.ACTIVE
			and manager.get_alive_count() == 2
			and is_equal_approx(manager.get_health(client_id), 100.0)
			and not (main.get_node("Interface/ResultsPanel") as Panel).visible
			and (main.get_node("DisasterDirector") as DisasterDirector).running
		)
		# Exercise the live server safety check, not a client-authored damage event.
		var escaped_player: PartyPlayer = main._player_nodes[client_id]
		escaped_player.position = Vector3(33, 1, 0) if rematch_index % 2 == 0 else Vector3(0, -9, 0)
		await create_timer(0.3).timeout
		rematch_passed = (
			rematch_passed
			and manager.state == MatchManager.MatchState.RESULTS
			and manager.get_alive_count() == 1
			and manager.get_cause_of_death(client_id) == "Out of bounds"
			and (main.get_node("Interface/ResultsPanel") as Panel).visible
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
	var passed: bool = lobby_passed and spawn_passed and movement_passed and active_passed and prop_replication_passed and ragdoll_replication_passed and disasters_passed and nonlethal_passed and lethal_passed and rematch_passed and cleanup_passed
	if passed:
		print("NETWORK_HOST_LOBBY_OK start_gating=passed readiness=passed hud_suppression=passed")
		print("PLAYABLE_NETWORK_SERVER_OK spawned=2 authoritative_movement=passed shared_props=passed ragdoll_presentation=passed match_health=passed disaster_presentation=passed elimination=passed network_rematches=5 remaining=1 disconnected_peer=%d" % client_id)
	else:
		push_error("Playable server validation failed spawn=%s movement=%s active=%s props=%s ragdoll=%s disasters=%s nonlethal=%s lethal=%s rematch=%s cleanup=%s ids=%s players=%s" % [spawn_passed, movement_passed, active_passed, prop_replication_passed, ragdoll_replication_passed, disasters_passed, nonlethal_passed, lethal_passed, rematch_passed, cleanup_passed, main.get_network_player_ids(), manager.players.keys()])
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	await create_timer(0.1).timeout
	main.free()
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
	var manager := main.get_node("MatchManager") as MatchManager
	while not manager.players.has(local_id) and Time.get_ticks_msec() < deadline:
		await process_frame
	main._update_lobby_ui()
	var lobby: Panel = main.get_node("Interface/LobbyPanel")
	var before: Dictionary = main._create_playable_snapshot().duplicate(true)
	var lobby_passed: bool = lobby.visible and not lobby.get_node("Start").visible and not lobby.get_node("Ready").disabled and "only the host" in lobby.get_node("Status").text and not main.start_network_match() and main._create_playable_snapshot() == before
	lobby_passed = lobby_passed and lobby.get_node("PlayerList").rows[local_id].get_node("Content/Identity/Markers").text == "YOU" and lobby.get_node("PlayerList").rows[1].get_node("Content/Identity/Markers").text == "HOST"
	main._set_lobby_visible(false)
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
	main.set_local_ready(true)
	while (
		(manager.state != MatchManager.MatchState.ACTIVE or manager.get_health(local_id) != 100.0)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	var active_passed := manager.state == MatchManager.MatchState.ACTIVE and manager.get_alive_count() == 2
	var pause_time: float = manager.elapsed_time
	main.pause_settings.open_pause()
	Input.action_press("move_right")
	await create_timer(0.25).timeout
	Input.action_release("move_right")
	active_passed = active_passed and not paused and manager.elapsed_time > pause_time and local_player.local_input_blocked
	main.pause_settings.back()
	print("NETWORK_CLIENT_PAUSE_OK=%s" % active_passed)
	var shared_prop := main._network_prop(1) as RigidBody3D
	while int(shared_prop.get_meta("grab_owner_peer_id", 0)) != 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	var prop_replication_passed := (
		int(shared_prop.get_meta("grab_owner_peer_id", 0)) == 1
		and shared_prop.freeze
		and shared_prop.global_position.distance_to(host_player.get_hold_position()) < 1.5
		and shared_prop.get_collision_exceptions().has(host_player)
	)
	while (int(shared_prop.get_meta("grab_owner_peer_id", 0)) != 0 or main.get_node("GrabManager").get_interaction_candidate(local_player) != shared_prop) and Time.get_ticks_msec() < deadline:
		await process_frame
	main.get_node("GrabManager").request_local_toggle(local_id)
	while int(shared_prop.get_meta("grab_owner_peer_id", 0)) != local_id and Time.get_ticks_msec() < deadline:
		await process_frame
	prop_replication_passed = prop_replication_passed and int(shared_prop.get_meta("grab_owner_peer_id", 0)) == local_id and shared_prop.get_collision_exceptions().has(local_player) and not shared_prop.get_collision_exceptions().has(host_player)
	main.get_node("GrabManager").request_local_toggle(local_id)
	while int(shared_prop.get_meta("grab_owner_peer_id", 0)) != 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	prop_replication_passed = prop_replication_passed and shared_prop.get_collision_exceptions().has(host_player) and not shared_prop.get_collision_exceptions().has(local_player)
	while not host_player.is_knocked_down() and Time.get_ticks_msec() < deadline:
		await process_frame
	while int(shared_prop.get_meta("grab_owner_peer_id", 0)) != 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	prop_replication_passed = prop_replication_passed and not shared_prop.get_collision_exceptions().has(host_player)
	var ragdoll_replication_passed := host_player.is_knocked_down() and host_player.ragdoll_body_count() == 11 and not host_player.visual.visible
	var meteor := main.get_node("MeteorShower") as MeteorShower
	while meteor.phase != MeteorShower.Phase.WARNING and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var meteor_passed: bool = (
		meteor.phase == MeteorShower.Phase.WARNING
		and meteor.active_effect_count() == 1
		and main.gameplay_hud.get_presented_hazards().any(func(line: String) -> bool: return "METEOR" in line)
	)
	if not meteor_passed:
		print("METEOR_PRESENTATION_DIAGNOSTIC phase=%s effects=%d hazards=%s" % [meteor.phase, meteor.active_effect_count(), main.gameplay_hud.get_presented_hazards()])
	var lightning := main.get_node("Lightning") as Lightning
	while lightning.phase != Lightning.Phase.WARNING and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var lightning_passed: bool = (
		lightning.phase == Lightning.Phase.WARNING
		and lightning.active_effect_count() == 1
		and main.gameplay_hud.get_presented_hazards().any(func(line: String) -> bool: return "LIGHTNING" in line)
	)
	var fire := main.get_node("Fire") as Fire
	while fire.phase != Fire.Phase.WARNING and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var fire_passed: bool = (
		fire.phase == Fire.Phase.WARNING
		and fire.active_effect_count() == 1
		and main.gameplay_hud.get_presented_hazards().any(func(line: String) -> bool: return "FIRE" in line)
	)
	var flood := main.get_node("Flood") as Flood
	var tornado := main.get_node("Tornado") as Tornado
	while flood.electrified_remaining <= 0.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var electric_text := "\n".join(main.gameplay_hud.get_presented_hazards())
	var electric_combination_passed := (
		flood.phase == Flood.Phase.RISING
		and flood.electrified_remaining > 0.0
		and flood.active_effect_count() == 1
		and "ELECTRIFIED WATER" in electric_text
	)
	while (fire.phase != Fire.Phase.ACTIVE or tornado.phase != Tornado.Phase.ACTIVE) and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var wind_text := "\n".join(main.gameplay_hud.get_presented_hazards())
	var wind_combination_passed := (
		fire.phase == Fire.Phase.ACTIVE
		and fire.wind_active
		and fire.burning_debris_count() == 1
		and tornado.phase == Tornado.Phase.ACTIVE
		and "WIND IS SPREADING FLAMES" in wind_text
		and "TORNADO" in wind_text
	)
	if wind_combination_passed and not capture_path.is_empty():
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var capture_error := image.save_png(capture_path)
		wind_combination_passed = capture_error == OK
	var earthquake := main.get_node("Earthquake") as Earthquake
	while earthquake.phase != Earthquake.Phase.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var earthquake_text := "\n".join(main.gameplay_hud.get_presented_hazards())
	var earthquake_passed := (
		earthquake.phase == Earthquake.Phase.ACTIVE
		and earthquake.active_effect_count() == 1
		and "EARTHQUAKE" in earthquake_text
	)
	while manager.get_health(local_id) != 75.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var nonlethal_passed: bool = (
		manager.get_health(local_id) == 75.0
		and manager.get_alive_count() == 2
		and main.gameplay_hud.get_presented_health() == 75
		and main.gameplay_hud.get_presented_alive_counts() == Vector2i(2, 2)
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
		and main.gameplay_hud.get_presented_health() == 0
		and main.gameplay_hud.get_presented_alive_counts() == Vector2i(1, 2)
		and (main.get_node("Interface/ResultsPanel") as Panel).visible
		and main.get_node("Interface/ResultsPanel/Table").rows[local_id].get_node("Outcome").text == "Network test"
		and (main.get_node("Interface/ResultsPanel/Prompt") as Label).text == "WAITING FOR HOST TO START REMATCH"
	)
	var rematch_passed := true
	for rematch_index: int in 5:
		while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		await process_frame
		var authoritative_health := manager.get_health(local_id)
		var replicated_position := local_player.position
		var reset_prop := main._network_prop(1) as RigidBody3D
		rematch_passed = rematch_passed and int(reset_prop.get_meta("grab_owner_peer_id", 0)) == 0 and reset_prop.get_collision_exceptions().is_empty() and main.get_node("GrabManager").get_held_body(local_id) == null
		local_player.position = Vector3(40, -10, 0)
		main._eliminate_out_of_bounds()
		rematch_passed = rematch_passed and manager.get_health(local_id) == authoritative_health
		local_player.position = replicated_position
		rematch_passed = (
			rematch_passed
			and manager.state == MatchManager.MatchState.ACTIVE
			and manager.get_alive_count() == 2
			and is_equal_approx(manager.get_health(local_id), 100.0)
			and local_player.visual.visible
			and not main.spectator_controller.active
			and not (main.get_node("Interface/ResultsPanel") as Panel).visible
		)
		while manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		await process_frame
		var rematch_outcome: String = main.get_node("Interface/ResultsPanel/Table").rows[local_id].get_node("Outcome").text
		rematch_passed = (
			rematch_passed
			and manager.state == MatchManager.MatchState.RESULTS
			and not local_player.visual.visible
			and main.spectator_controller.active
			and (main.get_node("Interface/ResultsPanel") as Panel).visible
			and rematch_outcome == "Out of bounds"
		)
	var passed: bool = lobby_passed and spawn_passed and movement_passed and active_passed and prop_replication_passed and ragdoll_replication_passed and meteor_passed and lightning_passed and fire_passed and electric_combination_passed and wind_combination_passed and earthquake_passed and nonlethal_passed and lethal_passed and rematch_passed
	if passed:
		print("NETWORK_CLIENT_LOBBY_OK local_host_markers=passed client_start_rejected=passed readiness=passed")
		print("PLAYABLE_NETWORK_CLIENT_OK local=%d players=2 observed_host_and_local_movement=passed shared_props=passed ragdoll_presentation=passed match_health_hud=passed disaster_presentation=passed elimination_spectating=passed results=passed network_rematches=5" % local_id)
	else:
		push_error("Playable client validation failed spawn=%s movement=%s active=%s meteor=%s lightning=%s fire=%s electric_combination=%s wind_combination=%s earthquake=%s nonlethal=%s lethal=%s rematch=%s local=%d ids=%s" % [spawn_passed, movement_passed, active_passed, meteor_passed, lightning_passed, fire_passed, electric_combination_passed, wind_combination_passed, earthquake_passed, nonlethal_passed, lethal_passed, rematch_passed, local_id, main.get_network_player_ids()])
	await create_timer(0.25).timeout
	(main.get_node("GameplayAudio") as GameplayAudioController).reset_for_match()
	await create_timer(0.1).timeout
	main.free()
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
	var earthquake := main.get_node("Earthquake") as Earthquake
	var lightning := main.get_node("Lightning") as Lightning
	var fire := main.get_node("Fire") as Fire
	var passed: bool = (
		manager.register_player(peer_id, "Cleanup Probe")
		and grab_manager.register_player(peer_id, replacement)
		and meteor.register_player(peer_id, replacement)
		and flood.register_player(peer_id, replacement)
		and tornado.register_player(peer_id, replacement)
		and earthquake.register_player(peer_id, replacement)
		and lightning.register_player(peer_id, replacement)
		and fire.register_player(peer_id, replacement)
	)
	grab_manager.unregister_player(peer_id)
	meteor.unregister_player(peer_id)
	flood.unregister_player(peer_id)
	tornado.unregister_player(peer_id)
	earthquake.unregister_player(peer_id)
	lightning.unregister_player(peer_id)
	fire.unregister_player(peer_id)
	manager.unregister_player(peer_id)
	replacement.queue_free()
	return passed


func _non_server_peer_id(peer_ids: Array[int]) -> int:
	for peer_id: int in peer_ids:
		if peer_id != 1:
			return peer_id
	return 0
