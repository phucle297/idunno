extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_expect(await main.start_local_match(), "Collision/rematch fixture explicitly starts solo")
	main.set_process(false)
	main.set_physics_process(false)
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		main.disaster_director.cleanup()
		main.match_manager.set_process(false)
		await physics_frame
		await physics_frame
		var count := get_nodes_in_group("solid_map_detail").size()
		_expect(count > 0, "%s has solid environmental detail" % map_id)
		for prop: Node in get_nodes_in_group("network_prop"):
			var has_grounding_shadow := false
			for visual: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
				if visual.mesh != null and visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					has_grounding_shadow = true
			_expect(has_grounding_shadow, "%s movable props retain a grounding shadow" % map_id)
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
	await _check_t48_props(main, player, map_id)
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


# T48: look-solid props (garage sign, harbor warehouse furniture) must block the
# capsule; door lanes and window trim must stay passable.
func _check_t48_props(main: Node3D, player: PartyPlayer, map_id: String) -> void:
	var sandbox := main.get_node("Sandbox")
	if map_id == "toy_town":
		var sign_node := sandbox.get_node("ParkingGarage/GarageSignboard") as Node3D
		_expect(sign_node.get_node_or_null("SolidDetail") != null, "T48 GarageSignboard has a collider")
		var deck_y := sign_node.global_position.y - 3.65 + 2.575
		for x in [-17.0, -15.0, -12.5]:
			var start := Vector3(x, deck_y, sign_node.global_position.z - 0.5)
			_expect(player.test_move(Transform3D(Basis.IDENTITY, start), Vector3(0, 0, 1.0)), "T48 capsule cannot enter the garage sign at x=%s" % x)
		for powered in [false, true]:
			player.reset_for_match(Vector3(-15.0, deck_y + 0.175, 18.0))
			player.movement_buff = Vector2(MatchPowerups.Kind.SPEED, 12) if powered else Vector2.ZERO
			player.set_camera_yaw(PI)
			for tick in 240:
				player.apply_movement_input(Vector2(0, -1), powered, false, 1.0 / 60.0)
				await physics_frame
			_expect(player.position.z < sign_node.global_position.z - 0.2 and player.is_on_floor() and player.position.y > deck_y, "T48 walking into the garage sign stops on the deck (powered=%s, z=%.2f)" % [powered, player.position.z])
		# Powered jump into the sign: it may hop over like any 1.5 m wall, but must
		# never end perched on top of it or stuck inside it.
		player.reset_for_match(Vector3(-15.0, deck_y + 0.175, 20.5))
		player.movement_buff = Vector2(MatchPowerups.Kind.JUMP, 12)
		player.set_camera_yaw(PI)
		var sign_top := sign_node.global_position.y + 0.4
		var max_z_before_top := -999.0
		var last_y := player.position.y
		var descending := false
		for tick in 180:
			player.apply_movement_input(Vector2(0, -1), false, tick == 2, 1.0 / 60.0)
			await physics_frame
			# Rising phase only: a hop over the top may legitimately fall past z later.
			if player.position.y < last_y - 0.001:
				descending = true
			if not descending and player.position.y < sign_top - 0.05:
				max_z_before_top = maxf(max_z_before_top, player.position.z)
			last_y = player.position.y
		player.movement_buff = Vector2.ZERO
		var perched := absf(player.position.y - sign_top) < 0.1
		var stuck_inside := player.test_move(Transform3D(Basis.IDENTITY, player.position), Vector3.ZERO)
		_expect(not perched and not stuck_inside and player.is_on_floor(), "T48 powered jump into the sign never perches or sticks (end y %.2f z %.2f)" % [player.position.y, player.position.z])
		_expect(max_z_before_top < sign_node.global_position.z - 0.2, "T48 while rising below the sign top the capsule never enters the sign (max z %.2f)" % max_z_before_top)
		# Window trim stays visual-only (inset in solid walls, not a new obstacle).
		var trim := sandbox.find_children("Sill", "MeshInstance3D", true, false)
		_expect(not trim.is_empty() and trim[0].get_node_or_null("SolidDetail") == null, "T48 window Sill stays passable trim")
	else:
		var warehouse := sandbox.get_node("Warehouse") as Node3D
		var floor_y := (warehouse.get_node("Rack0") as Node3D).global_position.y - 0.8
		var faces := {"Rack0": Vector3(1.3, 0, 0), "Rack2": Vector3(1.3, 0, 0), "Workbench": Vector3(0, 0, -1.0), "CrateStackA": Vector3(-0.95, 0, 0)}
		for prop_name in faces:
			var prop := warehouse.get_node(prop_name) as Node3D
			_expect(prop.get_node_or_null("SolidDetail") != null, "T48 %s has a collider" % prop_name)
			var start: Vector3 = prop.global_position + faces[prop_name]
			start.y = floor_y + 0.1
			var motion: Vector3 = -faces[prop_name].normalized() * 1.6
			_expect(player.test_move(Transform3D(Basis.IDENTITY, start), motion), "T48 capsule cannot enter warehouse %s" % prop_name)
		for prop_name in ["Rack1", "CrateStackB"]:
			_expect(warehouse.get_node(prop_name).get_node_or_null("SolidDetail") != null, "T48 %s has a collider" % prop_name)
		# Door lanes (x -1.3 / 0 / 1.3) must stay free through the warehouse.
		for x in [-1.3, 0.0, 1.3]:
			var lane := Vector3(warehouse.global_position.x + x, floor_y + 0.1, warehouse.global_position.z + 5.5)
			_expect(not player.test_move(Transform3D(Basis.IDENTITY, lane), Vector3(0, 0, -11.0)), "T48 warehouse door lane x=%s stays free" % x)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
