extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.match_manager.set_process(false)
	main.disaster_director.set_process(false)
	main.disaster_director.cleanup()
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Survivor", Vector3(4, 1, -4))
	main._add_gameplay_demo_player(3, "Survivor", Vector3(-4, 1, -4))
	for player in main._player_nodes.values():
		player.set_physics_process(false)
	var victim: PartyPlayer = main._player_nodes[1]
	for timing in ["before", "during", "after"]:
		main.match_manager.prepare_lobby()
		for id in main.match_manager.players:
			main.match_manager.set_player_ready(id, true)
		main.match_manager.start_match()
		main.disaster_director.cleanup()
		if timing != "before":
			main.earthquake.start_warning()
			main.earthquake.tick(main.earthquake.warning_duration + 0.01)
		if timing == "after":
			main.earthquake.tick(main.earthquake.active_duration)
		victim.velocity = Vector3(3, 2, -1)
		victim.apply_knockdown(Vector3(1, 0, 2))
		main._store_movement_input(1, Vector2.RIGHT, true, false, true, 0.7, 3)
		expect(main.match_manager.apply_damage(1, 100, "Death " + timing + " earthquake"), "Authority must eliminate victim")
		await physics_frame
		var position := victim.global_position
		var yaw := victim.get_camera_yaw()
		expect(victim.velocity == Vector3.ZERO and not victim.is_knocked_down() and victim.ragdoll_body_count() == 0, "Death must clear velocity and knockdown bodies")
		expect(not victim.visual.visible and victim.collider.disabled and not victim.can_grab_objects() and not victim.accepts_local_input(), "Dead body must be hidden, noncolliding and reject interaction/aim input")
		for step in 30:
			await physics_frame
			victim.apply_movement_input(Vector2.RIGHT, true, true, true, 1.0 / 60.0)
			victim.predict_movement_input(10 + step, Vector2.LEFT, true, false, true, 1.0 / 60.0)
			victim.apply_hazard_velocity(Vector3(4, 2, 1), 8)
			victim.apply_knockdown(Vector3.RIGHT)
			main._store_movement_input(1, Vector2.RIGHT, true, true, true, -1.0, 10 + step)
			main._network_mode = true
			main._physics_process(1.0 / 60.0)
			main._network_mode = false
		expect(victim.global_position == position and victim.velocity == Vector3.ZERO, "Dead node must not move under retained/new inputs or hazards")
		expect(victim.get_camera_yaw() == yaw, "Retained movement yaw must not rotate the spectator camera")
		victim.reconcile_movement(position + Vector3.ONE, Vector3(2, 3, 4), 1.0, true, 99, Vector3(0.12, 0.12, 1), true)
		expect(victim.global_position == position and victim.velocity == Vector3.ZERO and victim._prediction_inputs.is_empty(), "Late alive snapshot cannot revive dead movement/knockdown")
		expect(main.spectator_controller.active and main.spectator_controller.current_target_id == 2, "Death must follow live survivor while match continues")
		main.spectator_controller.cycle(1)
		main.spectator_controller._process(0.0)
		expect(victim.camera_pivot.global_position.is_equal_approx(main._player_nodes[3].global_position + Vector3(0, 1.2, 0)), "Spectator cycling must still follow survivor")
		main.earthquake.cleanup()
		main.match_manager.prepare_lobby()
		victim.reset_for_match(Vector3(0, 1, 7))
		await physics_frame
		victim.apply_movement_input(Vector2.RIGHT, false, false, false, 1.0 / 60.0)
		expect(victim.global_position.x > 0 and victim.visual.visible and not victim.collider.disabled and victim.can_grab_objects(), "Rematch must restore movement/collision/interaction")
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ELIMINATED_MOVEMENT_OK checks=%d timings=before,during,after" % checks)
	quit(0 if failures.is_empty() else 1)
