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
	# T44 A2 / AC12: whole-body waddle, no arm or leg swing, eases to identity.
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
				_expect(is_zero_approx((character.get_node(limb) as Node3D).rotation.x), "%s must not swing during %s" % [limb, clip])
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
