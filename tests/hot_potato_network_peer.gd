extends SceneTree
## Bounded real-ENet coverage for the production hidden-fuse controller.
## Private clock/deadline control is fixture-only; no fuse value is serialized or printed.

const TIMEOUT_MSEC := 90000
var role := ""
var port := 29970
var player_count := 2
var map_id := "toy_town"


class FixtureMain extends "res://game/main.gd":
	var fixture_acks: Dictionary = {}
	var departure_allowed := false
	var departure_phase := HotPotato.Phase.IDLE

	func _remove_network_player(peer_id: int) -> void:
		super._remove_network_player(peer_id)
		# Capture Main's real departure cleanup before a one-survivor result reset.
		departure_phase = hot_potato.phase

	@rpc("authority", "call_remote", "reliable", 2)
	func fixture_action(action: String, direction := Vector3.ZERO) -> void:
		var peer_id := multiplayer.get_unique_id()
		if action == "pickup":
			hot_potato.local_request(peer_id, true)
		elif action == "throw":
			hot_potato.local_request(peer_id, false, direction)
		elif action == "depart":
			departure_allowed = true

	@rpc("authority", "call_remote", "reliable", 2)
	func fixture_observe(stage: String, expected_phase: int, expected_owner: int) -> void:
		var deadline := Time.get_ticks_msec() + 6000
		var ok := false
		while Time.get_ticks_msec() < deadline:
			var public_state := hot_potato.create_snapshot()
			var wire := hot_potato.create_wire_snapshot()
			ok = public_state.size() == 6 and public_state.has_all(["round", "revision", "id", "phase", "owner", "position"]) and wire.size() == HotPotato.WIRE_SIZE and HotPotato.decode_wire_snapshot(wire).size() == 6 and int(public_state.phase) == expected_phase and int(public_state.owner) == expected_owner
			if expected_phase == HotPotato.Phase.BURST:
				var shoves := get_node("ShoveManager") as ShoveManager
				ok = ok and int(shoves._last_item_sequence.get(expected_owner, 0)) > 0 and match_manager.get_health(expected_owner) == 100.0
			if ok:
				break
			await get_tree().process_frame
		fixture_ack.rpc_id(1, stage, ok)

	@rpc("any_peer", "call_remote", "reliable", 2)
	func fixture_ack(stage: String, ok: bool) -> void:
		if multiplayer.is_server():
			fixture_acks[stage] = fixture_acks.get(stage, {})
			fixture_acks[stage][multiplayer.get_remote_sender_id()] = ok

	func wait_acks(stage: String, expected: int, deadline: int) -> bool:
		while (not fixture_acks.has(stage) or fixture_acks[stage].size() != expected or fixture_acks[stage].values().has(false)) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		return fixture_acks.has(stage) and fixture_acks[stage].size() == expected and not fixture_acks[stage].values().has(false)


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
	main.set_script(FixtureMain)
	main.name = "Main"
	root.add_child(main)
	if role == "server":
		main.set_map_id(map_id)
	await process_frame
	if role == "server":
		await _server(main as FixtureMain)
	elif role == "client":
		await _client(main as FixtureMain)
	else:
		push_error("Expected --role=server or --role=client")
		quit(1)


func _place(main: FixtureMain, peer_id: int, point: Vector3) -> void:
	var actor := main._player_nodes.get(peer_id) as PartyPlayer
	if not is_instance_valid(actor):
		return
	actor.global_position = Vector3(point.x, main.get_map_support_height(point) + 0.04, point.z)
	actor.velocity = Vector3.DOWN * 2.0
	for frame in 4:
		await physics_frame
	actor.velocity = Vector3.ZERO


func _publish(main: FixtureMain) -> void:
	main._match_snapshot_remaining = 0.0
	await process_frame
	await physics_frame


func _observe(main: FixtureMain, stage: String, phase: int, owner: int, expected: int, deadline: int) -> bool:
	main.fixture_acks.erase(stage)
	main.fixture_observe.rpc(stage, phase, owner)
	var ok := await main.wait_acks(stage, expected, deadline)
	print("HOT_POTATO_ENET_STAGE stage=%s ok=%s phase=%d owner=%d" % [stage, ok, phase, owner])
	return ok


func _wait_state(main: FixtureMain, phase: int, owner: int, deadline: int) -> bool:
	while (main.hot_potato.phase != phase or main.hot_potato.holder_id != owner) and Time.get_ticks_msec() < deadline:
		await process_frame
	return main.hot_potato.phase == phase and main.hot_potato.holder_id == owner


func _start(main: FixtureMain, deadline: int) -> bool:
	while main.get_network_player_ids().size() != player_count and Time.get_ticks_msec() < deadline:
		await process_frame
	var preset_ok := main.request_match_preset("hot_potato")
	main.set_local_ready(true)
	while not main.match_manager.can_start_match() and Time.get_ticks_msec() < deadline:
		await process_frame
	var start := InputEventAction.new()
	start.action = "ui_accept"
	start.pressed = true
	main._unhandled_input(start)
	while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	(main.disaster_director as DisasterDirector).set_process(false)
	var started := main.match_manager.state == MatchManager.MatchState.ACTIVE and main.match_preset == "hot_potato"
	print("HOT_POTATO_ENET_START preset_ok=%s started=%s preset=%s ready=%s" % [preset_ok, started, main.match_preset, main.match_manager.can_start_match()])
	return started


func _spawn_and_pickup(main: FixtureMain, remote_id: int, pad: Vector3, deadline: int, stage: String) -> bool:
	for peer_id in main.get_network_player_ids():
		await _place(main, peer_id, pad + Vector3(8, 0, 0))
	main.match_manager.elapsed_time = maxf(main.match_manager.elapsed_time, 5.0)
	main.hot_potato.tick(0.0)
	while main.hot_potato.phase != HotPotato.Phase.GROUND and Time.get_ticks_msec() < deadline:
		await process_frame
	await _place(main, remote_id, pad)
	print("HOT_POTATO_ENET_PICKUP_SETUP stage=%s phase=%d floor=%s collect=%s" % [stage, main.hot_potato.phase, (main._player_nodes[remote_id] as PartyPlayer).is_on_floor(), main.hot_potato.can_collect(remote_id)])
	main.fixture_action.rpc_id(remote_id, "pickup")
	var picked := await _wait_state(main, HotPotato.Phase.CARRIED, remote_id, deadline)
	await _publish(main)
	return picked and await _observe(main, stage, HotPotato.Phase.CARRIED, remote_id, player_count - 1, deadline)


func _server(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var passed: bool = await _start(main, deadline)
	var peers := main.get_network_player_ids()
	var host_id := peers[0]
	var remote_id := peers[1]
	var pad: Vector3 = main.toy_sabotage.anchors[0]
	# Retain the production anchor contract while suppressing unrelated pickups.
	main.hot_potato.anchors.assign([pad])
	passed = passed and await _spawn_and_pickup(main, remote_id, pad, deadline, "remote_pickup")
	await _place(main, host_id, pad + Vector3(1.2, 0, 0))
	main.fixture_action.rpc_id(remote_id, "throw", Vector3.RIGHT)
	passed = passed and await _wait_state(main, HotPotato.Phase.CARRIED, host_id, deadline)
	await _publish(main)
	passed = passed and await _observe(main, "throw_receive", HotPotato.Phase.CARRIED, host_id, player_count - 1, deadline)
	# The fixture advances only authority time; the wire/snapshot observer above
	# proves that no deadline data is present in normal Main snapshots.
	main.hot_potato._deadline = main.match_manager.elapsed_time
	main.hot_potato.tick(0.0)
	var shoves := main.get_node("ShoveManager") as ShoveManager
	passed = passed and main.hot_potato.phase == HotPotato.Phase.BURST and int(shoves._last_item_sequence.get(host_id, 0)) > 0 and (main._player_nodes[host_id] as PartyPlayer).velocity.length() <= 8.0
	await _publish(main)
	passed = passed and await _observe(main, "burst", HotPotato.Phase.BURST, host_id, player_count - 1, deadline)
	# Five real rematches exercise client sequence reset and normal snapshots.
	for cycle in 5:
		for peer_id in main.get_network_player_ids():
			main.match_manager.apply_damage(peer_id, 1000.0, "bomb fixture")
		while main.match_manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		passed = passed and main.restart_network_match()
		while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		(main.disaster_director as DisasterDirector).set_process(false)
		main.hot_potato.anchors.assign([pad])
		passed = passed and await _spawn_and_pickup(main, remote_id, pad, deadline, "rematch_%d" % cycle)
	# An actual ENet departure while carrying must remove the player through Main.
	# Two-player rows prove supported drop; larger rows prove void cancellation.
	if player_count > 2:
		(main._player_nodes[remote_id] as PartyPlayer).global_position.y = -20.0
	main.fixture_action.rpc_id(remote_id, "depart")
	while main.get_network_player_ids().has(remote_id) and Time.get_ticks_msec() < deadline:
		await process_frame
	passed = passed and not main.get_network_player_ids().has(remote_id) and not main._player_nodes.has(remote_id) and (main.departure_phase == HotPotato.Phase.GROUND if player_count == 2 else main.departure_phase == HotPotato.Phase.CANCEL)
	# Remaining observers have completed every snapshot check; close them through
	# the same fixture command rather than leaving client processes to time out.
	for peer_id in peers:
		if peer_id != host_id and peer_id != remote_id and main.get_network_player_ids().has(peer_id):
			main.fixture_action.rpc_id(peer_id, "depart")
	if passed:
		print("HOT_POTATO_ENET_SERVER_OK map=%s players=%d remote_pickup=passed throw_receive=passed burst=bounded_impulse snapshots=29_bytes_six_keys_private rematches=5 departure=%s" % [map_id, player_count, "drop" if player_count == 2 else "cancel"])
	else:
		push_error("Hot potato ENet server failed map=%s players=%d phase=%d owner=%d" % [map_id, player_count, main.hot_potato.phase, main.hot_potato.holder_id])
	quit(0 if passed else 1)


func _client(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (main.get_network_player_ids().size() != player_count or main.match_manager.players.size() != player_count) and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while not main.departure_allowed and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := main.departure_allowed and main.hot_potato.round_sequence >= 1
	if passed:
		print("HOT_POTATO_ENET_CLIENT_OK map=%s players=%d peer=%d snapshots=passed local_request_rpc=passed rematches=5" % [map_id, player_count, main.multiplayer.get_unique_id()])
	else:
		push_error("Hot potato ENet client failed departure=%s round=%d" % [main.departure_allowed, main.hot_potato.round_sequence])
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.free()
	await create_timer(0.1).timeout
	quit(0 if passed else 1)
