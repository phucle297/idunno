extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(0, 0.1, 0))
	main._add_gameplay_demo_player(3, "Third", Vector3(2, 0.1, 0))
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	var manager: MatchManager = main.match_manager
	var terrain: TerrainCollapse = main.terrain_collapse
	for map_id in ["toy_town", "toy_harbor"]:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		var world_nodes: Array = main.get_node("Sandbox").get_children()
		terrain.candidate_is_safe = main._collapse_district_is_safe
		_expect(terrain.eligible_districts() == [0, 1, 2, 3, 4, 5, 6, 7, 8], "Every district, including center and warehouse, is eligible on an intact map")
		for district in terrain.eligible_districts():
			await _start_round(main)
			var bounds := terrain.regions[district]
			var center := bounds.get_center()
			var at := Vector3(center.x, 0, center.y)
			_expect(not _ray(main, at).is_empty(), "Intact district has real support: %s/%d" % [map_id, district])
			terrain.candidate_is_safe = func(rect: Rect2) -> bool: return rect == bounds
			manager.elapsed_time = 120
			terrain.tick(manager, 881)
			_expect(terrain.pending == district and terrain.removed_mask == 0 and terrain.deadline == 150, "Warning freezes exactly one district without removing its floor")
			manager.elapsed_time = 149.99
			terrain.tick(manager, 999)
			_expect(terrain.pending == district and not _ray(main, at).is_empty(), "Warning never chases targets or changes collision early")
			manager.elapsed_time = 150
			terrain.tick(manager, 999)
			await physics_frame
			await physics_frame
			_expect(terrain.pending == -1 and terrain.removed_mask == 1 << district, "Impact removes the announced district permanently")
			if map_id == "toy_town":
				for roof_x: float in [-27.5, 27.5]:
					var roof_point := Vector3(roof_x, 2, -45)
					if not bounds.has_point(Vector2(roof_point.x, roof_point.z)):
						var support := _ray(main, roof_point)
						_expect(not support.is_empty() and support.position.y > 5, "Unwarned neighboring roof keeps its support: district=%d x=%.1f" % [district, roof_x])
			for x in range(1, ceili(bounds.size.x), 3):
				for z in range(1, ceili(bounds.size.y), 3):
					var point := Vector3(bounds.position.x + x, 0, bounds.position.y + z)
					_expect(_ray(main, point).is_empty(), "Real void has no hidden ground/road/roof support: %s/%d/%s" % [map_id, district, point])
			var neighbor := terrain.regions[(district + 1) % 9].get_center()
			var safe := Vector3(neighbor.x, 0, neighbor.y)
			_expect(not _ray(main, safe).is_empty(), "An unmarked district keeps real ground")
			for peer_id: int in [2, 3]:
				main._player_nodes[peer_id].position = safe + Vector3.UP * 40
			var player: PartyPlayer = main._player_nodes[1]
			player.reset_for_match(at + Vector3.UP * 0.1)
			var fell := false
			for step in 120:
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
				await physics_frame
				if player.global_position.y >= TerrainCollapse.VOID_Y:
					main._eliminate_out_of_bounds()
					_expect(manager.get_health(1) == 100, "No gradual collapse damage before entering the void")
				else:
					fell = true
					main._eliminate_out_of_bounds()
					break
			_expect(fell and manager.get_health(1) == 0 and manager.get_cause_of_death(1) == TerrainCollapse.DEATH_CAUSE, "Real gravity fall is immediately lethal, not a visual-only hole")
			_expect(manager.state == MatchManager.MatchState.ACTIVE and main.spectator_controller.active, "Fall death spectates remaining survivors without respawn")
			var state := manager.create_authoritative_snapshot()
			main._eliminate_out_of_bounds()
			_expect(manager.create_authoritative_snapshot() == state, "Already-dead players never receive duplicate fall damage")
			# Nothing may simulate an endless fall (the Phase1 crash class): a
			# prop dropped into the collapse parks below the kill depth.
			var crate := main.get_tree().get_nodes_in_group("network_prop")[0] as RigidBody3D
			crate.global_position = Vector3(at.x, 0.5, at.z)
			crate.linear_velocity = Vector3.ZERO
			crate.angular_velocity = Vector3.ZERO
			crate.sleeping = false
			for step in 150:
				await physics_frame
				main._despawn_fallen_props()
				if crate.has_meta("void_parked"):
					break
			_expect(crate.has_meta("void_parked") and not crate.visible and crate.freeze, "A prop fallen into the collapse parks out of sight and simulation: %s/%d" % [map_id, district])
			var parked_y := crate.global_position.y
			for step in 60:
				await physics_frame
			_expect(is_equal_approx(crate.global_position.y, parked_y), "A parked prop never keeps falling: %s/%d" % [map_id, district])
			await _start_round(main)
			_expect(not _ray(main, at).is_empty() and terrain.removed_mask == 0 and terrain.pending == -1, "Rematch restores district geometry and collision")
			_expect(main.get_node("Sandbox").get_children() == world_nodes, "Reset never rebuilds the static world")
			_expect(not crate.has_meta("void_parked") and crate.visible and not crate.freeze and crate.global_position.distance_to((crate.get_meta("spawn_transform") as Transform3D).origin) < 1.0, "Rematch restores a parked prop to its spawn state")
			print("TERRAIN_HOLE_CASE_OK map=%s district=%d" % [map_id, district])
		await _start_round(main)
		terrain.candidate_is_safe = Callable()
		manager.elapsed_time = 400
		terrain.tick(manager, 12)
		var selected := terrain.pending
		_expect(selected >= 0 and terrain.deadline == 430 and terrain.removed_mask == 0, "Clock jump publishes a full warning instead of unannounced collapse")
		manager.elapsed_time = 430
		terrain.tick(manager, 12)
		var center := terrain.regions[selected].get_center()
		for player: PartyPlayer in main._player_nodes.values():
			player.position = Vector3(center.x, TerrainCollapse.VOID_Y - 0.01, center.y)
		main._eliminate_out_of_bounds()
		_expect(manager.get_alive_count() == 0 and manager.winner_ids == [1, 2, 3], "Same-step void falls share a result rather than an iteration-order winner")
		await _start_round(main)
		if map_id == "toy_harbor":
			await _check_breakable_lifecycle(main)
			await _start_round(main)
		await _check_schedules(main, map_id)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("TERRAIN_COLLAPSE_OK checks=%d maps=2 physical_holes_fall_batch_reset_schedule=passed" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_breakable_lifecycle(main: Node) -> void:
	var lid := main.get_node("Sandbox/CargoLidWest") as BreakableStructure
	var terrain: TerrainCollapse = main.terrain_collapse
	main.match_manager.elapsed_time = 600
	terrain.apply_snapshot(PackedFloat32Array([1, -1, 0, 1]))
	for pulse in 16:
		main.earthquake._damage_structure()
	_expect(lid.structure_state == BreakableStructure.StructureState.INTACT, "Earthquake pulses exclude structures on removed ground")
	# Remote structure snapshots cannot override terrain removal either.
	lid.set_structure_state(BreakableStructure.StructureState.DAMAGED)
	await physics_frame
	_expect(not lid.get_node("Visual").visible and lid.get_node("Collision").disabled and _ray(main, lid.position).is_empty(), "Damage/snapshot updates never resurrect vanished structure visuals or support")
	await _start_round(main)
	# Capture the formerly broken collider before removing terrain, then reset.
	lid.set_structure_state(BreakableStructure.StructureState.BROKEN, true)
	var rubble := lid.get_debris()
	terrain.apply_snapshot(PackedFloat32Array([1, -1, 0, 1]))
	for frame in 180:
		await physics_frame
		if not is_instance_valid(rubble):
			break
	_expect(not is_instance_valid(rubble) and lid.get_debris() == null, "Ordinary non-burning rubble is freed below the kill depth, even without rematching")
	await _start_round(main)
	var hit := _ray(main, lid.position)
	_expect(lid.structure_state == BreakableStructure.StructureState.INTACT and lid.get_node("Visual").visible and not lid.get_node("Collision").disabled, "Break then collapse then rematch restores the intact structure collider after deferred work")
	_expect(not hit.is_empty() and hit.collider == lid and absf(hit.position.y - 2.84) < 0.01, "Restored cargo lid ray hits the authored top, not the platform underneath")


func _start_round(main: Node) -> void:
	main.match_manager.prepare_lobby()
	main._reset_sandbox()
	for id: int in main.match_manager.players:
		main.match_manager.set_player_ready(id, true)
	_expect(main.match_manager.start_match(), "Fresh round starts")
	main.disaster_director.cleanup()
	for player: PartyPlayer in main._player_nodes.values():
		player.reset_for_match(Vector3(0, 0.1, 0))
	await physics_frame
	await physics_frame


func _check_schedules(main: Node, map_id: String) -> void:
	var empty := Node3D.new()
	main.add_child(empty)
	var controller := TerrainCollapse.new()
	main.add_child(controller)
	controller.configure(map_id, empty)
	for duration: float in [60, 600]:
		main.match_manager.match_duration = duration
		for seed_value in 32:
			controller.reset()
			for stage in 4:
				main.match_manager.elapsed_time = TerrainCollapse.NOTICE_TIMES[stage] / 600 * duration
				controller.tick(main.match_manager, seed_value)
				_expect(controller.pending >= 0 and not controller.removed_mask & (1 << controller.pending), "Seeded cuts select any remaining district without fixed immunity")
				_expect(TerrainCollapse.snapshot_is_valid(map_id, controller.create_snapshot(), main.match_manager.elapsed_time, duration), "Warning snapshot is finite, bounded, clock-consistent and connected")
				main.match_manager.elapsed_time = controller.deadline
				controller.tick(main.match_manager, seed_value)
				_expect(controller.stage == stage + 1 and TerrainCollapse.snapshot_is_valid(map_id, controller.create_snapshot(), main.match_manager.elapsed_time, duration), "Four distinct removals retain connected remaining sectors")
			_expect(controller.eligible_districts().size() > 0, "No total-map destruction")
	main.match_manager.match_duration = 600
	controller.free()
	empty.free()


func _ray(main: Node3D, point: Vector3) -> Dictionary:
	return main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 40, point - Vector3.UP * 8, 1))


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
