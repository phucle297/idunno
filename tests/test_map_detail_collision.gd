extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_expect(main.start_local_match(), "Collision/rematch fixture explicitly starts solo")
	main.set_process(false)
	main.set_physics_process(false)
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.set_map_id(map_id)
		main.disaster_director.cleanup()
		main.match_manager.set_process(false)
		await physics_frame
		await physics_frame
		var count := get_nodes_in_group("solid_map_detail").size()
		_expect(count > 0, "%s has solid environmental detail" % map_id)
		for round_index in 5:
			await _check_obstacles(main, player, map_id)
			main.match_manager.apply_damage(1, 1000, "Fixture")
			_expect(main.restart_local_match(), "Rematch restores %s" % map_id)
			main.disaster_director.cleanup()
			main.match_manager.set_process(false)
			await physics_frame
			_expect(get_nodes_in_group("solid_map_detail").size() == count, "Rematch must not duplicate or lose solid details")
		print("MAP_DETAIL_COLLIDERS map=%s bodies=%d" % [map_id, count])
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MAP_DETAIL_COLLISION_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)


func _check_obstacles(main: Node3D, player: PartyPlayer, map_id: String) -> void:
	var sandbox := main.get_node("Sandbox")
	var probes: Array[Dictionary] = []
	if map_id == "toy_town":
		probes = [
			{"start": Vector3(17.9, 2.22, 8), "motion": Vector3(0, 0, 2)},
			{"start": Vector3(-42, 5.425, -14.5), "motion": Vector3(-3, 0, 0)},
			{"start": Vector3(-9.1, 0.05, -7.3), "motion": Vector3(0, 0, 3)},
			{"start": Vector3(-8, 0.14, -9), "motion": Vector3(0, 0, 2)}
		]
		# Probe above the planter's box so the foliage itself, not its container,
		# must collide. Check through real world physics rather than node names.
		var center := Vector3(-44.8, 1.93, -16.5)
		var query := PhysicsRayQueryParameters3D.create(center + Vector3(-2, 0.2, 0), center + Vector3(2, 0.2, 0), 1)
		var hit := main.get_world_3d().direct_space_state.intersect_ray(query)
		_expect(not hit.is_empty() and hit.collider.is_in_group("solid_map_detail"), "Shrub foliage above planter must block a ray")
	else:
		var rail: Node3D = sandbox.get_node("DockWest/SeawardRail")
		probes = [
			{"start": rail.global_position + Vector3(0, 0.02, 1), "motion": Vector3(0, 0, -2)},
			{"start": Vector3(16, 0.02, -22), "motion": Vector3(0, 0, 3)},
			{"start": Vector3(-20, 3.77, 10), "motion": Vector3(0, 0, 2)}
		]
	for probe in probes:
		_expect(player.test_move(Transform3D(Basis.IDENTITY, probe.start), probe.motion), "%s player capsule cannot pass through rail/planter/lamp/cargo: %s" % [map_id, probe.start])
	# No blanket collision on flat markings: a capsule can still cross the plaza
	# or boardwalk without a hidden wall introduced by decorative overlays.
	var start := Vector3(0, 0.18, 3) if map_id == "toy_town" else Vector3(0, 0.1, 22)
	_expect(not player.test_move(Transform3D(Basis.IDENTITY, start), Vector3(2, 0, 0)), "%s flat paving/paint remains traversable" % map_id)
	if map_id == "toy_town":
		# Walking with gravity must also remain blocked, not drop under a rail
		# floating beyond its supporting platform after a successful shape sweep.
		for powered in [false, true]:
			player.reset_for_match(Vector3(17.9, 2.22, 11))
			player.movement_buff = Vector2(MatchPowerups.Kind.SPEED, 12) if powered else Vector2.ZERO
			player.set_camera_yaw(0.0)
			for tick in 70:
				player.apply_movement_input(Vector2(0, -1), powered, false, 1.0 / 60.0)
				await physics_frame
			_expect(player.position.z > 10.3 and player.is_on_floor(), "Park railing blocks base walking and powered sprinting while supported by its platform")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
