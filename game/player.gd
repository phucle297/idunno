class_name PartyPlayer
extends CharacterBody3D

const Tuning = preload("res://game/player_tuning.gd")
const RagdollScene = preload("res://game/cosmetic_ragdoll.gd")

@onready var visual: Node3D = $Visual
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var character: ToyCharacterVisual = $Visual/Character

var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _knockdown_remaining := 0.0
var _is_crouched := false
var _camera_yaw := 0.0
var _camera_pitch := -0.14
var _ragdoll: Node3D
var _is_eliminated := false
var _get_up_remaining := 0.0
var _grab_manager: Node
var _shove_manager: Node
var _shove_cue_remaining := 0.0
var _peer_id := 1
var carrying_medium := false
var local_input_blocked := false
var mouse_sensitivity := 1.0
var invert_y := false
var camera_shake_level := 1.0
var _prediction_inputs: Array[Dictionary] = []
var _last_movement_ack := -1


func _ready() -> void:
	_update_capsule(false)
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		$CameraPivot/SpringArm3D/Camera3D.current = false


func _process(_delta: float) -> void:
	# Cosmetic, bounded knockdown feedback; never alters body or aiming rotation.
	var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
	var shake := minf(_knockdown_remaining, 0.25) * camera_shake_level if camera.current else 0.0
	camera.h_offset = sin(_knockdown_remaining * 80.0) * shake * 0.12
	if not is_instance_valid(character) or _is_eliminated or is_knocked_down():
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if _shove_cue_remaining > 0.0:
		_shove_cue_remaining = maxf(0.0, _shove_cue_remaining - _delta)
		character.play_clip("shove")
	elif _get_up_remaining > 0.0:
		_get_up_remaining = maxf(0.0, _get_up_remaining - _delta)
		character.play_clip("get_up")
	elif not is_on_floor():
		character.play_clip("jump_takeoff" if velocity.y > 0.0 else "falling")
	elif carrying_medium:
		character.play_clip("holding_walk" if horizontal_speed > 0.2 else "holding_idle")
	elif _is_crouched:
		character.play_clip("crouch_walk" if horizontal_speed > 0.2 else "crouch_idle")
	elif horizontal_speed > Tuning.WALK_SPEED + 0.5:
		character.play_clip("run")
	elif horizontal_speed > 0.2:
		character.play_clip("walk")
	else:
		character.play_clip("idle")


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_local_input() or local_input_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * 0.0025 * mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch - event.relative.y * 0.0025 * mouse_sensitivity * (-1.0 if invert_y else 1.0), -1.1, 0.35)
		camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)


func _physics_process(delta: float) -> void:
	if _is_eliminated or not accepts_local_input():
		return
	if not local_input_blocked and Input.is_action_just_pressed("grab") and is_instance_valid(_grab_manager):
		_grab_manager.request_local_toggle(_peer_id)
	if not local_input_blocked and Input.is_action_just_pressed("shove") and is_instance_valid(_shove_manager):
		_shove_manager.request_local_shove(_peer_id)
	if _has_active_network_session():
		return
	if not local_input_blocked and Input.is_action_just_pressed("knockdown_test"):
		apply_knockdown(Vector3.RIGHT * 4.0)
	apply_movement_input(
		Vector2.ZERO if local_input_blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		not local_input_blocked and Input.is_action_pressed("sprint"),
		not local_input_blocked and Input.is_action_pressed("crouch"),
		not local_input_blocked and Input.is_action_just_pressed("jump"),
		delta
	)


func apply_movement_input(
	input_2d: Vector2,
	sprinting: bool,
	crouched: bool,
	jump_pressed: bool,
	delta: float,
	grounded_override: int = -1
) -> void:
	if _is_eliminated:
		return
	if _knockdown_remaining > 0.0:
		_process_knockdown(delta)
		return
	# The first replay tick starts from server contact, not the client's future contact.
	var grounded := is_on_floor() if grounded_override < 0 else grounded_override != 0
	if grounded:
		_coyote_remaining = Tuning.COYOTE_TIME
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
		velocity.y -= Tuning.GRAVITY * delta

	if jump_pressed:
		_jump_buffer_remaining = Tuning.JUMP_BUFFER_TIME
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)

	_is_crouched = crouched
	_update_capsule(_is_crouched)

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0 and not _is_crouched:
		velocity.y = Tuning.JUMP_VELOCITY
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0

	var camera_basis := Basis(Vector3.UP, _camera_yaw)
	var wish_direction := (camera_basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
	var target_speed := Tuning.CROUCH_SPEED if _is_crouched else (
		Tuning.SPRINT_SPEED if sprinting else Tuning.WALK_SPEED
	)
	if carrying_medium:
		target_speed *= Tuning.MEDIUM_CARRY_SPEED_FACTOR
	var target_velocity := wish_direction * target_speed
	var acceleration := Tuning.GROUND_ACCELERATION if grounded else Tuning.AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if wish_direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-wish_direction.x, -wish_direction.z), 12.0 * delta)
	move_and_slide()


func predict_movement_input(sequence: int, direction: Vector2, sprinting: bool, crouched: bool, jump_pressed: bool, delta: float) -> void:
	if _is_eliminated or is_knocked_down():
		_prediction_inputs.clear()
		return
	_prediction_inputs.append({"sequence": sequence, "direction": direction, "sprinting": sprinting, "crouched": crouched, "jump_pressed": jump_pressed, "yaw": _camera_yaw, "delta": delta})
	if _prediction_inputs.size() > Tuning.PREDICTION_HISTORY_TICKS:
		_prediction_inputs.pop_front()
	apply_movement_input(direction, sprinting, crouched, jump_pressed, delta)


func get_movement_replay_state() -> Vector3:
	return Vector3(_coyote_remaining, _jump_buffer_remaining, 1.0 if is_on_floor() else 0.0)


func is_crouched() -> bool:
	return _is_crouched


func reconcile_movement(server_position: Vector3, server_velocity: Vector3, facing: float, knocked_down: bool, sequence: int, state: Vector3, crouched: bool, medium_carry: bool = false) -> void:
	if _is_eliminated or sequence < _last_movement_ack:
		return
	_last_movement_ack = sequence
	var missing_prefix := not _prediction_inputs.is_empty() and int(_prediction_inputs[0].sequence) > sequence + 1
	while not _prediction_inputs.is_empty() and int(_prediction_inputs[0].sequence) <= sequence:
		_prediction_inputs.pop_front()
	global_position = server_position
	velocity = server_velocity
	set_visual_yaw(facing)
	set_network_knockdown(knocked_down)
	_coyote_remaining = state.x
	_jump_buffer_remaining = state.y
	_is_crouched = crouched
	# Carry toggles are not predicted inputs. The movement snapshot owns this
	# state for replay and subsequent prediction, independent of prop channel 3.
	carrying_medium = medium_carry and not knocked_down
	_update_capsule(crouched)
	if knocked_down or _is_eliminated:
		_prediction_inputs.clear()
		return
	if missing_prefix:
		# Snap without replay, but retain bounded inputs so delayed acks can catch up.
		return
	var aiming_yaw := _camera_yaw
	var grounded := int(state.z)
	# Transport invokes reconciliation in a physics tick: move_and_slide uses that delta.
	for movement_input: Dictionary in _prediction_inputs:
		_camera_yaw = float(movement_input.yaw)
		apply_movement_input(movement_input.direction, movement_input.sprinting, movement_input.crouched, movement_input.jump_pressed, movement_input.delta, grounded)
		grounded = -1
	_camera_yaw = aiming_yaw


func apply_knockdown(impulse: Vector3) -> void:
	if _is_eliminated or _knockdown_remaining > 0.0:
		return
	release_held_object()
	_knockdown_remaining = Tuning.KNOCKDOWN_DURATION
	velocity += impulse.limit_length(8.0)
	_spawn_cosmetic_ragdoll(velocity, impulse)


func set_network_knockdown(active: bool) -> void:
	if _is_eliminated:
		return
	if active and _knockdown_remaining <= 0.0:
		_knockdown_remaining = Tuning.KNOCKDOWN_DURATION
		_spawn_cosmetic_ragdoll(velocity, Vector3.ZERO)
	elif not active and _knockdown_remaining > 0.0:
		_knockdown_remaining = 0.0
		_clear_cosmetic_ragdoll()


func _spawn_cosmetic_ragdoll(initial_velocity: Vector3, impulse: Vector3) -> void:
	if is_instance_valid(_ragdoll):
		return
	_ragdoll = RagdollScene.new()
	get_parent().add_child(_ragdoll)
	_ragdoll.global_transform = global_transform
	_ragdoll.activate(initial_velocity, impulse)
	visual.visible = false


func _clear_cosmetic_ragdoll() -> void:
	if is_instance_valid(_ragdoll):
		_ragdoll.queue_free()
		_ragdoll = null
	visual.visible = not _is_eliminated
	if not _is_eliminated:
		_get_up_remaining = character.get_clip_duration("get_up") if is_instance_valid(character) else 0.0
		character.play_clip("get_up")


func apply_hazard_velocity(velocity_change: Vector3, speed_cap: float) -> void:
	if _is_eliminated:
		return
	release_held_object()
	velocity = (velocity + velocity_change).limit_length(maxf(speed_cap, 0.0))


func is_knocked_down() -> bool:
	return _knockdown_remaining > 0.0


func set_eliminated(eliminated: bool) -> void:
	_is_eliminated = eliminated
	if eliminated:
		release_held_object()
		_prediction_inputs.clear()
		velocity = Vector3.ZERO
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_knockdown_remaining = 0.0
		_clear_cosmetic_ragdoll()
	visual.visible = not eliminated
	collider.set_deferred("disabled", eliminated)


func reset_for_match(spawn_position: Vector3) -> void:
	release_held_object()
	if is_instance_valid(_ragdoll):
		_ragdoll.queue_free()
		_ragdoll = null
	_knockdown_remaining = 0.0
	_get_up_remaining = 0.0
	_is_crouched = false
	_is_eliminated = false
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_prediction_inputs.clear()
	_last_movement_ack = -1
	position = spawn_position
	velocity = Vector3.ZERO
	visual.visible = true
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	collider.set_deferred("disabled", false)
	_update_capsule(false)
	if is_instance_valid(character):
		character.play_clip("idle")


func configure_grabbing(manager: Node, peer_id: int) -> void:
	_grab_manager = manager
	_peer_id = peer_id
	character.set_cosmetic_variant((peer_id - 1) % 4)
	character.set_player_color(peer_id - 1)


func configure_shoving(manager: Node) -> void:
	_shove_manager = manager


func play_shove_cue() -> void:
	_shove_cue_remaining = 0.3


func release_held_object() -> void:
	carrying_medium = false
	if is_instance_valid(_grab_manager):
		_grab_manager.release_grab(_peer_id)


func can_grab_objects() -> bool:
	return not _is_eliminated and _knockdown_remaining <= 0.0


func get_grab_origin() -> Vector3:
	return global_position + Vector3.UP * 0.9


func get_grab_direction() -> Vector3:
	return Basis(Vector3.UP, _camera_yaw) * Vector3.FORWARD


func get_hold_position() -> Vector3:
	return get_grab_origin() + get_grab_direction() * Tuning.GRAB_HOLD_DISTANCE


func get_head_sample_position() -> Vector3:
	var body_height := Tuning.CROUCHED_HEIGHT if _is_crouched else Tuning.STANDING_HEIGHT
	return global_position + Vector3.UP * (body_height - 0.15)


func ragdoll_body_count() -> int:
	return _ragdoll.body_count() if is_instance_valid(_ragdoll) else 0


func ragdoll_joint_count() -> int:
	return _ragdoll.joint_count() if is_instance_valid(_ragdoll) else 0


func ragdoll_total_mass() -> float:
	return _ragdoll.total_mass() if is_instance_valid(_ragdoll) else 0.0


func ragdoll_adjacent_exclusions_are_configured() -> bool:
	return _ragdoll.adjacent_exclusions_are_configured() if is_instance_valid(_ragdoll) else false


func ragdoll_maximum_body_separation() -> float:
	return _ragdoll.maximum_body_separation() if is_instance_valid(_ragdoll) else 0.0


func _process_knockdown(delta: float) -> void:
	_knockdown_remaining -= delta
	velocity.y -= Tuning.GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	move_and_slide()
	if _knockdown_remaining <= 0.0:
		_clear_cosmetic_ragdoll()
		_update_capsule(false)


func _update_capsule(crouched: bool) -> void:
	var capsule := collider.shape as CapsuleShape3D
	var target_height := Tuning.CROUCHED_HEIGHT if crouched else Tuning.STANDING_HEIGHT
	capsule.height = target_height
	collider.position.y = target_height * 0.5
	visual.scale.y = 0.72 if crouched else 1.0


func accepts_local_input() -> bool:
	return not _is_eliminated and (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority())


func _has_active_network_session() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func get_camera_yaw() -> float:
	return _camera_yaw


func set_camera_yaw(yaw: float) -> void:
	_camera_yaw = wrapf(yaw, -PI, PI)
	camera_pivot.rotation.y = _camera_yaw


func get_visual_yaw() -> float:
	return visual.rotation.y


func set_visual_yaw(yaw: float) -> void:
	visual.rotation.y = wrapf(yaw, -PI, PI)
