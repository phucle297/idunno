extends SceneTree

## Real Main instances only: mechanism intent uses Main's production RPC and
## all deck state/position observations use its regular match snapshots.
const TIMEOUT_MSEC := 30000
const Mechanisms = preload("res://game/world/town_mechanisms.gd")
var role := ""
var port := 29910

class FixtureMain extends "res://game/main.gd":
	var acks: Dictionary = {}
	var activation_results: Dictionary = {}

	@rpc("any_peer", "call_remote", "reliable")
	func fixture_ack(stage: String, good: bool) -> void:
		if multiplayer.is_server():
			acks[stage] = good

	func acknowledge_server(stage: String, good: bool) -> void:
		if multiplayer.get_unique_id() != 1:
			fixture_ack.rpc_id(1, stage, good)

	@rpc("authority", "call_remote", "reliable")
	func fixture_request_mechanism(id: String, require_nearby: bool) -> void:
		var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
		var player := _player_nodes.get(multiplayer.get_unique_id()) as PartyPlayer
		while require_nearby and is_instance_valid(player) and player.global_position.distance_to(town_mechanisms.get_control_position(id)) > 1.5 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not require_nearby and is_instance_valid(player):
			_request_mechanism.rpc_id(1, id)
			acknowledge_server("request_%s" % id, true)
		elif is_instance_valid(player) and request_nearby_mechanism():
			acknowledge_server("request_%s" % id, true)
		else:
			acknowledge_server("request_%s" % id, false)

	func wait_ack(stage: String, deadline: int) -> bool:
		while not acks.has(stage) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		return bool(acks.get(stage, false))

	func _activate_mechanism(peer_id: int, id: String) -> bool:
		var actor := _player_nodes.get(peer_id) as PartyPlayer
		# Exercise production admission verbatim, including its raycast LOS query.
		var accepted := super._activate_mechanism(peer_id, id)
		print("TOWN_MECHANISM_ACTIVATION id=%s accepted=%s position=%s floor=%s" % [id, accepted, actor.global_position if is_instance_valid(actor) else Vector3.INF, is_instance_valid(actor) and actor.is_on_floor()])
		activation_results[id] = accepted
		return accepted


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set_script(FixtureMain)
	root.add_child(main)
	await process_frame
	match role:
		"server": await _server(main)
		"client": await _client(main)
		_: push_error("Expected --role=server or --role=client"); quit(1)


func _server(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while main.get_network_player_ids().size() != 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while not main.match_manager.can_start_match() and Time.get_ticks_msec() < deadline:
		await process_frame
	var started := main.start_network_match()
	while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	main.disaster_director.set_process(false)
	var guest_id := main.get_network_player_ids()[1] if main.get_network_player_ids().size() == 2 else 0
	var guest := main._player_nodes.get(guest_id) as PartyPlayer
	var awning_control := main.town_mechanisms.get_control_position(Mechanisms.AWNING_ID)
	if is_instance_valid(guest):
		await _place_grounded(guest, awning_control + Vector3(0, 0.12, -0.45), deadline)
	if is_instance_valid(guest) and guest.is_on_floor():
		main.fixture_request_mechanism.rpc_id(guest_id, Mechanisms.AWNING_ID, true)
	var awning_request := await main.wait_ack("request_%s" % Mechanisms.AWNING_ID, deadline)
	while not main.activation_results.has(Mechanisms.AWNING_ID) and Time.get_ticks_msec() < deadline:
		await process_frame
	var awning_accepted := bool(main.activation_results.get(Mechanisms.AWNING_ID, false))
	main.town_mechanisms.reset_for_match()
	var control := main.town_mechanisms.get_control_position(Mechanisms.BRIDGE_ID)
	if is_instance_valid(guest):
		await _place_grounded(guest, control + Vector3(20, 0.12, 0), deadline)
	if is_instance_valid(guest) and guest.is_on_floor():
		main.fixture_request_mechanism.rpc_id(guest_id, Mechanisms.BRIDGE_ID, false)
	var denied_request := await main.wait_ack("request_%s" % Mechanisms.BRIDGE_ID, deadline)
	while not main.activation_results.has(Mechanisms.BRIDGE_ID) and Time.get_ticks_msec() < deadline:
		await process_frame
	var bridge_denied := denied_request and not bool(main.activation_results.get(Mechanisms.BRIDGE_ID, false))
	main.activation_results.erase(Mechanisms.BRIDGE_ID)
	main.acks.erase("request_%s" % Mechanisms.BRIDGE_ID)
	if is_instance_valid(guest):
		await _place_grounded(guest, control + Vector3(0, 0.12, -0.45), deadline)
	if is_instance_valid(guest) and guest.is_on_floor():
		main.fixture_request_mechanism.rpc_id(guest_id, Mechanisms.BRIDGE_ID, true)
	var request_sent := await main.wait_ack("request_%s" % Mechanisms.BRIDGE_ID, deadline)
	while not main.activation_results.has(Mechanisms.BRIDGE_ID) and Time.get_ticks_msec() < deadline:
		await process_frame
	var bridge_accepted := bool(main.activation_results.get(Mechanisms.BRIDGE_ID, false))
	if not bridge_accepted:
		push_error("Mechanism RPC contract failed awning=%s far_bridge_denied=%s guest_bridge_accepted=%s" % [awning_request and awning_accepted, bridge_denied, bridge_accepted])
		quit(1)
		return
	var deck := main.town_mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID)
	if bridge_accepted and is_instance_valid(guest):
		# Preparation teleport is deliberately before carriage; subsequent movement
		# is only AnimatableBody physics plus Main movement replication.
		guest.reset_for_match(deck.origin + Vector3(0.72, 0.38, 2.35))
	var server_start := guest.global_position if is_instance_valid(guest) else Vector3.INF
	while _state(main.town_mechanisms.create_snapshot(), Mechanisms.BRIDGE_ID) != Mechanisms.STATE_REST_B and Time.get_ticks_msec() < deadline:
		await process_frame
	var server_end := guest.global_position if is_instance_valid(guest) else Vector3.INF
	var server_carried := server_start.is_finite() and server_end.is_finite() and server_end.distance_to(server_start) > 1.0 and server_end.distance_to(main.town_mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID).origin) < 5.9
	var client_carried := await main.wait_ack("client_carriage", deadline)
	var reset_acks := true
	for cycle in 5:
		for id in main.get_network_player_ids():
			main.match_manager.apply_damage(id, 1000, "fixture")
		while main.match_manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		reset_acks = reset_acks and await main.wait_ack("results_%d" % (cycle + 1), deadline)
		reset_acks = reset_acks and main.restart_network_match()
		while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		reset_acks = reset_acks and await main.wait_ack("reset_%d" % (cycle + 1), deadline)
	var passed := started and awning_request and awning_accepted and bridge_denied and request_sent and bridge_accepted and server_carried and client_carried and reset_acks
	if passed:
		print("TOWN_MECHANISM_ENET_SERVER_OK guest_bridge_rpc=accepted server_carriage=passed client_reset_acks=5")
	else:
		push_error("Mechanism ENet server failed started=%s request=%s accepted=%s server_carriage=%s client_carriage=%s resets=%s" % [started, request_sent, bridge_accepted, server_carried, client_carried, reset_acks])
	await create_timer(0.3).timeout
	quit(0 if passed else 1)


func _client(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while main.get_network_player_ids().size() != 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	while not _moving(main.town_mechanisms.create_snapshot(), Mechanisms.BRIDGE_ID) and Time.get_ticks_msec() < deadline:
		await process_frame
	var player := main._player_nodes.get(main.multiplayer.get_unique_id()) as PartyPlayer
	while is_instance_valid(player) and player.global_position.distance_to(main.town_mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID).origin) > 5.8 and Time.get_ticks_msec() < deadline:
		await process_frame
	var passenger_start := player.global_position if is_instance_valid(player) else Vector3.INF
	while _state(main.town_mechanisms.create_snapshot(), Mechanisms.BRIDGE_ID) != Mechanisms.STATE_REST_B and Time.get_ticks_msec() < deadline:
		await process_frame
	var passenger_end := player.global_position if is_instance_valid(player) else Vector3.INF
	var client_carried := main._last_match_snapshot_sequence > 0 and passenger_start.is_finite() and passenger_end.is_finite() and passenger_end.distance_to(passenger_start) > 1.0 and passenger_end.distance_to(main.town_mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID).origin) < 5.9
	main.acknowledge_server("client_carriage", client_carried)
	for cycle in 5:
		while main.match_manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		main.acknowledge_server("results_%d" % (cycle + 1), main.match_manager.state == MatchManager.MatchState.RESULTS)
		while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		var reset := _state(main.town_mechanisms.create_snapshot(), Mechanisms.BRIDGE_ID) == Mechanisms.STATE_REST_A
		main.acknowledge_server("reset_%d" % (cycle + 1), reset)
	var passed := client_carried
	if passed:
		print("TOWN_MECHANISM_ENET_CLIENT_OK guest_bridge=accepted client_carriage=passed rematch_reset_acks=5")
	else:
		push_error("Mechanism ENet client failed carriage=%s" % client_carried)
	await create_timer(0.3).timeout
	quit(0 if passed else 1)


func _place_grounded(player: PartyPlayer, position: Vector3, deadline: int) -> void:
	player.reset_for_match(position)
	for _tick in 12:
		if Time.get_ticks_msec() >= deadline:
			return
		player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame


func _moving(snapshot: Dictionary, id: String) -> bool:
	for entry: Dictionary in snapshot.mechanisms:
		if entry.id == id:
			return entry.state == Mechanisms.STATE_MOVING and entry.progress > 0.0
	return false


func _state(snapshot: Dictionary, id: String) -> int:
	for entry: Dictionary in snapshot.mechanisms:
		if entry.id == id:
			return int(entry.state)
	return -1
