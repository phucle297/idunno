extends SceneTree

var checks := 0
var failures: Array[String] = []
var roof_summary: Array[String] = []
const ROOF := {"toy_town": "ShopRoof", "toy_harbor": "WarehouseRoof"}
const INDOOR := {"toy_town": "Shop", "toy_harbor": "Warehouse"}
const ROOF_SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
# Building footprints from main.gd _add_open_building; roof slab spans 4.505-4.855 m.
const FOOTPRINT := {"toy_town": Vector2(12.0, 10.0), "toy_harbor": Vector2(16.0, 12.0)}


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
	main.disaster_director.set_physics_process(false)
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
		await _roof_pressure(main, bees, player, map_id)
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
	_expect(is_equal_approx(bees.warning_duration, 5.0), "Initial warning stays 5.0 s")
	_expect(is_equal_approx(BeeSwarm.RETARGET_WARNING, 3.0), "Retarget warning stays 3.0 s")
	_expect(is_equal_approx(BeeSwarm.STING_DAMAGE, 8.0), "Sting damage stays 8")
	_expect(is_equal_approx(bees.active_duration, 24.0), "Active duration stays 24 s")
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("BEE_SWARM_OK checks=%d maps=2 resets=5 reach_wall_roof_water=passed roof_pressure=%s" % [checks, " ".join(roof_summary)])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _refuge(main, refuge_name: String) -> Dictionary:
	for refuge: Dictionary in main.map_anchors.refuges:
		if String(refuge.get("name", "")) == refuge_name:
			return refuge
	return {}


# T3g: an exposed roof is not shelter; a real roof overhead still is. The swarm
# starts at street level beside the building (as after a transfer from another
# survivor) and must reach the only, motionless roof camper within one
# active_duration. A camper never moves, so no forced relocation is counted:
# success here means at least one sting.
func _roof_pressure(main, bees: BeeSwarm, player: PartyPlayer, map_id: String) -> void:
	var roof := _refuge(main, ROOF[map_id])
	var indoor := _refuge(main, INDOOR[map_id])
	_expect(not roof.is_empty() and not indoor.is_empty(), "%s roof and indoor refuges exist" % map_id)
	if roof.is_empty() or indoor.is_empty():
		return
	var roof_feet: Vector3 = roof.center
	var indoor_feet: Vector3 = indoor.center
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(indoor_feet)
	player.global_position = indoor_feet
	await physics_frame
	_expect(bees._protected(indoor_feet), "%s indoor target is protected by a real roof" % map_id)
	_expect(not bees._eligible_targets().has(1), "%s indoor target is not eligible" % map_id)
	var indoor_rng := RandomNumberGenerator.new()
	indoor_rng.seed = 101
	_expect(not bees.start_disaster(indoor_rng), "%s swarm cannot start on an indoor-only player" % map_id)
	player.global_position = roof_feet
	await physics_frame
	_expect(not bees._protected(roof_feet), "%s exposed roof is not shelter" % map_id)
	_expect(bees._eligible_targets() == [1], "%s exposed roof target is eligible" % map_id)
	main.match_manager.prepare_lobby()
	var space := bees.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	probe.shape = sphere
	probe.collision_mask = 1
	var successes := 0
	for seed_value: int in ROOF_SEEDS:
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		player.reset_for_match(roof_feet)
		player.global_position = roof_feet
		await physics_frame
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var started := bees.start_disaster(rng)
		# Street-level approach point in open air around the building.
		var start := Vector3.ZERO
		for attempt in 32:
			var angle := rng.randf() * TAU
			var distance := rng.randf_range(9.0, 14.0)
			start = Vector3(roof_feet.x + cos(angle) * distance, 1.0, roof_feet.z + sin(angle) * distance)
			probe.transform = Transform3D(Basis.IDENTITY, start)
			if space.intersect_shape(probe, 1).is_empty():
				break
		bees.swarm_position = start
		var first_sting := -1.0
		var abandoned := false
		var elapsed := 0.0
		while bees.is_active() and elapsed < bees.active_duration + 0.01:
			bees.tick(1.0 / 60)
			elapsed += 1.0 / 60
			if bees.is_active() and bees.target_id != 1:
				abandoned = true
			if first_sting < 0 and main.match_manager.get_health(1) < 100:
				first_sting = elapsed
		var stings := int(round((100.0 - main.match_manager.get_health(1)) / BeeSwarm.STING_DAMAGE))
		var ok := started and stings >= 1 and not abandoned
		successes += 1 if ok else 0
		print("ROOF_PRESSURE map=%s seed=%d start=(%.1f,%.1f,%.1f) stings=%d first_sting_s=%s abandoned=%s result=%s" % [
			map_id, seed_value, start.x, start.y, start.z, stings,
			"%.2f" % first_sting if first_sting >= 0 else "none", abandoned, "PASS" if ok else "FAIL"])
		bees.cleanup()
		main.match_manager.prepare_lobby()
	# A swarm that starts indoors under the camper never climbs through the roof
	# (its centre never rises past the slab underside inside the walls).
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	player.reset_for_match(roof_feet)
	player.global_position = roof_feet
	await physics_frame
	var tunnel_rng := RandomNumberGenerator.new()
	tunnel_rng.seed = 101
	bees.start_disaster(tunnel_rng)
	bees.swarm_position = Vector3(indoor_feet.x, 1.5, indoor_feet.z)
	var half: Vector2 = FOOTPRINT[map_id] * 0.5 - Vector2(0.2, 0.2)
	var tunneled := false
	var indoor_hp: float = main.match_manager.get_health(1)
	for _step_index in int(bees.active_duration * 60):
		if not bees.is_active():
			break
		bees.tick(1.0 / 60)
		var at := bees.swarm_position
		if absf(at.x - indoor_feet.x) < half.x and absf(at.z - indoor_feet.z) < half.y and at.y > 4.505:
			tunneled = true
	print("ROOF_TUNNEL map=%s tunneled=%s hp_lost=%.0f" % [map_id, tunneled, indoor_hp - main.match_manager.get_health(1)])
	_expect(not tunneled, "%s swarm under the roof never passes through the roof slab" % map_id)
	bees.cleanup()
	main.match_manager.prepare_lobby()
	# Fixture warnings queue audio; drain it like the suite's own teardown.
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	roof_summary.append("%s:%d/%d" % [map_id, successes, ROOF_SEEDS.size()])
	_expect(successes >= 7, "%s exposed roof camper stung in >=7/10 seeds (got %d)" % [map_id, successes])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
