class_name PartyPlayer
extends CharacterBody3D

const Tuning = preload("res://game/player_tuning.gd")

@onready var visual: Node3D = $Visual
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot

var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _knockdown_remaining := 0.0
var _is_crouched := false
var _camera_yaw := 0.0
var _camera_pitch := -0.14


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_capsule(false)
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		$CameraPivot/SpringArm3D/Camera3D.current = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _accepts_local_input():
		_camera_yaw -= event.relative.x * 0.0025
		_camera_pitch = clampf(_camera_pitch - event.relative.y * 0.0025, -1.1, 0.35)
		camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not _accepts_local_input():
		return
	if Input.is_action_just_pressed("knockdown_test"):
		apply_knockdown(Vector3.RIGHT * 4.0)
	apply_movement_input(
		Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		Input.is_action_pressed("sprint"),
		Input.is_action_pressed("crouch"),
		Input.is_action_just_pressed("jump"),
		delta
	)


func apply_movement_input(
	input_2d: Vector2,
	sprinting: bool,
	crouched: bool,
	jump_pressed: bool,
	delta: float
) -> void:
	if _knockdown_remaining > 0.0:
		_process_knockdown(delta)
		return
	if is_on_floor():
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
	var target_velocity := wish_direction * target_speed
	var acceleration := Tuning.GROUND_ACCELERATION if is_on_floor() else Tuning.AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if wish_direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(wish_direction.x, wish_direction.z), 12.0 * delta)
	move_and_slide()


func apply_knockdown(impulse: Vector3) -> void:
	if _knockdown_remaining > 0.0:
		return
	_knockdown_remaining = Tuning.KNOCKDOWN_DURATION
	velocity += impulse.limit_length(8.0)
	visual.rotation.z = deg_to_rad(78.0)


func is_knocked_down() -> bool:
	return _knockdown_remaining > 0.0


func _process_knockdown(delta: float) -> void:
	_knockdown_remaining -= delta
	velocity.y -= Tuning.GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	move_and_slide()
	if _knockdown_remaining <= 0.0 and is_on_floor():
		visual.rotation.z = 0.0
		_update_capsule(false)


func _update_capsule(crouched: bool) -> void:
	var capsule := collider.shape as CapsuleShape3D
	var target_height := Tuning.CROUCHED_HEIGHT if crouched else Tuning.STANDING_HEIGHT
	capsule.height = target_height
	collider.position.y = target_height * 0.5
	visual.scale.y = 0.72 if crouched else 1.0


func _accepts_local_input() -> bool:
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
