class_name PartyPlayer
extends CharacterBody3D

signal landed(fall_height: float)

const Tuning = preload("res://game/player/player_tuning.gd")
const RagdollScene = preload("res://game/player/cosmetic_ragdoll.gd")

const EMOTE_WAVE := 1
const EMOTE_CHEER := 2
const EMOTE_CLIPS := {EMOTE_WAVE: "wave", EMOTE_CHEER: "cheer"}
const EMOTE_DURATIONS := {EMOTE_WAVE: 1.2, EMOTE_CHEER: 1.0}
const STEP_DOWN_MARGIN := 0.1 # step-up: down sweep reaches this far below the start
const STEP_PROBE_EXTRA := 0.02 # step-up: blocked-probe reach past this tick's motion
const STEP_OVERLAP_TOLERANCE := 0.002 # step-up: landing overlap that triggers a split re-sweep
const STEP_STAND_CLEARANCE := 0.05 # step-up: headroom check height above the lip top
const STEP_SETTLE := 0.002 # step-up: downward settle after a step, registers the floor contact
const STEP_NONE := -1.0
const STEP_KEEP_SPEED := -2.0
const STEP_CORNER_MAX_ANGLE := deg_to_rad(85.0) # step-up: steepest lip-corner contact to step onto
const STEP_DEPENETRATE := 0.06 # max upward recovery of a 2-5 cm step-top sink this tick

@onready var visual: Node3D = $Visual
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var character: ToyCharacterVisual = $Visual/Character

var _coyote_remaining := 0.0
# T6 fall credit: a disaster that carries/throws this player names the next
# landing's fall damage. Kept until that landing; if the player stays grounded
# it expires after FALL_CREDIT_GROUNDED_TICKS physics ticks (tick count, no clock).
const FALL_CREDIT_GROUNDED_TICKS := 30
var _fall_credit := ""
var _fall_credit_grounded_ticks := 0
var _jump_buffer_remaining := 0.0
var _knockdown_remaining := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.28
var _ragdoll: Node3D
var _is_eliminated := false
var _get_up_remaining := 0.0
var _landing_remaining := 0.0
var _presentation_airborne := false
var _foot_probe_shape: CylinderShape3D
var _network_grounded := -1
var _fall_peak := NAN
var _shove_manager: Node
var _shove_cue_remaining := 0.0
var _emote_gateway: Node
var _emote_id := 0
var _emote_remaining := 0.0
var _peer_id := 1
var local_input_blocked := false
var world_loaded := true
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
	if not world_loaded:
		return
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
	if grounded and is_instance_valid(weather_surfaces):
		# Render on observers too; a headless authority cannot draw their tracks.
		weather_surfaces.leave_footprint(_peer_id, global_position)
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


## test-only: headless has no OS pointer grab (mouse_mode always reads
## VISIBLE), so tests set this to drive the real left-click toy/bomb path.
## Ignored on any real display server; never set it in game code (T25).
static var headless_pointer_captured := false


static func pointer_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (headless_pointer_captured and DisplayServer.get_name() == "headless")


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
		and not pointer_captured()
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * 0.0025 * mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch - event.relative.y * 0.0025 * mouse_sensitivity * (-1.0 if invert_y else 1.0), -1.1, 0.35)
		camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)


func _physics_process(delta: float) -> void:
	if not world_loaded or _is_eliminated or not accepts_local_input():
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
	# Replay from an airborne server state must not snap with the client's
	# own (later) floor contact; the server did not snap on this tick either.
	var snap := floor_snap_length
	if grounded_override == 0:
		floor_snap_length = 0.0
	_move_and_report_landing(grounded and velocity.y <= 0.0, delta)
	floor_snap_length = snap


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
	_fall_credit = ""
	_fall_credit_grounded_ticks = 0
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


func _move_and_report_landing(allow_step := false, delta := 0.0) -> void:
	var airborne := not is_on_floor()
	# Measure the actual descent, not velocity (impulses can exaggerate impact).
	if not airborne or is_nan(_fall_peak):
		_fall_peak = global_position.y
	_fall_peak = maxf(_fall_peak, global_position.y)
	var step_contact_angle := _step_up(delta) if allow_step else STEP_NONE
	if step_contact_angle == STEP_KEEP_SPEED:
		# Climbable lip just ahead: normal move, but keep the speed the face
		# would zero, and stay grounded so the next tick steps.
		var kept_velocity := velocity
		move_and_slide()
		velocity.x = kept_velocity.x
		velocity.z = kept_velocity.z
	if step_contact_angle >= 0.0 or (step_contact_angle == STEP_KEEP_SPEED and not is_on_floor()):
		# Already moved this tick. Refresh floor contact with a 2 mm settle (no
		# snap) so the next tick is grounded, keeping horizontal speed; after a
		# step the rounded capsule may rest on the lip's corner, so that
		# contact counts as floor.
		var kept_velocity := velocity
		var max_angle := floor_max_angle
		var snap := floor_snap_length
		floor_max_angle = maxf(max_angle, step_contact_angle + 0.01)
		floor_snap_length = 0.0
		velocity = -up_direction * (STEP_SETTLE / maxf(delta, 1e-4))
		move_and_slide()
		floor_max_angle = max_angle
		floor_snap_length = snap
		velocity = Vector3(kept_velocity.x, 0.0, kept_velocity.z)
	elif step_contact_angle == STEP_NONE:
		# body_test_motion can miss a graze that move_and_slide then zeroes
		# (QA 0.28 m walk at (37.31, 743.7) k=4). Restore speed only when a
		# climbable lip is immediately ahead, not when we ran into a wall.
		var kept_velocity := velocity
		move_and_slide()
		if allow_step:
			var kept_h := Vector2(kept_velocity.x, kept_velocity.z).length()
			var now_h := Vector2(velocity.x, velocity.z).length()
			if kept_h > 1.0 and now_h < 0.25 * kept_h and is_on_floor() and velocity.y <= 0.05 and _climbable_lip_ahead(kept_velocity, delta):
				velocity.x = kept_velocity.x
				velocity.z = kept_velocity.z
	if allow_step and not is_on_floor() and velocity.y <= 0.0:
		_settle_on_probed_floor(delta)
	if velocity.y <= 0.0:
		_depenetrate_walkable_floor()
	_fall_peak = maxf(_fall_peak, global_position.y)
	if is_on_floor():
		var fall_height := maxf(_fall_peak - global_position.y, 0.0)
		_fall_peak = global_position.y
		if airborne and fall_height > 0.0:
			landed.emit(fall_height)
		elif not airborne and _fall_credit != "":
			_fall_credit_grounded_ticks += 1
			if _fall_credit_grounded_ticks >= FALL_CREDIT_GROUNDED_TICKS:
				_fall_credit = ""
				_fall_credit_grounded_ticks = 0


# T6: called on authority by a disaster that carries or throws this player.
func credit_fall_to(disaster: String) -> void:
	_fall_credit = disaster
	_fall_credit_grounded_ticks = 0


# T6: returns and clears the current fall credit ("" when none).
func take_fall_credit() -> String:
	var credit := _fall_credit
	_fall_credit = ""
	_fall_credit_grounded_ticks = 0
	return credit


# Classic step-up (up / forward / down sweep), DESIGN §8. Runs before
# move_and_slide on grounded ticks, so a lip's face never zeroes velocity:
# if this tick's horizontal motion is blocked, sweep up by STEP_HEIGHT, forward
# by exactly this tick's motion (no extra pop), then down by the lift plus a
# margin. The step is taken only when it ends higher than the start, the lip's
# top surface (read by a short ray just inside the contact) is walkable, no
# more than STEP_HEIGHT above the feet and within the (ceiling-limited) lift,
# and the capsule fits standing on it. Otherwise nothing moves here and the
# normal move_and_slide runs. Ramps are left to move_and_slide (slope speed
# unchanged). Shared by local, predicted, replayed and server movement (all go
# through apply_movement_input). Returns the landing contact's angle from up,
# STEP_KEEP_SPEED when a climbable lip is just out of reach, or STEP_NONE.
func _step_up(delta: float) -> float:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 1e-8:
		return STEP_NONE
	# Start from a clean pose: after riding a lip corner the body can rest
	# slightly inside it, which would make every sweep below stop at once.
	var start := global_transform
	start = start.translated(_recovery(start))
	# Probe slightly past this tick's motion: move_and_slide also collides with
	# a face it only grazes within the safe margin.
	var probe_motion := motion + motion.normalized() * STEP_PROBE_EXTRA
	var blocked := _sweep(start, probe_motion, 4)
	if blocked == null or blocked.get_travel().length() >= probe_motion.length() - 1e-4:
		return STEP_NONE
	# The floor under the feet is reported too; the blocker is the steepest contact.
	var face_angle := 0.0
	var face_index := 0
	for index in blocked.get_collision_count():
		var angle := blocked.get_collision_normal(index).angle_to(up_direction)
		if angle > face_angle:
			face_angle = angle
			face_index = index
	var face_point: Vector3 = blocked.get_collision_point(face_index)
	var face_normal: Vector3 = blocked.get_collision_normal(face_index)
	var early_top := _step_top(start, face_point, face_normal, motion, 0.01)
	# A steep face with a walkable top no higher than STEP_HEIGHT: if this tick
	# cannot finish the step, keep speed instead of letting move_and_slide zero it.
	var climbable := early_top.x >= 0.0 and early_top.y <= Tuning.STEP_HEIGHT + 0.005
	# 3 cm of temporary extra lift helps the down sweep register a 0.28 m lip
	# when this tick only just reaches the face (walk k=7). Not a forward pop.
	var lift := up_direction * (Tuning.STEP_HEIGHT + 0.03)
	var ceiling := _sweep(start, lift, 1)
	if ceiling != null:
		lift = ceiling.get_travel()
	if lift.dot(up_direction) < 0.02:
		return STEP_NONE
	if climbable:
		climbable = early_top.y <= lift.dot(up_direction) + 0.005
	var keep := climbable
	var raised := start.translated(lift)
	if _sweep(raised, motion, 1) != null:
		return STEP_KEEP_SPEED if keep else STEP_NONE
	var ahead := raised.translated(motion)
	var down := _sweep_down(ahead, -lift - up_direction * STEP_DOWN_MARGIN)
	if down.is_empty():
		return STEP_KEEP_SPEED if keep else STEP_NONE
	var landed := ahead.translated(down.travel)
	# Stepped only if the down sweep rests on something above the start floor.
	var stepped := ((down.point as Vector3) - start.origin).dot(up_direction) >= 0.001 \
		and (landed.origin - start.origin).dot(up_direction) >= 0.001
	# Walkability is judged on the lip's top surface, read by a short ray just
	# inside the landing contact (the round bottom may only touch the corner),
	# or, when this tick's motion does not reach the lip yet, inside the face.
	var contact: Vector3 = down.point if stepped else face_point
	var contact_normal: Vector3 = down.normal if stepped else face_normal
	var top := _step_top(start, contact, contact_normal, motion, 0.001 if stepped else 0.01)
	var top_angle := top.x
	# No walkable top, or the lift (cut short by a ceiling) cannot clear it.
	if top_angle < 0.0 or top.y > lift.dot(up_direction) + 0.005 or top.y > Tuning.STEP_HEIGHT + 0.005:
		return STEP_KEEP_SPEED if keep else STEP_NONE
	# The capsule must fit standing on the top just past the edge (no stepping
	# into a gap lower than the capsule); checked a little above the top so a
	# tilted top does not count as an overlap.
	var stand := contact + _inward_of(contact_normal, motion) * 0.01
	stand += up_direction * (start.origin + up_direction * (top.y + STEP_STAND_CLEARANCE) - stand).dot(up_direction)
	if _recovery(Transform3D(start.basis, stand)).length() > STEP_OVERLAP_TOLERANCE:
		return STEP_KEEP_SPEED if keep else STEP_NONE
	# Blocked by a walkable plane that continues as the "top": a ramp, not a lip.
	# (A face angle near 0 means only the floor under the feet was reported.)
	if face_angle > deg_to_rad(1.0) and face_angle <= floor_max_angle and top_angle > face_angle - deg_to_rad(1.0):
		return STEP_NONE
	if not stepped or contact_normal.angle_to(up_direction) > STEP_CORNER_MAX_ANGLE:
		# A climbable lip is just ahead but this tick's motion does not reach
		# it (or only grazes its corner): move normally but keep the speed,
		# so the next tick steps from the face.
		return STEP_KEEP_SPEED
	global_transform = landed
	return contact_normal.angle_to(up_direction)


# A grounded move that ends without floor contact although a walkable floor is
# right under the feet (the capsule can end a tick hovering about one safe
# margin above a flat top, e.g. after a step) settles onto it, so the contact
# does not drop for a tick. A real edge or drop is left alone: the probe finds
# no floor within FOOT_PROBE_DEPTH, or starts inside the lip the capsule rests on.

func _climbable_lip_ahead(kept_velocity: Vector3, delta: float) -> bool:
	var motion := Vector3(kept_velocity.x, 0.0, kept_velocity.z) * maxf(delta, 1e-4)
	if motion.length_squared() < 1e-8:
		return false
	var blocked := _sweep(global_transform, motion + motion.normalized() * STEP_PROBE_EXTRA, 4)
	if blocked == null:
		return false
	var face_angle := 0.0
	var face_index := 0
	for index in blocked.get_collision_count():
		var angle := blocked.get_collision_normal(index).angle_to(up_direction)
		if angle > face_angle:
			face_angle = angle
			face_index = index
	if face_angle <= floor_max_angle:
		return false
	var top := _step_top(global_transform, blocked.get_collision_point(face_index), blocked.get_collision_normal(face_index), motion, 0.01)
	return top.x >= 0.0 and top.y <= Tuning.STEP_HEIGHT + 0.005


func _settle_on_probed_floor(delta: float) -> void:
	var gap := _foot_probe_gap(global_transform)
	if is_nan(gap):
		gap = _capsule_floor_gap(0.06)
	if is_nan(gap) or delta <= 0.0:
		return
	var kept_velocity := velocity
	var snap := floor_snap_length
	floor_snap_length = 0.0
	velocity = -up_direction * ((maxf(gap, 0.0) + STEP_SETTLE) / delta)
	move_and_slide()
	floor_snap_length = snap
	velocity = kept_velocity


# If the capsule has sunk a small amount into a walkable floor (the 2-5 cm
# one-tick step-top dips new in attempt 4), push it back up. The existing
# ~8 cm move_and_slide snap sinks on main are left alone.
func _depenetrate_walkable_floor() -> void:
	var push := _recovery(global_transform)
	var up_comp := push.dot(up_direction)
	var sideways := (push - up_direction * up_comp).length()
	if up_comp > 0.005 and up_comp <= STEP_DEPENETRATE and sideways <= 0.01:
		global_transform = global_transform.translated(up_direction * up_comp)


# Fallback when the cylinder foot probe misses (large-coordinate precision):
# the body's own capsule swept a short way down onto a walkable floor.
func _capsule_floor_gap(depth: float) -> float:
	var hit := _sweep(global_transform, -up_direction * depth, 1)
	if hit == null:
		return NAN
	if hit.get_collision_normal(0).angle_to(up_direction) > floor_max_angle:
		return NAN
	return hit.get_travel().length()


# Foot probe: synchronous cylinder cast (same mask as the body) from
# FOOT_PROBE_START above the soles to FOOT_PROBE_DEPTH below them. Returns the
# gap from the soles down to a walkable floor (negative if slightly above the
# soles), or NAN if there is none or the cast starts overlapping.
func _foot_probe_gap(pose: Transform3D) -> float:
	if _foot_probe_shape == null:
		_foot_probe_shape = CylinderShape3D.new()
		_foot_probe_shape.radius = Tuning.FOOT_PROBE_RADIUS
		_foot_probe_shape.height = Tuning.FOOT_PROBE_THICKNESS
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = _foot_probe_shape
	parameters.collision_mask = collision_mask
	parameters.exclude = [get_rid()]
	parameters.transform = Transform3D(pose.basis, pose.origin + up_direction * (Tuning.FOOT_PROBE_START + Tuning.FOOT_PROBE_THICKNESS * 0.5))
	parameters.motion = -up_direction * (Tuning.FOOT_PROBE_START + Tuning.FOOT_PROBE_DEPTH)
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(parameters)
	if fractions.size() < 2 or fractions[1] >= 1.0 or fractions[1] <= 0.0:
		return NAN
	parameters.transform = parameters.transform.translated(parameters.motion * fractions[1])
	var rest := space.get_rest_info(parameters)
	if rest.is_empty() or (rest.normal as Vector3).angle_to(up_direction) > floor_max_angle:
		return NAN
	return parameters.motion.length() * fractions[0] - Tuning.FOOT_PROBE_START


# (angle from up, rise above the feet at `start`) of the walkable lip top just
# inside `contact`; angle -1 if there is no walkable top min_rise..STEP_HEIGHT up
# (a small min_rise lets the capsule finish riding over a lip's corner).
func _step_top(start: Transform3D, contact: Vector3, contact_normal: Vector3, motion: Vector3, min_rise: float) -> Vector2:
	var best_miss := Vector2(-1.0, 0.0)
	var inward := _inward_of(contact_normal, motion)
	for distance: float in [0.02, 0.05, 0.08]:
		var probe := contact + inward * distance
		var from := probe + up_direction * ((start.origin - probe).dot(up_direction) + Tuning.STEP_HEIGHT + 0.05)
		var query := PhysicsRayQueryParameters3D.create(from, probe - up_direction * 0.05, collision_mask, [get_rid()])
		var top := get_world_3d().direct_space_state.intersect_ray(query)
		if top.is_empty():
			continue
		var top_angle := (top.normal as Vector3).angle_to(up_direction)
		var top_rise := ((top.position as Vector3) - start.origin).dot(up_direction)
		if top_angle > floor_max_angle or top_rise < min_rise or top_rise > Tuning.STEP_HEIGHT + 0.005:
			best_miss = Vector2(-1.0, top_rise)
			continue
		return Vector2(top_angle, top_rise)
	return best_miss


# Down sweep whose resting pose is checked: a capsule sweep against a box edge
# can occasionally stop inside the edge, so if the end pose overlaps, sweep
# again in two halves and keep the cleaner result, pushed out of any overlap.
# Returns {travel, point, normal}, or {} if nothing is below.
func _sweep_down(from: Transform3D, motion: Vector3) -> Dictionary:
	var best := {}
	for attempt in 2:
		var parts := [motion] if attempt == 0 else [motion * 0.5, motion * 0.5]
		var offset := Vector3.ZERO
		for part: Vector3 in parts:
			var hit := _sweep(from.translated(offset), part, 1)
			if hit == null:
				offset += part
				continue
			offset += hit.get_travel()
			var push := _recovery(from.translated(offset))
			if best.is_empty() or push.length() < (best.push as Vector3).length():
				best = {"travel": offset + push, "push": push, "point": hit.get_collision_point(0), "normal": hit.get_collision_normal(0)}
			break
		if not best.is_empty() and (best.push as Vector3).length() <= STEP_OVERLAP_TOLERANCE:
			break
	return best


# Horizontal direction into the solid at a contact (fallback: along the motion).
func _inward_of(contact_normal: Vector3, motion: Vector3) -> Vector3:
	var inward := -(contact_normal - up_direction * contact_normal.dot(up_direction))
	return inward.normalized() if inward.length_squared() > 1e-6 else motion.normalized()


# How far the body would be pushed out of overlaps at `pose` (zero when it only touches).
func _recovery(pose: Transform3D) -> Vector3:
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = pose
	parameters.motion = Vector3.ZERO
	parameters.margin = safe_margin
	var result := PhysicsTestMotionResult3D.new()
	PhysicsServer3D.body_test_motion(get_rid(), parameters, result)
	return result.get_travel()


func _sweep(from: Transform3D, motion: Vector3, max_collisions: int) -> PhysicsTestMotionResult3D:
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = from
	parameters.motion = motion
	parameters.margin = safe_margin
	parameters.max_collisions = max_collisions
	var result := PhysicsTestMotionResult3D.new()
	return result if PhysicsServer3D.body_test_motion(get_rid(), parameters, result) else null


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
