extends SceneTree
## Real ENet power-up contract fixture. Pickups are seeded only as world state;
## every collection still travels through MatchPowerups.tick on the authority.

const TIMEOUT_MSEC := 90000

var role := ""
var port := 29860
var player_count := 2
var map_id := "toy_town"


class FixtureMain extends "res://game/main.gd":
	var powerup_acks: Dictionary = {}
	var departure_allowed := false

	@rpc("authority", "call_remote", "reliable", 2)
	func inspect_powerups(stage_name: String, expected_pickups: int, expected_kind: int, expected_holder: int, require_tuning: bool, expected_round: int, expected_state: int, expected_id: int) -> void:
		var local_id := multiplayer.get_unique_id()
		var deadline := Time.get_ticks_msec() + 5000
		var ok := false
		while Time.get_ticks_msec() < deadline:
			var holder := _player_nodes.get(expected_holder) as PartyPlayer
			var local := _player_nodes.get(local_id) as PartyPlayer
			ok = powerups.pickups.size() == expected_pickups and powerups.round_sequence == expected_round and match_manager.state == expected_state
			if expected_holder > 0:
				var buff: Dictionary = powerups.buffs.get(expected_holder, {})
				ok = ok and int(buff.get("kind", -1)) == expected_kind and int(buff.get("id", 0)) == expected_id
				ok = ok and is_instance_valid(holder) and int(holder.movement_buff.x) == expected_kind and holder.movement_buff.y > 0.0
			else:
				ok = ok and powerups.buffs.is_empty()
				for avatar: PartyPlayer in _player_nodes.values():
					ok = ok and avatar.movement_buff == Vector2.ZERO
			if require_tuning:
				ok = ok and is_instance_valid(holder) and holder.effective_sprint_speed() > PartyPlayer.Tuning.SPRINT_SPEED
				if local_id == expected_holder:
					ok = ok and is_instance_valid(local) and local.effective_walk_speed() > PartyPlayer.Tuning.WALK_SPEED
			if ok:
				break
			await get_tree().physics_frame
		if ok and stage_name == "prediction":
			var holder := _player_nodes.get(expected_holder) as PartyPlayer
			if local_id == expected_holder:
				var from := holder.global_position
				Input.action_press("move_right")
				Input.action_press("sprint")
				for frame in 30:
					await get_tree().physics_frame
				Input.action_release("move_right")
				Input.action_release("sprint")
				ok = holder.global_position.distance_to(from) > 1.0 and Vector2(holder.velocity.x, holder.velocity.z).length() > 6.5
			else:
				while is_instance_valid(holder) and Vector2(holder.velocity.x, holder.velocity.z).length() <= 6.5 and Time.get_ticks_msec() < deadline:
					await get_tree().physics_frame
				ok = is_instance_valid(holder) and Vector2(holder.velocity.x, holder.velocity.z).length() > 6.5
		if not ok:
			print("POWERUP_INSPECTION_FAILED stage=%s round=%d expected=%d state=%d buffs=%s" % [stage_name, powerups.round_sequence, expected_round, match_manager.state, powerups.buffs])
		rpc_id(1, "acknowledge_powerups", stage_name, ok)

	@rpc("authority", "call_remote", "reliable", 2)
	func allow_departure() -> void:
		departure_allowed = true

	@rpc("any_peer", "call_local", "reliable")
	func acknowledge_powerups(stage_name: String, ok: bool) -> void:
		if multiplayer.is_server() and get_network_player_ids().has(multiplayer.get_remote_sender_id()):
			if not powerup_acks.has(stage_name):
				powerup_acks[stage_name] = {}
			powerup_acks[stage_name][multiplayer.get_remote_sender_id()] = ok
			if not ok:
				print("POWERUP_ACK_FAILED stage=%s peer=%d" % [stage_name, multiplayer.get_remote_sender_id()])

	func wait_for_powerups(stage_name: String, expected: int, deadline: int) -> bool:
		while (not powerup_acks.has(stage_name) or powerup_acks[stage_name].size() != expected or powerup_acks[stage_name].values().has(false)) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		return powerup_acks.has(stage_name) and powerup_acks[stage_name].size() == expected and not powerup_acks[stage_name].values().has(false)


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
		await _run_server(main)
	elif role == "client":
		await _run_client(main)
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
	return main.get_network_player_ids().size() == player_count and main.match_manager.state == MatchManager.MatchState.ACTIVE


func _place(main: FixtureMain, peer_id: int, at: Vector3) -> void:
	var player := main._player_nodes.get(peer_id) as PartyPlayer
	player.global_position = at + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO


func _seed(main: FixtureMain, pickup_id: int, kind: int, at: Vector3, expires: float) -> void:
	main.powerups.pickups.append({"id": pickup_id, "kind": kind, "position": at, "expires": expires})


func _publish(main: FixtureMain) -> void:
	main._match_snapshot_remaining = 0.0
	await process_frame
	await physics_frame


func _inspect(main: FixtureMain, stage_name: String, expected_pickups: int, kind: int, holder: int, deadline: int, tuning := false) -> bool:
	var id := int(main.powerups.buffs.get(holder, {}).get("id", 0))
	main.inspect_powerups.rpc(stage_name, expected_pickups, kind, holder, tuning, main.powerups.round_sequence, main.match_manager.state, id)
	var ok := await main.wait_for_powerups(stage_name, player_count - 1, deadline)
	print("POWERUP_STAGE stage=%s ok=%s round=%d" % [stage_name, ok, main.powerups.round_sequence])
	return ok


func _run_server(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var manager: MatchManager = main.match_manager
	var passed: bool = await _start(main, deadline)
	var peers := main.get_network_player_ids()
	var host_id := peers[0]
	var remote_id := peers[1] # For two players this is the real client contender.
	var contention_a := host_id if player_count == 2 else peers[1]
	var contention_b := remote_id if player_count == 2 else peers[2]
	var pad := main.powerups.anchors[0]
	var far_pad := main.powerups.anchors[1]
	# An ordinary seeded scheduled drop must replicate before any fixture pickup.
	for peer_id in peers:
		_place(main, peer_id, main.map_anchors.spawn_origin)
	manager.elapsed_time = MatchPowerups.SPAWN_INTERVAL + 0.1
	main.powerups.tick(manager, main._player_nodes, 12031)
	await _publish(main)
	passed = passed and main.powerups.pickups.size() == 1
	passed = passed and await _inspect(main, "scheduled", 1, MatchPowerups.Kind.NONE, 0, deadline)
	main.powerups.pickups.clear()
	# At 2 the host/client pair contend; at larger counts two remote real
	# avatars contend. Stable peer ordering must consume the pickup only once.
	for peer_id in peers:
		_place(main, peer_id, far_pad)
	_place(main, contention_a, pad)
	_place(main, contention_b, pad)
	_seed(main, 901, MatchPowerups.Kind.SPEED, pad, manager.elapsed_time + 20.0)
	main.powerups.tick(manager, main._player_nodes, 12031)
	await _publish(main)
	passed = passed and main.powerups.buffs.has(contention_a) and not main.powerups.buffs.has(contention_b)
	passed = passed and await _inspect(main, "contention", 0, MatchPowerups.Kind.SPEED, contention_a, deadline)
	# A remote player replaces Speed with Jump, then refreshes Jump through pickups.
	for peer_id in peers:
		_place(main, peer_id, far_pad)
	_place(main, remote_id, pad)
	_seed(main, 900, MatchPowerups.Kind.SPEED, pad, manager.elapsed_time + 20.0)
	main.powerups.tick(manager, main._player_nodes, 12031)
	await _publish(main)
	passed = passed and await _inspect(main, "remote_speed", 0, MatchPowerups.Kind.SPEED, remote_id, deadline)
	_seed(main, 902, MatchPowerups.Kind.JUMP, pad, manager.elapsed_time + 20.0)
	main.powerups.tick(manager, main._player_nodes, 12031)
	var replaced_id := int(main.powerups.buffs.get(remote_id, {}).get("id", 0))
	await _publish(main)
	passed = passed and replaced_id == 902 and await _inspect(main, "replace", 0, MatchPowerups.Kind.JUMP, remote_id, deadline)
	_seed(main, 903, MatchPowerups.Kind.JUMP, pad, manager.elapsed_time + 20.0)
	main.powerups.tick(manager, main._player_nodes, 12031)
	var refreshed: Dictionary = main.powerups.buffs.get(remote_id, {})
	await _publish(main)
	passed = passed and int(refreshed.get("id", 0)) == 903 and float(refreshed.get("expires", 0.0)) > manager.elapsed_time
	passed = passed and await _inspect(main, "refresh", 0, MatchPowerups.Kind.JUMP, remote_id, deadline)
	# Give the client Speed so its reconciled local prediction and every observer
	# receive effective movement tuning over channel 1.
	_seed(main, 904, MatchPowerups.Kind.SPEED, pad, manager.elapsed_time + 20.0)
	main.powerups.tick(manager, main._player_nodes, 12031)
	await _publish(main)
	passed = passed and await _inspect(main, "prediction", 0, MatchPowerups.Kind.SPEED, remote_id, deadline, true)
	# Advance authoritative match time, rather than editing a buff, to expire it.
	manager.elapsed_time = float(main.powerups.buffs[remote_id].expires) + 0.1
	main.powerups.tick(manager, main._player_nodes, 12031)
	await _publish(main)
	passed = passed and main.powerups.buffs.is_empty()
	passed = passed and await _inspect(main, "expiry", 0, MatchPowerups.Kind.NONE, 0, deadline)
	# Five production rematches clear drops/buffs and advance the power-up round.
	var rematches_ok := true
	var prior_round := main.powerups.round_sequence
	for cycle in 5:
		for peer_id in peers:
			manager.apply_damage(peer_id, 100.0, "Power-up rematch fixture")
		while manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		rematches_ok = rematches_ok and await _inspect(main, "results_%d" % cycle, 0, MatchPowerups.Kind.NONE, 0, deadline)
		rematches_ok = rematches_ok and main.restart_network_match()
		while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		(main.disaster_director as DisasterDirector).set_process(false)
		await _publish(main)
		rematches_ok = rematches_ok and main.powerups.pickups.is_empty() and main.powerups.buffs.is_empty() and main.powerups.round_sequence == prior_round + cycle + 1
		rematches_ok = rematches_ok and await _inspect(main, "rematch_%d" % cycle, 0, MatchPowerups.Kind.NONE, 0, deadline)
	passed = passed and rematches_ok
	# Last real client receives a pickup, then its actual ENet departure removes it.
	for peer_id in peers:
		_place(main, peer_id, far_pad)
	_place(main, remote_id, pad)
	_seed(main, 950, MatchPowerups.Kind.SPEED, pad, manager.elapsed_time + 20.0)
	main.powerups.tick(manager, main._player_nodes, 12031)
	await _publish(main)
	passed = passed and await _inspect(main, "departure_buff", 0, MatchPowerups.Kind.SPEED, remote_id, deadline)
	passed = passed and await _inspect(main, "done", 0, MatchPowerups.Kind.SPEED, remote_id, deadline)
	_stop_producers(main)
	for peer_id in peers:
		if peer_id == 1:
			continue
		main.rpc_id(peer_id, "allow_departure")
		while main.get_network_player_ids().has(peer_id) and Time.get_ticks_msec() < deadline:
			await process_frame
		passed = passed and not main.get_network_player_ids().has(peer_id) and not main.powerups.buffs.has(peer_id)
	if passed:
		print("POWERUP_ENET_SERVER_OK map=%s players=%d scheduled=passed contention=passed replace_refresh_expiry=passed prediction=passed stale_round=passed rematches=5 disconnect_cleanup=passed" % [map_id, player_count])
	else:
		push_error("Power-up ENet server failed map=%s players=%d state=%d buffs=%s" % [map_id, player_count, manager.state, main.powerups.buffs])
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.free()
	await create_timer(0.1).timeout
	quit(0 if passed else 1)


func _run_client(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (main.get_network_player_ids().size() != player_count or main.match_manager.players.size() != player_count) and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_local_ready(true)
	while main.match_manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	while main.powerups.round_sequence <= 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := main.match_manager.state == MatchManager.MatchState.ACTIVE
	# This is an actual client-side stale round rejection, independent of packet
	# ordering: it may not replace the current replicated power-up state.
	var before_round := main.powerups.round_sequence
	var stale: Dictionary = {"round": max(0, before_round - 1), "revision": 0, "pickups": [], "buffs": {}}
	passed = passed and not main.powerups.apply_snapshot(stale) and main.powerups.round_sequence == before_round
	while not main.departure_allowed and Time.get_ticks_msec() < deadline:
		await process_frame
	passed = passed and main.departure_allowed
	if passed:
		print("POWERUP_ENET_CLIENT_OK map=%s players=%d peer=%d snapshots=passed prediction_observer=passed stale_round=passed rematches=5" % [map_id, player_count, root.multiplayer.get_unique_id()])
	else:
		push_error("Power-up ENet client failed map=%s players=%d round=%d buffs=%s" % [map_id, player_count, main.powerups.round_sequence, main.powerups.buffs])
	_stop_producers(main)
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.free()
	await create_timer(0.1).timeout
	quit(0 if passed else 1)


func _stop_producers(main: Node) -> void:
	main.set_process(false)
	main.set_physics_process(false)
	main.gameplay_audio.reset_for_match()
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
