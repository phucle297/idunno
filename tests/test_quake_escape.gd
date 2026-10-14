extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	main.set_process(false)
	main.disaster_director.cleanup()
	var manager := main.get_node("MatchManager") as MatchManager
	manager.set_process(false)
	var quake := main.get_node("Earthquake") as Earthquake
	quake.set_process(false)
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_camera_yaw(0.0)
	for map_id in ["toy_town", "toy_harbor"]:
		main.set_map_id(map_id)
		await physics_frame
		manager.prepare_lobby()
		manager.set_player_ready(1, true)
		manager.start_match()
		main.disaster_director.cleanup()
		for settle in 12:
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
			await physics_frame
		var rng := RandomNumberGenerator.new()
		rng.seed = 811000
		var events := 0
		var direction := Vector2.RIGHT
		# A full configured solo round, with repeated seeded earthquakes. Only
		# moving ticks await physics; idle time still ticks the real match and
		# hazard at 60 Hz. No healing, teleport or reset during the round.
		while manager.state == MatchManager.MatchState.ACTIVE:
			if not quake.is_active() and fmod(manager.elapsed_time, 20.0) < 1.0 / 60.0:
				_expect(quake.start_disaster(rng), "Seeded quake must start during the solo round")
				events += 1
				direction = -direction
			if quake.phase == Earthquake.Phase.WARNING and quake.is_in_fracture(player.global_position):
				player.apply_movement_input(direction, false, false, 1.0 / 60.0)
				await physics_frame
			elif Vector2(player.velocity.x, player.velocity.z).length() > 0.01:
				player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60.0)
				await physics_frame
			quake.tick(1.0 / 60.0)
			manager.tick_match(1.0 / 60.0)
		_expect(events >= 10, "Full-duration solo control must encounter repeated earthquakes")
		_expect(manager.elapsed_time == manager.match_duration and manager.is_player_alive(1), "Ordinary-controller relocation must survive the full solo timeout")
		_expect(is_equal_approx(manager.get_health(1), 100.0), "Leaving every warned footprint must avoid all direct quake damage")
		print("QUAKE_ESCAPE map=%s seed=811000 duration=%.0f events=%d hp=%.1f" % [map_id, manager.elapsed_time, events, manager.get_health(1)])
		quake.cleanup()
	main.free()
	if failures.is_empty():
		print("QUAKE_ESCAPE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
