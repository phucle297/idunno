extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_expect(await main.start_local_match(), "Map/rematch fixture explicitly starts solo")
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.match_manager.set_process(false)
	var flood := main.get_node("Flood") as Flood
	flood.set_process(false)
	flood.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.set_camera_yaw(0.0)
	# Server-selected map identity remains metadata-only until the explicit
	# gameplay preparation boundary builds the selected map and its anchors.
	_expect(not main.set_map_id("not_a_map"), "Unknown map id must be rejected")
	_expect(main.get_map_id() == "toy_town", "Toy Town remains the default map")
	_expect(main.set_map_id("toy_harbor") and main.get_map_id() == "toy_harbor", "Map selection switches to Toy Harbor")
	await main.prepare_gameplay_map()
	_expect(main.get_node("Sandbox").get_node_or_null("Warehouse") != null, "Toy Harbor builds the warehouse landmark")
	_expect(main.set_map_id("toy_town"), "Map selection switches back to Toy Town")
	await main.prepare_gameplay_map()
	_expect(main.get_node("Sandbox").get_node_or_null("Shop") != null, "Toy Town rebuilds its own landmarks")
	for map_name in ["toy_town", "toy_harbor"]:
		_expect(main.set_map_id(map_name), "Select %s" % map_name)
		await main.prepare_gameplay_map()
		await _check_map(main, player, flood, map_name)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	_finish()


func _check_map(main: Node3D, player: PartyPlayer, flood: Flood, map_name: String) -> void:
	var anchors: Dictionary = main.get_node("Sandbox").get_meta("map_anchors")
	_expect(anchors.map_id == map_name, "Sandbox anchors belong to %s" % map_name)
	var expected_extent := 72.0 if map_name == "toy_town" else 32.0
	_expect(main.get_map_half_extent() == expected_extent, "%s uses its own playable extent" % map_name)
	_expect(flood.map_half_extent == expected_extent, "%s flood covers its whole map" % map_name)
	for key in ["spawn_origin", "cover_volumes", "tornado_paths", "strike_half_extent", "fire_zones", "fire_zone_neighbors", "elevation_routes", "refuges", "spawn_groups"]:
		_expect(anchors.has(key), "%s anchors include %s" % [map_name, key])
	_expect(anchors.tornado_paths.size() >= 2 and anchors.cover_volumes.size() >= 1, "%s anchors provide wind paths and shelter" % map_name)
	_expect(anchors.fire_zones.size() >= 6 and anchors.fire_zones.size() == anchors.fire_zone_neighbors.size(), "%s anchors provide a connected fire zone layout" % map_name)
	_expect(anchors.strike_half_extent >= 16.0, "%s strike area reaches the playable area" % map_name)
	# Hazard systems must consume the map anchors, not hardcoded positions.
	var tornado := main.get_node("Tornado") as Tornado
	tornado.set_process(false)
	var meteor := main.get_node("MeteorShower") as MeteorShower
	var lightning := main.get_node("Lightning") as Lightning
	var fire := main.get_node("Fire") as Fire
	_expect(is_equal_approx(meteor.strike_half_extent, expected_extent) and is_equal_approx(lightning.strike_half_extent, anchors.strike_half_extent), "%s meteor uses full playable footprint; lightning uses authored strike anchors" % map_name)
	_expect(tornado.path_presets.size() == anchors.tornado_paths.size(), "%s tornado paths come from map anchors" % map_name)
	_expect(fire.zone_positions.size() == anchors.fire_zones.size(), "%s fire zones come from map anchors" % map_name)
	var reached := {0: true}
	var pending := [0]
	while not pending.is_empty():
		var zone: int = pending.pop_back()
		for neighbor: int in anchors.fire_zone_neighbors[zone]:
			if not reached.has(neighbor):
				reached[neighbor] = true
				pending.append(neighbor)
	_expect(reached.size() == anchors.fire_zones.size(), "%s fire can spread to every district" % map_name)
	await physics_frame
	if map_name == "toy_town":
		_expect(get_nodes_in_group("shelter").size() >= 12, "Expanded Town has populated buildings, not just a bigger empty floor")
		for sample in [[Vector3(-34, 0, 0), 1.25], [Vector3(34, 0, 0), 1.75], [Vector3(10, 0, -42), 2.0], [Vector3(4, 0, 45), 0.65], [Vector3(-42, 0, 17), 5.405]]:
			_expect(absf(main.get_map_surface_height(sample[0]) - sample[1]) < 0.02, "Terrace/roof has real collision at %s, height %s" % [sample[0], sample[1]])
		var elevated_targets := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 297
		for trial in 8:
			_expect(meteor.start_disaster(rng), "Generated meteor targets on expanded Town")
			var targets: Array = meteor.strike_points.duplicate()
			_expect(lightning.start_disaster(rng), "Generated lightning target on expanded Town")
			targets.append(lightning.target_position)
			for target: Vector3 in targets:
				# Independent world ray, not the height callback under test.
				var query := PhysicsRayQueryParameters3D.create(Vector3(target.x, 35, target.z), Vector3(target.x, -7, target.z), 1)
				var hit := main.get_world_3d().direct_space_state.intersect_ray(query)
				_expect(not hit.is_empty() and absf(target.y - hit.position.y - 0.06) < 0.02, "Hazard warning sits on actual terrain/roof: %s" % target)
				if target.y > 0.5:
					elevated_targets += 1
			meteor.cleanup()
			lightning.cleanup()
		_expect(elevated_targets >= 4, "Seeded hazard scenarios actually exercise raised terrain, not only flat ground")
	# No spawn inside geometry; every grid spawn stays in the playset.
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for index in 20:
		var spawn: Vector3 = main._network_spawn_position(index)
		_expect(absf(spawn.x) < expected_extent - 1 and absf(spawn.z) < expected_extent - 1 and spawn.y > -0.5, "%s spawn %d stays inside the boundary: %s" % [map_name, index, spawn])
		var probe := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		probe.shape = box
		probe.transform = Transform3D(Basis(), spawn + Vector3(0.0, 0.9, 0.0))
		# Moving actors (players, demo crowd) legitimately overlap grid spawns;
		# the gate is about static map geometry and prop placement.
		var blocked := false
		for hit: Dictionary in space.intersect_shape(probe, 8):
			var collider: Object = hit.get("collider")
			if not (collider is CharacterBody3D):
				blocked = true
		_expect(not blocked, "%s spawn %d must not sit inside geometry: %s" % [map_name, index, spawn])
	# Four walk-only elevation routes reach their refuges without jumps.
	for route: Dictionary in anchors.elevation_routes:
		_expect(main.get_node("Sandbox").get_node_or_null(route.name) != null, "%s builds elevation route %s" % [map_name, route.name])
		var low: Vector3 = route.low
		var high: Vector3 = route.high
		var direction := Vector2(high.x - low.x, high.z - low.z).normalized()
		player.reset_for_match(Vector3(low.x - direction.x, low.y + 0.1, low.z - direction.y))
		for settle in 5:
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
			await physics_frame
		await _walk_to(main, player, Vector2(high.x, high.z), 300)
		_expect(player.is_on_floor() and Vector2(player.position.x - high.x, player.position.z - high.z).length() < 0.4 and absf(player.position.y - high.y) < 0.35, "%s route %s must be walkable without jumps: %s" % [map_name, route.name, player.position])
		player.reset_for_match(Vector3.ZERO)
	# Every refuge keeps at least two walked exits.
	for refuge: Dictionary in anchors.refuges:
		var exits: Array = refuge.exits
		_expect(exits.size() >= 2, "%s refuge %s keeps two exits" % [map_name, refuge.name])
		for exit: Vector3 in exits:
			var center: Vector3 = refuge.center
			player.reset_for_match(center + Vector3(0.0, 0.1, 0.0))
			for settle in 5:
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
				await physics_frame
			var travel_ticks := maxi(240, ceili(center.distance_to(exit) / PlayerTuning.WALK_SPEED * 60.0) + 90)
			await _walk_to(main, player, Vector2(exit.x, exit.z), travel_ticks)
			_expect(player.is_on_floor() and Vector2(player.position.x - exit.x, player.position.z - exit.z).length() < 0.4 and absf(player.position.y - exit.y) < 0.35, "%s refuge %s exit %s must be walkable: %s" % [map_name, refuge.name, exit, player.position])
			player.reset_for_match(Vector3.ZERO)
	# Flood escape from every spawn group: walk to the group's route and stand
	# through the real warning/rise and a three-second peak window without drowning.
	for group: Dictionary in anchors.spawn_groups:
		player.reset_for_match(group.spawn)
		for settle in 5:
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
			await physics_frame
		_expect(flood.start_warning(), "%s spawn group %s flood warning precedes escape" % [map_name, group.name])
		var walked := 0
		for waypoint: Vector3 in group.waypoints:
			walked += await _walk_to(main, player, Vector2(waypoint.x, waypoint.z), 480, flood)
			_expect(Vector2(player.position.x - waypoint.x, player.position.z - waypoint.z).length() < 0.6, "%s spawn group %s must walk waypoint %s: %s" % [map_name, group.name, waypoint, player.position])
		var route := _route_by_name(anchors, group.route)
		var high: Vector3 = route.high
		walked += await _walk_to(main, player, Vector2(high.x, high.z), 480, flood)
		_expect(player.is_on_floor() and absf(player.position.y - high.y) < 0.35, "%s spawn group %s must reach refuge %s: %s" % [map_name, group.name, group.route, player.position])
		_expect(walked / 60.0 < flood.warning_duration + flood.rise_duration and main.match_manager.is_player_alive(1), "%s spawn group %s reaches refuge alive before peak: %d ticks" % [map_name, group.name, walked])
		print("MAP_REFUGE_APPROACH map=%s group=%s walk_seconds=%.2f" % [map_name, group.name, walked / 60.0])
		# The escape contract is "the flood does not drown the player who made
		# it to high ground": health must hold through the peak while alive.
		var health_before: float = main.match_manager.get_health(1)
		while flood.phase != Flood.Phase.HOLDING and flood.is_active():
			flood.tick(1.0 / 60.0)
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
			await physics_frame
		for tick in 180:
			flood.tick(1.0 / 60.0)
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
			await physics_frame
		_expect(
			is_equal_approx(flood.water_level, 3.5)
				and main.match_manager.is_player_alive(1)
				and main.match_manager.get_health(1) == health_before,
			"%s spawn group %s escapes peak Flood from %s" % [map_name, group.name, group.route]
		)
		flood.cleanup()
		player.reset_for_match(Vector3.ZERO)
	# No universally safe location: every refuge sits inside the strike areas,
	# within tornado reach, and covered spots cannot dodge the strike areas.
	for refuge: Dictionary in anchors.refuges:
		var center: Vector3 = refuge.center
		_expect(absf(center.x) <= anchors.strike_half_extent and absf(center.z) <= anchors.strike_half_extent, "%s refuge %s is inside meteor/lightning strike areas" % [map_name, refuge.name])
		var exposed := false
		for path: Array in anchors.tornado_paths:
			var closest := Geometry2D.get_closest_point_to_segment(Vector2(center.x, center.z), Vector2(path[0].x, path[0].z), Vector2(path[1].x, path[1].z))
			if Vector2(center.x, center.z).distance_to(closest) >= tornado.influence_radius:
				continue
			player.reset_for_match(center)
			tornado.start_warning(path[0], path[1])
			tornado.tick(tornado.warning_duration)
			for tick in ceili(tornado.active_duration * 60.0):
				player.velocity = Vector3.ZERO
				tornado.tick(1.0 / 60.0)
				if player.velocity.length() > 0.0:
					exposed = true
			tornado.cleanup()
		_expect(exposed, "%s refuge %s receives runtime tornado force inside radius %.1f" % [map_name, refuge.name, tornado.influence_radius])
	for volume: AABB in anchors.cover_volumes:
		var outside: bool = volume.position.x > anchors.strike_half_extent or volume.position.x + volume.size.x < -anchors.strike_half_extent or volume.position.z > anchors.strike_half_extent or volume.position.z + volume.size.z < -anchors.strike_half_extent
		_expect(not outside, "%s sheltered cover must not sit outside the strike areas" % map_name)
	var fire_bounds := _bounds_xz(anchors.fire_zones)
	_expect(fire_bounds.x >= 12.0 and fire_bounds.y >= 8.0, "%s fire zones span the play area: %s" % [map_name, fire_bounds])
	var breakables: Array = main.get_tree().get_nodes_in_group("breakable_structure")
	_expect(breakables.size() >= 4, "%s provides at least four breakable sections" % map_name)
	# Gameplay and overview views per map for visual review.
	var player_head: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	player.reset_for_match(main.map_anchors.spawn_origin)
	player_head.make_current()
	main._process(0.0)
	await _capture(map_name + "Gameplay")
	var overview := Camera3D.new()
	main.add_child(overview)
	overview.position = Vector3(34.0, 30.0, 34.0)
	overview.look_at(Vector3(0.0, 0.0, 0.0))
	overview.make_current()
	main.gameplay_hud.hide()
	await _capture(map_name + "Overview")
	main.gameplay_hud.show()
	overview.free()
	# Structures and props reset through five rematches.
	var expected_crates: int = main.get_tree().get_nodes_in_group("grabbable").size()
	for round_index in 5:
		for structure in main.get_tree().get_nodes_in_group("breakable_structure"):
			var breakable := structure as BreakableStructure
			breakable.apply_damage(false)
			breakable.apply_damage(false)
		main.match_manager.apply_damage(1, 1000, "Fixture")
		_expect(main.restart_local_match(), "%s rematch %d restarts" % [map_name, round_index + 1])
		main.disaster_director.cleanup()
		for structure in main.get_tree().get_nodes_in_group("breakable_structure"):
			_expect((structure as BreakableStructure).structure_state == BreakableStructure.StructureState.INTACT, "%s rematch %d restores %s" % [map_name, round_index + 1, structure.name])
		_expect(main.get_tree().get_nodes_in_group("grabbable").size() == expected_crates, "%s rematch %d restores props" % [map_name, round_index + 1])
		_expect(main.get_node("Sandbox").get_meta("map_anchors").map_id == map_name, "%s rematch %d keeps the selected map" % [map_name, round_index + 1])


func _route_by_name(anchors: Dictionary, route_name: String) -> Dictionary:
	for route: Dictionary in anchors.elevation_routes:
		if route.name == route_name:
			return route
	return {}


func _bounds_xz(points: Array) -> Vector2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point: Vector3 in points:
		minimum = Vector2(minf(minimum.x, point.x), minf(minimum.y, point.z))
		maximum = Vector2(maxf(maximum.x, point.x), maxf(maximum.y, point.z))
	return maximum - minimum


func _walk_to(main: Node3D, player: PartyPlayer, target: Vector2, max_ticks: int, flood: Flood = null) -> int:
	for tick in max_ticks:
		if flood != null:
			flood.tick(1.0 / 60.0)
		var remaining := target - Vector2(player.position.x, player.position.z)
		player.apply_movement_input(remaining.normalized() if remaining.length() > 0.15 else Vector2.ZERO, false, false, 1.0 / 60.0)
		await physics_frame
		if remaining.length() <= 0.15:
			return tick + 1
	return max_ticks


func _capture(state: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await process_frame
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("map-variety-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			_expect(root.get_texture().get_image().save_png(path) == OK, "Save review capture")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP_VARIETY_OK checks=%d" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
