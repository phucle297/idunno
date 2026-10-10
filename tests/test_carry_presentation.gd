extends SceneTree

const DELTA := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0
var capture_dir := ""
var review_size := Vector2i(1280, 720)
var review_camera: Camera3D
var review_player: PartyPlayer
var review_crate: RigidBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
		elif argument.begins_with("--review-size="):
			var size_text := argument.trim_prefix("--review-size=")
			var separator := size_text.find("x")
			if separator > 0:
				review_size = Vector2i(size_text.left(separator).to_int(), size_text.substr(separator + 1).to_int())
	root.size = review_size

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	var player := main.get_node("Player") as PartyPlayer
	review_player = player
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	player.set_camera_yaw(0.0)
	player.reset_for_match(Vector3.ZERO)
	for _tick in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	var grab_manager := main.get_node("GrabManager") as GrabManager
	var crate := get_first_node_in_group("grabbable") as RigidBody3D
	_expect(is_instance_valid(crate), "Carry presentation fixture needs a real grabbable prop")
	if not is_instance_valid(crate):
		_finish()
		return
	review_crate = crate
	crate.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	for candidate: Node in get_nodes_in_group("grabbable"):
		var extra_body := candidate as RigidBody3D
		if extra_body == crate:
			continue
		extra_body.visible = false
		extra_body.freeze = true
		extra_body.collision_layer = 0
		extra_body.collision_mask = 0
		extra_body.remove_from_group("grabbable")
	crate.freeze = true
	crate.global_position = player.get_hold_position()
	crate.linear_velocity = Vector3.ZERO
	crate.angular_velocity = Vector3.ZERO
	crate.freeze = false
	_expect(grab_manager.request_grab(1, crate) and player.carrying_medium, "Fixture must acquire an actual medium crate")

	var camera := Camera3D.new()
	main.add_child(camera)
	review_camera = camera
	_frame_review("carry-idle")
	camera.make_current()
	player.visual.rotation = Vector3.ZERO
	main._update_context_prompt(1)
	_expect(main.gameplay_hud.get_presented_context_action() == "RELEASE TO RESTORE SPEED", "Held state must show release/restored speed")
	player.velocity = Vector3.ZERO
	player._process(DELTA)
	_expect(player.character.current_clip == "holding_idle", "Held idle state must use holding_idle")
	if is_instance_valid(player.character._animation_player):
		player.character._animation_player.seek(0.0, true)
		player.character._animation_player.pause()
	var left_arm := player.character.get_node("LeftArm") as Node3D
	var right_arm := player.character.get_node("RightArm") as Node3D
	_expect(left_arm.rotation.x > 0.8 and right_arm.rotation.x > 0.8 and absf(left_arm.rotation.z + right_arm.rotation.z) < 0.02, "Both arms must form the forward converging holding pose")
	await _capture("carry-idle")

	player.velocity = Vector3(0.0, 0.0, -1.0)
	player._process(DELTA)
	_expect(player.character.current_clip == "holding_walk", "Held walking state must use holding_walk")
	if is_instance_valid(player.character._animation_player):
		player.character._animation_player.seek(0.4, true)
		player.character._animation_player.pause()
	var left_leg := player.character.get_node("LeftLeg") as Node3D
	var right_leg := player.character.get_node("RightLeg") as Node3D
	_expect(absf(left_leg.rotation.x - right_leg.rotation.x) > 0.5, "Holding walk must retain a readable leg swing")
	await _capture("carry-walk")

	player.apply_movement_input(Vector2.ZERO, false, true, false, DELTA)
	player._process(DELTA)
	_expect(player.character.current_clip.begins_with("holding_") and player.is_crouched(), "Crouched carry must keep the holding presentation")
	if is_instance_valid(player.character._animation_player):
		player.character._animation_player.seek(0.0, true)
		player.character._animation_player.pause()
	await _capture("carry-crouch")

	player.position = Vector3(0.0, 4.0, 0.0)
	player.velocity = Vector3(0.0, 1.0, 0.0)
	player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA, 0)
	player._process(DELTA)
	_expect(player.character.current_clip == "jump_takeoff", "Airborne carry must use the takeoff/fall presentation")
	crate.freeze = true
	crate.global_position = player.get_hold_position()
	if is_instance_valid(player.character._animation_player):
		player.character._animation_player.seek(0.05, true)
		player.character._animation_player.pause()
	await _capture("carry-airborne")
	crate.freeze = false

	grab_manager.release_grab(1)
	player.carrying_medium = false
	player.reset_for_match(Vector3.ZERO)
	player.set_camera_yaw(0.0)
	for _tick in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	crate.freeze = true
	crate.global_position = player.global_position + Vector3(0.0, 0.3, -0.9)
	crate.linear_velocity = Vector3.ZERO
	crate.angular_velocity = Vector3.ZERO
	crate.freeze = false
	main._update_context_prompt(1)
	_expect(main.gameplay_hud.get_presented_context_action() == "GRAB — CARRY SLOWS YOU 25%", "Released state must show acquisition and the carry tradeoff")
	player._process(DELTA)
	_expect(player.character.current_clip == "idle", "Release must resume ordinary idle presentation")
	if is_instance_valid(player.character._animation_player):
		player.character._animation_player.seek(0.5, true)
		player.character._animation_player.pause()
	await _capture("release")

	player.apply_knockdown(Vector3(1.0, 0.0, 0.0))
	_expect(player.is_knocked_down() and not player.visual.visible, "Knockdown must override carrying and hide the upright visual")
	for _tick in 120:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(not player.is_knocked_down() and player.visual.visible, "Recovery must restore the visible actor")
	_expect(player.character.current_clip == "get_up", "Recovery must show get_up before locomotion resumes")
	if is_instance_valid(player.character._animation_player):
		# get_up limb-swing peaks at 0.0/0.5/1.0s; 0.5s is the readable mid pose.
		player.character._animation_player.seek(0.5, true)
		player.character._animation_player.pause()
	var recovery_arm := player.character.get_node("LeftArm") as Node3D
	_expect(recovery_arm.rotation.x < -0.5, "Recovery cue must hold a readable limb swing at the review frame")
	await _capture("knockdown-recovery")

	# Shove cue review: bounded forward arm thrust at gameplay distance with
	# hazard warnings present, and the cooldown pill clear of them.
	var shove_manager := main.get_node("ShoveManager") as ShoveManager
	var victim := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	victim.name = "ShoveVictim"
	main.add_child(victim)
	victim.set_physics_process(false)
	victim.set_process(false)
	victim.set_process_unhandled_input(false)
	victim.set_camera_yaw(0.0)
	if is_instance_valid(review_crate):
		review_crate.global_position = Vector3(10.0, 0.3, 0.0)
	player.reset_for_match(Vector3.ZERO)
	player.set_camera_yaw(0.0)
	victim.reset_for_match(Vector3(0.9, 0.0, -1.2))
	for _tick in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		victim.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	main.match_manager.state = MatchManager.MatchState.LOBBY
	main.match_manager.register_player(2, "Victim")
	main.match_manager.set_player_ready(1, true)
	main.match_manager.set_player_ready(2, true)
	_expect(main.match_manager.start_match(), "Shove cue review needs a live active match")
	player.configure_shoving(shove_manager)
	victim.configure_shoving(shove_manager)
	_expect(shove_manager.register_player(1, player) and shove_manager.register_player(2, victim), "Shove review fixture must register both players")
	player.set_process(true)
	_expect(shove_manager.request_shove(1), "Shove review fixture must accept a bounded in-range shove")
	for _cue_frame in 3:
		await main.get_tree().process_frame
	_expect(player.character.current_clip == "shove", "Accepted shove must play the dedicated shove clip")
	player.set_process(false)
	# Drive the victim's knockback a few ticks with the shover frozen in the
	# thrust pose so one frame reads as a shove at gameplay distance.
	for _knockback_tick in 10:
		victim.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(is_instance_valid(player.character._animation_player), "The toy visual must own a runtime animation player")
	player.character._animation_player.seek(0.1, true)
	player.character._animation_player.pause()
	var shove_left_arm := player.character.get_node("LeftArm") as Node3D
	var shove_right_arm := player.character.get_node("RightArm") as Node3D
	_expect(shove_left_arm.rotation.x > 1.0 and shove_right_arm.rotation.x > 1.0, "Shove cue must thrust both arms forward")
	var shove_torso := player.character.get_node("Torso") as Node3D
	_expect(shove_torso.rotation.x < -0.2, "Shove cue must lean the torso forward for rear-camera readability")
	main.gameplay_hud.present_lobby_overlay(false)
	main.gameplay_hud.present_shove_state(1.4)
	main.gameplay_hud.present_major_warning("meteor", 2.0)
	var shove_hazard_lines: Array[String] = ["METEOR"]
	main.gameplay_hud.present_hazards(shove_hazard_lines)
	await process_frame
	_expect(not main.gameplay_hud.shove_pill.get_global_rect().intersects(main.gameplay_hud.warning_banner.get_global_rect()), "The shove pill must not obscure the major warning")
	_expect(not main.gameplay_hud.shove_pill.get_global_rect().intersects(main.gameplay_hud.hazard_tray.get_global_rect()), "The shove pill must not obscure hazard chips")
	_frame_review("shove-cue")
	await _capture("shove-cue")

	# Social emote review: readable wave and cheer poses at gameplay
	# distance, then the emote presentation yielding to carry and knockdown.
	main.gameplay_hud.present_shove_state(-1.0)
	main.gameplay_hud.present_major_warning("")
	var no_hazards: Array[String] = []
	main.gameplay_hud.present_hazards(no_hazards)
	victim.visible = false
	player.reset_for_match(Vector3.ZERO)
	player.set_camera_yaw(0.0)
	for _tick in 5:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
	await process_frame
	main._local_emote_cooldown_until.clear()
	main._server_emote_cooldown_until.clear()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	player._process(DELTA)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Wave review must start through the real request path")
	_expect(player.character.current_clip == "wave", "Wave review must play the wave clip")
	if is_instance_valid(player.character._animation_player):
		# Wave arm reaches its readable raised pose at 0.15s.
		player.character._animation_player.seek(0.15, true)
		player.character._animation_player.pause()
	var wave_arm := player.character.get_node("RightArm") as Node3D
	_expect(wave_arm.rotation.x > 2.0 and wave_arm.rotation.z < -0.4, "Wave cue must raise the arm in a readable wave pose")
	await _capture("emote-wave")

	main._local_emote_cooldown_until.clear()
	main._server_emote_cooldown_until.clear()
	main.request_local_emote(1, PartyPlayer.EMOTE_CHEER)
	player._process(DELTA)
	_expect(player.character.current_clip == "cheer", "Cheer review must play the cheer clip")
	if is_instance_valid(player.character._animation_player):
		# Cheer V-arms peak at 0.12s.
		player.character._animation_player.seek(0.12, true)
		player.character._animation_player.pause()
	var cheer_left_arm := player.character.get_node("LeftArm") as Node3D
	var cheer_right_arm := player.character.get_node("RightArm") as Node3D
	_expect(cheer_left_arm.rotation.x > 2.0 and cheer_right_arm.rotation.x > 2.0, "Cheer cue must bounce both arms into a readable V")
	_expect(cheer_left_arm.rotation.z < -0.4 and cheer_right_arm.rotation.z > 0.4, "Cheer arms must splay outward into a readable V")
	await _capture("emote-cheer")

	# The emote must yield to a held medium: acquiring the crate cancels it
	# and the holding pose takes over immediately.
	main._local_emote_cooldown_until.clear()
	main._server_emote_cooldown_until.clear()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Wave must start before the carry interrupt")
	review_crate.freeze = true
	review_crate.global_position = player.get_hold_position()
	review_crate.linear_velocity = Vector3.ZERO
	review_crate.angular_velocity = Vector3.ZERO
	review_crate.freeze = false
	_expect(grab_manager.request_grab(1, review_crate) and player.carrying_medium, "Carry interrupt must acquire the medium")
	main._tick_server_emotes()
	_expect(player.get_emote_id() == 0, "Carrying a medium must cancel the emote")
	player._process(DELTA)
	_expect(player.character.current_clip == "holding_idle", "Carry interrupt must present the holding pose")
	if is_instance_valid(player.character._animation_player):
		player.character._animation_player.seek(0.0, true)
		player.character._animation_player.pause()
	await _capture("emote-interrupt-carry")

	# Knockdown must cancel the emote, and recovery presents get_up without
	# the emote resuming.
	grab_manager.release_grab(1)
	player.carrying_medium = false
	main._local_emote_cooldown_until.clear()
	main._server_emote_cooldown_until.clear()
	main.request_local_emote(1, PartyPlayer.EMOTE_WAVE)
	_expect(player.get_emote_id() == PartyPlayer.EMOTE_WAVE, "Wave must start before the knockdown interrupt")
	player.apply_knockdown(Vector3(1.0, 0.0, 0.0))
	_expect(player.get_emote_id() == 0 and not player.visual.visible, "Knockdown must cancel the emote and hide the upright visual")
	for _tick in 120:
		player.apply_movement_input(Vector2.ZERO, false, false, false, DELTA)
		await physics_frame
	_expect(not player.is_knocked_down() and player.get_emote_id() == 0, "Recovery must not resume the cancelled emote")
	_expect(player.character.current_clip == "get_up", "Knockdown interrupt must present get_up")
	if is_instance_valid(player.character._animation_player):
		# get_up limb-swing peaks at 0.0/0.5/1.0s; 0.5s is the readable mid pose.
		player.character._animation_player.seek(0.5, true)
		player.character._animation_player.pause()
	await _capture("emote-interrupt-knockdown")

	_finish()


func _capture(state: String) -> void:
	if capture_dir.is_empty():
		return
	_frame_review(state)
	# Instantiated player scenes bring their own camera into the tree; keep the
	# dedicated review camera authoritative for the capture. player.tscn marks
	# its camera current = true, so every other camera must be released.
	for camera in _collect_cameras(root):
		camera.current = camera == review_camera
	review_camera.make_current()
	_expect(review_camera.is_current(), "Capture must render through the review camera: %s" % state)
	await process_frame
	if state == "carry-airborne" and is_instance_valid(review_crate):
		review_crate.global_position = review_player.get_hold_position()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(root.size == review_size and image.get_size() == review_size, "Capture framebuffer must match the requested review resolution")
	var path := capture_dir.path_join("%s-%dx%d.png" % [state, root.size.x, root.size.y])
	_expect(image.save_png(path) == OK, "Carry review capture must save: %s" % state)


func _collect_cameras(node: Node) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if node is Camera3D:
		cameras.append(node)
	for child in node.get_children():
		cameras.append_array(_collect_cameras(child))
	return cameras


func _frame_review(state: String) -> void:
	if not is_instance_valid(review_camera) or not is_instance_valid(review_player):
		return
	if state == "carry-airborne":
		review_camera.global_position = Vector3(6.0, 5.0, 6.0)
		review_camera.look_at(review_player.global_position + Vector3(0.0, 1.0, 0.0))
	elif state in ["carry-walk", "knockdown-recovery"]:
		review_camera.global_position = review_player.global_position + Vector3(3.4, 1.65, 0.0)
		review_camera.look_at(review_player.global_position + Vector3(0.0, 1.0, 0.0))
	elif state == "shove-cue":
		review_camera.global_position = review_player.global_position + Vector3(3.6, 1.7, -1.4)
		review_camera.look_at(review_player.global_position + Vector3(0.3, 1.0, -1.1))
	elif state in ["emote-wave", "emote-cheer"]:
		# A 3/4 view keeps both the forward arm swing and the lateral
		# splay readable; pure side or frontal views foreshorten one axis.
		review_camera.global_position = review_player.global_position + Vector3(2.2, 1.7, -2.4)
		review_camera.look_at(review_player.global_position + Vector3(0.0, 1.15, -0.6))
	else:
		review_camera.global_position = review_player.global_position + Vector3(1.2, 1.65, -3.2)
		review_camera.look_at(review_player.global_position + Vector3(0.0, 1.0, -0.6))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CARRY_PRESENTATION_OK checks=%d resolution=%dx%d" % [checks, root.size.x, root.size.y])
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
