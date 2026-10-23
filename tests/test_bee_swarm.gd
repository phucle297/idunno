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
	var bees: BeeSwarm = main.bee_swarm
	bees.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var origin: Vector3 = main.map_anchors.spawn_origin
		for cycle in 5:
			main.match_manager.set_player_ready(1, true)
			main.match_manager.start_match()
			player.reset_for_match(origin)
			var rng := RandomNumberGenerator.new()
			rng.seed = 1001
			_expect(bees.start_disaster(rng), "Start on %s" % map_id)
			var first := bees.create_presentation_snapshot()
			bees.tick(4.9)
			_expect(main.match_manager.get_health(1) == 100 and bees.phase == BeeSwarm.Phase.WARNING, "Warning never stings")
			bees.tick(1.2)
			_expect(main.match_manager.get_health(1) == 92, "Reach produces one periodic sting")
			player.position.x += 12
			var previous := bees.swarm_position
			bees.tick(1)
			_expect(main.match_manager.get_health(1) == 92, "Outside actual reach never stings")
			_expect(previous.distance_to(bees.swarm_position) <= BeeSwarm.SPEED + 0.001, "Pursuit slower than walking; no teleport")
			bees.cleanup()
			player.reset_for_match(origin)
			rng.seed = 1001
			bees.start_disaster(rng)
			_expect(bees.create_presentation_snapshot() == first, "Same seed reconstructs target and position")
			bees.water_level = func() -> float: return origin.y + 1.6
			bees.tick(0.1)
			_expect(not bees.is_active(), "Head immersion breaks pursuit")
			bees.water_level = Callable()
			main.match_manager.prepare_lobby()
		# Wall-backed attack rejection and roof-backed pursuit break.
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(origin)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1001
		bees.start_disaster(rng)
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 3, 6)
		shape.shape = box
		wall.add_child(shape)
		root.add_child(wall)
		wall.position = player.position + Vector3(0.6, 1.5, 0)
		await physics_frame
		bees.swarm_position = player.position + Vector3(1.2, 1, 0)
		bees.tick(6.2)
		_expect(main.match_manager.get_health(1) == 100, "Wall blocks swept pursuit and stings")
		wall.position = player.position + Vector3(0, 2.5, 0)
		box.size = Vector3(5, 0.3, 5)
		await physics_frame
		await physics_frame
		bees.tick(0.1)
		_expect(not bees.is_active(), "Actual roof breaks pursuit")
		wall.free()
		main.match_manager.prepare_lobby()
	# A real second registered survivor receives a fresh warning; no position warp.
	var second := Node3D.new()
	main.add_child(second)
	second.position = main.map_anchors.spawn_origin + Vector3(4, 0, 0)
	main.match_manager.register_player(2, "Second")
	bees.register_player(2, second)
	for id in [1, 2]:
		main.match_manager.set_player_ready(id, true)
	main.match_manager.start_match()
	player.reset_for_match(main.map_anchors.spawn_origin)
	var transfer_rng := RandomNumberGenerator.new()
	transfer_rng.seed = 1001
	bees.start_disaster(transfer_rng)
	var original_target := bees.target_id
	bees.tick(11.1)
	_expect(bees.target_id != original_target and bees.phase == BeeSwarm.Phase.WARNING, "Rotate survivor with recovery warning")
	var transfer_position := bees.swarm_position
	bees.unregister_player(bees.target_id)
	bees.tick(0.1)
	_expect(bees.target_id == original_target and bees.phase == BeeSwarm.Phase.WARNING, "Disconnect safely warns new target")
	_expect(bees.swarm_position == transfer_position, "Target transfer does not teleport swarm")
	bees.cleanup()
	main.match_manager.prepare_lobby()
	main.match_manager.unregister_player(2)
	second.free()
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("BEE_SWARM_OK checks=%d maps=2 resets=5 reach_wall_roof_water=passed" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
