extends SceneTree

var failures: Array[String] = []
var checks := 0


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
	main.match_manager.set_process(false)
	var ufo: UFO = main.ufo
	ufo.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var at: Vector3 = main.map_anchors.spawn_origin
		for cycle in 5:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			player.reset_for_match(at)
			var rng := RandomNumberGenerator.new()
			rng.seed = 1002
			_expect(ufo.start_disaster(rng), "Start exposed beam on %s" % map_id)
			var first := ufo.create_presentation_snapshot()
			ufo.tick(4.9)
			_expect(player.velocity == Vector3.ZERO and ufo.captured.is_empty(), "Warning never lifts")
			var highest := player.position.y
			for step in 360:
				ufo.tick(1.0 / 60)
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
				highest = maxf(highest, player.position.y)
				await physics_frame
			_expect(highest > first.position.y + 1 and highest <= first.position.y + UFO.LIFT_HEIGHT + 0.01, "Real lift bounded from collision support, not nominal spawn")
			_expect(main.match_manager.get_health(1) > 0 and player.position.y < at.y + 0.1, "Ordinary fall returns to real support nonlethally")
			_expect(not ufo.is_active() and ufo.captured.is_empty(), "Single capture expires and resets")
			player.reset_for_match(at)
			rng.seed = 1002
			ufo.start_disaster(rng)
			_expect(ufo.create_presentation_snapshot() == first, "Seeded fixed footprint replay")
			# A real walk exits the ring well inside the five-second warning.
			player.set_camera_yaw(0)
			for step in 70:
				player.apply_movement_input(Vector2.RIGHT, false, false, 1.0 / 60)
				await physics_frame
			ufo.tick(5.1)
			_expect(ufo.captured.is_empty() and player.position.x - at.x > UFO.BEAM_RADIUS, "Walking counter escapes fixed beam")
			ufo.cleanup()
			main.match_manager.prepare_lobby()
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(at)
		var rng := RandomNumberGenerator.new()
		ufo.start_disaster(rng)
		ufo.tick(5.1)
		_expect(1 in ufo.captured, "Exposed survivor captured")
		var roof := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6, 0.3, 6)
		shape.shape = box
		roof.add_child(shape)
		main.add_child(roof)
		roof.position = at + Vector3.UP * 3
		await physics_frame
		await physics_frame
		ufo.tick(0.1)
		_expect(ufo.captured.is_empty() and player.velocity.y <= 0, "New roof interrupts safely without ceiling penetration")
		ufo.tick(0.1)
		_expect(ufo.captured.is_empty(), "No repeated capture after release")
		ufo.cleanup()
		_expect(not ufo.start_disaster(rng), "Real overhead cover excludes initial target")
		roof.free()
		main.match_manager.prepare_lobby()
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("UFO_OK checks=%d maps=2 resets=5 actual_lift_walk_fall_roof=passed" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
