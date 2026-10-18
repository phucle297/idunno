extends SceneTree

## Exercises the mechanisms that Main actually constructs, including its LOS,
## active-match activation path, real capsule traversal, and weather geometry.
const TICK := 1.0 / 60.0
const Mechanisms = preload("res://game/world/town_mechanisms.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	var mechanisms: TownMechanisms = main.town_mechanisms
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_camera_yaw(0.0)
	_expect(is_instance_valid(mechanisms), "Main owns TownMechanisms under Sandbox")
	_prepare_active(main)
	await _walk_all_mechanism_ramps(main, player)
	await _cross_bridge_endpoints(main, player, mechanisms)
	await _check_activation_and_denials(main, player, mechanisms)
	await _check_awning_weather(main, mechanisms)
	await _check_stationary_rider(main, player, mechanisms)
	await _check_district_support(main, mechanisms)
	for cycle in 5:
		mechanisms.reset_for_match()
		var snapshot := mechanisms.create_snapshot()
		_expect(_state(snapshot, Mechanisms.AWNING_ID) == Mechanisms.STATE_REST_A and _state(snapshot, Mechanisms.BRIDGE_ID) == Mechanisms.STATE_REST_A, "Rematch %d resets both mechanisms" % (cycle + 1))
	main.gameplay_audio.reset_for_match()
	main.free()
	for failure in failures:
		push_error(failure)
	print("TOWN_MECHANISMS_OK checks=%d ramps=4 orientations=2 bridge_endpoints=2 rematches=5" % checks)
	quit(0 if failures.is_empty() else 1)


func _prepare_active(main: Node) -> void:
	main.match_manager.set_player_ready(1, true)
	_expect(main.match_manager.start_match(), "Fixture enters Main's active match state")


func _walk_all_mechanism_ramps(main: Node3D, player: PartyPlayer) -> void:
	for ramp: StaticBody3D in main.town_mechanisms.find_children("*Ramp", "StaticBody3D", true, false):
		var collisions := ramp.find_children("*", "CollisionShape3D", true, false)
		_expect(collisions.size() == 1 and (collisions[0] as CollisionShape3D).shape is BoxShape3D, "%s has one box walk surface" % ramp.name)
		if collisions.size() != 1 or not (collisions[0] as CollisionShape3D).shape is BoxShape3D:
			continue
		var shape := (collisions[0] as CollisionShape3D).shape as BoxShape3D
		var endpoint_a := ramp.to_global(Vector3(0, shape.size.y * 0.5, -shape.size.z * 0.5))
		var endpoint_b := ramp.to_global(Vector3(0, shape.size.y * 0.5, shape.size.z * 0.5))
		var low := endpoint_a if endpoint_a.y < endpoint_b.y else endpoint_b
		var high := endpoint_b if endpoint_a.y < endpoint_b.y else endpoint_a
		_expect(await _walk(player, low, high), "%s capsule walks 3.4m ramp uphill" % ramp.name)
		_expect(await _walk(player, high, low), "%s capsule walks 3.4m ramp downhill" % ramp.name)


func _walk(player: PartyPlayer, start: Vector3, target: Vector3) -> bool:
	var direction := Vector2(target.x - start.x, target.z - start.z).normalized()
	player.reset_for_match(start - Vector3(direction.x, 0, direction.y) + Vector3.UP * 0.12)
	for settle in 12:
		player.apply_movement_input(Vector2.ZERO, false, false, TICK)
		await physics_frame
	for tick in 300:
		var delta := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if delta.length() < 0.38 and player.is_on_floor():
			return true
		player.apply_movement_input(delta.normalized(), true, false, TICK)
		await physics_frame
	print("MECHANISM_WALK_FAILED start=%s target=%s actual=%s floor=%s" % [start, target, player.global_position, player.is_on_floor()])
	return false


func _cross_bridge_endpoints(_main: Node, player: PartyPlayer, mechanisms: TownMechanisms) -> void:
	var pivot := mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID).origin
	for target in [Mechanisms.STATE_REST_A, Mechanisms.STATE_REST_B]:
		mechanisms.reset_for_match()
		if target == Mechanisms.STATE_REST_B:
			_expect(mechanisms.request_activation(Mechanisms.BRIDGE_ID, 1, mechanisms.get_control_position(Mechanisms.BRIDGE_ID), true, false, true, true) == Mechanisms.ActivationResult.ACCEPTED, "Bridge accepts alternate-orientation turn")
			for tick in 181:
				mechanisms.server_tick(TICK, {}, true)
			await physics_frame
		var axis := mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID).basis.z.normalized()
		var crossed := await _walk(player, pivot - axis * 5.0, pivot + axis * 5.0)
		_expect(crossed, "Bridge crosses both landing endpoints in orientation %d" % target)


func _check_activation_and_denials(main: Node, player: PartyPlayer, mechanisms: TownMechanisms) -> void:
	mechanisms.reset_for_match()
	var awning := mechanisms.get_control_position(Mechanisms.AWNING_ID)
	player.reset_for_match(awning + Vector3(0, 0.12, -0.45))
	for tick in 10:
		player.apply_movement_input(Vector2.ZERO, false, false, TICK)
		await physics_frame
	_expect(player.is_on_floor() and main._activate_mechanism(1, Mechanisms.AWNING_ID), "Grounded nearby E activation is accepted through Main")
	_expect(not main._activate_mechanism(1, Mechanisms.AWNING_ID), "Spam during motion is denied through Main")
	mechanisms.reset_for_match()
	player.global_position = awning + Vector3(20, 0, 0)
	_expect(not main._activate_mechanism(1, Mechanisms.AWNING_ID), "Far activation is denied through Main")
	mechanisms.reset_for_match()
	player.global_position = awning + Vector3.UP * 4
	_expect(not main._activate_mechanism(1, Mechanisms.AWNING_ID), "Airborne activation is denied through Main")
	mechanisms.reset_for_match()
	player.apply_knockdown(Vector3.ZERO)
	player.global_position = awning + Vector3(0, 0.12, -0.45)
	_expect(not main._activate_mechanism(1, Mechanisms.AWNING_ID), "Ragdolled activation is denied through Main")
	main.match_manager.apply_damage(1, 1000.0, "mechanism fixture")
	_expect(not main._activate_mechanism(1, Mechanisms.AWNING_ID), "Dead activation is denied through Main")


func _check_awning_weather(main: Node, mechanisms: TownMechanisms) -> void:
	var weather: WeatherSurfaces = main.weather_surfaces
	mechanisms.reset_for_match()
	weather.tick(4.0, true, false, -INF)
	var pivot := mechanisms.get_deck_transform(Mechanisms.AWNING_ID).origin
	var turning_point := Vector3(pivot.x + 2.0, 0.08, pivot.z - 0.5)
	var rest_a := weather.sample_surface(turning_point)
	_expect(rest_a.y == 0.0 and not weather.is_exposed(turning_point), "Awning rest A covers its actual dry footprint")
	_expect(mechanisms.request_activation(Mechanisms.AWNING_ID, 1, mechanisms.get_control_position(Mechanisms.AWNING_ID), true, false, true, true) == Mechanisms.ActivationResult.ACCEPTED, "Awning turns for actual cover check")
	for tick in 181: mechanisms.server_tick(TICK, {}, true)
	await physics_frame
	weather.invalidate_cover()
	var rest_b := weather.sample_surface(turning_point)
	_expect(rest_b.y > 0.0 and weather.is_exposed(turning_point), "Awning rest B exposes and wets the former footprint")


func _check_stationary_rider(main: Node, player: PartyPlayer, mechanisms: TownMechanisms) -> void:
	main.restart_local_match()
	mechanisms.reset_for_match()
	var deck := mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID)
	player.reset_for_match(deck.origin + Vector3(0, 0.35, 2.0))
	for settle in 20:
		player.apply_movement_input(Vector2.ZERO, false, false, TICK)
		await physics_frame
	var start := player.global_position
	_expect(player.is_on_floor(), "Bridge rider starts grounded on the actual deck")
	_expect(mechanisms.request_activation(Mechanisms.BRIDGE_ID, 1, mechanisms.get_control_position(Mechanisms.BRIDGE_ID), true, false, true, true) == Mechanisms.ActivationResult.ACCEPTED, "Bridge starts with stationary rider")
	var max_speed := 0.0
	for tick in 190:
		mechanisms.server_tick(TICK, {}, true)
		player.apply_movement_input(Vector2.ZERO, false, false, TICK)
		await physics_frame
		max_speed = maxf(max_speed, player.velocity.length())
	var end := player.global_position
	_expect(end.distance_to(start) > 1.0 and end.distance_to(mechanisms.get_deck_transform(Mechanisms.BRIDGE_ID).origin) < 5.9, "Grounded stationary rider is carried once through 90-degree turn")
	_expect(max_speed < 20.0 and player.velocity.is_finite(), "Bridge carriage has no velocity explosion")


func _check_district_support(main: Node, mechanisms: TownMechanisms) -> void:
	main.terrain_collapse.apply_snapshot(PackedFloat32Array([128, -1, 0, 1]))
	mechanisms.server_tick(TICK, {}, true)
	await physics_frame
	var entries: Array = mechanisms.create_snapshot().mechanisms
	_expect(bool(entries[1].enabled), "South district loss must not remove the bridge's still-supported central deck")
	_expect(bool(entries[0].enabled), "South district loss preserves the central awning")
	_expect(mechanisms.apply_snapshot(mechanisms.create_snapshot()), "Mechanism replica accepts current state after terrain removal")
	await physics_frame
	for point in [Vector3(2, 2.5, 31.5), Vector3(2, 2.5, 32.1)]:
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1)
		var supported: bool = not main.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		_expect(supported == (point.z < 32), "Replica preserves only the landing piece inside surviving terrain at %s" % point)
	main.terrain_collapse.reset()
	mechanisms.reset_for_match()
	main.terrain_collapse.apply_snapshot(PackedFloat32Array([16, -1, 0, 1]))
	mechanisms.server_tick(TICK, {}, true)
	await physics_frame
	entries = mechanisms.create_snapshot().mechanisms
	_expect(not bool(entries[1].enabled) and not bool(entries[0].enabled), "Loss of actual pivot support disables both mechanisms")
	main.terrain_collapse.reset()
	mechanisms.reset_for_match()
	await physics_frame


func _state(snapshot: Dictionary, id: String) -> int:
	for entry: Dictionary in snapshot.mechanisms:
		if entry.id == id: return int(entry.state)
	return -1


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
