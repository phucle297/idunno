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
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(2, 0.05, 7))
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	var drops: MatchPowerups = main.powerups
	var manager: MatchManager = main.match_manager
	var player: PartyPlayer = main._player_nodes[1]
	var other: PartyPlayer = main._player_nodes[2]
	for map_id in ["toy_town", "toy_harbor"]:
		manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		for peer_id: int in manager.players:
			manager.set_player_ready(peer_id, true)
		_expect(manager.start_match(), "Round starts normally")
		var eligible: Array[Vector3] = []
		for point: Vector3 in drops.anchors:
			if main._powerup_anchor_is_valid(point, true):
				eligible.append(point)
			else:
				print("POWERUP_ANCHOR_DECLINED map=%s point=%s" % [map_id, point])
		_expect(eligible.size() >= 4, "Both maps offer multiple real reachable clear pads")
		_expect(not main._powerup_anchor_is_valid(Vector3(0, 30, 0), true), "No fabricated midair support")
		_expect(not main._powerup_anchor_is_valid(main._network_spawn_position(0), true), "No spawn capsule overlap")
		manager.elapsed_time = 29.99
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.pickups.is_empty(), "No drop before thirty seconds")
		manager.elapsed_time = 30
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.pickups.size() == 1, "One authoritative scheduled drop")
		if drops.pickups.is_empty():
			continue
		var first: Dictionary = drops.pickups[0].duplicate(true)
		drops.begin_round()
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.pickups[0] == first, "Same seed and eligible anchors reproduce exact type and position")
		var replica := MatchPowerups.new()
		root.add_child(replica)
		var before := drops.create_snapshot()
		_expect(replica.apply_snapshot(before) and replica.pickups == drops.pickups, "Late snapshot reconstructs live drops")
		player.reset_for_match(first.position)
		other.reset_for_match(first.position)
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.pickups.is_empty() and drops.buffs.size() == 1 and drops.buffs.has(1), "Equal-distance contention consumes once with stable peer-ID tie-break")
		var buff: Dictionary = drops.buffs[1].duplicate()
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.buffs[1] == buff, "A duplicate physics tick cannot regrant the consumed ID")
		_expect(replica.apply_snapshot(drops.create_snapshot()) and not replica.apply_snapshot(before), "Reordered older state cannot restore a consumed drop")
		var invalid := drops.create_snapshot()
		invalid.pickups = [{"id": 99, "kind": 999, "position": Vector3.ZERO, "expires": 99.0}]
		_expect(not replica.apply_snapshot(invalid), "Fabricated type rejected at snapshot boundary")
		var previous_round := drops.create_snapshot()
		drops.begin_round()
		_expect(replica.apply_snapshot(drops.create_snapshot()) and not replica.apply_snapshot(previous_round), "Prior-round state cannot revive a buff")
		replica.free()
		player.reset_for_match(main.map_anchors.spawn_origin)
		other.reset_for_match(main.map_anchors.spawn_origin + Vector3.RIGHT * 3)
		manager.elapsed_time = 30
		drops.tick(manager, main._player_nodes, 297)
		var wet_point: Vector3 = drops.pickups[0].position
		main.flood.phase = Flood.Phase.RISING
		main.flood.water_level = wet_point.y + 0.2
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.pickups.is_empty() and not main._powerup_anchor_is_valid(wet_point, true), "Submerged support despawns and refuses drops")
		main.flood.cleanup()
		var anchor: Vector3 = eligible[0]
		var district := -1
		for index in main.terrain_collapse.regions.size():
			if main.terrain_collapse.regions[index].has_point(Vector2(anchor.x, anchor.z)):
				district = index
		main.terrain_collapse.removed_mask = 1 << district
		_expect(not main._powerup_anchor_is_valid(anchor, true), "Missing district never supplies pickup support")
		main.terrain_collapse.reset()
		# A real intervening wall rejects collection even within the radius.
		var wall := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.1, 2, 2)
		collider.shape = shape
		wall.add_child(collider)
		main.add_child(wall)
		wall.position = anchor + Vector3(0.4, 1, 0)
		player.position = anchor
		await physics_frame
		_expect(not main._powerup_collection_is_clear(player, anchor + Vector3.RIGHT * 0.8), "Collection never crosses a solid wall")
		wall.free()
		manager.prepare_lobby()
		drops.tick(manager, main._player_nodes, 297)
		_expect(drops.pickups.is_empty() and drops.buffs.is_empty(), "Lobby boundary clears drops and effects")
		for cycle in 5:
			for peer_id: int in manager.players:
				manager.set_player_ready(peer_id, true)
			manager.start_match()
			player.reset_for_match(anchor)
			other.reset_for_match(main.map_anchors.spawn_origin)
			manager.elapsed_time = 1
			_offer(drops, anchor, MatchPowerups.Kind.SPEED, 101)
			drops.tick(manager, main._player_nodes, 297)
			_expect(drops.buff_state(1, 1) == Vector2(1, 12), "Collection starts a twelve-second Speed buff")
			manager.elapsed_time = 3
			_offer(drops, anchor, MatchPowerups.Kind.SPEED, 102)
			drops.tick(manager, main._player_nodes, 297)
			_expect(drops.buff_state(1, 3) == Vector2(1, 12), "Same type refreshes, never adds strength or duration")
			_offer(drops, anchor, MatchPowerups.Kind.JUMP, 103)
			drops.tick(manager, main._player_nodes, 297)
			_expect(drops.buff_state(1, 3) == Vector2(2, 10) and drops.buffs.size() == 1, "Jump replaces Speed without stacking")
			manager.elapsed_time = 13
			drops.tick(manager, main._player_nodes, 297)
			_expect(drops.buffs.is_empty(), "Match-clock expiry clears the buff")
			_offer(drops, anchor, MatchPowerups.Kind.JUMP, 104)
			drops.tick(manager, main._player_nodes, 297)
			manager.apply_damage(1, 100, "Fixture")
			_expect(drops.buffs.is_empty() and player.movement_buff == Vector2.ZERO, "Death/end clears tuning immediately")
			manager.prepare_lobby()
			player.reset_for_match(main.map_anchors.spawn_origin)
			_expect(player.movement_buff == Vector2.ZERO and drops.pickups.is_empty(), "Five rematches retain no power-up state")
	await _measure_movement()
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("MATCH_POWERUPS_OK checks=%d maps=2 seeded_atomic_replication_support_movement_five_rematches=passed" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _offer(drops: MatchPowerups, point: Vector3, kind: int, id: int) -> void:
	# Controlled spawn fixture; collection still uses production distance/LOS,
	# not a client claim or a direct buff grant.
	drops.pickups.append({"id": id, "kind": kind, "position": point, "expires": 500.0})


func _measure_movement() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.position.y = 100
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.2, 60)
	collider.shape = box
	collider.position.y = -0.1
	floor.add_child(collider)
	world.add_child(floor)
	var player: PartyPlayer = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	const DT := 1.0 / 60.0
	for sprint in [false, true]:
		for kind in [MatchPowerups.Kind.NONE, MatchPowerups.Kind.SPEED, MatchPowerups.Kind.JUMP]:
			player.reset_for_match(Vector3.ZERO)
			player.movement_buff = Vector2(kind, 12)
			for step in 60:
				player.apply_movement_input(Vector2.RIGHT, sprint, false, DT)
				await physics_frame
			var from := player.position.x
			for step in 60:
				player.apply_movement_input(Vector2.RIGHT, sprint, false, DT)
				await physics_frame
			var distance := player.position.x - from
			var expected := (6.5 if sprint else 4.5) * (1.2 if kind == MatchPowerups.Kind.SPEED else 1.0)
			_expect(absf(distance - expected) < 0.01, "Real grounded distance matches effective tuning")
			print("POWERUP_DISTANCE sprint=%s kind=%d distance_m=%.4f expected=%.4f" % [sprint, kind, distance, expected])
	for kind in [MatchPowerups.Kind.NONE, MatchPowerups.Kind.JUMP]:
		player.reset_for_match(Vector3.ZERO)
		for step in 5:
			player.apply_movement_input(Vector2.ZERO, false, false, DT)
			await physics_frame
		player.movement_buff = Vector2(kind, 10)
		var base := player.position.y
		var apex := base
		for step in 70:
			player.apply_movement_input(Vector2.ZERO, false, step == 0, DT)
			if step == 1:
				player.movement_buff = Vector2.ZERO # Expiry cannot rewrite airborne velocity.
			apex = maxf(apex, player.position.y)
			await physics_frame
		var target := 1.62 if kind == MatchPowerups.Kind.JUMP else 1.35
		_expect(absf(apex - base - target) < 0.08, "Measured jump apex matches height multiplier even after airborne expiry")
		print("POWERUP_APEX kind=%d height_m=%.4f target=%.4f" % [kind, apex - base, target])
	player.reset_for_match(Vector3.ZERO)
	player.movement_buff = Vector2(MatchPowerups.Kind.SPEED, 0.05)
	for step in 30:
		player.apply_movement_input(Vector2.RIGHT, true, false, DT)
		await physics_frame
	_expect(absf(player.velocity.x - 6.5) < 0.01 and player.movement_buff == Vector2.ZERO, "Sprint expiry converges to base speed")
	player.reset_for_match(Vector3.ZERO)
	player.movement_buff = Vector2(MatchPowerups.Kind.SPEED, 12)
	player.apply_hazard_velocity(Vector3(3, 2, -1), 8)
	_expect(player.velocity == Vector3(3, 2, -1), "Buff never scales external impulses")
	player.reset_for_match(Vector3.ZERO)
	for sequence in range(1, 11):
		player.predict_movement_input(sequence, Vector2.RIGHT, true, false, DT)
	player.reconcile_movement(Vector3.ZERO + world.position, Vector3(7.8, 0, 0), 0, false, 6, Vector3(0.12, 0, 1), Vector2(1, 0.04))
	_expect(player.movement_buff == Vector2.ZERO and player.velocity.x <= 7.8 and player.velocity.x >= 6.5, "Reconciliation replays buff expiry on the acknowledged simulation timeline")
	world.free()
	await physics_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
