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
	var slide: Rockslide = main.rockslide
	slide.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		await physics_frame
		var lane: Dictionary = main.map_anchors.rockslide_lane
		var low: Vector3 = lane.low
		var high: Vector3 = lane.high
		_expect(high.y > low.y + 3.9 and high.z < low.z, "Real downhill source on %s" % map_id)
		var middle := high.lerp(low, 0.5)
		_expect(absf(main.get_map_surface_height(middle) - middle.y) < 0.08, "Slope collision matches anchors")
		for target: Vector3 in lane.exits:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			player.reset_for_match(low + Vector3.UP * 0.04)
			player.set_camera_yaw(0)
			for step in 75:
				player.apply_movement_input(Vector2(signf(target.x - low.x), 0), false, false, 1.0 / 60)
				await physics_frame
			_expect(absf(player.position.x - low.x) > 3.0, "Real walking lateral escape fits warning on %s" % map_id)
			main.match_manager.prepare_lobby()
		for scenario in ["hit", "side", "cover"]:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			var at := middle + Vector3.UP * 0.03
			if scenario == "side":
				at.x += 3.5
				at.y = main.get_map_support_height(at)
			elif scenario == "cover":
				at = low + Vector3(0, 0.03, 4.5)
			player.reset_for_match(at)
			var rng := RandomNumberGenerator.new()
			rng.seed = 902
			_expect(slide.start_disaster(rng), "Rockslide starts")
			var replay := slide.create_presentation_snapshot()
			_expect(replay.positions.is_empty() and slide.phase == Rockslide.Phase.WARNING, "Five second warning before rocks")
			slide.tick(5)
			for step in 420:
				slide.tick(1.0 / 60)
				await physics_frame
			_expect(slide._rocks.size() == 3, "Rock budget at most three")
			if scenario == "hit":
				_expect(main.match_manager.get_health(1) < 100 and player.is_knocked_down(), "Actual capsule impact damages and ragdolls")
			else:
				_expect(main.match_manager.get_health(1) == 100, "%s prevents actual impact on %s" % [scenario, map_id])
			if scenario == "cover":
				for rock in slide._rocks:
					_expect(rock.position.z < low.z + 3 and rock.get_meta("stopped", false), "Solid cover intercepts each actual rock")
			for rock in slide._rocks:
				_expect(rock.velocity.length() <= Rockslide.MAX_SPEED + 0.01 and rock.position.y >= low.y, "Bounded speed and collision-backed support")
			slide.cleanup()
			_expect(slide.create_presentation_snapshot().positions.is_empty(), "Cleanup removes all bodies")
			main.match_manager.prepare_lobby()
		for cycle in 5:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			var rng := RandomNumberGenerator.new()
			rng.seed = 902
			slide.start_disaster(rng)
			var first := slide.create_presentation_snapshot()
			slide.cleanup()
			rng.seed = 902
			slide.start_disaster(rng)
			_expect(slide.create_presentation_snapshot() == first, "Same-seed replay and reset")
			slide.cleanup()
			main.match_manager.prepare_lobby()
	# Dummy audio still owns playback refs until its next mix; detach streams
	# before freeing the scene rather than abandoning outstanding UI cues.
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("ROCKSLIDE_OK checks=%d maps=2 collision_escape_cover=passed resets=5" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
