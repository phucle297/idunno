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
	_test_range_and_contention()
	await _test_bounded_spring()
	_test_lifecycle_releases()
	_test_disconnect_release()
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
	floor_shape.size = Vector3(20.0, 0.2, 20.0)
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


func _place_crate_in_reach() -> void:
	crate.freeze = true
	crate.global_position = Vector3(0.0, 0.4, -1.0)
	crate.linear_velocity = Vector3.ZERO
	crate.freeze = false


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
