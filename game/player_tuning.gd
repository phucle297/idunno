class_name PlayerTuning
extends RefCounted

const WALK_SPEED := 4.5
const SPRINT_SPEED := 6.5
const CROUCH_SPEED := 2.5
const GROUND_ACCELERATION := 25.0
const AIR_ACCELERATION := 8.0
const GRAVITY := 20.0
const JUMP_HEIGHT := 1.35
const JUMP_VELOCITY := sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const STANDING_HEIGHT := 1.5
const CROUCHED_HEIGHT := 0.95
const CAPSULE_RADIUS := 0.28
const KNOCKDOWN_MIN_TIME := 0.6
const KNOCKDOWN_DURATION := 1.4
