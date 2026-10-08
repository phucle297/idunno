extends SceneTree

const DELTA := 1.0 / 60.0
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	collision.shape = box
	collision.position.y = -0.1
	floor.add_child(collision)
	world.add_child(floor)
	var player: PartyPlayer = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	expect(player.has_method("predict_movement_input") and player.has_method("reconcile_movement"), "Local movement must support bounded prediction and acknowledged reconciliation")
	if not failures.is_empty():
		finish(world)
		return
	for _step in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	player.velocity = Vector3(4.5, 0, 0)
	player.set_camera_yaw(0)
	# Delayed ack covers six of ten inputs; only the last four may replay.
	for sequence in range(1, 11):
		player.predict_movement_input(sequence, Vector2.RIGHT, false, false, false, DELTA)
	player.set_camera_yaw(0.73)
	player.reconcile_movement(Vector3(2.1, 0, -0.4), Vector3(4.5, 0, 0), 0.3, false, 6, Vector3(0.12, 0, 1), false)
	expect(player.position.is_equal_approx(Vector3(2.4, 0, -0.4)), "Reconciliation must apply server correction and replay exactly four unacknowledged ticks")
	expect(player._prediction_inputs.size() == 4, "Acknowledged inputs must leave the replay queue")
	expect(is_equal_approx(player.get_camera_yaw(), 0.73) and is_equal_approx(player.camera_pivot.rotation.y, 0.73), "Replay must preserve local camera heading")
	player.reconcile_movement(Vector3(99, 0, 99), Vector3.ZERO, 0, false, 5, Vector3.ZERO, false)
	expect(player.position.is_equal_approx(Vector3(2.4, 0, -0.4)), "Stale acknowledgement must not rewind prediction")
	player.reset_for_match(Vector3.ZERO)
	player.set_camera_yaw(0)
	for sequence in range(1, 11):
		player.predict_movement_input(sequence, Vector2.ZERO, false, false, sequence == 7, DELTA)
	# Client is already airborne; authoritative floor contact must seed the replayed jump.
	player.reconcile_movement(Vector3.ZERO, Vector3.ZERO, 0, false, 6, Vector3(0.12, 0, 1), false)
	var expected_jump_velocity := sqrt(2.0 * 20.0 * 1.35) - 3.0 * 20.0 * DELTA
	expect(is_equal_approx(player.velocity.y, expected_jump_velocity) and player.position.y > 0.4, "Pending jump must replay from authoritative grounded state")
	player.reconcile_movement(Vector3(0, 0.12247449, 0), Vector3(0, sqrt(54.0), 0), 0, false, 7, Vector3.ZERO, false)
	expect(is_equal_approx(player.velocity.y, expected_jump_velocity), "Acknowledged jump must not fire a second time")
	player.reconcile_movement(Vector3(1, 1, 2), Vector3(3, 2, -1), 0.2, true, 8, Vector3.ZERO, false)
	expect(player._prediction_inputs.is_empty() and player.position == Vector3(1, 1, 2) and player.velocity == Vector3(3, 2, -1), "Authoritative knockdown must discard walking prediction and preserve the impulse")
	player.predict_movement_input(11, Vector2.RIGHT, true, false, true, DELTA)
	expect(player._prediction_inputs.is_empty() and player.velocity == Vector3(3, 2, -1), "Walking prediction cannot override knockdown")
	player.reset_for_match(Vector3.ZERO)
	for sequence in range(1, 81):
		player.predict_movement_input(sequence, Vector2.RIGHT, false, false, false, DELTA)
	expect(player._prediction_inputs.size() == 60, "Replay history must be bounded to sixty physics ticks")
	player.reconcile_movement(Vector3(2, 0, 3), Vector3.ZERO, 0, false, 1, Vector3.ZERO, false)
	expect(player._prediction_inputs.is_empty() and player.position == Vector3(2, 0, 3), "History overflow must snap to authority rather than replay an incomplete prefix")
	player.predict_movement_input(81, Vector2.RIGHT, false, false, false, DELTA)
	player.set_eliminated(true)
	expect(player._prediction_inputs.is_empty(), "Elimination must clear prediction history")
	player.reset_for_match(Vector3(0, 0, 1))
	expect(player._prediction_inputs.is_empty() and player._last_movement_ack == -1, "Rematch must reset prediction and acknowledgement state")
	finish(world)

func finish(world: Node) -> void:
	world.queue_free()
	if failures.is_empty():
		print("NETWORK_PREDICTION_OK checks=%d" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
