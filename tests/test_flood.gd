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
