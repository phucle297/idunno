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
	main.match_manager.set_process(false)
	var volcano: Volcano = main.volcano
	volcano.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		await physics_frame
		var center := volcano.district_center
		for cycle in 5:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			player.reset_for_match(center + Vector3.UP * 0.03)
			var rng := RandomNumberGenerator.new()
			rng.seed = 1003
			_expect(volcano.start_disaster(rng), "Authored district warning starts")
			var first := volcano.create_presentation_snapshot()
			volcano.tick(11.9)
			_expect(not volcano.mutated and main.match_manager.get_health(1) == 100, "No collision mutation or damage before warning expires")
			# Measure two opposite real walking exits before eruption.
			for direction in [-1, 1]:
				player.reset_for_match(center + Vector3.UP * 0.03)
				player.set_camera_yaw(0)
				for step in 210:
					player.apply_movement_input(Vector2(direction, 0), false, false, 1.0 / 60)
					await physics_frame
				_expect(absf(player.position.x - center.x) > volcano.district_size.x / 2 + 0.3, "Walk evacuation fits 12s warning on %s" % map_id)
			volcano.tick(0.2)
			await physics_frame
			await physics_frame
			_expect(volcano.mutated and volcano.centers.size() == 9, "Nine collision-backed shelves replace district topology")
			for index in [0, 4, 8]:
				_expect(absf(main.get_map_support_height(volcano.centers[index]) - volcano.centers[index].y) < 0.02, "Collision matches visible shelf")
			if cycle == 0:
				for index in [0, 2, 6, 8]:
					var shoulder := volcano.centers[index] + Vector3(volcano.district_size.x / 6 * 0.7, 0, volcano.district_size.y / 6 * 0.4)
					shoulder.y = main.get_map_support_height(shoulder)
					_expect(volcano.centers[index].y - shoulder.y > 0.1, "Banks have actual uneven collision, not flat podiums")
					player.reset_for_match(shoulder + Vector3.UP * 0.03)
					for step in 8:
						player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
						await physics_frame
					_expect(player.is_on_floor() and volcano.surface_at(player.position) == index, "Real sloping support is grounded and recognized as hot")
					var slope_hp: float = main.match_manager.get_health(1)
					volcano.tick(0.2)
					_expect(is_equal_approx(main.match_manager.get_health(1), slope_hp - 1.2), "Slope contact retains authority damage away from shelf peak")
			# Center crossing remains wide; banks actually change route geometry.
			_expect(volcano.centers[0].y - volcano.centers[4].y > 0.8, "Crater has real raised banks, not a texture swap")
			player.reset_for_match(volcano.centers[4] + Vector3.UP * 0.02)
			for step in 5:
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
				await physics_frame
			var hp: float = main.match_manager.get_health(1)
			volcano.environment = func() -> Dictionary: return {}
			volcano.tick(1)
			_expect(is_equal_approx(main.match_manager.get_health(1), hp - 6), "Immediate contact damage, not a 60s delay")
			player.position.y += 1
			volcano.tick(1)
			_expect(is_equal_approx(main.match_manager.get_health(1), hp - 6), "Airborne/other support never inherits heat damage")
			volcano.cleanup()
			rng.seed = 1003
			volcano.start_disaster(rng)
			_expect(volcano.create_presentation_snapshot() == first, "Seeded district/variant reset")
			volcano.cleanup()
			main.match_manager.prepare_lobby()
		# Exact cooling boundaries and caller-delta partitions at matched seed.
		for mode in ["dry", "rain", "snow", "partial_flood"]:
			var reference := PackedFloat32Array()
			for partitions in [1, 60]:
				main.match_manager.set_player_ready(1, true)
				main.match_manager.start_match()
				player.reset_for_match(center + Vector3(0, 5, 0))
				var rng := RandomNumberGenerator.new()
				rng.seed = 1003
				volcano.start_disaster(rng)
				volcano.tick(12)
				await physics_frame
				await physics_frame
				volcano.environment = func() -> Dictionary: return {"rain": mode == "rain", "snow": mode == "snow", "water": center.y + 0.3 if mode == "partial_flood" else -INF}
				for part in partitions:
					volcano.tick(6.0 / partitions)
				var expected := 54.0 if mode == "dry" else (42.0 if mode == "rain" else (36.0 if mode == "snow" else 0.0))
				_expect(absf(volcano.heat[4] - expected) < 0.001, "%s cooling boundary" % mode)
				if mode == "partial_flood":
					_expect(volcano.heat[0] > 53.99 and volcano.is_active(), "Raised dry banks stay hot and reserve director slot")
				if partitions == 1:
					reference = volcano.heat.duplicate()
				else:
					for index in 9:
						_expect(absf(reference[index] - volcano.heat[index]) < 0.001, "Cooling invariant to delta partitions")
				volcano.environment = func() -> Dictionary: return {}
				volcano.tick(60)
				_expect(not volcano.is_active() and volcano.mutated, "Cooled geometry persists but no hidden lethal director threat")
				_expect(not volcano.start_disaster(rng), "No reheating the same district during this event/round")
				main._reset_sandbox()
				_expect(not volcano.mutated and volcano.centers.is_empty(), "Static map reuse restores mutable terrain")
				main.match_manager.prepare_lobby()
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("VOLCANO_OK checks=%d maps=2 resets=5 evacuation_collision_contact_cooling=passed" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
