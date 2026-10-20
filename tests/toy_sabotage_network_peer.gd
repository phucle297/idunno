extends SceneTree
## Real ENet fixture for the toy controller. World pickups are fixture-seeded;
## clients only acquire/use them through ToySabotage's public local requests.

const TIMEOUT_MSEC := 90000
var role := ""
var port := 29940
var player_count := 2
var map_id := "toy_town"


class FixtureMain extends "res://game/main.gd":
	var fixture_acks: Dictionary = {}
	var departure_allowed := false

	@rpc("authority", "call_remote", "reliable", 2)
	func fixture_intent(intent: String, direction: Vector3 = Vector3.ZERO, round := 0, sequence := 0) -> void:
		var peer_id := multiplayer.get_unique_id()
		match intent:
			"pickup": toy_sabotage.local_request_pickup(peer_id)
			"use": toy_sabotage.local_request_use(peer_id, direction)
			"raw_use": toy_sabotage._request_use.rpc_id(1, round, sequence, direction)

	@rpc("authority", "call_remote", "reliable", 2)
	func fixture_expect(stage: String, expected_round: int, expected_peer: int, expected_kind: String, expected_ammo: int, expected_pickups: int) -> void:
		var deadline := Time.get_ticks_msec() + 6000
		var ok := false
		while Time.get_ticks_msec() < deadline:
			var slot: Dictionary = toy_sabotage.slots.get(expected_peer, {})
			ok = toy_sabotage.round_sequence == expected_round and toy_sabotage.pickups.size() == expected_pickups
			if expected_kind.is_empty():
				ok = ok and slot.is_empty()
			else:
				ok = ok and String(slot.get("kind", "")) == expected_kind and int(slot.get("ammo", -1)) == expected_ammo
			if ok:
				break
			await get_tree().process_frame
		fixture_ack.rpc_id(1, stage, ok)

	@rpc("authority", "call_remote", "reliable", 2)
	func fixture_allow_departure() -> void:
		departure_allowed = true

	@rpc("authority", "call_remote", "reliable", 2)
	func fixture_observe_impulse(victim_id: int) -> void:
		var deadline := Time.get_ticks_msec() + 6000
		var shoves := get_node("ShoveManager") as ShoveManager
		while int(shoves._last_item_sequence.get(victim_id, 0)) == 0 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		fixture_ack.rpc_id(1, "hammer_impulse", int(shoves._last_item_sequence.get(victim_id, 0)) > 0)

	@rpc("authority", "call_remote", "reliable")
	func fixture_verify_old_round(victim_id: int) -> void:
		# Same ordered channel as the preceding production impulse, not a timer
		# or a different-channel acknowledgement that could race its delivery.
		var shoves := get_node("ShoveManager") as ShoveManager
		fixture_ack.rpc_id(1, "old_round_rejected", int(shoves._last_item_sequence.get(victim_id, 0)) < 999)

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
		await _server(main)
	elif role == "client":
		await _client(main)
	else:
		push_error("Expected --role=server or --role=client")
		quit(1)


func _start(main: FixtureMain, deadline: int) -> bool:
	while main.get_network_player_ids().size() != player_count and Time.get_ticks_msec() < deadline:
		await process_frame
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
	return main.match_manager.state == MatchManager.MatchState.ACTIVE


func _place(main: FixtureMain, peer_id: int, point: Vector3) -> void:
	var player := main._player_nodes.get(peer_id) as PartyPlayer
	if is_instance_valid(player):
		player.global_position = point + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO


func _publish(main: FixtureMain) -> void:
	main._match_snapshot_remaining = 0.0
	await process_frame
	await physics_frame


func _expect(main: FixtureMain, stage: String, round: int, peer_id: int, kind: String, ammo: int, pickups: int, deadline: int) -> bool:
	main.fixture_acks.erase(stage)
	main.fixture_expect.rpc(stage, round, peer_id, kind, ammo, pickups)
	var ok := await main.wait_acks(stage, player_count - 1, deadline)
	print("TOY_ENET_STAGE stage=%s ok=%s round=%d" % [stage, ok, round])
	return ok


func _remote_intent(main: FixtureMain, peer_id: int, intent: String, direction := Vector3.ZERO, round := 0, sequence := 0) -> void:
	main.fixture_intent.rpc_id(peer_id, intent, direction, round, sequence)


func _give_remote(main: FixtureMain, remote_id: int, kind: String, pickup_id: int, pad: Vector3, deadline: int, stage: String) -> bool:
	for peer_id in main.get_network_player_ids():
		_place(main, peer_id, pad + Vector3(8, 0, 0))
	_place(main, remote_id, pad)
	main.toy_sabotage.pickups.append({"id": pickup_id, "kind": kind, "position": pad, "expires": main.match_manager.elapsed_time + 20.0})
	main.toy_sabotage._revision += 1
	await _publish(main)
	_remote_intent(main, remote_id, "pickup")
	var expected_ammo := int(ToySabotage.KINDS[kind])
	while not main.toy_sabotage.slots.has(remote_id) and Time.get_ticks_msec() < deadline:
		await process_frame
	await _publish(main)
	return main.toy_sabotage.slots.has(remote_id) and await _expect(main, stage, main.toy_sabotage.round_sequence, remote_id, kind, expected_ammo, 0, deadline)


func _use_remote(main: FixtureMain, remote_id: int, kind: String, ammo: int, deadline: int, stage: String) -> bool:
	main.match_manager.elapsed_time += 1.0
	_remote_intent(main, remote_id, "use", Vector3(1, 0, 0))
	var slot: Dictionary = main.toy_sabotage.slots.get(remote_id, {})
	while int(slot.get("ammo", -1)) != ammo and Time.get_ticks_msec() < deadline:
		await process_frame
		slot = main.toy_sabotage.slots.get(remote_id, {})
	await _publish(main)
	return int(slot.get("ammo", -1)) == ammo and await _expect(main, stage, main.toy_sabotage.round_sequence, remote_id, kind, ammo, 0, deadline)


func _server(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var passed: bool = await _start(main, deadline)
	var peers := main.get_network_player_ids()
	var host_id := peers[0]
	var remote_id := peers[1]
	var pad: Vector3 = main.toy_sabotage.anchors[0]
	# This scenario seeds drops explicitly; scheduled spawning has its own
	# controller test and must not add a fourth pickup during charge assertions.
	main.toy_sabotage.anchors.clear()
	main.match_manager.elapsed_time = 3.1
	# Two real controllers contend for one seed; the client must observe the
	# single winner rather than receiving a fixture-granted slot.
	_place(main, host_id, pad)
	_place(main, remote_id, pad)
	main.toy_sabotage.pickups.append({"id": 700, "kind": "foam_blaster", "position": pad, "expires": 30.0})
	main.toy_sabotage._revision += 1
	_remote_intent(main, remote_id, "pickup")
	main.toy_sabotage.local_request_pickup(host_id)
	while main.toy_sabotage.pickups.size() != 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	passed = passed and main.toy_sabotage.slots.size() == 1
	var winner := remote_id if main.toy_sabotage.slots.has(remote_id) else host_id
	await _publish(main)
	passed = passed and await _expect(main, "competition", main.toy_sabotage.round_sequence, remote_id, "foam_blaster" if winner == remote_id else "", 3 if winner == remote_id else 0, 0, deadline)
	main.toy_sabotage.reset()
	# Actual client requests cover every finite-charge toy, repeated uses and
	# the replicated slots/effects snapshot path.
	passed = passed and await _give_remote(main, remote_id, "foam_blaster", 701, pad, deadline, "foam_pickup")
	for ammo in [2, 1, 0]:
		passed = passed and await _use_remote(main, remote_id, "foam_blaster", ammo, deadline, "foam_%d" % ammo)
		main.toy_sabotage.tick(4.0, 1)
	passed = passed and await _give_remote(main, remote_id, "plunger_rocket", 702, pad, deadline, "rocket_pickup")
	passed = passed and await _use_remote(main, remote_id, "plunger_rocket", 0, deadline, "rocket_use")
	main.toy_sabotage.tick(4.0, 1)
	passed = passed and await _give_remote(main, remote_id, "squeaky_hammer", 703, pad, deadline, "hammer_pickup")
	_place(main, host_id, pad + Vector3(1.2, 0, 0))
	for ammo in [1, 0]:
		passed = passed and await _use_remote(main, remote_id, "squeaky_hammer", ammo, deadline, "hammer_%d" % ammo)
		main.toy_sabotage.tick(1.0, 1)
	var shoves := main.get_node("ShoveManager") as ShoveManager
	passed = passed and int(shoves._last_item_sequence.get(host_id, 0)) > 0
	main.fixture_observe_impulse.rpc(host_id)
	passed = passed and await main.wait_acks("hammer_impulse", player_count - 1, deadline)
	# Five production rematches require ordinary ready snapshots, then prove the
	# client-local request sequence is reset by acquiring and firing every round.
	for cycle in 5:
		for peer_id in main.get_network_player_ids():
			main.match_manager.apply_damage(peer_id, 1000.0, "toy fixture")
		while main.match_manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		passed = passed and main.restart_network_match()
		while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		(main.disaster_director as DisasterDirector).set_process(false)
		main.match_manager.elapsed_time = 3.1
		passed = passed and await _give_remote(main, remote_id, "foam_blaster", 800 + cycle, pad, deadline, "rematch_pickup_%d" % cycle)
		passed = passed and await _use_remote(main, remote_id, "foam_blaster", 2, deadline, "rematch_use_%d" % cycle)
	# The same real RPC path must reject malformed, duplicate and stale requests
	# without consuming the remaining client-owned foam charge.
	var before_ammo := int(main.toy_sabotage.slots[remote_id].ammo)
	_remote_intent(main, remote_id, "raw_use", Vector3.INF, main.toy_sabotage.round_sequence, 3)
	_remote_intent(main, remote_id, "raw_use", Vector3(1, 0, 0), main.toy_sabotage.round_sequence, 3)
	_remote_intent(main, remote_id, "raw_use", Vector3(1, 0, 0), main.toy_sabotage.round_sequence - 1, 4)
	for _frame in 12:
		await process_frame
	passed = passed and before_ammo == 2 and int(main.toy_sabotage.slots[remote_id].ammo) == before_ammo
	shoves._replicate_item_impulse.rpc(host_id, remote_id, 999, Vector3.RIGHT, 2.0, 8.0, main.toy_sabotage.round_sequence - 1)
	main.fixture_verify_old_round.rpc(remote_id)
	passed = passed and await main.wait_acks("old_round_rejected", player_count - 1, deadline)
	# Disconnect after a real client slot was observed; Main's departure cleanup
	# must remove it without fixture mutation.
	for peer_id in peers:
		if peer_id != host_id:
			main.fixture_allow_departure.rpc_id(peer_id)
			# Listen-host relay remains enabled; wait for real departure before
			# asking another peer to close its native ENet channels.
			while main.get_network_player_ids().has(peer_id) and Time.get_ticks_msec() < deadline:
				await process_frame
	passed = passed and not main.get_network_player_ids().has(remote_id) and not main.toy_sabotage.slots.has(remote_id)
	if passed:
		print("TOY_SABOTAGE_ENET_SERVER_OK map=%s players=%d competition=single_winner charges=3,1,2 snapshot_observer=passed malformed_duplicate_stale=passed rematches=5 disconnect_cleanup=passed" % [map_id, player_count])
	else:
		push_error("Toy sabotage ENet server failed map=%s players=%d round=%d slots=%s" % [map_id, player_count, main.toy_sabotage.round_sequence, main.toy_sabotage.slots])
	quit(0 if passed else 1)


func _client(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (main.get_network_player_ids().size() != player_count or main.match_manager.players.size() != player_count) and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	while not main.departure_allowed and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := main.departure_allowed and main.toy_sabotage.round_sequence >= 1
	if passed:
		print("TOY_SABOTAGE_ENET_CLIENT_OK map=%s players=%d peer=%d snapshots=passed local_intents=passed rematches=5" % [map_id, player_count, main.multiplayer.get_unique_id()])
	else:
		push_error("Toy sabotage ENet client failed round=%d departure=%s" % [main.toy_sabotage.round_sequence, main.departure_allowed])
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	if is_instance_valid(main.toy_audio):
		main.toy_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.free()
	await create_timer(0.1).timeout
	quit(0 if passed else 1)
