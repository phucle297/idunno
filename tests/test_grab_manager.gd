extends SceneTree

const Tuning = preload("res://game/player_tuning.gd")
const ManagerScript = preload("res://game/grab_manager.gd")

var failures: Array[String] = []
var checks := 0
var world: Node3D
var manager: Node
var player_one: PartyPlayer
var player_two: PartyPlayer
var crate: RigidBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_world()
	await physics_frame
	await _test_acquisition_eligibility()
	_test_range_and_contention()
	await _test_bounded_spring()
	_test_lifecycle_releases()
	await _test_repeated_carry_motion()
	_test_disconnect_release()
	await _test_destroyed_prop_release()
	if failures.is_empty():
		print("GRAB_MANAGER_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build_world() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(80.0, 0.2, 80.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)
	world.add_child(floor)

	manager = ManagerScript.new()
	world.add_child(manager)
	player_one = _add_player(Vector3.ZERO)
	player_two = _add_player(Vector3(0.2, 0.0, 0.0))
	crate = RigidBody3D.new()
	crate.mass = 12.0
	crate.add_to_group("grabbable")
	var crate_collision := CollisionShape3D.new()
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(0.6, 0.6, 0.6)
	crate_collision.shape = crate_shape
	crate.add_child(crate_collision)
	world.add_child(crate)
	crate.global_position = Vector3(0.0, 0.4, -1.0)
	_expect(manager.register_player(1, player_one), "Server must register the first player")
	_expect(manager.register_player(2, player_two), "Server must register the second player")


func _add_player(spawn_position: Vector3) -> PartyPlayer:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	world.add_child(player)
	player.global_position = spawn_position
	player.set_physics_process(false)
	return player


func _test_acquisition_eligibility() -> void:
	crate.freeze = true
	for mass in [1.99, 25.01]:
		crate.mass = mass
		_expect(manager.get_interaction_candidate(player_one) == null and not manager.request_grab(1, crate), "Prompt and authority reject uncarryable mass %s" % mass)
	for mass in [2.0, 25.0]:
		crate.mass = mass
		_expect(manager.get_interaction_candidate(player_one) == crate and manager.request_grab(1, crate), "Both carry mass boundaries are eligible")
		manager.release_grab(1)
	crate.mass = 12.0
	crate.position = Vector3(0, 0.4, 1)
	_expect(manager.get_interaction_candidate(player_one) == null and not manager.request_grab(1, crate), "A direct request cannot bypass the forward cone")
	crate.position = player_one.get_grab_origin() + Vector3.FORWARD * 1.5
	_expect(manager.get_interaction_candidate(player_one) == crate and manager.request_grab(1, crate), "Exact 1.5m boundary is reachable")
	manager.release_grab(1)
	crate.position.z -= 0.01
	_expect(manager.get_interaction_candidate(player_one) == null and not manager.request_grab(1, crate), "Just outside range is rejected by both paths")
	crate.position = Vector3(0, 0.4, -1)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.15)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.position = Vector3(0, 1, -0.5)
	await physics_frame
	_expect(manager.get_interaction_candidate(player_one) == null and not manager.request_grab(1, crate), "Wall obstruction rejects prompt and authoritative acquisition")
	_expect(manager.get_grab_owner(crate) == 0 and not crate.has_meta("grab_owner_peer_id"), "Rejected request leaves ownership unchanged")
	wall.position.x = -1.8
	var other_wall := wall.duplicate() as StaticBody3D
	world.add_child(other_wall)
	other_wall.position.x = 1.8
	await physics_frame
	_expect(manager.get_interaction_candidate(player_one) == crate and manager.request_grab(1, crate), "Open doorway between walls permits actual reach")
	_expect(crate.get_collision_exceptions().has(player_one), "Holding excludes the holder collider")
	wall.position.x = 0
	player_one.set_camera_yaw(PI)
	await physics_frame
	_expect(manager.toggle_grab(1) and manager.get_grab_owner(crate) == 0, "Release works despite occlusion and aim turning away")
	_expect(not crate.get_collision_exceptions().has(player_one), "Release restores holder collision")
	player_one.set_camera_yaw(0)
	wall.free()
	other_wall.free()
	var rapid_toggles_passed := true
	for _index in 50:
		rapid_toggles_passed = manager.toggle_grab(1) and rapid_toggles_passed
		rapid_toggles_passed = manager.toggle_grab(1) and rapid_toggles_passed
	_expect(rapid_toggles_passed and not crate.has_meta("grab_owner_peer_id") and crate.get_collision_exceptions().is_empty(), "100 immediate toggles preserve deliberate release/re-grab and clear ownership")
	crate.freeze = false
	await physics_frame


func _test_range_and_contention() -> void:
	crate.global_position = Vector3(0.0, 0.4, -Tuning.GRAB_RANGE - 0.2)
	_expect(manager.get_interaction_candidate(player_one) == null, "The contextual query must reject props beyond grab range")
	_expect(not manager.request_grab(1, crate), "A player must not grab beyond the 1.5 m range")
	crate.global_position = Vector3(0.0, 0.4, -1.0)
	_expect(manager.get_interaction_candidate(player_one) == crate, "The contextual query must return the same nearest prop used by grabbing")
	_expect(manager.request_grab(1, crate), "A player must grab an in-range tagged body")
	_expect(manager.get_grab_owner(crate) == 1, "The authoritative owner must be recorded")
	_expect(manager.get_interaction_candidate(player_two) == null, "The contextual query must reject an owned prop")
	_expect(not manager.request_grab(2, crate), "A second player must lose contention for an owned body")
	_expect(crate.get_meta("grab_owner_peer_id", 0) == 1, "The body must expose its authoritative owner")


func _test_bounded_spring() -> void:
	crate.freeze = true
	crate.global_position = Vector3(0.8, 0.9, -1.0)
	crate.freeze = false
	crate.linear_velocity = Vector3.ZERO
	var initial_position := crate.global_position
	var initial_distance := initial_position.distance_to(player_one.get_hold_position())
	manager._physics_process(1.0 / 60.0)
	_expect(crate.global_position.is_equal_approx(initial_position), "Holding must apply force without teleporting the body")
	for index in 20:
		await physics_frame
	var final_distance := crate.global_position.distance_to(player_one.get_hold_position())
	_expect(final_distance < initial_distance, "The bounded spring must pull the body toward the hold target")
	_expect(crate.linear_velocity.length() < 8.0, "The hold spring must keep a medium prop at a bounded practical speed")


func _test_lifecycle_releases() -> void:
	player_one.apply_knockdown(Vector3.ZERO)
	_expect(manager.get_grab_owner(crate) == 0, "Knockdown must release the held body")
	player_one.reset_for_match(Vector3.ZERO)
	_place_crate_in_reach()
	_expect(manager.request_grab(1, crate), "A recovered player must be able to grab again")
	player_one.set_eliminated(true)
	_expect(manager.get_grab_owner(crate) == 0, "Elimination must release the held body")
	player_one.reset_for_match(Vector3.ZERO)
	_place_crate_in_reach()
	_expect(manager.request_grab(1, crate), "A reset player must regain interaction")
	crate.freeze = true
	crate.global_position = Vector3(0.0, 0.4, -Tuning.GRAB_BREAK_DISTANCE - 0.2)
	crate.freeze = false
	manager._physics_process(1.0 / 60.0)
	_expect(manager.get_grab_owner(crate) == 0, "Excessive separation must break the hold")


func _test_disconnect_release() -> void:
	_place_crate_in_reach()
	_expect(manager.request_grab(2, crate), "The second player must grab after ownership is released")
	_expect(manager.unregister_player(2), "Disconnect cleanup must unregister the peer")
	_expect(manager.get_grab_owner(crate) == 0, "Disconnect cleanup must release the peer's body")
	_expect(not crate.has_meta("grab_owner_peer_id"), "Disconnect cleanup must clear body ownership metadata")


func _test_repeated_carry_motion() -> void:
	var obstacle := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	collision.shape = shape
	obstacle.add_child(collision)
	world.add_child(obstacle)
	for context in ["wall", "ramp", "player"]:
		obstacle.rotation = Vector3.ZERO
		obstacle.position = Vector3(0, 1.5, -1.7) if context == "wall" else Vector3(8, 1.5, 0)
		if context == "ramp":
			shape.size = Vector3(4, 0.3, 5)
			obstacle.position = Vector3(0, 0.7, -3)
			obstacle.rotation.x = 0.3
		else:
			shape.size = Vector3(4, 3, 0.3)
		for mass in [2.0, 12.0, 25.0]:
			manager.release_all()
			player_one.reset_for_match(Vector3.ZERO)
			player_two.reset_for_match(Vector3(0, 0, -1.4) if context == "player" else Vector3(7, 0, 0))
			player_one.set_camera_yaw(0)
			crate.mass = mass
			crate.freeze = true
			crate.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.65 if context == "ramp" else 0.4, -1))
			crate.linear_velocity = Vector3.ZERO
			crate.angular_velocity = Vector3.ZERO
			crate.freeze = false
			await physics_frame
			var acquisitions := 0
			var peak_speed := 0.0
			var peak_spin := 0.0
			var previous_position := crate.position
			var peak_step := 0.0
			var minimum_height := crate.position.y
			var minimum_z := crate.position.z
			for tick in 240:
				if tick % 30 == 0:
					if manager.get_held_body(1) != null:
						_expect(manager.toggle_grab(1) and not crate.get_collision_exceptions().has(player_one), "Repeated release restores collision near %s" % context)
					elif manager.request_nearest_grab(1):
						acquisitions += 1
					var held_position := crate.position
					if manager.get_held_body(1) != null:
						_expect(not manager.request_grab(2, crate), "Other player cannot steal the carried prop")
					_expect(crate.position == held_position, "Toggle/contending requests never teleport the prop")
				# Approach a dropped prop naturally instead of resetting its transform.
				var offset := crate.position - player_one.position
				player_one.set_camera_yaw(atan2(-offset.x, -offset.z))
				var movement := Vector2.ZERO
				if manager.get_held_body(1) != null:
					movement.y = -1 if tick % 60 < 30 else 1
				elif Vector2(offset.x, offset.z).length() > 0.9:
					movement.y = -1
				player_one.apply_movement_input(movement, false, false, false, 1.0 / 60.0)
				await physics_frame
				peak_speed = maxf(peak_speed, crate.linear_velocity.length())
				peak_spin = maxf(peak_spin, crate.angular_velocity.length())
				peak_step = maxf(peak_step, crate.position.distance_to(previous_position))
				minimum_height = minf(minimum_height, crate.position.y)
				minimum_z = minf(minimum_z, crate.position.z)
				previous_position = crate.position
			manager.release_all()
			print("CARRY_MOTION context=%s mass=%s acquisitions=%d speed=%.3f spin=%.3f step=%.3f" % [context, mass, acquisitions, peak_speed, peak_spin, peak_step])
			_expect(acquisitions >= 2, "Stress must actually reacquire near %s at mass %s" % [context, mass])
			_expect(peak_speed < 8.0 and peak_spin < 20.0 and peak_step < 0.3, "Repeated carry cannot explosively launch or teleport near %s" % context)
			_expect(minimum_height > 0.0 and (context != "wall" or minimum_z > -1.6), "Prop cannot tunnel through the floor or wall")
			_expect(not crate.has_meta("grab_owner_peer_id") and not crate.get_collision_exceptions().has(player_one), "Stress ends without stale ownership/exclusion")
	obstacle.free()
	player_one.reset_for_match(Vector3.ZERO)
	player_two.reset_for_match(Vector3(0.2, 0, 0))
	player_one.set_camera_yaw(0)
	crate.mass = 12.0


func _test_destroyed_prop_release() -> void:
	_place_crate_in_reach()
	_expect(manager.request_grab(1, crate), "Acquire the prop before destruction")
	var replacement := crate.duplicate() as RigidBody3D
	replacement.remove_meta("grab_owner_peer_id")
	crate.free()
	await physics_frame
	await physics_frame
	_expect(manager.get_held_body(1) == null, "Destroying the held prop leaves no stale held body")
	world.add_child(replacement)
	replacement.position = Vector3(0, 0.4, -1)
	_expect(manager.request_grab(1, replacement), "Holder can acquire a replacement after prop destruction")
	_expect(manager.release_grab(1) and not replacement.get_collision_exceptions().has(player_one), "Replacement releases with ordinary collision restored")
	replacement.free()


func _place_crate_in_reach() -> void:
	crate.freeze = true
	crate.global_position = Vector3(0.0, 0.4, -1.0)
	crate.linear_velocity = Vector3.ZERO
	crate.freeze = false


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
