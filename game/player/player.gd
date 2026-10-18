class_name PartyPlayer
extends CharacterBody3D

signal landed(fall_height: float)

const Tuning = preload("res://game/player/player_tuning.gd")
const RagdollScene = preload("res://game/player/cosmetic_ragdoll.gd")

const EMOTE_WAVE := 1
const EMOTE_CHEER := 2
const EMOTE_CLIPS := {EMOTE_WAVE: "wave", EMOTE_CHEER: "cheer"}
const EMOTE_DURATIONS := {EMOTE_WAVE: 1.2, EMOTE_CHEER: 1.0}

@onready var visual: Node3D = $Visual
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var character: ToyCharacterVisual = $Visual/Character

var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _knockdown_remaining := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.28
var _ragdoll: Node3D
var _is_eliminated := false
var _get_up_remaining := 0.0
var _landing_remaining := 0.0
var _presentation_airborne := false
var _network_grounded := -1
var _fall_peak := NAN
var _shove_manager: Node
var _shove_cue_remaining := 0.0
var _emote_gateway: Node
var _emote_id := 0
var _emote_remaining := 0.0
var _peer_id := 1
var local_input_blocked := false
var mouse_sensitivity := 1.0
var invert_y := false
var camera_shake_level := 1.0
var _prediction_inputs: Array[Dictionary] = []
var _last_movement_ack := -1
var weather_surfaces: WeatherSurfaces
var movement_buff := Vector2.ZERO # Authoritative kind and remaining simulation seconds.


func _ready() -> void:
	_update_capsule()
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
	# Observers do not run move_and_slide, so their floor contact must come
	# from the authoritative replay state, not their local collision cache.
	var grounded := is_on_floor() if _network_grounded < 0 else _network_grounded != 0
	var surface := weather_surfaces.sample_surface(global_position) if grounded and is_instance_valid(weather_surfaces) else Vector2.ZERO
	# Small cosmetic hunch/shiver; capsule, aiming and gait timing are unchanged.
	visual.rotation.x = surface.y * 0.06
	visual.rotation.z = sin(Time.get_ticks_msec() * 0.018) * surface.x * 0.025
	if grounded and _presentation_airborne:
		_landing_remaining = character.get_clip_duration("landing")
	_presentation_airborne = not grounded
	if _shove_cue_remaining > 0.0:
		_shove_cue_remaining = maxf(0.0, _shove_cue_remaining - _delta)
		character.play_clip("shove")
	elif _get_up_remaining > 0.0:
		_get_up_remaining = maxf(0.0, _get_up_remaining - _delta)
		character.play_clip("get_up")
	elif not grounded:
		_landing_remaining = 0.0
		character.play_clip("jump_takeoff" if velocity.y > 0.0 else "falling")
	elif _landing_remaining > 0.0:
		_landing_remaining = maxf(0.0, _landing_remaining - _delta)
		character.play_clip("landing")
	elif _emote_id != 0:
		# Cosmetic social emote; never locks movement or aim. Local input,
		# shove and knockdown cancel it immediately.
		_emote_remaining = maxf(0.0, _emote_remaining - _delta)
		if _emote_remaining <= 0.0:
			_emote_id = 0
		else:
			character.play_clip(EMOTE_CLIPS[_emote_id])
	elif horizontal_speed > effective_walk_speed() + 0.5:
		character.play_clip("run")
	elif horizontal_speed > 0.2:
		character.play_clip("walk")
	else:
		character.play_clip("idle")
	character.set_locomotion_speed(horizontal_speed)


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
	if not local_input_blocked and Input.is_action_just_pressed("shove") and is_instance_valid(_shove_manager):
		_shove_manager.request_local_shove(_peer_id)
	if not local_input_blocked and Input.is_action_just_pressed("emote_wave"):
		request_emote(EMOTE_WAVE)
	if not local_input_blocked and Input.is_action_just_pressed("emote_cheer"):
		request_emote(EMOTE_CHEER)
	if _has_active_network_session():
		return
	if not local_input_blocked and Input.is_action_just_pressed("knockdown_test"):
		apply_knockdown(Vector3.RIGHT * 4.0)
	apply_movement_input(
		Vector2.ZERO if local_input_blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		not local_input_blocked and Input.is_action_pressed("sprint"),
		not local_input_blocked and Input.is_action_just_pressed("jump"),
		delta
	)


func apply_movement_input(
	input_2d: Vector2,
	sprinting: bool,
	jump_pressed: bool,
	delta: float,
	grounded_override: int = -1
) -> void:
	if _is_eliminated:
		return
	movement_buff.y = maxf(0.0, movement_buff.y - delta)
	if movement_buff.y == 0.0:
		movement_buff.x = MatchPowerups.Kind.NONE
	if _knockdown_remaining > 0.0:
		_process_knockdown(delta)
		return
	if _emote_id != 0 and (input_2d.length_squared() > 0.0001 or jump_pressed):
		cancel_emote()
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

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		var height_multiplier := Tuning.POWERUP_JUMP_HEIGHT_MULTIPLIER if int(movement_buff.x) == MatchPowerups.Kind.JUMP else 1.0
		velocity.y = sqrt(2.0 * Tuning.GRAVITY * Tuning.JUMP_HEIGHT * height_multiplier)
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0

	var camera_basis := Basis(Vector3.UP, _camera_yaw)
	var wish_direction := (camera_basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
	var target_speed := effective_sprint_speed() if sprinting else effective_walk_speed()
	var target_velocity := wish_direction * target_speed
	var acceleration := Tuning.GROUND_ACCELERATION if grounded else Tuning.AIR_ACCELERATION
	if grounded and is_instance_valid(weather_surfaces):
		var surface := weather_surfaces.movement_surface(global_position)
		if bool(surface.deep_snow):
			target_velocity *= Tuning.DEEP_SNOW_SPEED
			acceleration *= Tuning.DEEP_SNOW_TRACTION if sprinting else Tuning.DEEP_SNOW_WALK_TRACTION
		elif bool(surface.ice):
			acceleration *= Tuning.ICE_BRAKING
		elif float(surface.wet) > 0.05:
			acceleration *= Tuning.WET_SPRINT_BRAKING if sprinting else Tuning.WET_WALK_BRAKING
		if bool(surface.puddle):
			target_velocity *= Tuning.PUDDLE_SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if wish_direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-wish_direction.x, -wish_direction.z), 12.0 * delta)
	_move_and_report_landing()


func predict_movement_input(sequence: int, direction: Vector2, sprinting: bool, jump_pressed: bool, delta: float) -> void:
	if _is_eliminated or is_knocked_down():
		_prediction_inputs.clear()
		return
	_prediction_inputs.append({"sequence": sequence, "direction": direction, "sprinting": sprinting, "jump_pressed": jump_pressed, "yaw": _camera_yaw, "delta": delta})
	if _prediction_inputs.size() > Tuning.PREDICTION_HISTORY_TICKS:
		_prediction_inputs.pop_front()
	apply_movement_input(direction, sprinting, jump_pressed, delta)


func get_movement_replay_state() -> Vector3:
	return Vector3(_coyote_remaining, _jump_buffer_remaining, 1.0 if is_on_floor() else 0.0)


func effective_walk_speed() -> float:
	return Tuning.WALK_SPEED * (Tuning.POWERUP_SPEED_MULTIPLIER if int(movement_buff.x) == MatchPowerups.Kind.SPEED and movement_buff.y > 0.0 else 1.0)


func effective_sprint_speed() -> float:
	return Tuning.SPRINT_SPEED * (Tuning.POWERUP_SPEED_MULTIPLIER if int(movement_buff.x) == MatchPowerups.Kind.SPEED and movement_buff.y > 0.0 else 1.0)


func reconcile_movement(server_position: Vector3, server_velocity: Vector3, facing: float, knocked_down: bool, sequence: int, state: Vector3, buff := Vector2.ZERO) -> void:
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
	# Rewind the buff clock with position before replaying pending inputs.
	# The slower match snapshot is for HUD/drops, never movement tuning.
	movement_buff = buff
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
		apply_movement_input(movement_input.direction, movement_input.sprinting, movement_input.jump_pressed, movement_input.delta, grounded)
		grounded = -1
	_camera_yaw = aiming_yaw


func apply_knockdown(impulse: Vector3) -> void:
	if _is_eliminated or _knockdown_remaining > 0.0:
		return
	cancel_emote()
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


func set_network_grounded(grounded: bool) -> void:
	_network_grounded = 1 if grounded else 0


func _spawn_cosmetic_ragdoll(initial_velocity: Vector3, impulse: Vector3) -> void:
	if is_instance_valid(_ragdoll):
		return
	_ragdoll = RagdollScene.new()
	get_parent().add_child(_ragdoll)
	# Retain live visual heading without scaling any existing physics bodies.
	_ragdoll.global_transform = Transform3D(visual.global_basis.orthonormalized(), global_position)
	_ragdoll.copy_appearance(character)
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
	velocity = (velocity + velocity_change).limit_length(maxf(speed_cap, 0.0))


func is_knocked_down() -> bool:
	return _knockdown_remaining > 0.0


func set_eliminated(eliminated: bool) -> void:
	_is_eliminated = eliminated
	if eliminated:
		movement_buff = Vector2.ZERO
		_prediction_inputs.clear()
		velocity = Vector3.ZERO
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_knockdown_remaining = 0.0
		_clear_cosmetic_ragdoll()
	visual.visible = not eliminated
	collider.set_deferred("disabled", eliminated)


func reset_for_match(spawn_position: Vector3) -> void:
	cancel_emote()
	movement_buff = Vector2.ZERO
	if is_instance_valid(_ragdoll):
		_ragdoll.queue_free()
		_ragdoll = null
	_knockdown_remaining = 0.0
	_get_up_remaining = 0.0
	_landing_remaining = 0.0
	_presentation_airborne = false
	_network_grounded = -1
	_fall_peak = NAN
	_shove_cue_remaining = 0.0
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
	_update_capsule()
	if is_instance_valid(character):
		character.play_clip("idle")


func configure_identity(peer_id: int) -> void:
	_peer_id = peer_id
	character.set_player_color(peer_id - 1)


func configure_shoving(manager: Node) -> void:
	_shove_manager = manager


func play_shove_cue() -> void:
	_shove_cue_remaining = 0.3


func configure_emotes(gateway: Node) -> void:
	_emote_gateway = gateway


func request_emote(emote_id: int) -> void:
	if is_instance_valid(_emote_gateway):
		_emote_gateway.request_local_emote(_peer_id, emote_id)


func start_emote(emote_id: int, duration: float) -> void:
	_emote_id = emote_id
	_emote_remaining = duration


func cancel_emote() -> void:
	_emote_id = 0
	_emote_remaining = 0.0


func get_emote_id() -> int:
	return _emote_id


func can_perform_actions() -> bool:
	return not _is_eliminated and _knockdown_remaining <= 0.0


func get_forward_direction() -> Vector3:
	return Basis(Vector3.UP, _camera_yaw) * Vector3.FORWARD


func get_head_sample_position() -> Vector3:
	return global_position + Vector3.UP * (Tuning.STANDING_HEIGHT - 0.15)


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
	_move_and_report_landing()
	if _knockdown_remaining <= 0.0:
		_clear_cosmetic_ragdoll()
		_update_capsule()


func _move_and_report_landing() -> void:
	var airborne := not is_on_floor()
	# Measure the actual descent, not velocity (impulses can exaggerate impact).
	if not airborne or is_nan(_fall_peak):
		_fall_peak = global_position.y
	_fall_peak = maxf(_fall_peak, global_position.y)
	move_and_slide()
	_fall_peak = maxf(_fall_peak, global_position.y)
	if is_on_floor():
		var fall_height := maxf(_fall_peak - global_position.y, 0.0)
		_fall_peak = global_position.y
		if airborne and fall_height > 0.0:
			landed.emit(fall_height)


func _update_capsule() -> void:
	var capsule := collider.shape as CapsuleShape3D
	var target_height := Tuning.STANDING_HEIGHT
	capsule.height = target_height
	collider.position.y = target_height * 0.5


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
