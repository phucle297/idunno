extends SceneTree
## Real ENet fixture for the toy controller. World pickups are fixture-seeded;
## clients only acquire/use them through ToySabotage's public local requests.

const TIMEOUT_MSEC := 90000
var role := ""
var port := 29940
var player_count := 2
var map_id := "toy_town"


class ObservedShoves extends ShoveManager:
	var applied_lifts := {}
	var balloon_lifts := {}
	var applied_owners := {}

	func apply_replicated_item_impulse(owner_id: int, victim_id: int, sequence: int, direction: Vector3, strength: float, speed_cap: float = 8.0, lift: float = 0.0) -> bool:
		var accepted := super.apply_replicated_item_impulse(owner_id, victim_id, sequence, direction, strength, speed_cap, lift)
		if accepted:
			applied_owners[victim_id] = owner_id
		if accepted and lift > 0.0 and is_equal_approx((_players[victim_id] as PartyPlayer).velocity.y, 5.4):
			applied_lifts[victim_id] = sequence
		if accepted and is_equal_approx(lift, 3.0) and is_equal_approx((_players[victim_id] as PartyPlayer).velocity.y, 3.0):
			balloon_lifts[victim_id] = sequence
		return accepted


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
			"disabled_spam":
				for index in 70:
					toy_sabotage.local_request_use(peer_id, Vector3.FORWARD)
				fixture_disabled_barrier.rpc_id(1)

	@rpc("any_peer", "call_remote", "reliable")
	func fixture_disabled_barrier() -> void:
		# Same ordered channel as the seventy production use requests. Do not
		# recover the server actor on an independent-channel acknowledgement.
		if multiplayer.is_server():
			fixture_acks["disabled_spam"] = {multiplayer.get_remote_sender_id(): true}

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
	func fixture_observe_effect(stage: String, effect_kind: String, expected_owner := 0) -> void:
		var deadline := Time.get_ticks_msec() + 6000
		var found := false
		while Time.get_ticks_msec() < deadline:
			found = toy_sabotage.effects.any(func(effect: Dictionary) -> bool: return effect.kind == effect_kind and float(effect.remaining) > 0.0 and (expected_owner == 0 or int(effect.owner) == expected_owner))
			if found:
				break
			await get_tree().process_frame
		fixture_ack.rpc_id(1, stage, found)


	@rpc("authority", "call_remote", "reliable")
	func fixture_observe_reflection(owner: int, victim: int) -> void:
		var shoves := get_node("ShoveManager") as ObservedShoves
		fixture_ack.rpc_id(1, "reflection_hit", int(shoves.applied_owners.get(victim, 0)) == owner)

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
	func fixture_observe_lift(victim_id: int, sequence: int, balloon := false) -> void:
		var shoves := get_node("ShoveManager") as ObservedShoves
		# This barrier follows the production lift on the same ordered channel.
		# Record at acceptance: independent movement snapshots can replace velocity
		# before this barrier, so querying the later velocity tests a channel race.
		var observations: Dictionary = shoves.balloon_lifts if balloon else shoves.applied_lifts
		fixture_ack.rpc_id(1, "balloon_lift" if balloon else "spring_lift", sequence > 0 and int(observations.get(victim_id, 0)) == sequence)

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
	main.get_node("ShoveManager").set_script(ObservedShoves)
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
	await _publish(main)
	passed = passed and await _expect(main, "initial_round", main.toy_sabotage.round_sequence, remote_id, "", 0, 0, deadline)
	var recovering := main._player_nodes[remote_id] as PartyPlayer
	recovering.set_network_knockdown(true)
	_remote_intent(main, remote_id, "disabled_spam")
	passed = passed and await main.wait_acks("disabled_spam", 1, deadline)
	passed = passed and not main.toy_sabotage._seen_sequences.has(remote_id)
	recovering.set_network_knockdown(false)
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
	for kind: String in ["boxing_glove", "boomerang", "water_soaker", "soap_slick", "spring_pad", "confetti_bomb", "foam_launcher", "toy_fan", "decoy_runner", "remote_popper", "reflector_umbrella", "rocket_cart", "party_balloon"]:
		main.toy_sabotage.effects.clear()
		passed = passed and await _give_remote(main, remote_id, kind, 710 + ToySabotage.KINDS.keys().find(kind), pad, deadline, kind + "_pickup")
		for ammo in range(int(ToySabotage.KINDS[kind]) - 1, -1, -1):
			passed = passed and await _use_remote(main, remote_id, kind, ammo, deadline, "%s_%d" % [kind, ammo])
			if kind in ["foam_launcher", "toy_fan", "decoy_runner", "remote_popper", "reflector_umbrella"]:
				if kind == "foam_launcher":
					main.toy_sabotage.tick(1.21, 1)
				var effect_kind: String = {"foam_launcher": "foam_screen", "toy_fan": "fan_gust", "decoy_runner": "decoy_running", "remote_popper": "popper_armed", "reflector_umbrella": "umbrella_open"}[kind]
				var effect_stage := "%s_effect_%d" % [kind, ammo]
				await _publish(main)
				main.fixture_observe_effect.rpc(effect_stage, effect_kind)
				passed = passed and await main.wait_acks(effect_stage, player_count - 1, deadline)
			if kind == "spring_pad" and ammo == 1:
				var springs: Array = main.toy_sabotage.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "spring_armed")
				if springs.is_empty():
					passed = false
				else:
					# Earlier hammer protection uses wall time, not the fixture's
					# accelerated match clock; observe expiry before the lift control.
					while shoves.is_protected(host_id) and Time.get_ticks_msec() < deadline:
						await process_frame
					_place(main, host_id, springs[0].position)
					main.toy_sabotage.tick(0.81, 1)
					var sequence := int(shoves._last_item_sequence.get(host_id, 0))
					print("TOY_ENET_LIFT_CONTROL sequence=%d velocity_y=%.3f" % [sequence, (main._player_nodes[host_id] as PartyPlayer).velocity.y])
					main.fixture_observe_lift.rpc(host_id, sequence)
					passed = passed and await main.wait_acks("spring_lift", player_count - 1, deadline)
					_place(main, host_id, pad + Vector3(8, 0, 0))
			main.toy_sabotage.tick(4.0, 1)
			main.toy_sabotage.tick(4.0, 1)
	# Keep physics time fixed while real requests/snapshots cross the network;
	# the short reflection window must not expire while observer barriers arrive.
	main.set_physics_process(false)
	main.toy_sabotage.effects.clear()
	shoves.reset_state()
	passed = passed and await _give_remote(main, remote_id, "remote_popper", 780, pad, deadline, "remote_control_pickup")
	passed = passed and await _use_remote(main, remote_id, "remote_popper", 0, deadline, "remote_control_place")
	main.toy_sabotage.tick(0.71, 1)
	_remote_intent(main, remote_id, "use", Vector3.RIGHT)
	while not main.toy_sabotage.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "popper_warning") and Time.get_ticks_msec() < deadline:
		await process_frame
	await _publish(main)
	main.fixture_observe_effect.rpc("remote_countdown", "popper_warning", remote_id)
	passed = passed and await main.wait_acks("remote_countdown", player_count - 1, deadline)
	main.toy_sabotage.effects.clear()
	passed = passed and await _give_remote(main, remote_id, "reflector_umbrella", 781, pad, deadline, "reflection_pickup")
	passed = passed and await _use_remote(main, remote_id, "reflector_umbrella", 0, deadline, "reflection_open")
	main.toy_sabotage.tick(0.26, 1)
	_place(main, host_id, pad + Vector3.RIGHT * 3.0)
	main.toy_sabotage.pickups.append({"id": 782, "kind": "foam_blaster", "position": (main._player_nodes[host_id] as PartyPlayer).global_position, "expires": main.match_manager.elapsed_time + 20.0})
	main.toy_sabotage.local_request_pickup(host_id)
	main.toy_sabotage.local_request_use(host_id, Vector3.LEFT)
	main.toy_sabotage.tick(0.4, 1)
	await _publish(main)
	main.fixture_observe_effect.rpc("reflection_credit", "pellet_reflected", remote_id)
	passed = passed and await main.wait_acks("reflection_credit", player_count - 1, deadline)
	main.toy_sabotage.tick(0.4, 1)
	main.fixture_observe_reflection.rpc(remote_id, host_id)
	passed = passed and await main.wait_acks("reflection_hit", player_count - 1, deadline)
	main.toy_sabotage.reset()
	shoves.reset_state()
	passed = passed and await _give_remote(main, remote_id, "rocket_cart", 790, pad, deadline, "cart_pickup")
	passed = passed and await _use_remote(main, remote_id, "rocket_cart", 0, deadline, "cart_windup")
	await _publish(main)
	main.fixture_observe_effect.rpc("cart_warning", "cart_windup", remote_id)
	passed = passed and await main.wait_acks("cart_warning", player_count - 1, deadline)
	main.toy_sabotage.tick(1.01, 1)
	await _publish(main)
	main.fixture_observe_effect.rpc("cart_running", "cart_running", remote_id)
	passed = passed and await main.wait_acks("cart_running", player_count - 1, deadline)
	main.toy_sabotage.reset()
	shoves.reset_state()
	passed = passed and await _give_remote(main, remote_id, "party_balloon", 791, pad, deadline, "balloon_pickup")
	_place(main, host_id, pad + Vector3.RIGHT * 2.0)
	var target := main._player_nodes[host_id] as PartyPlayer
	for frame in 10:
		await physics_frame
		target.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
	passed = passed and await _use_remote(main, remote_id, "party_balloon", 0, deadline, "balloon_dart")
	main.toy_sabotage.tick(0.4, 1)
	await _publish(main)
	main.fixture_observe_effect.rpc("balloon_attached", "balloon_attached", remote_id)
	passed = passed and await main.wait_acks("balloon_attached", player_count - 1, deadline)
	main.toy_sabotage.tick(0.61, 1)
	var balloon_sequence := int(shoves._last_item_sequence.get(host_id, 0))
	passed = passed and is_equal_approx(target.velocity.y, 3.0)
	main.fixture_observe_lift.rpc(host_id, balloon_sequence, true)
	passed = passed and await main.wait_acks("balloon_lift", player_count - 1, deadline)
	main.set_physics_process(true)
	# Five production rematches require ordinary ready snapshots, then prove the
	# client-local request sequence is reset by acquiring and firing every round.
	if not passed:
		push_error("Toy catalog or replicated spring acceptance failed before rematch")
		quit(1)
		return
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
		print("TOY_SABOTAGE_ENET_SERVER_OK map=%s players=%d competition=single_winner finite_charge_catalog=%d spring_lift=replicated snapshot_observer=passed malformed_duplicate_stale=passed rematches=5 disconnect_cleanup=passed" % [map_id, player_count, ToySabotage.KINDS.size()])
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
