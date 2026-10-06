extends SceneTree

const DELTA := 1.0 / 60.0
const Tuning = preload("res://game/player_tuning.gd")

var failures: Array[String] = []
var checks := 0
var player: PartyPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_test_world()
	await physics_frame
	player.set_physics_process(false)
	_settle_player()
	_test_mouse_capture()
	_test_walk_and_sprint()
	_test_crouch()
	_test_jump_arc()
	_test_ramp_traversal()
	await _test_knockdown_recovery()
	if failures.is_empty():
		print("PLAYER_INTEGRATION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build_test_world() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 0.2, 40.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)
	world.add_child(floor)
	var ramp := StaticBody3D.new()
	ramp.position = Vector3(10.0, 0.83, 3.25)
	ramp.rotation.x = deg_to_rad(11.5)
	var ramp_collision := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(4.0, 0.35, 10.0)
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)
	world.add_child(ramp)
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.position = Vector3.ZERO


func _test_mouse_capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var initial_rotation := player.camera_pivot.rotation
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	player._unhandled_input(escape)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape must release the captured cursor")

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, 40.0)
	player._unhandled_input(motion)
	_expect(player.camera_pivot.rotation.is_equal_approx(initial_rotation), "Visible cursor motion must not rotate the camera")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	if DisplayServer.get_name() != "headless":
		_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Left click must recapture the cursor")
		player._unhandled_input(motion)
		_expect(not player.camera_pivot.rotation.is_equal_approx(initial_rotation), "Captured cursor motion must rotate the camera")


func _settle_player() -> void:
	for index in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)


func _test_walk_and_sprint() -> void:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_settle_player()
	for index in 60:
		player.apply_movement_input(Vector2(0.0, -1.0), false, false, false, DELTA)
	var walk_distance := -player.position.z
	_expect(walk_distance > 3.5 and walk_distance < 4.6, "Walk distance after one second must reflect acceleration toward 4.5 m/s")

	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_settle_player()
	for index in 60:
		player.apply_movement_input(Vector2(0.0, -1.0), true, false, false, DELTA)
	var sprint_distance := -player.position.z
	_expect(sprint_distance > walk_distance + 1.5, "Sprint must travel materially farther than walk over one second")
	_expect(player.velocity.z <= -6.45, "Sprint must reach the 6.5 m/s target")


func _test_crouch() -> void:
	player.apply_movement_input(Vector2.ZERO, false, true, false, DELTA)
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	_expect(is_equal_approx(capsule.height, Tuning.CROUCHED_HEIGHT), "Crouch must set the 0.95 m capsule")
	_expect(is_equal_approx(player.get_node("Visual").scale.y, 0.72), "Crouch must visibly lower the character")
	player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	_expect(is_equal_approx(capsule.height, Tuning.STANDING_HEIGHT), "Releasing crouch must restore the 1.50 m capsule")


func _test_jump_arc() -> void:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_settle_player()
	player.apply_movement_input(Vector2.ZERO, false, false, true, DELTA)
	_expect(player.velocity.y > 7.3, "Jump takeoff must use the configured velocity")
	var maximum_height := player.position.y
	for index in 120:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		maximum_height = maxf(maximum_height, player.position.y)
	_expect(maximum_height > 1.25 and maximum_height < 1.45, "Jump apex must stay near the 1.35 m target")
	_expect(player.is_on_floor(), "Player must land within two seconds")


func _test_ramp_traversal() -> void:
	player.position = Vector3(10.0, 0.0, 8.7)
	player.velocity = Vector3.ZERO
	_settle_player()
	var maximum_height := player.position.y
	for index in 150:
		player.apply_movement_input(Vector2(0.0, -1.0), false, false, false, DELTA)
		maximum_height = maxf(maximum_height, player.position.y)
	_expect(maximum_height > 1.7, "Controller must ascend the representative map ramp (max y %.3f)" % maximum_height)
	_expect(player.position.z < 2.0, "Controller must traverse beyond the lower half of the ramp (z %.3f)" % player.position.z)


func _test_knockdown_recovery() -> void:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_settle_player()
	player.apply_knockdown(Vector3(4.0, 1.0, 0.0))
	_expect(player.is_knocked_down(), "Impact must enter knockdown")
	_expect(player.ragdoll_body_count() == 11, "Knockdown must create an 8–12 body cosmetic ragdoll")
	_expect(player.ragdoll_joint_count() == 10, "Ragdoll bodies must be connected by 10 constrained joints")
	_expect(is_equal_approx(player.ragdoll_total_mass(), 55.0), "Ragdoll mass distribution must total the 55 kg reference mass")
	_expect(player.ragdoll_adjacent_exclusions_are_configured(), "Adjacent ragdoll bodies must exclude mutual collision")
	_expect(not player.get_node("Visual").visible, "Knockdown must hide the upright visual")
	for index in 100:
		player.apply_movement_input(Vector2(0.0, -1.0), true, false, false, DELTA)
		await physics_frame
		if index == 30:
			_expect(player.ragdoll_maximum_body_separation() < 3.0, "Ragdoll joints must not explosively separate")
	_expect(not player.is_knocked_down(), "Knockdown must recover after the bounded duration")
	_expect(player.ragdoll_body_count() == 0, "Recovery must clean up the cosmetic ragdoll")
	_expect(player.get_node("Visual").visible, "Recovery must restore the upright visual")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
