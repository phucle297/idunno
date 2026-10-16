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


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
