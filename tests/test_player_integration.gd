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
	_test_visual_facing()
	_test_crouch()
	_test_carry_presentation()
	_test_jump_arc()
	_test_ramp_traversal()
	await _test_knockdown_recovery()
	await _test_default_scene_offline_input()
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
	var initial_yaw := player.get_camera_yaw()
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
	# Later movement, visual-facing, and ramp checks assume the initial world heading.
	player.set_camera_yaw(initial_yaw)


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

	var initial_yaw := player.get_camera_yaw()
	var yaw := 0.63
	player.set_camera_yaw(yaw)
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_settle_player()
	for index in 60:
		player.apply_movement_input(Vector2(0.0, -1.0), true, false, false, DELTA)
	# Independent trig expectation catches ignored/reversed yaw or a pivot-only reset.
	var expected_velocity := Vector3(-sin(yaw), 0.0, -cos(yaw)) * Tuning.SPRINT_SPEED
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	_expect(horizontal_velocity.distance_to(expected_velocity) < 0.05, "Sprint must follow an asymmetric camera heading at the configured speed")
	player.set_camera_yaw(initial_yaw)


func _test_visual_facing() -> void:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.visual.rotation = Vector3.ZERO
	_settle_player()
	for _index in 60:
		player.apply_movement_input(Vector2(0.0, -1.0), false, false, false, DELTA)
	var forward_facing := (player.visual.global_transform.basis * Vector3.FORWARD).normalized()
	_expect(forward_facing.dot(Vector3.FORWARD) > 0.95, "Moving forward must turn the character visual forward")

	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.visual.rotation = Vector3.ZERO
	_settle_player()
	for _index in 60:
		player.apply_movement_input(Vector2(-1.0, 0.0), false, false, false, DELTA)
	var left_facing := (player.visual.global_transform.basis * Vector3.FORWARD).normalized()
	_expect(left_facing.dot(Vector3.LEFT) > 0.95, "Moving left must turn the character visual left")


func _test_crouch() -> void:
	player.apply_movement_input(Vector2.ZERO, false, true, false, DELTA)
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	_expect(is_equal_approx(capsule.height, Tuning.CROUCHED_HEIGHT), "Crouch must set the 0.95 m capsule")
	_expect(is_equal_approx(player.get_node("Visual").scale.y, 0.72), "Crouch must visibly lower the character")
	player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	_expect(is_equal_approx(capsule.height, Tuning.STANDING_HEIGHT), "Releasing crouch must restore the 1.50 m capsule")


func _test_carry_presentation() -> void:
	player.reset_for_match(Vector3.ZERO)
	player.set_camera_yaw(0.0)
	player.carrying_medium = true
	player.velocity = Vector3.ZERO
	player._process(DELTA)
	_expect(player.character.current_clip == "holding_idle", "A grounded stationary holder must use the holding idle pose")
	player.velocity = Vector3(0.0, 0.0, -1.0)
	player._process(DELTA)
	_expect(player.character.current_clip == "holding_walk", "A grounded moving holder must use the holding walk pose")
	player.apply_movement_input(Vector2.ZERO, false, true, false, DELTA)
	player._process(DELTA)
	_expect(player.character.current_clip.begins_with("holding_") and player.is_crouched(), "Crouch while carrying must keep the readable hold and lowered capsule")
	player.position = Vector3(0.0, 5.0, 0.0)
	player.velocity = Vector3(0.0, 1.0, 0.0)
	player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA, 0)
	player._process(DELTA)
	_expect(player.character.current_clip == "jump_takeoff", "Airborne takeoff must override the holding pose")
	player.velocity.y = -1.0
	player._process(DELTA)
	_expect(player.character.current_clip == "falling", "Falling must override the holding pose")
	player.carrying_medium = false
	player.reset_for_match(Vector3.ZERO)
	player.velocity = Vector3.ZERO
	for _tick in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	player._process(DELTA)
	_expect(player.character.current_clip == "idle", "Release/rematch must resume ordinary locomotion")


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
	_expect(player.character.current_clip == "get_up", "Grounded recovery must play the get-up presentation before locomotion")
	# Earthquake can knock a living player off an elevated route. Expiry must
	# restore the visible actor even when the capsule has not landed yet.
	player.reset_for_match(Vector3(0.0, 40.0, 0.0))
	player.apply_knockdown(Vector3(3.0, 2.0, -1.0))
	for index in 90:
		await physics_frame
		player.apply_movement_input(Vector2.RIGHT, true, false, false, DELTA)
	_expect(not player.is_on_floor() and not player.is_knocked_down(), "Airborne knockdown must expire before landing")
	_expect(player.visual.visible and player.ragdoll_body_count() == 0, "Airborne recovery must not leave a movable invisible capsule and abandoned ragdoll")
	var recovered_position := player.position
	for index in 120:
		await physics_frame
		player.apply_movement_input(Vector2.RIGHT, true, false, true, DELTA)
	_expect(player.position.x > recovered_position.x + 2.0 and player.visual.visible and player.ragdoll_body_count() == 0, "Running and landing/jumping after airborne recovery must retain the visible actor")


func _test_default_scene_offline_input() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var playable_player := main.get_node("Player") as PartyPlayer
	_expect(main.get_tree().get_nodes_in_group("landmark").size() >= 4, "Toy Town must expose at least three distinct landmarks plus the pocket park")
	_expect(main.get_tree().get_nodes_in_group("shelter").size() >= 3, "Toy Town must provide accessible indoor and covered shelter")
	_expect(main.get_tree().get_nodes_in_group("elevation_route").size() >= 4, "Toy Town must provide four routes to elevation")
	_expect(main.get_tree().get_nodes_in_group("map_prop").size() >= 10, "Toy Town must include readable trees, cars, fences, bench, and sign props")
	_expect(playable_player.character.get_skeleton_bone_count() == 18, "Playable character must instantiate the canonical skeleton")
	_expect(playable_player.character.play_clip("run"), "Playable character must play a required locomotion clip")
	var lobby_event := InputEventAction.new()
	lobby_event.action = "toggle_lobby"
	lobby_event.pressed = true
	main._unhandled_input(lobby_event)
	_expect((main.get_node("Interface/LobbyPanel") as Panel).visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Opening the lobby must expose its mouse controls")
	main._unhandled_input(lobby_event)
	_expect(not (main.get_node("Interface/LobbyPanel") as Panel).visible, "Closing the lobby must hide its controls")
	if DisplayServer.get_name() != "headless":
		_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Closing the lobby must restore camera input")
	var start := playable_player.global_position
	main._process(0.0)
	_expect(main.gameplay_hud.get_presented_context_action() == "GRAB — CARRY SLOWS YOU 25%", "An in-range prop must show acquisition plus the carry tradeoff")
	Input.action_press("grab")
	playable_player._physics_process(DELTA)
	Input.action_release("grab")
	_expect(is_instance_valid((main.get_node("GrabManager") as GrabManager).get_held_body(1)), "Default-scene offline grab input must reach GrabManager")
	main._process(0.0)
	_expect(main.gameplay_hud.get_presented_context_action() == "RELEASE TO RESTORE SPEED", "A held prop must replace acquisition with release/restored speed")
	Input.action_press("move_forward")
	for _frame in 30:
		await physics_frame
	Input.action_release("move_forward")
	_expect(not main.is_network_session(), "Default scene must launch in offline mode")
	_expect(playable_player.accepts_local_input(), "Default-scene player must accept local input")
	_expect(playable_player.global_position.distance_to(start) > 0.5, "Default-scene offline input must move the player")
	var flood := main.get_node("Flood") as Flood
	(main.get_node("DisasterDirector") as DisasterDirector).cleanup()
	flood.set_process(false)
	playable_player.set_physics_process(false)
	playable_player.apply_movement_input(Vector2.ZERO, false, true, false, 0.0)
	_expect(flood.start_warning(), "Default scene must start a representative Flood for feedback validation")
	flood.tick(flood.warning_duration)
	flood._set_water_level(1.0)
	flood.phase = Flood.Phase.HOLDING
	flood.tick(1.0)
	main._process(0.0)
	_expect(main.gameplay_hud.personal_danger.visible and "HOLD BREATH" in main.gameplay_hud.danger_status.text, "Head submersion must immediately show breathing-grace feedback")
	flood.tick(1.0)
	main._process(0.0)
	_expect(main.gameplay_hud.danger_status.text == "HOLD BREATH — 0.0 s", "The exact breathing-grace boundary must not announce damage early")
	flood.tick(0.5)
	main._process(0.0)
	_expect((main.get_node("MatchManager") as MatchManager).get_health(1) < 100.0, "Flood must reduce HP after the breathing grace expires")
	_expect(main.gameplay_hud.personal_danger.visible and main.gameplay_hud.danger_status.text == "DROWNING — -12 HP/s", "Active Flood damage must replace breathing copy with the authoritative damage rate")
	for state: int in [MatchManager.MatchState.LOBBY, MatchManager.MatchState.RESULTS]:
		main.match_manager.state = state
		main._update_flood_feedback(1)
		_expect(not main.gameplay_hud.personal_danger.visible, "Non-active match states must suppress personal danger despite lingering water")
	main.match_manager.state = MatchManager.MatchState.ACTIVE
	main.get_node("Interface/LobbyPanel").show()
	main._update_flood_feedback(1)
	_expect(not main.gameplay_hud.personal_danger.visible, "The open lobby must suppress personal danger")
	main.get_node("Interface/LobbyPanel").hide()
	main.spectator_controller.active = true
	main._update_flood_feedback(1)
	_expect(not main.gameplay_hud.personal_danger.visible, "Spectators must not inherit the submerged player's danger")
	main.spectator_controller.active = false
	main._update_flood_feedback(1)
	_expect(main.gameplay_hud.personal_danger.visible, "Returning to active local play must restore current exposure")
	playable_player.position.y = 5.0
	flood.tick(0.1)
	main._update_flood_feedback(1)
	_expect(not main.gameplay_hud.personal_danger.visible and main.gameplay_hud.danger_status.text.is_empty(), "Surfacing onto dry ground must clear stale personal danger")
	_test_electrified_flood_feedback(main, playable_player, flood)
	main.queue_free()
	await process_frame


func _test_electrified_flood_feedback(main: Node, local_player: PartyPlayer, flood: Flood) -> void:
	var hud := main.gameplay_hud as GameplayHud
	# Shallow contact (only 2 cm above feet), breathing grace, and existing drowning.
	for entry: Array in [[0.12, 0.0, 25, "IN FLOODWATER"], [2.0, 0.5, 25, "HOLD BREATH"], [2.0, 2.5, 37, "DROWNING"]]:
		flood.cleanup()
		main.match_manager.prepare_lobby()
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		local_player.position = Vector3(0, 0.1, 0)
		flood.start_warning()
		flood.tick(flood.warning_duration)
		flood.phase = Flood.Phase.HOLDING
		flood._set_water_level(entry[0])
		flood.tick(entry[1])
		_expect(flood.electrify_at(Vector3(0, entry[0], 0)), "Flood must electrify for the combined feedback fixture")
		var before := main.match_manager.get_health(1) as float
		flood.tick(0.1)
		main._update_flood_feedback(1)
		_expect(is_equal_approx(main.match_manager.get_health(1), before - entry[2] * 0.1), "Combined electric/drowning HP loss must match independently expected damage")
		_expect(hud.danger_status.text == "ELECTRIFIED WATER — -%d HP/s" % entry[2] and hud.danger_action.text == "LEAVE THE WATER", "Electrical exposure must override wading/grace/drowning instructions and include all active damage")
		flood.electrified_remaining = 0.0
		main._update_flood_feedback(1)
		_expect(hud.danger_status.text.begins_with(entry[3]), "Electrical expiry must restore the correct remaining Flood exposure")
		local_player.position.y = 3.0
		main._update_flood_feedback(1)
		_expect(not hud.personal_danger.visible, "Leaving water must clear personal danger immediately")
	flood.cleanup()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
