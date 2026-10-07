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
	camera.position = Vector3(0, 40, 47)
	camera.look_at(Vector3(0, 0, 0))
	await _capture("town")
	main.free()
	_finish()


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
