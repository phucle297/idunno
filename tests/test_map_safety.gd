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
	main.match_manager.set_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	# Scripted world-space paths must not be rotated by real OS mouse events.
	print("MAP_FIXTURE_INITIAL_YAW ", player.get_camera_yaw())
	player.set_process_unhandled_input(false)
	player.set_camera_yaw(0.0)
	await _check_elevation_routes(main, player)
	await _check_elevation_routes(main, player, true)
	player.set_camera_yaw(0.0)
	await _check_roof_breakage(main, player)
	_expect(main.get_node("Sandbox").get_node_or_null("BoundaryNorth") != null, "Map requires a continuous perimeter, not separated north fences")
	if not main.has_method("_eliminate_out_of_bounds"):
		_expect(false, "Escaped players require an authoritative safety check")
		main.free()
		_finish()
		return
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	for direction: Vector2 in directions:
		for mode in 4:
			player.reset_for_match(Vector3(signf(direction.x) * 30.0, 0.1, signf(direction.y) * 30.0))
			for step in 10:
				player.apply_movement_input(Vector2.ZERO, false, false, false, 1.0 / 60.0)
			if mode == 3:
				player.apply_knockdown(Vector3(direction.x * 8.0, 3.0, direction.y * 8.0))
			for step in 120:
				player.apply_movement_input(direction, mode > 0, false, mode == 2 and step == 0, 1.0 / 60.0)
			_expect(maxf(absf(player.position.x), absf(player.position.z)) > 31.0, "Traversal must actually reach the perimeter collider")
			_expect(absf(player.position.x) < 31.5 and absf(player.position.z) < 31.5, "Edges/corners must block walk, sprint, jump and bounded disaster impulses: %s mode=%d position=%s" % [direction, mode, player.position])
	# Exact threshold is safe; just outside each side and below the floor is lethal.
	for position in [Vector3(32, 2, 0), Vector3(-32, 2, 0), Vector3(0, 2, 32), Vector3(0, 2, -32), Vector3(0, -8, 0)]:
		player.position = position
		main._eliminate_out_of_bounds()
		_expect(main.match_manager.is_player_alive(1), "Exact safety threshold must not kill: %s" % position)
	for position in [Vector3(32.01, 2, 0), Vector3(-32.01, 2, 0), Vector3(0, 2, 32.01), Vector3(0, 2, -32.01), Vector3(0, -8.01, 0)]:
		player.position = position
		main._eliminate_out_of_bounds()
		_expect(main.match_manager.state == MatchManager.MatchState.RESULTS and main.match_manager.get_cause_of_death(1) == "Out of bounds", "Solo escape must finish with explicit cause: %s" % position)
		var snapshot: Dictionary = main.match_manager.create_authoritative_snapshot()
		main._eliminate_out_of_bounds()
		_expect(main.match_manager.create_authoritative_snapshot() == snapshot, "Dead player must not be eliminated twice")
		_expect(main.restart_local_match(), "Safety death must allow rematch")
		main.disaster_director.cleanup()
		_expect(player.position.length() < 32 and player.visual.visible and main.match_manager.get_health(1) == 100, "Rematch restores safe spawn, visibility and HP")
	# One death while others survive must use existing spectator and prop-release flow.
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(-3, 0.1, 4))
	main._add_gameplay_demo_player(3, "Third", Vector3(3, 0.1, 4))
	for peer_id: int in main.match_manager.players:
		main.match_manager.set_player_ready(peer_id, true)
	main.match_manager.start_match()
	var crate := get_first_node_in_group("grabbable") as RigidBody3D
	crate.global_position = player.get_grab_origin() + Vector3(0, -0.5, -1)
	_expect(main.get_node("GrabManager").request_grab(1, crate), "Acquire prop before safety elimination")
	player.position = Vector3(33, 1, 0)
	main._eliminate_out_of_bounds()
	_expect(main.get_node("GrabManager").get_held_body(1) == null, "Safety death releases prop")
	_expect(main.spectator_controller.active and not player.visual.visible and main.match_manager.state == MatchManager.MatchState.ACTIVE, "Safety death enters spectator without respawn")
	main._process(0.0)
	_expect(main.gameplay_hud.elimination_label.text.begins_with("ELIMINATED — Out of bounds"), "Actual death feedback names out-of-bounds cause")
	await process_frame
	await _capture("death")
	# Batch all same-step escapes before choosing winners.
	main._player_nodes[2].free()
	main._player_nodes[3].free()
	main._player_nodes.erase(2)
	main._player_nodes.erase(3)
	main.match_manager.unregister_player(2)
	main.match_manager.unregister_player(3)
	main.restart_local_match()
	main.disaster_director.cleanup()
	main.match_manager.prepare_lobby()
	var other: PartyPlayer = load("res://scenes/player.tscn").instantiate()
	main.add_child(other)
	other.set_physics_process(false)
	main.match_manager.register_player(2, "Second")
	main._player_nodes[2] = other
	main.match_manager.set_player_ready(1, true)
	main.match_manager.set_player_ready(2, true)
	main.match_manager.start_match()
	player.position = Vector3(33, 1, 0)
	other.position = Vector3(0, -9, 0)
	main._eliminate_out_of_bounds()
	_expect(main.match_manager.get_alive_count() == 0 and main.match_manager.winner_ids == [1, 2], "Simultaneous escapes share last-survivor result, not iteration-order winner")
	main._player_nodes.erase(2)
	main.match_manager.unregister_player(2)
	other.free()
	_expect(main.restart_local_match(), "Simultaneous elimination permits a solo reset")
	main.disaster_director.cleanup()
	player.set_physics_process(false)
	player.position = Vector3(25, 0.1, 25)
	main._process(0.0)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.position = Vector3(23, 7, 20)
	camera.look_at(Vector3(30, 1, 30))
	camera.make_current()
	await process_frame
	await _capture("corner")
	main.gameplay_hud.hide()
	camera.position = Vector3(0, 40, -47)
	camera.look_at(Vector3(0, 0, 0))
	await _capture("routes")
	camera.position = Vector3(0, 40, 47)
	camera.look_at(Vector3(0, 0, 0))
	await _capture("town")
	main.free()
	_finish()


func _check_elevation_routes(main: Node3D, player: PartyPlayer, carrying: bool = false) -> void:
	var routes := {
		"ShopRoofRamp": Vector3(-16, 4.855, -16),
		"HallRoofRamp": Vector3(16, 4.855, -17),
		"GarageRamp": Vector3(-15, 2.575, 13),
		"ParkRamp": Vector3(15, 2.2, 13),
	}
	for route_name in routes:
		var ramp := main.get_node("Sandbox/" + route_name) as StaticBody3D
		var collision := ramp.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
		var shape := (collision.shape as BoxShape3D).size
		var low := ramp.to_global(Vector3(0, shape.y / 2, -shape.z / 2))
		var high := ramp.to_global(Vector3(0, shape.y / 2, shape.z / 2))
		if low.y > high.y:
			var swap := low
			low = high
			high = swap
		var direction := Vector2(high.x - low.x, high.z - low.z).normalized()
		player.reset_for_match(Vector3(low.x - direction.x, 0.1, low.z - direction.y))
		for tick in 10:
			player.apply_movement_input(Vector2.ZERO, false, false, false, 1.0 / 60.0)
			await physics_frame
		var crate := get_first_node_in_group("grabbable") as RigidBody3D
		var crate_spawn := crate.global_transform
		if carrying:
			player.set_camera_yaw(atan2(-direction.x, -direction.y))
			crate.freeze = true
			crate.global_position = player.get_hold_position()
			crate.linear_velocity = Vector3.ZERO
			crate.angular_velocity = Vector3.ZERO
			crate.freeze = false
			_expect(main.get_node("GrabManager").request_grab(1, crate) and player.carrying_medium, "Acquire actual medium crate before ramp ascent")
		var ascent_ticks := 0
		for tick in (360 if carrying else 240):
			player.apply_movement_input(Vector2.UP if carrying else direction, false, false, false, 1.0 / 60.0)
			await physics_frame
			ascent_ticks += 1
			if Vector2(player.position.x - high.x, player.position.z - high.z).length() < 0.15:
				break
		var goal: Vector3 = routes[route_name]
		for tick in 180:
			var remaining := Vector2(goal.x - player.position.x, goal.z - player.position.z)
			if carrying and remaining.length() > 0.1:
				player.set_camera_yaw(atan2(-remaining.x, -remaining.y))
			player.apply_movement_input((Vector2.UP if carrying else remaining.normalized()) if remaining.length() > 0.1 else Vector2.ZERO, false, false, false, 1.0 / 60.0)
			await physics_frame
		print("ELEVATION_ROUTE route=%s carry=%s ascent_ticks=%s feet=%s goal=%s" % [route_name, carrying, ascent_ticks, player.position, goal])
		if carrying:
			_expect(player.carrying_medium and main.get_node("GrabManager").get_held_body(1) == crate, "Ramp ascent must keep actual crate ownership, not silently drop penalty")
			await _capture(route_name + "Carrying")
			main.get_node("GrabManager").release_grab(1)
			player.set_camera_yaw(0.0)
			# The existing straight-line descent checks an unobstructed route.
			# Remove the fixture's dropped obstacle, not a gameplay collision rule.
			crate.freeze = true
			crate.global_transform = crate_spawn
			crate.linear_velocity = Vector3.ZERO
			crate.angular_velocity = Vector3.ZERO
			crate.freeze = false
		_expect(Vector2(goal.x - player.position.x, goal.z - player.position.z).length() < 0.25 and absf(player.position.y - goal.y) < 0.05 and player.is_on_floor(), "Walk without jumps must reach the actual refuge via %s: %s" % [route_name, player.position])
		await _capture(route_name + ("CarryArrival" if carrying else ""))
		_expect(main.get_node("Flood").start_warning(), "Start actual Flood at the reached refuge")
		var flood := main.get_node("Flood") as Flood
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration)
		flood.tick(3.0)
		_expect(is_equal_approx(flood.water_level, 3.5) and main.get_node("MatchManager").get_health(1) == 100, "Standing at %s must escape peak Flood without drowning" % route_name)
		if route_name == "ParkRamp":
			await _capture("ParkFlood")
		flood.cleanup()
		for tick in 300:
			var remaining := Vector2(low.x - direction.x - player.position.x, low.z - direction.y - player.position.z)
			player.apply_movement_input(remaining.normalized() if remaining.length() > 0.1 else Vector2.ZERO, false, false, false, 1.0 / 60.0)
			await physics_frame
			if remaining.length() < 0.1 and player.is_on_floor() and player.position.y < 0.1:
				break
		_expect(player.is_on_floor() and player.position.y < 0.1 and Vector2(player.position.x - low.x + direction.x, player.position.z - low.z + direction.y).length() < 0.25, "Walk back down %s without a jump or drop" % route_name)
	player.reset_for_match(Vector3.ZERO)


func _check_roof_breakage(main: Node3D, player: PartyPlayer) -> void:
	var flood := main.get_node("Flood") as Flood
	flood.set_process(false)
	var camera := Camera3D.new()
	main.add_child(camera)
	for building_name in ["Shop", "Hall"]:
		var x := -16.0 if building_name == "Shop" else 16.0
		var panel := main.get_node("Sandbox/RoofPanel" + building_name) as BreakableStructure
		player.reset_for_match(Vector3(x + 3, 4.9, -13))
		await _walk_roof(player, Vector2(x, -13), 90)
		_expect(player.is_on_floor() and absf(player.position.y - 4.855) < 0.03 and absf(player.position.x - x) < 0.15, "Intact %s panel must be flush and walkable without jumping" % building_name)
		camera.position = Vector3(x + 8, 12, -5)
		camera.look_at(Vector3(x, 3, -13))
		camera.make_current()
		main._process(0.0)
		await _capture(building_name + "RoofIntact")
		_expect(flood.start_warning(), "Start Flood while player stands on intact panel")
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration)
		_expect(main.match_manager.get_health(1) == 100, "Intact roof panel protects player from peak Flood")
		panel.apply_damage(false)
		await _walk_roof(player, Vector2(x, -13), 10)
		_expect(player.is_on_floor() and player.position.y > 4.8, "Damaged panel must retain support until broken")
		panel.apply_damage(false)
		main.get_node("Earthquake").cleanup()
		await _walk_roof(player, Vector2(x, -13), 90)
		_expect(player.is_on_floor() and player.position.y < 0.1, "Broken %s panel must drop the actual capsule indoors, even after Earthquake cleanup" % building_name)
		flood.tick(2.0)
		_expect(main.match_manager.get_health(1) == 100, "Drop into Flood retains the two-second breathing grace")
		flood.tick(0.5)
		_expect(is_equal_approx(main.match_manager.get_health(1), 94), "Dropped player takes independently calculated 6HP after 0.5s beyond grace")
		print("ROOF_BREAKAGE building=%s dropped_feet=%s hp=%s" % [building_name, player.position, main.match_manager.get_health(1)])
		main._process(0.0)
		await _capture(building_name + "RoofBroken")
		flood.cleanup()
		main.match_manager.apply_damage(1, 1000, "Fixture")
		_expect(main.restart_local_match(), "Roof death must allow rematch")
		main.disaster_director.cleanup()
		panel = main.get_node("Sandbox/RoofPanel" + building_name) as BreakableStructure
		player.reset_for_match(Vector3(x, 4.9, -13))
		await _walk_roof(player, Vector2(x, -13), 30)
		_expect(panel.structure_state == BreakableStructure.StructureState.INTACT and player.is_on_floor() and player.position.y > 4.8, "Rematch restores actual support, not only panel appearance")
		await _walk_roof(player, Vector2(x + 3, -13), 90)
		panel.apply_damage(false)
		panel.apply_damage(false)
		await _walk_roof(player, Vector2(x + 3, -13), 30)
		_expect(absf(player.position.x - x - 3) < 0.15 and player.is_on_floor() and absf(player.position.y - 4.855) < 0.03, "Walking sideways before collapse reaches preserved roof escape without jumping")
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood.tick(flood.rise_duration)
		flood.tick(3.0)
		_expect(main.match_manager.get_health(1) == 100, "Preserved same-roof escape remains safe from peak Flood")
		main._process(0.0)
		await _capture(building_name + "RoofEscape")
		flood.cleanup()
		main.match_manager.apply_damage(1, 1000, "Fixture")
		_expect(main.restart_local_match(), "Escape fixture rematches")
		main.disaster_director.cleanup()
	for round_index in 5:
		for building_name in ["Shop", "Hall"]:
			var panel := main.get_node("Sandbox/RoofPanel" + building_name) as BreakableStructure
			panel.apply_damage(false)
			panel.apply_damage(false)
		main.match_manager.apply_damage(1, 1000, "Fixture")
		_expect(main.restart_local_match(), "Repeated collapsed-roof round must rematch")
		main.disaster_director.cleanup()
		for building_name in ["Shop", "Hall"]:
			var x := -16.0 if building_name == "Shop" else 16.0
			player.reset_for_match(Vector3(x, 4.9, -13))
			await _walk_roof(player, Vector2(x, -13), 30)
			_expect(player.is_on_floor() and absf(player.position.y - 4.855) < 0.03, "Five rematches restore %s panel's standing collision" % building_name)
	camera.free()
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
	player.reset_for_match(Vector3.ZERO)


func _walk_roof(player: PartyPlayer, target: Vector2, ticks: int) -> void:
	for tick in ticks:
		var remaining := target - Vector2(player.position.x, player.position.z)
		player.apply_movement_input(remaining.normalized() if remaining.length() > 0.1 else Vector2.ZERO, false, false, false, 1.0 / 60.0)
		await physics_frame


func _capture(state: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await process_frame
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("map-safety-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Save review capture")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP_SAFETY_OK checks=%d" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
