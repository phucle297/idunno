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
	for hazard in [main.bee_swarm, main.ufo, main.volcano]:
		hazard.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	var remote_root := Node3D.new()
	root.add_child(remote_root)
	var api := SceneMultiplayer.new()
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 39995)
	api.multiplayer_peer = peer
	set_multiplayer(api, remote_root.get_path())
	var remote_bees := BeeSwarm.new()
	var remote_ufo := UFO.new()
	var remote_volcano := Volcano.new()
	for hazard in [remote_bees, remote_ufo, remote_volcano]:
		remote_root.add_child(hazard)
		hazard.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		var volcano: Volcano = main.volcano
		var center := volcano.district_center
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(center + Vector3.UP * 5)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1010
		volcano.start_disaster(rng)
		volcano.tick(12)
		await physics_frame
		await physics_frame
		var roof := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2, 0.2, 2)
		shape.shape = box
		roof.add_child(shape)
		main.add_child(roof)
		roof.position = volcano.centers[0] + Vector3.UP * 3
		await physics_frame
		await physics_frame
		volcano.environment = func() -> Dictionary: return {"rain": true, "snow": true}
		volcano.tick(5)
		_expect(volcano.heat[0] == 55 and volcano.heat[4] == 40, "Roof blocks precipitation cooling; strongest snow/rain rate wins")
		volcano.environment = func() -> Dictionary: return {"rain": true, "snow": true, "water": volcano.centers[0].y}
		volcano.tick(1)
		_expect(volcano.heat[0] == 45 and volcano.heat[4] == 30, "Exact support immersion overrides roof/weather without stacking rates")
		roof.free()
		var state := volcano.create_presentation_snapshot()
		remote_volcano.set_district(volcano.district_id, center, volcano.district_size)
		_expect(remote_volcano.apply_presentation_snapshot(state), "Late snapshot reconstructs stable authored district")
		_expect(remote_volcano.create_presentation_snapshot() == state and remote_volcano.centers == volcano.centers, "Remote heat and changed collision converge")
		remote_volcano.tick(100)
		_expect(remote_volcano.create_presentation_snapshot() == state, "Client cannot cool or damage independently")
		var invalid := state.duplicate(true)
		invalid.heat = "bad"
		_expect(not remote_volcano.apply_presentation_snapshot(invalid), "Malformed heat type rejected")
		invalid.heat = PackedFloat32Array([NAN])
		_expect(not remote_volcano.apply_presentation_snapshot(invalid) and remote_volcano.create_presentation_snapshot() == state, "Malformed heat leaves remote state intact")
		remote_volcano.cleanup()
		volcano.environment = func() -> Dictionary: return {}
		volcano.tick(60)
		_expect(remote_volcano.apply_presentation_snapshot(volcano.create_presentation_snapshot()) and remote_volcano.mutated and not remote_volcano.is_active(), "Cooled terrain reconstructs after hazard ends")
		remote_volcano.cleanup()
		# Re-enter all four crossing exits without a mandatory jump after mutation.
		for axis in [Vector2.RIGHT, Vector2.DOWN]:
			var extent: float = volcano.district_size.x / 2 if axis.x != 0 else volcano.district_size.y / 2
			# North/south follows the clear lane beside the authored loose crate,
			# rather than testing a straight line through that movable obstacle.
			var lane := Vector3(-1, 0, 0) if axis.y != 0 else Vector3.ZERO
			for direction in [-1, 1]:
				player.reset_for_match(center + lane + Vector3(axis.x * direction * (extent + 1.7), 0.03, axis.y * direction * (extent + 1.7)))
				player.set_camera_yaw(0)
				for step in 220:
					player.apply_movement_input(-axis * direction, false, false, 1.0 / 60)
					await physics_frame
				var offset := Vector2(player.position.x - center.x, player.position.z - center.z)
				_expect(direction * offset.dot(axis) < -1, "Cooled crossing traverses center without jumping on %s axis=%s; feet=%s" % [map_id, axis, player.position])
		volcano.cleanup()
		_expect(remote_volcano.apply_presentation_snapshot({}) and not remote_volcano.mutated, "Absent snapshot restores remote original map")
		player.reset_for_match(main.map_anchors.spawn_origin)
		for pair in [[main.bee_swarm, remote_bees], [main.ufo, remote_ufo]]:
			var hazard: Node = pair[0]
			var remote: Node = pair[1]
			_expect(hazard.start_disaster(rng), "New hazard starts for transport fixture")
			var snapshot: Dictionary = hazard.create_presentation_snapshot()
			_expect(remote.apply_presentation_snapshot(snapshot) and remote.create_presentation_snapshot() == snapshot, "Target/beam warning snapshot convergence")
			remote.tick(100)
			_expect(remote.create_presentation_snapshot() == snapshot, "Remote cannot advance authority")
			hazard.cleanup()
			_expect(remote.apply_presentation_snapshot({}) and not remote.is_active(), "Absent snapshot clears old targets/captures")
		var director: DisasterDirector = main.disaster_director
		main.match_manager.elapsed_time = 300
		director.start_directing(1010)
		_expect(director.try_start_disaster("Volcano"), "Director can select authored eruption solo")
		_expect(not director.try_start_disaster("UFO") and not director.try_start_disaster("Bee Swarm"), "Unsafe no-escape overlaps excluded")
		director.cleanup()
		main.match_manager.prepare_lobby()
	for sound: String in ["bees", "ufo", "volcano"]:
		main.gameplay_audio.play_warning(sound)
		var filename := "bee" if sound == "bees" else sound
		_expect(main.gameplay_audio._warning_voice.stream.resource_path.ends_with(filename + "_warning.wav"), "Distinct reserved synthesized warning")
		await create_timer(0.05).timeout
	# Actual landing height controls damage; routine jumps and low drops are safe.
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	var origin: Vector3 = main.map_anchors.spawn_origin
	player.reset_for_match(origin)
	for step in 120:
		player.apply_movement_input(Vector2.ZERO, false, step == 10, 1.0 / 60)
		await physics_frame
	_expect(main.match_manager.get_health(1) == 100, "Normal jump never causes fall damage")
	var previous_damage := 0.0
	for height in [2.5, 6.0, 10.0, 16.0]:
		main.match_manager.prepare_lobby()
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(origin + Vector3.UP * height)
		for step in 180:
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
			await physics_frame
		var damage: float = 100.0 - main.match_manager.get_health(1)
		print("FALL_HEIGHT height=%.1f damage=%.2f" % [height, damage])
		if height == 2.5:
			_expect(damage == 0.0, "Low ledge drops are safe")
		else:
			_expect(damage > previous_damage, "Higher real drops cause progressively more damage")
		if height == 6.0:
			_expect(damage < 12.0, "Typical rooftop descent deals modest damage")
		if height == 10.0:
			_expect(damage > 0.0 and damage < 45.0, "Ten-metre drop is survivable from full health")
		previous_damage = damage
	_expect(main.match_manager.get_cause_of_death(1) == "Fall", "Real lethal landing reports Fall, not cosmetic or UFO damage")
	peer.close()
	remote_root.free()
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("PHASE10_INTEGRATION_OK checks=%d maps=2 cover_cooling_snapshot_crossing_audio_fall=passed" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
