extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")
const FloodScript = preload("res://game/flood.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var manager := ManagerScript.new()
	world.add_child(manager)
	var flood := FloodScript.new()
	flood.rise_duration = 1.0
	flood.hold_duration = 10.0
	flood.drain_duration = 1.0
	world.add_child(flood)
	flood.configure(manager)

	var low_player := _add_player(world, "LowPlayer", Vector3(0.0, 4.5, 0.0))
	var high_player := _add_player(world, "HighPlayer", Vector3(0.0, 4.5, 0.0))
	for peer_id in [1, 2]:
		var player: PartyPlayer = low_player if peer_id == 1 else high_player
		_expect(manager.register_player(peer_id, player.name), "Player %d must register with match state" % peer_id)
		_expect(manager.set_player_ready(peer_id, true), "Player %d must become ready" % peer_id)
		_expect(flood.register_player(peer_id, player), "Player %d must register with Flood" % peer_id)
	_expect(manager.start_match(), "Flood test match must start")

	var prop := _add_prop(world, Vector3(0.0, 0.2, 0.0))
	_expect(flood.start_warning(), "Authority must start Flood during an active match")
	_expect(not flood.start_warning(), "A second Flood warning must not replace the active flood")
	_expect(flood.phase == FloodScript.Phase.WARNING and flood.active_effect_count() == 1, "Flood must create one warning surface")
	flood.tick(5.99)
	_expect(flood.phase == FloodScript.Phase.WARNING, "Flood must not rise before the six-second warning completes")
	flood.tick(0.02)
	_expect(flood.phase == FloodScript.Phase.RISING, "Flood must rise after the warning")
	low_player.position.y = 0.0
	_expect(is_equal_approx(low_player.get_head_sample_position().y, 1.35), "Standing must retain the 1.35 m authoritative head sample")
	flood._set_water_level(1.0)
	flood._apply_water_effects(2.5, 1.0, 0.0)
	_expect(is_equal_approx(manager.get_health(1), 100.0), "Water below a standing player's head must not deal drowning damage")
	low_player.apply_movement_input(Vector2.ZERO, false, true, false, 0.0)
	_expect(low_player.get_head_sample_position().y < 1.0, "Crouching must lower the authoritative head sample with the capsule")
	flood._apply_water_effects(2.5, 1.0, 0.0)
	_expect(is_equal_approx(manager.get_health(1), 94.0), "Water covering a crouched player's head must deal damage after breathing grace")
	var exposure_snapshot := flood.create_presentation_snapshot()
	_expect(exposure_snapshot.submerged_peer_ids == PackedInt32Array([1, 2]) and is_equal_approx(exposure_snapshot.submerged_times[0], 2.5), "Flood snapshots must carry per-player breathing exposure for client feedback")
	low_player.position.y = 4.5
	low_player.apply_movement_input(Vector2.ZERO, false, false, false, 0.0)
	flood._apply_water_effects(0.1, 1.0, 0.0)
	var low_state: Dictionary = manager.players[1]
	low_state.health = 100.0
	low_state.damage_taken = 0.0
	manager.players[1] = low_state
	flood._set_water_level(flood.start_level)
	flood._phase_elapsed = 0.0
	flood.tick(1.0)
	_expect(is_equal_approx(flood.water_level, flood.target_level), "Flood must reach the configured 3.5 m target")
	_expect(is_equal_approx(manager.get_health(1), 100.0), "A player above rising water must not take damage")
	_expect(is_equal_approx(manager.get_health(2), 100.0), "A player above water must not take damage")
	low_player.position.y = 0.0
	flood.tick(1.99)
	_expect(is_equal_approx(manager.get_health(1), 100.0), "Damage must not begin before two submerged seconds")
	flood.tick(0.51)
	_expect(is_equal_approx(manager.get_health(1), 94.0), "Only time beyond breathing grace must deal 12 HP/s")
	_expect(is_equal_approx(manager.get_health(2), 100.0), "High ground must remain safe at target water level")
	_expect(prop.constant_force.length() <= flood.buoyancy_force_max + flood.drag_force_max * 2.0 + 0.001, "Combined water force must remain bounded")
	_expect(flood.current_speed <= 1.5, "Flood current must respect the design speed cap")

	low_player.position.y = 4.5
	flood.tick(0.25)
	_expect(is_zero_approx(flood.get_submerged_time(1)), "Surfacing must reset breathing grace")
	low_player.position.y = 0.0
	flood.tick(1.0)
	_expect(is_equal_approx(manager.get_health(1), 94.0), "Re-submersion must receive a fresh breathing grace period")

	# 3.3.2 role boundaries (asymmetric two-player case): at refuge-height
	# water the escape-aid elevation keeps its passenger dry while a grounded
	# player drowns; at the3.5m peak the elevation confers no safety, and
	# electrified water still damages flooded players at that elevation.
	low_player.position.y = 1.7
	high_player.position.y = 0.0
	flood._set_water_level(2.2)
	flood._apply_water_effects(2.5, 2.2, 0.0)
	_expect(is_equal_approx(manager.get_health(1), 94.0), "Escape-aid elevation must keep its passenger dry at refuge-height water")
	_expect(is_equal_approx(manager.get_health(2), 94.0), "A grounded player at the same water level must drown")
	# Wet/dry prop boundary: water forces apply only below the water line.
	prop.position = Vector3(6.0, 2.4, 0.0)
	prop.sleeping = true
	flood._apply_water_effects(0.5, flood.water_level, 0.0)
	_expect(prop.sleeping, "A dry prop above the water line must receive no water forces")
	prop.position = Vector3(6.0, 1.0, 0.0)
	flood._apply_water_effects(0.5, flood.water_level, 0.0)
	_expect(not prop.sleeping, "A submerged prop must be woken by water forces")
	flood._set_water_level(flood.target_level)
	flood._apply_water_effects(2.5, flood.target_level, 0.0)
	_expect(is_equal_approx(manager.get_health(1), 88.0), "Peak flood must drown a player on the escape-aid elevation after breathing grace")
	flood._apply_water_effects(0.5, flood.target_level, 0.5)
	_expect(is_equal_approx(manager.get_health(1), 69.5), "Electrified water must damage a flooded player even at escape-aid elevation")

	flood.cleanup()
	await process_frame
	_expect(flood.phase == FloodScript.Phase.IDLE and flood.active_effect_count() == 0, "Cleanup must remove Flood state and visual")
	_expect(flood.start_warning(), "A cleaned Flood must be reusable")
	flood.cleanup()

	# Task 4.1b: bounded server-selected rise/current variants with replicated
	# gameplay parameters and deterministic replay from the round seed.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4111
	_expect(flood.start_disaster(rng_a), "Seeded Flood must start")
	var rise_a: FloodScript.RisePattern = flood.rise_pattern
	var current_a: FloodScript.CurrentPattern = flood.current_pattern
	var direction_a := flood.current_direction
	_expect(rise_a == FloodScript.RisePattern.STEADY or rise_a == FloodScript.RisePattern.SURGE, "Flood must select a bounded rise pattern")
	_expect(current_a == FloodScript.CurrentPattern.CALM or current_a == FloodScript.CurrentPattern.DRIFT, "Flood must select a bounded current pattern")
	_expect(direction_a in FloodScript.CARDINAL_DIRECTIONS, "Flood current direction must come from the bounded cardinal set")
	flood.cleanup()
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4111
	_expect(flood.start_disaster(rng_b), "Seeded Flood replay must start")
	_expect(flood.rise_pattern == rise_a and flood.current_pattern == current_a and flood.current_direction == direction_a, "Same seed must reproduce the same Flood variant parameters")
	flood.cleanup()

	# SURGE is a monotonic bounded two-stage curve that still reaches the
	# configured target level and beats STEADY early.
	flood.rise_pattern = FloodScript.RisePattern.SURGE
	flood.rise_duration = 4.0
	var surge_levels: Array[float] = []
	for sample in [0.0, 1.8, 2.2, 3.0, 4.0]:
		surge_levels.append(flood._rise_level(sample))
	_expect(surge_levels[0] <= surge_levels[1] and surge_levels[1] <= surge_levels[2] and surge_levels[2] <= surge_levels[3] and surge_levels[3] <= surge_levels[4], "Surge rise must stay monotonic")
	_expect(is_equal_approx(surge_levels[4], flood.target_level), "Surge rise must reach the configured target level")
	var surge_mid := flood._rise_level(1.0)
	flood.rise_pattern = FloodScript.RisePattern.STEADY
	_expect(surge_mid > flood._rise_level(1.0), "Surge must beat steady rise early without changing the target")
	flood.rise_duration = 35.0

	flood.current_pattern = FloodScript.CurrentPattern.CALM
	_expect(flood._current_vector().is_zero_approx(), "Calm flood must apply no lateral current")
	flood.current_pattern = FloodScript.CurrentPattern.DRIFT
	flood.current_direction = Vector3.FORWARD
	_expect(flood._current_vector().is_equal_approx(Vector3(0.0, 0.0, -flood.current_speed)), "Drift current must follow the selected bounded direction")
	flood.current_direction = Vector3.RIGHT

	# Variant parameters replicate through presentation snapshots.
	flood.rise_pattern = FloodScript.RisePattern.SURGE
	flood.current_pattern = FloodScript.CurrentPattern.CALM
	flood.current_direction = Vector3.FORWARD
	_expect(flood.start_warning(), "Flood must run for the replication gate")
	var client_root := Node3D.new()
	root.add_child(client_root)
	var client_api := SceneMultiplayer.new()
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 39999)
	client_api.multiplayer_peer = client_peer
	set_multiplayer(client_api, client_root.get_path())
	var client_flood := FloodScript.new()
	client_root.add_child(client_flood)
	var flood_snapshot := flood.create_presentation_snapshot()
	_expect(client_flood.apply_presentation_snapshot(flood_snapshot), "Client must accept replicated Flood variant parameters")
	_expect(client_flood.rise_pattern == flood.rise_pattern and client_flood.current_pattern == flood.current_pattern and client_flood.current_direction == flood.current_direction, "Replicated Flood must match the server's rise/current parameters")
	flood.cleanup()

	# Five rematch cycles clear variant state and effects.
	for cycle in 5:
		var cycle_rng := RandomNumberGenerator.new()
		cycle_rng.seed = 4300 + cycle
		_expect(flood.start_disaster(cycle_rng), "Rematch cycle %d must start Flood" % (cycle + 1))
		flood.cleanup()
		_expect(flood.phase == FloodScript.Phase.IDLE and flood.rise_pattern == FloodScript.RisePattern.STEADY and flood.current_pattern == FloodScript.CurrentPattern.DRIFT, "Rematch cycle %d must clear Flood variant state" % (cycle + 1))
	await process_frame
	_expect(flood.active_effect_count() == 0, "Five rematch cycles must leave no Flood effects")

	if failures.is_empty():
		print("FLOOD_OK checks=%d water_level=%.1f" % [checks, flood.water_level])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _add_player(parent: Node3D, player_name: String, position: Vector3) -> PartyPlayer:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	player.name = player_name
	player.position = position
	parent.add_child(player)
	player.set_physics_process(false)
	return player


func _add_prop(parent: Node3D, position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.add_to_group("grabbable")
	body.mass = 12.0
	body.position = position
	body.freeze = true
	parent.add_child(body)
	body.freeze = false
	return body


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
