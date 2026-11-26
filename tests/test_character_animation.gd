extends SceneTree

const STEP := 0.05

var checks := 0
var failures: Array[String] = []
var character: ToyCharacterVisual
var animation_player: AnimationPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	character = (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	root.add_child(character)
	await process_frame
	animation_player = character.get_node("AnimationPlayer") as AnimationPlayer
	_test_held_takeoff()
	_test_falling_pose()
	_test_stop_face_attachment()
	_test_interrupted_body_cues()
	_test_plop_toddle()
	_test_arm_overlay()
	character.free()
	if failures.is_empty():
		print("CHARACTER_ANIMATION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_held_takeoff() -> void:
	var left_arm := character.get_node("LeftArm") as Node3D
	character.play_clip("jump_takeoff")
	var initial_play_position := animation_player.current_animation_position
	for _sample in 12:
		animation_player.advance(STEP)
		character.play_clip("jump_takeoff")
		_expect(is_equal_approx(left_arm.rotation.x, -0.8), "Held takeoff must retain its raised-arm pose after the one-shot ends")
		_expect((character.get_node("RightArm") as Node3D).rotation.is_equal_approx(left_arm.rotation), "Takeoff uses a symmetric airborne pose, not an opposed walking stride")
	_expect(animation_player.current_animation_position >= character.get_clip_duration("jump_takeoff"), "Held takeoff must not restart after its one-shot end")
	_expect(initial_play_position <= STEP, "Takeoff must start from its first frame")


func _test_falling_pose() -> void:
	var left_arm := character.get_node("LeftArm") as Node3D
	character.play_clip("falling")
	for _sample in 12:
		animation_player.advance(STEP)
		_expect(is_equal_approx(left_arm.rotation.x, -0.45), "Falling must keep a stable arm pose across loop samples")
		_expect((character.get_node("RightArm") as Node3D).rotation.is_equal_approx(left_arm.rotation), "Falling arms remain symmetric")


func _test_stop_face_attachment() -> void:
	var face := character.get_node("FacePlate") as Node3D
	var head := character.get_node("Head") as Node3D
	var initial_offset := face.global_position - head.global_position
	for gait in ["walk", "run"]:
		character.play_clip(gait)
		animation_player.advance(0.2)
		animation_player.seek(animation_player.current_animation_length * 0.4, true)
		character.play_clip("idle")
		for _sample in 6:
			animation_player.advance(0.04)
			_expect(face.global_position.distance_to(head.global_position + initial_offset) < 0.0001, "Stopping either gait keeps the face fixed relative to the head")


func _test_interrupted_body_cues() -> void:
	var face := character.get_node("FacePlate") as Node3D
	var rest := face.transform
	for cue in ["shove", "get_up"]:
		character.play_clip(cue)
		animation_player.advance(0.1)
		character.play_clip("idle")
		animation_player.advance(0.2)
		_expect(face.transform.is_equal_approx(rest), "Interrupting a body cue restores face position, rotation and flattened scale")
		_expect((character.get_node("Torso") as Node3D).rotation.is_zero_approx(), "Interrupting a body cue restores torso lean")
	character.ensure_runtime_setup()
	character.play_clip("walk")
	animation_player.advance(0.3)
	character.play_clip("idle")
	animation_player.advance(0.2)
	_expect(face.transform.is_equal_approx(rest), "Repeated runtime setup cannot capture an animated pose as rest")


func _test_plop_toddle() -> void:
	# T44 A2 / AC12: whole-body waddle, eases to identity. The arm/leg proxies stay at
	# rest in walk/run; T45 arm swing is a bone overlay (see _test_arm_overlay).
	character.play_clip("idle")
	character.sync_rig(1.0)
	_expect(character.get_waddle_transform().is_equal_approx(Transform3D.IDENTITY), "Idle waddle transform must be identity")
	var peaks := {}
	for clip in ["walk", "run"]:
		character.play_clip(clip)
		character.set_locomotion_speed(4.5 if clip == "walk" else 6.5)
		animation_player.advance(0.3)
		character.sync_rig(1.0)
		animation_player.pause()
		var peak := 0.0
		for sample in 24:
			animation_player.seek(sample / 24.0 * animation_player.current_animation_length, true)
			character.sync_rig()
			for limb in ["LeftArm", "RightArm"]:
				_expect(is_zero_approx((character.get_node(limb) as Node3D).rotation.x), "%s proxy must not swing during %s (T45 swing is a bone overlay)" % [limb, clip])
			peak = maxf(peak, absf(character.get_waddle_transform().basis.get_euler().z))
		peaks[clip] = peak
		# AC12 A3 amendment: legs step (replaces "legs rotation.x = 0 in walk/run").
		# Phases 0.0 / 0.5 are a quarter cycle from the stance centres (0.25 / 0.75),
		# where the feet are at opposite stride ends. At 0.25 / 0.75 one foot is
		# planted under the hip and the other mid-swing, so both thighs pitch forward
		# (measured +0.40 / +0.54 rad); the plan's phases cannot show opposite signs.
		var pitch := {}
		for phase in [0.0, 0.5]:
			animation_player.seek(phase * animation_player.current_animation_length, true)
			character.sync_rig()
			pitch[phase] = [_thigh_pitch("l"), _thigh_pitch("r")]
		print("T44_A3_PITCH %s %s" % [clip, pitch])
		for phase in [0.0, 0.5]:
			_expect(signf(pitch[phase][0]) == -signf(pitch[phase][1]) and pitch[phase][0] != 0.0, "AC12 A3 amendment: left/right upperleg pitch must have opposite signs at phase %.2f during %s" % [phase, clip])
		animation_player.play()
		# Leave locomotion: W must ease back to identity within 0.15 s.
		animation_player.seek(0.25 * animation_player.current_animation_length, true)
		character.sync_rig()
		character.play_clip("idle")
		for _frame in 9:
			character.sync_rig(1.0 / 60.0)
		_expect(character.get_waddle_transform().is_equal_approx(Transform3D.IDENTITY), "%s->idle must ease the waddle to identity within 0.15 s" % clip)
		var rig := character.get_node("Model/Rig/Skeleton3D") as Skeleton3D
		for bone_name in ["upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "foot.l", "foot.r"]:
			var bone := rig.find_bone(bone_name)
			var angle := rig.get_bone_pose_rotation(bone).angle_to(rig.get_bone_rest(bone).basis.get_rotation_quaternion())
			_expect(angle < 0.002, "AC12 A3 amendment: %s must be back at rest within 0.15 s of idle after %s (off %.4f rad)" % [bone_name, clip, angle])
	_expect(peaks.run > peaks.walk, "Run peak roll must exceed walk peak roll")


## T45 A+B: relaxed rest pose + counter-phase arm swing (Architect T45 plan section 5).
func _test_arm_overlay() -> void:
	var rig := character.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var root_inv := func() -> Transform3D: return character.global_transform.affine_inverse()
	character.set_item_held(false)
	character.play_clip("idle")
	character.set_locomotion_speed(0.0)
	for _frame in 30:
		character.sync_rig(1.0 / 60.0)
	var arm: Dictionary = character.get_arm_overlay_debug()
	_expect(arm.swing == 0.0 and arm.swing_l == 0.0 and arm.swing_r == 0.0, "T45: idle arm swing must be exactly 0")
	_expect(is_equal_approx(arm.elbow_l, ToyCharacterVisual.ARM_RELAX_ELBOW) and is_equal_approx(arm.elbow_r, ToyCharacterVisual.ARM_RELAX_ELBOW), "T45: idle elbows carry the relaxed flexion")
	_expect(is_equal_approx(arm.abduction_r, ToyCharacterVisual.ARM_RELAX_ABDUCTION), "T45: idle arms carry the relaxed abduction")
	var lower_r := rig.find_bone("lowerarm.r")
	var flex := rig.get_bone_pose_rotation(lower_r).angle_to(rig.get_bone_rest(lower_r).basis.get_rotation_quaternion())
	_expect(absf(flex - ToyCharacterVisual.ARM_RELAX_ELBOW) < 0.01, "T45: lowerarm.r flexed by the relaxed elbow angle at idle (got %.3f)" % flex)
	# Elbow bends the hand forward (root -Z) on both sides.
	var hand_l := (root_inv.call() as Transform3D) * rig.global_transform * rig.get_bone_global_pose(rig.find_bone("handslot.l")).origin
	var hand_r := (root_inv.call() as Transform3D) * rig.global_transform * rig.get_bone_global_pose(rig.find_bone("handslot.r")).origin
	_expect(hand_l.z < -0.05 and hand_r.z < -0.05, "T45: relaxed elbows carry both paws forward (l %.3f r %.3f)" % [hand_l.z, hand_r.z])
	var peaks := {}
	for case in [["walk", 4.5, ToyCharacterVisual.ARM_SWING_WALK], ["walk", 2.25, ToyCharacterVisual.ARM_SWING_WALK * 0.5], ["run", 6.5, ToyCharacterVisual.ARM_SWING_RUN]]:
		character.play_clip(case[0])
		character.set_locomotion_speed(case[1])
		for _frame in 30:
			animation_player.advance(1.0 / 60.0)
			character.sync_rig(1.0 / 60.0)
		animation_player.pause()
		var peak := 0.0
		var corr_l := 0.0
		var corr_r := 0.0
		var foot_l: Array[float] = []
		var foot_r: Array[float] = []
		var swings: Array[float] = []
		for sample in 24:
			animation_player.seek(sample / 24.0 * animation_player.current_animation_length, true)
			character.sync_rig()
			arm = character.get_arm_overlay_debug()
			_expect(absf(arm.swing_l + arm.swing_r) < 0.0001, "T45: left arm swing is opposite the right at every sample (%s)" % case[0])
			peak = maxf(peak, absf(arm.swing_r))
			swings.append(arm.swing_r)
			foot_l.append(-((root_inv.call() as Transform3D) * character.get_visible_foot_global("l")).z)
			foot_r.append(-((root_inv.call() as Transform3D) * character.get_visible_foot_global("r")).z)
		var mean_l := 0.0
		var mean_r := 0.0
		for i in 24:
			mean_l += foot_l[i] / 24.0
			mean_r += foot_r[i] / 24.0
		for i in 24:
			corr_l += swings[i] * (foot_l[i] - mean_l)
			corr_r += swings[i] * (foot_r[i] - mean_r)
		_expect(corr_l > 0.0 and corr_r < 0.0, "T45: right arm swings forward with the LEFT foot forward (counter-phase) during %s (corr l %.4f r %.4f)" % [case[0], corr_l, corr_r])
		_expect(absf(peak - case[2]) <= 0.1 * case[2], "T45: %s @ %.2f swing peak %.3f within 10%% of %.3f" % [case[0], case[1], peak, case[2]])
		peaks["%s%.2f" % [case[0], case[1]]] = peak
		animation_player.play()
		print("T45_ARM_SWING %s speed=%.2f peak=%.3f corr_l=%.4f corr_r=%.4f" % [case[0], case[1], peak, corr_l, corr_r])
	_expect(peaks["run6.50"] > peaks["walk4.50"], "T45: run swing peak exceeds walk")
	# walk -> idle: swing back to 0 within 0.15 s.
	character.play_clip("walk")
	character.set_locomotion_speed(4.5)
	for _frame in 30:
		animation_player.advance(1.0 / 60.0)
		character.sync_rig(1.0 / 60.0)
	character.play_clip("idle")
	character.set_locomotion_speed(0.0)
	for _frame in 9:
		animation_player.advance(1.0 / 60.0)
		character.sync_rig(1.0 / 60.0)
	_expect(character.get_arm_overlay_debug().swing == 0.0, "T45: walk->idle swing back to 0 within 0.15 s")
	# Holding an item: right arm returns to the legacy (pre-T45) pose, left still swings.
	character.set_item_held(true)
	for case in [["idle", 0.0], ["walk", 4.5], ["run", 6.5]]:
		character.play_clip(case[0])
		character.set_locomotion_speed(case[1])
		for _frame in 12:
			animation_player.advance(1.0 / 60.0)
			character.sync_rig(1.0 / 60.0)
		arm = character.get_arm_overlay_debug()
		_expect(arm.weight_r == 0.0 and arm.elbow_r == 0.0 and arm.swing_r == 0.0, "T45: held item eases the right arm overlay to 0 within 0.12 s (%s)" % case[0])
		print("T45_HELD %s legacy_off=%.5f elbow_off=%.5f" % [case[0], _arm_matches_legacy("RightArm"), rig.get_bone_pose_rotation(lower_r).angle_to(rig.get_bone_rest(lower_r).basis.get_rotation_quaternion())])
		_expect(_arm_matches_legacy("RightArm") < 0.0175 and rig.get_bone_pose_rotation(lower_r).angle_to(rig.get_bone_rest(lower_r).basis.get_rotation_quaternion()) < 0.002, "T45: held right arm equals the legacy pose (%s)" % case[0])
		var slot := rig.global_transform * rig.get_bone_global_pose(rig.find_bone("handslot.r")).origin
		_expect(character.get_hand_anchor().global_position.distance_to(slot) < 0.001, "T45: HandAnchor rides handslot.r while held (%s)" % case[0])
		if case[0] == "walk":
			animation_player.seek(0.0, true)
			character.sync_rig()
			_expect(absf(character.get_arm_overlay_debug().swing_l) > 0.1, "T45: left arm still swings while the right holds an item")
	character.set_item_held(false)
	# Clip overrides: arms hand back to the legacy clip-driven pose.
	for clip in ["shove", "wave", "cheer", "jump_takeoff", "falling", "landing", "get_up"]:
		character.play_clip("idle")
		for _frame in 12:
			character.sync_rig(1.0 / 60.0)
		character.play_clip(clip)
		for _frame in 8:
			animation_player.advance(1.0 / 60.0)
			character.sync_rig(1.0 / 60.0)
		arm = character.get_arm_overlay_debug()
		_expect(arm.weight_l == 0.0 and arm.weight_r == 0.0 and arm.swing == 0.0, "T45: %s eases the arm overlay to 0" % clip)
		var off := maxf(_arm_matches_legacy("LeftArm"), _arm_matches_legacy("RightArm"))
		_expect(off < 0.0175, "T45: %s arm bones equal the legacy pose within 1 degree (off %.4f rad)" % [clip, off])
	character.play_clip("idle")


## Angle (rad) between an upper-arm bone and the pre-T45 proxy-derived pose.
func _arm_matches_legacy(proxy: String) -> float:
	var rig := character.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var bone := rig.find_bone(ToyCharacterVisual.BONE_MAP[proxy])
	var flip := Quaternion(Vector3.UP, PI)
	var rest_q := rig.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	rest_q = Quaternion(Vector3.BACK, (-1.0 if proxy == "LeftArm" else 1.0) * ToyCharacterVisual.ARM_DOWN_ANGLE) * rest_q
	var expected := flip * (character.get_node(proxy) as Node3D).basis.get_rotation_quaternion() * flip * rest_q
	return expected.angle_to(rig.get_bone_global_pose(bone).basis.get_rotation_quaternion())


## Upperleg pitch in the character root (radians, + = thigh forward) relative to rest.
func _thigh_pitch(side: String) -> float:
	var rig := character.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var upper := rig.find_bone("upperleg." + side)
	var lower := rig.find_bone("lowerleg." + side)
	var root_xform := character.global_transform.affine_inverse() * rig.global_transform
	var hip := root_xform * rig.get_bone_global_pose(upper).origin
	var knee := root_xform * rig.get_bone_global_pose(lower).origin
	var rest_hip := ToyCharacterVisual.MODEL_BASE * rig.get_bone_global_rest(upper).origin
	var rest_knee := ToyCharacterVisual.MODEL_BASE * rig.get_bone_global_rest(lower).origin
	var now := atan2(-(knee - hip).z, -(knee - hip).y)
	var rest := atan2(-(rest_knee - rest_hip).z, -(rest_knee - rest_hip).y)
	return now - rest


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
