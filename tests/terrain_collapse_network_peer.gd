extends SceneTree
## Real ENet collapse matrix. The authority advances the match clock only; every
## client observes ordinary match snapshots before the next destructive step.

const TIMEOUT_MSEC := 90000

var role := ""
var port := 29820
var player_count := 2
var map_id := "toy_town"


class FixtureMain extends "res://game/main.gd":
	var collapse_acks: Dictionary = {}
	var departure_allowed := false

	@rpc("authority", "call_remote", "reliable", 2)
	func allow_departure() -> void:
		departure_allowed = true

	@rpc("any_peer", "call_local", "reliable")
	func acknowledge_collapse(stage_name: String, ok: bool) -> void:
		if multiplayer.is_server() and get_network_player_ids().has(multiplayer.get_remote_sender_id()):
			if not collapse_acks.has(stage_name):
				collapse_acks[stage_name] = {}
			collapse_acks[stage_name][multiplayer.get_remote_sender_id()] = ok
			if not ok:
				print("COLLAPSE_ACK_FAILED stage=%s peer=%d" % [stage_name, multiplayer.get_remote_sender_id()])

	func wait_for_collapse(stage_name: String, expected: int, deadline: int) -> bool:
		while (not collapse_acks.has(stage_name) or collapse_acks[stage_name].size() != expected or collapse_acks[stage_name].values().has(false)) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		return collapse_acks.has(stage_name) and collapse_acks[stage_name].size() == expected and not collapse_acks[stage_name].values().has(false)


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


func _run_server(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while main.get_network_player_ids().size() != player_count and Time.get_ticks_msec() < deadline:
		await process_frame
	var manager: MatchManager = main.match_manager
	main.set_local_ready(true)
	while not manager.can_start_match() and Time.get_ticks_msec() < deadline:
		await process_frame
	var start := InputEventAction.new()
	start.action = "ui_accept"
	start.pressed = true
	main._unhandled_input(start)
	while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
		await process_frame
	(main.disaster_director as DisasterDirector).set_process(false)
	var terrain: TerrainCollapse = main.terrain_collapse
	var peers := main.get_network_player_ids()
	var client_count := player_count - 1
	var all_passed := peers.size() == player_count and manager.get_alive_count() == player_count
	var removed_count := 0
	var section := main.get_node("Sandbox/" + ("RoofPanelWarehouse" if map_id == "toy_harbor" else "RoofPanelShop")) as BreakableStructure
	section.set_structure_state(BreakableStructure.StructureState.BROKEN)
	main._match_snapshot_remaining = 0.0
	all_passed = all_passed and await main.wait_for_collapse("broken_structure", client_count, deadline)
	# Advance through each real warning and wait for actual replicated state.
	for stage_index in 4:
		# Cover formerly immune districts with real authoritative warnings.
		if stage_index < 2:
			var forced: Rect2 = terrain.regions[4 if stage_index == 0 else 1]
			terrain.candidate_is_safe = func(bounds: Rect2) -> bool: return bounds == forced
		else:
			terrain.candidate_is_safe = main._collapse_district_is_safe
		manager.elapsed_time = TerrainCollapse.NOTICE_TIMES[stage_index] / 600.0 * manager.match_duration + 0.02
		terrain.tick(manager, 19011)
		while terrain.pending < 0 and Time.get_ticks_msec() < deadline:
			await process_frame
		var pending := terrain.pending
		# No fixed safe center: seat controls on a district surviving this cut.
		for region: Rect2 in terrain.regions:
			var center := region.get_center()
			var at := Vector3(center.x, 0, center.y)
			if not terrain.supports_point(at, 0.0, true):
				continue
			for index in peers.size():
				var control := main._player_nodes[peers[index]] as PartyPlayer
				var seat := at + Vector3((index % 5) * 0.7, 0, (index / 5) * 0.7)
				seat.y = main.get_map_surface_height(seat) + 0.05
				control.global_position = seat
				control.velocity = Vector3.ZERO
			break
		main._match_snapshot_remaining = 0.0
		await process_frame
		var warning_ok: bool = await main.wait_for_collapse("warning_%d" % stage_index, client_count, deadline)
		all_passed = all_passed and pending >= 0 and warning_ok
		# The victim is a real remote capsule. The other peers remain alive at
		# 100 HP; collision disappears via TerrainCollapse's cached world nodes.
		var victim_id: int = peers[1]
		var victim := main._player_nodes.get(victim_id) as PartyPlayer
		if stage_index == 3 and is_instance_valid(victim):
			var bounds: Rect2 = terrain.regions[pending]
			victim.global_position = Vector3(bounds.get_center().x, 2.0, bounds.get_center().y)
			victim.velocity = Vector3.ZERO
		manager.elapsed_time = terrain.deadline + 0.02
		terrain.tick(manager, 19011)
		removed_count += 1
		main._match_snapshot_remaining = 0.0
		await process_frame
		var removal_ok: bool = await main.wait_for_collapse("removed_%d" % stage_index, client_count, deadline)
		all_passed = all_passed and terrain.removed_mask & (1 << pending) != 0 and terrain.pending == -1 and removal_ok
		if stage_index == 0:
			# A real prop body dropped into the hole must park on the server
			# and despawn on every client instead of falling forever.
			var bounds0: Rect2 = terrain.regions[pending]
			var crate := main.get_tree().get_nodes_in_group("network_prop")[0] as RigidBody3D
			crate.global_position = Vector3(bounds0.get_center().x, 0.5, bounds0.get_center().y)
			crate.linear_velocity = Vector3.ZERO
			crate.angular_velocity = Vector3.ZERO
			crate.sleeping = false
			while not crate.has_meta("void_parked") and Time.get_ticks_msec() < deadline:
				await physics_frame
			all_passed = all_passed and crate.has_meta("void_parked") and not crate.visible
			all_passed = all_passed and await main.wait_for_collapse("prop_despawn", client_count, deadline)
		for peer_id in peers:
			if peer_id != victim_id:
				all_passed = all_passed and is_equal_approx(manager.get_health(peer_id), 100.0)
	while manager.is_player_alive(peers[1]) and Time.get_ticks_msec() < deadline:
		await physics_frame
	all_passed = all_passed and not manager.is_player_alive(peers[1]) and manager.get_cause_of_death(peers[1]) == TerrainCollapse.DEATH_CAUSE
	# Five real owner restarts must restore terrain and health on all peers.
	var rematches_ok := true
	for cycle in 5:
		# Results is required by the production restart API.
		for peer_id in peers:
			manager.apply_damage(peer_id, 100.0, "Collapse rematch fixture")
		while manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		rematches_ok = rematches_ok and await main.wait_for_collapse("results_%d" % cycle, client_count, deadline)
		rematches_ok = rematches_ok and main.restart_network_match()
		while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		main._match_snapshot_remaining = 0.0
		await process_frame
		rematches_ok = rematches_ok and await main.wait_for_collapse("rematch_%d" % cycle, client_count, deadline)
		rematches_ok = rematches_ok and terrain.removed_mask == 0 and terrain.pending == -1 and terrain.stage == 0
		rematches_ok = rematches_ok and section.structure_state == BreakableStructure.StructureState.INTACT and section.get_node("Visual").visible and not section.get_node("Collision").disabled
		var reset_crate := main.get_tree().get_nodes_in_group("network_prop")[0] as RigidBody3D
		rematches_ok = rematches_ok and reset_crate.visible and not reset_crate.has_meta("void_parked") and not reset_crate.freeze
		for peer_id in peers:
			rematches_ok = rematches_ok and is_equal_approx(manager.get_health(peer_id), 100.0)
		main.disaster_director.set_process(false)
	all_passed = all_passed and rematches_ok and removed_count == 4
	all_passed = all_passed and await main.wait_for_collapse("done", client_count, deadline)
	_stop_producers(main)
	# Listen-host relay remains enabled. Serialize observer departures instead
	# of closing all native ENet channels simultaneously.
	for peer_id in peers:
		if peer_id == 1:
			continue
		main.rpc_id(peer_id, "allow_departure")
		while main.get_network_player_ids().has(peer_id) and Time.get_ticks_msec() < deadline:
			await process_frame
		all_passed = all_passed and not main.get_network_player_ids().has(peer_id)
	if all_passed:
		print("TERRAIN_COLLAPSE_ENET_SERVER_OK map=%s players=%d warnings=4 removals=4 collision_fall=passed alive_100=passed sequence_monotonic=passed rematches=5" % [map_id, player_count])
	else:
		push_error("Terrain collapse ENet server failed map=%s players=%d removed=%d rematches=%s ids=%s state=%d" % [map_id, player_count, removed_count, rematches_ok, peers, manager.state])
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	quit(0 if all_passed else 1)


func _run_client(main: FixtureMain) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (main.get_network_player_ids().size() != player_count or main.match_manager.players.size() != player_count) and Time.get_ticks_msec() < deadline:
		await process_frame
	var local_id: int = root.multiplayer.get_unique_id()
	main.set_local_ready(true)
	var terrain: TerrainCollapse = main.terrain_collapse
	var manager: MatchManager = main.match_manager
	var client_authority_ok := terrain.pending == -1 and terrain.removed_mask == 0
	# A client tick is deliberately a no-op: it cannot select, remove, or kill.
	terrain.tick(manager, 19011)
	client_authority_ok = client_authority_ok and terrain.pending == -1 and terrain.removed_mask == 0 and manager.is_player_alive(local_id)
	var sequence := main._last_match_snapshot_sequence
	var passed := client_authority_ok
	var section := main.get_node("Sandbox/" + ("RoofPanelWarehouse" if map_id == "toy_harbor" else "RoofPanelShop")) as BreakableStructure
	while section.structure_state != BreakableStructure.StructureState.BROKEN and Time.get_ticks_msec() < deadline:
		await process_frame
	passed = passed and section.structure_state == BreakableStructure.StructureState.BROKEN
	main.rpc_id(1, "acknowledge_collapse", "broken_structure", section.structure_state == BreakableStructure.StructureState.BROKEN)
	for stage_index in 4:
		while (terrain.pending < 0 or terrain.stage != stage_index) and Time.get_ticks_msec() < deadline:
			await process_frame
		var warning_ok := terrain.pending >= 0 and terrain.stage == stage_index and main._last_match_snapshot_sequence > sequence
		var pending := terrain.pending
		sequence = main._last_match_snapshot_sequence
		main.rpc_id(1, "acknowledge_collapse", "warning_%d" % stage_index, warning_ok)
		while (terrain.stage != stage_index + 1 or terrain.pending != -1) and Time.get_ticks_msec() < deadline:
			await process_frame
		var removed_ok := terrain.stage == stage_index + 1 and terrain.removed_mask != 0 and main._last_match_snapshot_sequence > sequence
		await physics_frame
		await physics_frame
		var center := terrain.regions[pending].get_center()
		var at := Vector3(center.x, 0, center.y)
		var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40, at - Vector3.UP * 8, 1))
		removed_ok = removed_ok and hit.is_empty()
		sequence = main._last_match_snapshot_sequence
		passed = passed and warning_ok and removed_ok
		main.rpc_id(1, "acknowledge_collapse", "removed_%d" % stage_index, removed_ok)
		if stage_index == 0:
			var parked := false
			while not parked and Time.get_ticks_msec() < deadline:
				for candidate in main.get_tree().get_nodes_in_group("network_prop"):
					var body := candidate as RigidBody3D
					if is_instance_valid(body) and body.has_meta("void_parked") and not body.visible:
						parked = true
				if not parked:
					await process_frame
			passed = passed and parked
			main.rpc_id(1, "acknowledge_collapse", "prop_despawn", parked)
	for cycle in 5:
		while manager.state != MatchManager.MatchState.RESULTS and Time.get_ticks_msec() < deadline:
			await process_frame
		main.rpc_id(1, "acknowledge_collapse", "results_%d" % cycle, manager.state == MatchManager.MatchState.RESULTS)
		while manager.state != MatchManager.MatchState.ACTIVE and Time.get_ticks_msec() < deadline:
			await process_frame
		# Require a post-restart snapshot, not merely a local reset callback.
		while (terrain.stage != 0 or terrain.removed_mask != 0 or terrain.pending != -1) and Time.get_ticks_msec() < deadline:
			await process_frame
		var reset_ok := terrain.stage == 0 and terrain.removed_mask == 0 and terrain.pending == -1 and is_equal_approx(manager.get_health(local_id), 100.0)
		var client_crate := main.get_tree().get_nodes_in_group("network_prop")[0] as RigidBody3D
		var unpark_deadline := Time.get_ticks_msec() + 5000
		while client_crate.has_meta("void_parked") and Time.get_ticks_msec() < unpark_deadline:
			await process_frame
		reset_ok = reset_ok and client_crate.visible and not client_crate.has_meta("void_parked")
		var top: float = section.global_position.y + (section.get_node("Collision").shape as BoxShape3D).size.y * 0.5
		var point := Vector3(section.global_position.x, top, section.global_position.z)
		# Terrain restores shapes with set_deferred. ACTIVE/prop snapshots may
		# arrive before the physics space has incorporated those shape changes.
		await physics_frame
		await physics_frame
		var restored_hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 0.02, 1))
		reset_ok = reset_ok and section.structure_state == BreakableStructure.StructureState.INTACT and section.get_node("Visual").visible and not section.get_node("Collision").disabled and not restored_hit.is_empty() and restored_hit.collider == section
		if not reset_ok:
			print("COLLAPSE_RESET_FAILED cycle=%d health=%.1f parked=%s structure=%d visible=%s disabled=%s hit=%s" % [cycle, manager.get_health(local_id), client_crate.has_meta("void_parked"), section.structure_state, section.get_node("Visual").visible, section.get_node("Collision").disabled, restored_hit])
		passed = passed and reset_ok
		main.rpc_id(1, "acknowledge_collapse", "rematch_%d" % cycle, reset_ok)
	main.rpc_id(1, "acknowledge_collapse", "done", passed)
	_stop_producers(main)
	while not main.departure_allowed and Time.get_ticks_msec() < deadline:
		await process_frame
	passed = passed and main.departure_allowed
	if passed:
		print("TERRAIN_COLLAPSE_ENET_CLIENT_OK map=%s players=%d peer=%d pending_removed_ack=passed client_tick_noop=passed sequence_monotonic=passed rematches=5" % [map_id, player_count, local_id])
	else:
		push_error("Terrain collapse ENet client failed map=%s players=%d peer=%d stage=%d mask=%d seq=%d" % [map_id, player_count, local_id, terrain.stage, terrain.removed_mask, main._last_match_snapshot_sequence])
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	quit(0 if passed else 1)


func _stop_producers(main: Node) -> void:
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
