class_name PlayerTuning
extends RefCounted

const WALK_SPEED := 4.5
const SPRINT_SPEED := 6.5
const GROUND_ACCELERATION := 25.0
const WET_SPRINT_BRAKING := 0.78
const WET_WALK_BRAKING := 0.9
const DEEP_SNOW_TRACTION := 0.48
const DEEP_SNOW_WALK_TRACTION := 0.72
const DEEP_SNOW_SPEED := 0.72
const ICE_BRAKING := 0.3
const PUDDLE_SPEED := 0.82
const AIR_ACCELERATION := 8.0
const GRAVITY := 20.0
const FALL_DAMAGE_SAFE_HEIGHT := 4.0
const FALL_DAMAGE_LETHAL_HEIGHT := 12.0
# T6/T15: piecewise-linear fall damage (x = fall height in metres, y = HP of 100).
# Drops up to 4 m are free (T15: jumps, stairs, ledges, deck jump-offs); the
# ramp 4.0-4.7 m reaches the roof band. Roof falls (step-off, jump-off,
# tornado/UFO carry-off, ~4.7-7.5 m) cost about 1/3 HP; 12 m or more is lethal.
const FALL_DAMAGE_CURVE := [Vector2(4, 0), Vector2(4.7, 32), Vector2(7.5, 36), Vector2(12, 100)]
const JUMP_HEIGHT := 1.35
const JUMP_VELOCITY := sqrt(2.0 * GRAVITY * JUMP_HEIGHT)

const POWERUP_SPEED_MULTIPLIER := 1.2
const POWERUP_JUMP_HEIGHT_MULTIPLIER := 1.2
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const STEP_HEIGHT := 0.30 # DESIGN §8: climb square lips up to 0.30 m without jumping.
# Foot probe (T2 a4): a flat cylinder, narrower than the capsule, cast down from
# just above the soles after a grounded move; a walkable floor this close
# keeps the floor contact when the capsule's own contact drops for a tick.
const FOOT_PROBE_RADIUS := 0.22
const FOOT_PROBE_THICKNESS := 0.02
const FOOT_PROBE_START := 0.01 # cast starts this far above the soles
const FOOT_PROBE_DEPTH := 0.03 # and reaches this far below them
const STANDING_HEIGHT := 1.5
const CAPSULE_RADIUS := 0.28
const PREDICTION_HISTORY_TICKS := 60
const KNOCKDOWN_MIN_TIME := 0.6
const KNOCKDOWN_DURATION := 1.4
const SHOVE_RANGE := 2.2
const SHOVE_MIN_FORWARD_DOT := 0.5
const SHOVE_COOLDOWN := 2.0
const SHOVE_PROTECTION := 2.5
const EMOTE_REQUEST_COOLDOWN := 1.5
const SHOVE_IMPULSE := 6.0
const SHOVE_MAX_HORIZONTAL_SPEED := 8.0


# T6: damage in HP (of 100) for a landing after falling fall_height metres.
# Monotone non-decreasing; pure function of the height (no clock reads).
static func fall_damage(fall_height: float) -> float:
	if fall_height <= FALL_DAMAGE_SAFE_HEIGHT:
		return 0.0
	if fall_height >= FALL_DAMAGE_LETHAL_HEIGHT:
		return 100.0
	for index in range(1, FALL_DAMAGE_CURVE.size()):
		var upper: Vector2 = FALL_DAMAGE_CURVE[index]
		if fall_height <= upper.x:
			var lower: Vector2 = FALL_DAMAGE_CURVE[index - 1]
			return lerpf(lower.y, upper.y, (fall_height - lower.x) / (upper.x - lower.x))
	return 100.0
