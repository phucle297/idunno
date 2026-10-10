extends SceneTree

# Task 3.4.1 bounded shove prototype coverage: spam, opposing attackers,
# simultaneous requests, angle/range/cover boundaries, stationary and moving
# targets, stairs/roof edges, death/spectator and rematch, plus the promise
# that protection covers only shoves and never disasters.

const ManagerScript = preload("res://game/match_manager.gd")
const ShoveScript = preload("res://game/shove_manager.gd")
const DELTA := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0
var world: Node3D
var manager: ManagerScript
var shove: ShoveScript
var players: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_world()
	await physics_frame
	await _test_basic_effect()
	await _test_spam()
	await _test_range_angle_cover()
	await _test_opposing_and_opportunity()
	await _test_moving_target_clamp()
	await _test_edges_no_launch()
	await _test_state_and_death_gates()
	await _test_recovery_protection()
	await _test_protection_scope()
	await _test_rematch_reset()
	if failures.is_empty():
		print("SHOVE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build_world() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_static_box(Vector3(80.0, 0.2, 80.0), Vector3(0.0, -0.1, 0.0))
	# Cover wall for the line-of-sight boundary and a raised roof edge.
	_add_static_box(Vector3(4.0, 3.0, 0.3), Vector3(20.0, 1.5, 0.0))
	_add_static_box(Vector3(4.0, 1.0, 4.0), Vector3(-20.0, 0.5, 0.0))
	# Representative stair/ramp slab.
	var ramp := StaticBody3D.new()
	var ramp_collision := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(4.0, 0.3, 5.0)
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)
	world.add_child(ramp)
	ramp.position = Vector3(0.0, 0.7, -8.0)
	ramp.rotation.x = 0.3
	manager = ManagerScript.new()
	world.add_child(manager)
	shove = ShoveScript.new()
	world.add_child(shove)
	shove.configure(manager)
	for peer_id in [1, 2, 3]:
		var player := _add_player(Vector3(0.0, 0.05, peer_id * 3.0))
		players[peer_id] = player
		_expect(manager.register_player(peer_id, player.name), "Player %d must register" % peer_id)
		_expect(manager.set_player_ready(peer_id, true), "Player %d must ready up" % peer_id)
		_expect(shove.register_player(peer_id, player), "Player %d must register with the shove boundary" % peer_id)
	_expect(manager.start_match(), "Shove test match must start")


func _add_static_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = position
	return body


func _add_player(spawn_position: Vector3) -> PartyPlayer:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	world.add_child(player)
	player.global_position = spawn_position
	player.set_physics_process(false)
	return player


func _place(player: PartyPlayer, position: Vector3, face: Vector3) -> void:
	player.reset_for_match(position)
	var offset := face - position
	player.set_camera_yaw(atan2(-offset.x, -offset.z))
	for tick in 60:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
		if tick > 4 and player.is_on_floor():
			break


func _setup_open_pair() -> void:
	await _place(players[1], Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.05, -1.5))
	await _place(players[2], Vector3(0.0, 0.05, -1.5), Vector3.ZERO)
	await _place(players[3], Vector3(30.0, 0.05, 0.0), Vector3(30.0, 0.05, -1.0))
	shove.reset_state()


func _test_basic_effect() -> void:
	await _setup_open_pair()
	_expect(shove.request_shove(1), "A grounded shover must shove an eligible in-range target")
	_expect(players[2].velocity.z <= -5.9 and absf(players[2].velocity.y) < 0.01, "The accepted shove applies one bounded horizontal impulse")
	_expect(is_equal_approx(manager.get_health(2), 100.0) and not players[2].is_knocked_down(), "The shove deals no HP damage and no routine knockdown")
	_expect(not shove.request_shove(1), "The shover cooldown must reject an immediate second shove")


func _test_spam() -> void:
	await _setup_open_pair()
	var accepted := 0
	for attempt in 10:
		if shove.request_shove(1):
			accepted += 1
	_expect(accepted == 1, "Request spam must accept exactly one shove per cooldown window (accepted %d)" % accepted)
	_expect(players[2].velocity.length() <= 8.01, "Spam must not stack shove impulses")


func _test_range_angle_cover() -> void:
	await _setup_open_pair()
	await _place(players[2], Vector3(0.0, 0.05, -2.4), Vector3.ZERO)
	_expect(not shove.request_shove(1), "A target beyond 2.2m must be rejected")
	await _place(players[2], Vector3(0.0, 0.05, -2.1), Vector3.ZERO)
	_expect(shove.request_shove(1), "A target inside 2.2m must be accepted")
	await _setup_open_pair()
	await _place(players[2], Vector3(0.0, 0.05, 1.5), Vector3.ZERO)
	_expect(not shove.request_shove(1), "A target behind the shover must be rejected")
	var outside_cone := Vector3(sin(deg_to_rad(61.0)), 0.05, -cos(deg_to_rad(61.0))) * 1.5
	await _place(players[2], outside_cone, Vector3.ZERO)
	_expect(not shove.request_shove(1), "A target outside the forward cone must be rejected")
	shove.reset_state()
	# Within range but separated by the cover wall (z=0 slab).
	await _place(players[1], Vector3(20.0, 0.05, 1.0), Vector3(20.0, 0.05, -1.0))
	await _place(players[2], Vector3(20.0, 0.05, -1.0), Vector3.ZERO)
	shove.reset_state()
	_expect(not shove.request_shove(1), "A target behind cover must not be shoved through it")


func _test_opposing_and_opportunity() -> void:
	await _setup_open_pair()
	await _place(players[3], Vector3(0.0, 0.05, -3.0), Vector3(0.0, 0.05, -1.5))
	shove.reset_state()
	_expect(shove.request_shove(1), "First attacker's shove is accepted")
	_expect(not shove.request_shove(3), "A simultaneous second attacker must be rejected by protection")
	var start: Vector3 = players[2].position
	for tick in 18:
		players[2].apply_movement_input(Vector2(1, 0), false, false, false, DELTA)
		await physics_frame
	_expect(players[2].position.distance_to(start) > 0.3, "The victim must retain a real movement window between accepted shoves")
	await create_timer(2.6).timeout
	_expect(shove.is_protected(2) == false, "Shove protection must expire")
	# Re-place the victim squarely in both attackers' reach so the chain-lock
	# rejection can only be the protection window, never range/cone.
	await _place(players[2], Vector3(0.0, 0.05, -1.5), Vector3.ZERO)
	_expect(shove.request_shove(3), "After the protection window a second attacker may shove")
	_expect(not shove.request_shove(1), "Alternating attackers cannot chain-lock the victim")


func _test_moving_target_clamp() -> void:
	await _setup_open_pair()
	players[2].velocity = Vector3(0.0, 0.0, -6.5)
	_expect(shove.request_shove(1), "A moving target remains shovable")
	_expect(is_equal_approx(players[2].velocity.length(), 8.0), "Sprint stacking must clamp to the bounded horizontal result (got %.2f)" % players[2].velocity.length())
	_expect(absf(players[2].velocity.y) < 0.01, "A shove never adds vertical velocity")


func _test_edges_no_launch() -> void:
	await _setup_open_pair()
	await _place(players[1], Vector3(-20.0, 1.05, 1.5), Vector3(-20.0, 1.05, -0.5))
	await _place(players[2], Vector3(-20.0, 1.05, -0.5), Vector3.ZERO)
	shove.reset_state()
	_expect(shove.request_shove(1), "A roof-edge target is shovable")
	_expect(absf(players[2].velocity.y) < 0.01 and players[2].velocity.length() <= 8.01, "A roof-edge shove must not launch vertically")
	await _setup_open_pair()
	await _place(players[1], Vector3(0.0, 1.35, -6.5), Vector3(0.0, 1.15, -8.0))
	await _place(players[2], Vector3(0.0, 1.15, -8.0), Vector3.ZERO)
	shove.reset_state()
	_expect(shove.request_shove(1), "A stairs/ramp target is shovable")
	_expect(absf(players[2].velocity.y) < 0.01 and players[2].velocity.length() <= 8.01, "A stairs/ramp shove must not launch vertically")


func _test_state_and_death_gates() -> void:
	await _setup_open_pair()
	players[2].set_eliminated(true)
	_expect(not shove.request_shove(1), "An eliminated victim cannot be shoved")
	players[2].set_eliminated(false)
	shove.reset_state()
	players[1].set_eliminated(true)
	_expect(not shove.request_shove(1), "An eliminated/spectating sender cannot shove")
	players[1].set_eliminated(false)
	shove.reset_state()
	players[1].position += Vector3(0.0, 1.5, 0.0)
	players[1].velocity = Vector3.ZERO
	for tick in 2:
		players[1].apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(not players[1].is_on_floor() and not shove.request_shove(1), "An airborne sender cannot shove")
	shove.reset_state()
	manager.prepare_lobby()
	_expect(not shove.request_shove(1), "Shoves require a live active match")
	for peer_id in [1, 2, 3]:
		manager.set_player_ready(peer_id, true)
	_expect(manager.start_match(), "Shove test match must restart")


func _test_recovery_protection() -> void:
	await _setup_open_pair()
	players[2].apply_knockdown(Vector3.ZERO)
	_expect(players[2].is_knocked_down(), "Knockdown must be active for the recovery case")
	for tick in 100:
		players[2].apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(not players[2].is_knocked_down(), "The victim must recover from knockdown")
	_expect(shove.is_protected(2), "Knockdown recovery must grant the shove protection window")
	_expect(not shove.request_shove(1), "A recovering player is protected from immediate re-shove")
	await create_timer(2.6).timeout
	_expect(not shove.is_protected(2) and shove.request_shove(1), "After the recovery protection window the victim is shovable again")


func _test_protection_scope() -> void:
	await _setup_open_pair()
	_expect(shove.request_shove(1), "Accepted shove grants the victim protection")
	_expect(shove.is_protected(2), "Protection window must be observable")
	var events: Array[Dictionary] = [{"peer_id": 2, "amount": 10.0, "cause": "Test"}]
	var health_before := manager.get_health(2)
	_expect(manager.apply_damage_batch(events), "Disaster damage must still apply")
	_expect(is_equal_approx(manager.get_health(2), health_before - 10.0), "Shove protection must not block disaster damage")
	players[2].apply_knockdown(Vector3(4.0, 1.0, 0.0))
	_expect(players[2].is_knocked_down(), "Shove protection must not disable disaster knockdown")


func _test_rematch_reset() -> void:
	await _setup_open_pair()
	_expect(shove.request_shove(1), "Pre-reset shove is accepted")
	_expect(shove.is_protected(2), "Pre-reset protection exists")
	shove.reset_state()
	_expect(not shove.is_protected(2), "Match reset must clear protection state")
	_expect(shove.request_shove(1), "Match reset must clear cooldown state for the next round")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
