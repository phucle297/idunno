class_name ToyCharacterVisual
extends Node3D

const REQUIRED_CLIPS := [
	"idle", "walk", "run", "jump_takeoff", "falling", "landing",
	"get_up", "shove", "wave", "cheer",
]
const LOCOMOTION_CLIPS := ["idle", "walk", "run"]
const GAIT_REACH := 0.36
const SUIT_COLORS := [
	Color("31c5df"), Color("f28a3c"), Color("9b72e8"),
	Color("8fcf4f"), Color("e66ba8"), Color("4f86e8"),
]
const BACK_ACCESSORY_OUTFITS := [3, 4, 6, 7, 9]
const HEAD_PARTS := ["Head", "FacePlate", "LeftEye", "RightEye", "Mouth"]
## Runtime mirror of tools/asset_generation/critter_parts.gd (tools/ is not exported;
## test_critter_asset asserts these stay in sync).
const CRITTER_PARTS_DIR := "res://assets/models/critter/parts"
const CRITTER_SPECIES := ["bear", "cat", "bunny", "bear", "cat", "bunny", "bear", "cat", "bunny", "bear", "cat", "bunny"]
const ACCESSORY_ORIGIN := Vector3(0.0, 0.603, 0.0)
const Tuning = preload("res://game/player/player_tuning.gd")
## KayKit Rogue_Hooded faces model +Z; yaw it to the game's -Z front and scale
## the 2.25-unit hood figure to the ~1.4 m toy height.
const MODEL_BASE := Transform3D(Vector3(-0.62, 0, 0), Vector3(0, 0.62, 0), Vector3(0, 0, -0.62), Vector3.ZERO)
const BONE_MAP := {
	"Torso": "chest", "Head": "head",
	"LeftArm": "upperarm.l", "RightArm": "upperarm.r",
	"LeftLeg": "upperleg.l", "RightLeg": "upperleg.r",
}
## Arms hang from the KayKit T-pose (model-space roll about Z per side).
const ARM_DOWN_ANGLE := 1.2217305
## T45 arm overlay (code only, idle/walk/run): relaxed rest pose (A) plus counter-phase
## swing vs the A3 gait (B). Other clips, and the right arm while an item is held,
## ease back to the legacy proxy pose exactly.
const ARM_RELAX_ABDUCTION := 0.21
const ARM_RELAX_ELBOW := 0.38
const ARM_RELAX_PITCH := 0.10
const ARM_SWING_WALK := 0.30
const ARM_SWING_RUN := 0.52
const ARM_RELAX_EASE := 0.12
const ARM_RELAX_CLIPS := ["idle", "walk", "run"]
const ARM_ELBOW_AXIS := Vector3.BACK
const ARM_ELBOW_SIGN_L := -1.0
const ARM_ELBOW_SIGN_R := 1.0
## Plop-toddle waddle (AC12): whole-body side roll about the planted foot plus a
## small bob; arms and legs never swing.
const WADDLE_CYCLE_M := 1.8
const WADDLE_WALK_ROLL := 0.10471976
const WADDLE_RUN_ROLL := 0.17453293
const WADDLE_WALK_BOB := 0.030
const WADDLE_RUN_BOB := 0.050
const WADDLE_EASE_IN := 0.15
const WADDLE_EASE_OUT := 0.12
## AC12 A3 hop-step (Architect A3 gait delta): alternating leg steps on the sway clock,
## planted foot world-fixed, analytic 2-bone IK on the visible KayKit legs.
const STEP_HALF := 0.10
const STEP_LIFT_WALK := 0.05
const STEP_LIFT_RUN := 0.07
## Knee bend while stepping (body lowers by this much at full weight). The measured KayKit
## leg is almost straight at rest (hip->ankle 0.232 m vs leg 0.234 m), so without it the
## plan's reach clamp would cap the half step at 0.029 m.
const STANCE_CROUCH := 0.045
const SUIT_SOFTEN := Color("ece3d8")

static var _suit_material_cache: Dictionary = {}

var cosmetic_variant := 0
var current_clip := "idle"
var _animation_player: AnimationPlayer
var _clip_started := false
var _speed := 0.0
var _waddle_weight := 0.0
var _waddle_phase := 0.0
var _waddle := Transform3D.IDENTITY
var _model: Node3D
var _rig: Skeleton3D
var _bone_ids := {}
var _foot_ids := {}
var _handslot := -1
var _proxies := {}
var _rest_q := {}
var _chain_q := {}
var _chain_from_chest := {}
var _accessories: Node3D
var _legs := {}
var _hips_q := Quaternion.IDENTITY
var _step_half := STEP_HALF
var _legs_posed := false
var _suit_current: Material
var _item_held := false
var _arm_weight_l := 0.0
var _arm_weight_r := 0.0
var _arm_swing := 0.0
var _lowerarm_l := -1
var _lowerarm_r := -1
var _lowerarm_rest_l := Quaternion.IDENTITY
var _lowerarm_rest_r := Quaternion.IDENTITY
var _elbow_posed := false


static func catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/cosmetic_catalog.json")) as Dictionary


static func starter_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: Dictionary in catalog().items:
		if item.pool == "starter":
			ids.append(item.id)
	return ids


func _ready() -> void:
	ensure_runtime_setup()
	play_clip("idle")
	# Run after the child AnimationPlayer so the rig follows this frame's pose.
	process_priority = 1


func _process(delta: float) -> void:
	sync_rig(delta)


func ensure_runtime_setup() -> void:
	_build_skeleton_contract()
	_build_accessories()
	_build_animation_library()
	_bind_rig()
	set_cosmetic_variant(cosmetic_variant)


func get_hand_anchor() -> Marker3D:
	return get_node_or_null("RightArm/HandAnchor") as Marker3D


func play_clip(clip_name: String) -> bool:
	if not clip_name in REQUIRED_CLIPS or not is_instance_valid(_animation_player):
		return false
	# A non-looping presentation (notably takeoff) may finish while the player
	# is still airborne. Keep its terminal pose until state selection advances
	# to falling instead of restarting it every process frame.
	if current_clip == clip_name and _clip_started:
		return true
	# Locomotion clips share a gait cycle. When walk/run/idle replace one another
	# on a rapid Shift edge, restart the new clip at the same normalized phase
	# instead of at pose 0, so limbs do not snap back to the start of the cycle.
	var previous := current_clip
	var phase := 0.0
	if previous in LOCOMOTION_CLIPS and not _animation_player.current_animation.is_empty() and _animation_player.current_animation_length > 0.0:
		phase = clampf(_animation_player.current_animation_position / _animation_player.current_animation_length, 0.0, 1.0)
	current_clip = clip_name
	_animation_player.play(clip_name, 0.12 if previous in LOCOMOTION_CLIPS and clip_name in LOCOMOTION_CLIPS else 0.0)
	_clip_started = true
	if clip_name in LOCOMOTION_CLIPS and phase > 0.0:
		var length := _animation_player.current_animation_length
		if length > 0.0:
			_animation_player.seek(phase * length)
	return true


func set_locomotion_speed(speed: float) -> void:
	_speed = speed
	if not is_instance_valid(_animation_player):
		return
	# One full plop-toddle cycle (left + right contact) per WADDLE_CYCLE_M of travel.
	_animation_player.speed_scale = speed * _clip_duration(current_clip) / WADDLE_CYCLE_M if current_clip in ["walk", "run"] else 1.0


func _bind_rig() -> void:
	_model = get_node_or_null("Model") as Node3D
	_rig = get_node_or_null("Model/Rig/Skeleton3D") as Skeleton3D
	if _rig == null:
		return
	_foot_ids = {"l": _rig.find_bone("foot.l"), "r": _rig.find_bone("foot.r")}
	_handslot = _rig.find_bone("handslot.r")
	var chest := _rig.find_bone("chest")
	for proxy: String in BONE_MAP:
		var bone := _rig.find_bone(BONE_MAP[proxy])
		_bone_ids[proxy] = bone
		_proxies[proxy] = get_node(proxy)
		var rest_q := _rig.get_bone_global_rest(bone).basis.get_rotation_quaternion()
		if proxy == "LeftArm":
			rest_q = Quaternion(Vector3.BACK, -ARM_DOWN_ANGLE) * rest_q
		elif proxy == "RightArm":
			rest_q = Quaternion(Vector3.BACK, ARM_DOWN_ANGLE) * rest_q
		_rest_q[proxy] = rest_q
		# Parent global rotation = (posed chest or model root) * fixed rest chain,
		# so sync_rig never forces a skeleton update per bone.
		var parent := _rig.get_bone_parent(bone)
		var parent_q := _rig.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var ancestor := parent
		var under_chest := false
		while ancestor >= 0:
			if ancestor == chest and bone != chest:
				under_chest = true
				break
			ancestor = _rig.get_bone_parent(ancestor)
		_chain_from_chest[proxy] = under_chest
		_chain_q[proxy] = (_rig.get_bone_global_rest(chest).basis.get_rotation_quaternion().inverse() * parent_q) if under_chest else parent_q
	_accessories = get_node_or_null("Accessories") as Node3D
	_lowerarm_l = _rig.find_bone("lowerarm.l")
	_lowerarm_r = _rig.find_bone("lowerarm.r")
	if _lowerarm_l >= 0:
		_lowerarm_rest_l = _rig.get_bone_rest(_lowerarm_l).basis.get_rotation_quaternion()
	if _lowerarm_r >= 0:
		_lowerarm_rest_r = _rig.get_bone_rest(_lowerarm_r).basis.get_rotation_quaternion()
	_bind_legs()


func _bind_legs() -> void:
	var hips := _rig.find_bone("hips")
	_hips_q = _rig.get_bone_global_rest(hips).basis.get_rotation_quaternion()
	var reach := INF
	for side in ["l", "r"]:
		var upper := _rig.find_bone("upperleg." + side)
		var lower := _rig.find_bone("lowerleg." + side)
		var foot := _rig.find_bone("foot." + side)
		var rest_u := _rig.get_bone_global_rest(upper)
		var rest_l := _rig.get_bone_global_rest(lower)
		var rest_f := _rig.get_bone_global_rest(foot)
		var leg := {
			"upper": upper, "lower": lower, "foot": foot,
			"hip": rest_u.origin,
			"l1": rest_u.origin.distance_to(rest_l.origin), "l2": rest_l.origin.distance_to(rest_f.origin),
			"rest_u": rest_u.basis.get_rotation_quaternion(), "rest_l": rest_l.basis.get_rotation_quaternion(),
			"rest_f": rest_f.basis.get_rotation_quaternion(),
			"dir_u": (rest_l.origin - rest_u.origin).normalized(), "dir_l": (rest_f.origin - rest_l.origin).normalized(),
			"local_l": _rig.get_bone_rest(lower).basis.get_rotation_quaternion(),
			"local_f": _rig.get_bone_rest(foot).basis.get_rotation_quaternion(),
			"ankle_root": MODEL_BASE * rest_f.origin,
		}
		_legs[side] = leg
		# Reach clamp (plan section 2) in root metres, at the stepping knee bend.
		var length: float = (leg.l1 + leg.l2) * 0.62
		var height: float = (rest_u.origin.y - rest_f.origin.y) * 0.62 - STANCE_CROUCH
		reach = minf(reach, 0.9 * sqrt(maxf(length * length - height * height, 0.0)))
	_step_half = minf(STEP_HALF, reach)


## Stance duty per foot (fraction of the cycle the foot is planted).
func get_stance_duty() -> float:
	return 2.0 * _step_half / WADDLE_CYCLE_M


func get_step_half() -> float:
	return _step_half


static func _stance_centre(side: String) -> float:
	return 0.25 if side.to_lower().begins_with("l") else 0.75


## Root-space ankle target for the hop-step: planted feet move back at body speed
## (world-fixed), swing feet arc forward. Left stance is centred at phase 0.25 (the
## A2 roll pivot), right at 0.75.
func gait_foot_target(side: String, phase: float, speed: float) -> Vector3:
	var key := "l" if side.to_lower().begins_with("l") else "r"
	var ankle: Vector3 = _legs[key].ankle_root
	var duty := get_stance_duty()
	var offset := fposmod(phase - _stance_centre(key) + 0.5, 1.0) - 0.5
	if absf(offset) <= duty * 0.5:
		return Vector3(ankle.x, ankle.y, ankle.z + offset * WADDLE_CYCLE_M)
	var swing := fposmod(offset - duty * 0.5, 1.0) / (1.0 - duty)
	var blend := clampf(inverse_lerp(Tuning.WALK_SPEED, Tuning.SPRINT_SPEED, speed), 0.0, 1.0)
	var lift := lerpf(STEP_LIFT_WALK, STEP_LIFT_RUN, blend)
	var z := _step_half - 2.0 * _step_half * smoothstep(0.0, 1.0, swing)
	return Vector3(ankle.x, ankle.y + lift * sin(PI * swing), ankle.z + z)


## True while this foot is in its stance window of a walk/run cycle.
func is_foot_planted(side: String) -> bool:
	if _waddle_weight <= 0.0 or not current_clip in ["walk", "run"]:
		return false
	var offset := fposmod(_waddle_phase - _stance_centre(side) + 0.5, 1.0) - 0.5
	return absf(offset) <= get_stance_duty() * 0.5


func _solve_leg(key: String, model_inverse: Transform3D, model_roll: Quaternion) -> void:
	var leg: Dictionary = _legs[key]
	var target_root: Vector3 = (leg.ankle_root as Vector3).lerp(gait_foot_target(key, _waddle_phase, _speed), _waddle_weight)
	var hip: Vector3 = leg.hip
	var l1: float = leg.l1
	var l2: float = leg.l2
	var to_target := model_inverse * target_root - hip
	var distance := clampf(to_target.length(), absf(l1 - l2) + 0.0001, 0.999 * (l1 + l2))
	var direction := to_target.normalized()
	# Knee bends toward the model front (+Z in KayKit space), never hyperextended.
	var pole := Vector3.BACK - direction * direction.z
	pole = pole.normalized() if pole.length_squared() > 0.000001 else Vector3.BACK
	var cos_hip := clampf((l1 * l1 + distance * distance - l2 * l2) / (2.0 * l1 * distance), -1.0, 1.0)
	var sin_hip := sqrt(1.0 - cos_hip * cos_hip)
	var knee := hip + (direction * cos_hip + pole * sin_hip) * l1
	var ankle := hip + direction * distance
	var upper_q: Quaternion = Quaternion(leg.dir_u, (knee - hip).normalized()) * leg.rest_u
	var lower_q: Quaternion = Quaternion(leg.dir_l, (ankle - knee).normalized()) * leg.rest_l
	# Sole flat in root space: undo the waddle roll on the foot.
	var foot_q: Quaternion = model_roll.inverse() * leg.rest_f
	_rig.set_bone_pose_rotation(leg.upper, (_hips_q.inverse() * upper_q).normalized())
	_rig.set_bone_pose_rotation(leg.lower, (upper_q.inverse() * lower_q).normalized())
	_rig.set_bone_pose_rotation(leg.foot, (lower_q.inverse() * foot_q).normalized())


## Waddle transform W in character-root space (identity at rest / idle).
func get_waddle_transform() -> Transform3D:
	return _waddle


## World position of the visible KayKit foot bone ("l"/"r" or "Left"/"Right").
func get_visible_foot_global(side: String) -> Vector3:
	if _rig == null or _foot_ids.is_empty():
		_bind_rig()
	if _rig == null:
		return global_position
	var key := "l" if side.to_lower().begins_with("l") else "r"
	return _rig.global_transform * _rig.get_bone_global_pose(_foot_ids[key]).origin


static func waddle_at(phase: float, speed: float, weight: float) -> Transform3D:
	var blend := clampf(inverse_lerp(Tuning.WALK_SPEED, Tuning.SPRINT_SPEED, speed), 0.0, 1.0)
	var roll := lerpf(WADDLE_WALK_ROLL, WADDLE_RUN_ROLL, blend) * sin(TAU * phase) * weight
	var bob := lerpf(WADDLE_WALK_BOB, WADDLE_RUN_BOB, blend) * absf(cos(TAU * phase)) * weight
	# Roll about the planted foot. Positive roll lifts +X, so the pivot is the
	# -X foot (sign deviation from the A2 plan's sign(theta) noted in the PR).
	var hip_x := 0.1709 * 0.62
	var pivot := Vector3(-signf(roll) * hip_x, 0.0, 0.0)
	var rolled := Transform3D(Basis(Vector3.BACK, roll), Vector3.ZERO)
	# A3: knees bend (body lowers) while stepping so the short legs reach the stride.
	bob -= STANCE_CROUCH * weight
	return Transform3D(Basis.IDENTITY, Vector3(0.0, bob, 0.0)) * Transform3D(Basis.IDENTITY, pivot) * rolled * Transform3D(Basis.IDENTITY, -pivot)


## Drive the KayKit rig from the contract proxies and apply the waddle.
func sync_rig(delta := 0.0) -> void:
	if _rig == null:
		_bind_rig()
	if _rig == null:
		return
	var moving := current_clip in ["walk", "run"]
	if delta > 0.0:
		_waddle_weight = move_toward(_waddle_weight, 1.0 if moving else 0.0, delta / (WADDLE_EASE_IN if moving else WADDLE_EASE_OUT))
	if moving and is_instance_valid(_animation_player) and _animation_player.current_animation_length > 0.0:
		_waddle_phase = _animation_player.current_animation_position / _animation_player.current_animation_length
	_waddle = waddle_at(_waddle_phase, _speed, _waddle_weight) if _waddle_weight > 0.0 else Transform3D.IDENTITY
	_model.transform = _waddle * MODEL_BASE
	if _accessories == null:
		_accessories = get_node_or_null("Accessories") as Node3D
	if _accessories != null:
		_accessories.transform = _waddle
	var flip := Quaternion(Vector3.UP, PI)
	var chest_global := Quaternion.IDENTITY
	var stepping := _waddle_weight > 0.0 and not _legs.is_empty()
	# T45 arm overlay weights (0.12 s ease) and the signed counter-phase swing.
	var relax_clip := current_clip in ARM_RELAX_CLIPS
	if delta > 0.0:
		_arm_weight_l = move_toward(_arm_weight_l, 1.0 if relax_clip else 0.0, delta / ARM_RELAX_EASE)
		_arm_weight_r = move_toward(_arm_weight_r, 1.0 if relax_clip and not _item_held else 0.0, delta / ARM_RELAX_EASE)
	var swing_blend := clampf(inverse_lerp(Tuning.WALK_SPEED, Tuning.SPRINT_SPEED, _speed), 0.0, 1.0)
	_arm_swing = lerpf(ARM_SWING_WALK, ARM_SWING_RUN, swing_blend) * clampf(_speed / Tuning.WALK_SPEED, 0.0, 1.0) * _waddle_weight * cos(TAU * _waddle_phase) if _waddle_weight > 0.0 else 0.0
	for proxy: String in ["Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		if stepping and proxy.ends_with("Leg"):
			continue
		var root_q := (_proxies[proxy] as Node3D).basis.get_rotation_quaternion()
		var global_q: Quaternion = flip * root_q * flip * _rest_q[proxy]
		if proxy == "LeftArm" and _arm_weight_l > 0.0:
			global_q = _arm_overlay_q(-1.0, _arm_weight_l, root_q, flip, _rest_q[proxy])
		elif proxy == "RightArm" and _arm_weight_r > 0.0:
			global_q = _arm_overlay_q(1.0, _arm_weight_r, root_q, flip, _rest_q[proxy])
		var parent_q: Quaternion = (chest_global * _chain_q[proxy]) if _chain_from_chest[proxy] else _chain_q[proxy]
		_rig.set_bone_pose_rotation(_bone_ids[proxy], (parent_q.inverse() * global_q).normalized())
		if proxy == "Torso":
			chest_global = global_q
	if _arm_weight_l > 0.0 or _arm_weight_r > 0.0 or _elbow_posed:
		if _lowerarm_l >= 0:
			_rig.set_bone_pose_rotation(_lowerarm_l, _lowerarm_rest_l * Quaternion(ARM_ELBOW_AXIS, ARM_ELBOW_SIGN_L * ARM_RELAX_ELBOW * _arm_weight_l))
		if _lowerarm_r >= 0:
			_rig.set_bone_pose_rotation(_lowerarm_r, _lowerarm_rest_r * Quaternion(ARM_ELBOW_AXIS, ARM_ELBOW_SIGN_R * ARM_RELAX_ELBOW * _arm_weight_r))
		_elbow_posed = _arm_weight_l > 0.0 or _arm_weight_r > 0.0
	if stepping:
		var model_roll := flip * _waddle.basis.get_rotation_quaternion() * flip
		var model_inverse := (_waddle * MODEL_BASE).affine_inverse()
		_solve_leg("l", model_inverse, model_roll)
		_solve_leg("r", model_inverse, model_roll)
		_legs_posed = true
	elif _legs_posed:
		# Back to the A2 proxy-driven rest legs: restore knee/ankle rest rotations.
		for key: String in _legs:
			_rig.set_bone_pose_rotation(_legs[key].lower, _legs[key].local_l)
			_rig.set_bone_pose_rotation(_legs[key].foot, _legs[key].local_f)
		_legs_posed = false
	var anchor := get_hand_anchor()
	if anchor != null and _handslot >= 0:
		anchor.global_transform = _rig.global_transform * _rig.get_bone_global_pose(_handslot)


## Relaxed + swinging upper-arm global rotation (model space). side +1 = right arm.
## The right arm swings with sin(TAU * phase) (forward as the LEFT foot lands at 0.25),
## the left arm opposite. Pitch is a root-space proxy rotation.x (+ = hand toward -Z).
func _arm_overlay_q(side: float, weight: float, root_q: Quaternion, flip: Quaternion, rest_q: Quaternion) -> Quaternion:
	var pitch := (ARM_RELAX_PITCH + side * _arm_swing) * weight
	var abduct := Quaternion(Vector3.BACK, -side * ARM_RELAX_ABDUCTION * weight)
	return flip * Quaternion(Vector3.RIGHT, pitch) * root_q * flip * abduct * rest_q


## T45: true while this character holds an item (right arm keeps the legacy pose so the
## HandAnchor / held item stays where it was before T45).
func set_item_held(held: bool) -> void:
	_item_held = held


func is_item_held() -> bool:
	return _item_held


## Read-only arm overlay state for tests/evidence (radians and weights).
func get_arm_overlay_debug() -> Dictionary:
	return {
		"weight_l": _arm_weight_l, "weight_r": _arm_weight_r, "swing": _arm_swing,
		"pitch_l": (ARM_RELAX_PITCH - _arm_swing) * _arm_weight_l, "pitch_r": (ARM_RELAX_PITCH + _arm_swing) * _arm_weight_r,
		"swing_l": -_arm_swing * _arm_weight_l, "swing_r": _arm_swing * _arm_weight_r,
		"elbow_l": ARM_RELAX_ELBOW * _arm_weight_l, "elbow_r": ARM_RELAX_ELBOW * _arm_weight_r,
		"abduction_l": ARM_RELAX_ABDUCTION * _arm_weight_l, "abduction_r": ARM_RELAX_ABDUCTION * _arm_weight_r,
	}


func set_cosmetic_variant(variant: int) -> void:
	cosmetic_variant = posmod(variant, catalog().items.size())
	if has_node("Accessories/Cap"):
		for accessory in $Accessories.get_children():
			accessory.visible = accessory.get_meta("outfit", -1) == cosmetic_variant
	var rear_cue := get_node_or_null("Torso/RearCue") as Node3D
	if rear_cue != null:
		rear_cue.visible = not (cosmetic_variant in BACK_ACCESSORY_OUTFITS)


func set_outfit_id(outfit_id: String) -> bool:
	var items: Array = catalog().items
	for index in items.size():
		if items[index].id == outfit_id:
			set_cosmetic_variant(index)
			return true
	return false


func get_outfit_id() -> String:
	return catalog().items[cosmetic_variant].id


func set_player_color(color_index: int) -> void:
	if _rig == null:
		_bind_rig()
	var idx := posmod(color_index, SUIT_COLORS.size())
	var material: StandardMaterial3D = _suit_material_cache.get(idx)
	if material == null:
		material = _material((SUIT_COLORS[idx] as Color).lerp(SUIT_SOFTEN, 0.28))
		_suit_material_cache[idx] = material
	_suit_current = material
	for part_name in ["Torso", "LeftArm/Mesh", "RightArm/Mesh", "LeftLeg/Mesh", "RightLeg/Mesh", "Head"]:
		(get_node(part_name) as MeshInstance3D).material_override = material
	if _rig != null:
		for child in _rig.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = material
	if has_node("Accessories"):
		for accessory: MeshInstance3D in $Accessories.get_children():
			if accessory.get_meta("body") == "Head":
				accessory.set_surface_override_material(0, material)


func get_animation_names() -> Array[String]:
	return REQUIRED_CLIPS.duplicate()


func get_skeleton_bone_count() -> int:
	ensure_runtime_setup()
	return ($Skeleton3D as Skeleton3D).get_bone_count() if has_node("Skeleton3D") else 0


func _build_skeleton_contract() -> void:
	if has_node("Skeleton3D"):
		return
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	var bones := [
		["root", -1], ["pelvis", 0], ["spine", 1], ["chest", 2], ["neck", 3], ["head", 4],
		["upper_arm_l", 3], ["lower_arm_l", 6], ["hand_l", 7],
		["upper_arm_r", 3], ["lower_arm_r", 9], ["hand_r", 10],
		["upper_leg_l", 1], ["lower_leg_l", 12], ["foot_l", 13],
		["upper_leg_r", 1], ["lower_leg_r", 15], ["foot_r", 16],
	]
	for bone_data in bones:
		skeleton.add_bone(bone_data[0])
		var index := skeleton.get_bone_count() - 1
		skeleton.set_bone_parent(index, bone_data[1])
		skeleton.set_bone_rest(index, Transform3D.IDENTITY)


func _build_accessories() -> void:
	if has_node("Accessories"):
		return
	var accessories := Node3D.new()
	accessories.name = "Accessories"
	add_child(accessories)
	var pattern := critter_material("pattern")
	var suit := _suit_current if _suit_current != null else critter_material("suit")
	for outfit in CRITTER_SPECIES.size():
		for part: String in ["Ears", "Tail", "Belly"]:
			var instance := MeshInstance3D.new()
			# "Cap" stays the sentinel name the runtime contract looks up.
			instance.name = "Cap" if outfit == 0 and part == "Ears" else "%s_%02d" % [part, outfit]
			instance.mesh = load("%s/%s_%02d.res" % [CRITTER_PARTS_DIR, part, outfit]) as Mesh
			instance.set_meta("outfit", outfit)
			instance.set_meta("body", {"Ears": "Head", "Tail": "Pelvis", "Belly": "Chest"}[part])
			instance.set_meta("species", CRITTER_SPECIES[outfit])
			instance.position = ACCESSORY_ORIGIN
			if part == "Ears":
				instance.set_surface_override_material(0, suit)
				instance.set_surface_override_material(1, pattern)
			else:
				instance.material_override = pattern
			accessories.add_child(instance)


## Shared flat plush materials (also written to assets/models/critter/materials).
static func critter_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.metallic = 0.0
	material.roughness = 0.92
	match kind:
		"suit":
			material.albedo_color = Color("cdb9a3")
		"cream":
			# Warm face/paw tint with a soft glow so the face reads at camera range.
			material.albedo_color = Color("f4dcc2")
			material.emission_enabled = true
			material.emission = Color("f4dcc2")
			material.emission_energy_multiplier = 0.32
		"face":
			# A4: the concept sheet's flat grey plate (130,135,129), unshaded so it reads
			# the same in any light and under any player colour.
			material.albedo_color = Color(0.51, 0.53, 0.506)
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"bead":
			material.albedo_color = Color("20242c")
			material.roughness = 0.25
		"shine":
			material.albedo_color = Color.WHITE
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"blush":
			material.albedo_color = Color("f2a49c")
			material.emission_enabled = true
			material.emission = Color("f2a49c")
			material.emission_energy_multiplier = 0.25
		"pattern":
			material.albedo_color = Color.WHITE
			material.vertex_color_use_as_albedo = true
	return material


func _build_animation_library() -> void:
	if has_node("AnimationPlayer"):
		_animation_player = $AnimationPlayer
		return
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for clip_name in REQUIRED_CLIPS:
		var animation := _create_clip(clip_name)
		_split_transform_tracks(animation)
		library.add_animation(clip_name, animation)
	_animation_player.add_animation_library("", library)


func _split_transform_tracks(animation: Animation) -> void:
	# Blend position/rotation/scale separately. Blending affine Transform3D
	# values distorts the flattened face basis even between identical rest poses.
	for track in range(animation.get_track_count() - 1, -1, -1):
		var path := String(animation.track_get_path(track))
		if not path.ends_with(":transform"):
			continue
		for property in ["position", "rotation", "scale"]:
			var component := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(component, NodePath(path.trim_suffix("transform") + property))
			for key in animation.track_get_key_count(track):
				var pose: Transform3D = animation.track_get_key_value(track, key)
				var value := pose.origin if property == "position" else (pose.basis.orthonormalized().get_euler() if property == "rotation" else pose.basis.get_scale())
				animation.track_insert_key(component, animation.track_get_key_time(track, key), value)
		animation.remove_track(track)


func _create_clip(clip_name: String) -> Animation:
	var animation := Animation.new()
	animation.length = _clip_duration(clip_name)
	animation.loop_mode = Animation.LOOP_LINEAR if clip_name in ["idle", "walk", "run", "falling"] else Animation.LOOP_NONE
	if clip_name not in ["walk", "run"]:
		for side in ["Left", "Right"]:
			for property in ["Mesh:scale", "Mesh:position", side + "Shoe:position", side + "Shoe:rotation"]:
				var parts: PackedStringArray = property.split(":")
				var reset := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(reset, NodePath("%sLeg/%s" % [side, property]))
				animation.track_insert_key(reset, 0.0, get_node("%sLeg/%s" % [side, parts[0]]).get(parts[1]))

	var squash := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(squash, NodePath("Torso:scale"))
	var rest_scale: Vector3 = $Torso.scale
	if clip_name == "idle":
		animation.track_insert_key(squash, 0.0, rest_scale)
		animation.track_insert_key(squash, animation.length * 0.5, rest_scale * Vector3(1.015, 0.975, 1.015))
		animation.track_insert_key(squash, animation.length, rest_scale)
	elif clip_name == "jump_takeoff":
		animation.track_insert_key(squash, 0.0, rest_scale * Vector3(0.94, 1.07, 0.94))
		animation.track_insert_key(squash, animation.length, rest_scale * Vector3(0.96, 1.04, 0.96))
	elif clip_name == "landing":
		animation.track_insert_key(squash, 0.0, rest_scale * Vector3(1.06, 0.90, 1.06))
		animation.track_insert_key(squash, 0.13, rest_scale)
		animation.track_insert_key(squash, animation.length, rest_scale)
	else:
		animation.track_insert_key(squash, 0.0, rest_scale)
		animation.track_insert_key(squash, animation.length, rest_scale)

	if clip_name != "shove":
		var start_lean := -0.5 if clip_name == "get_up" else (-0.10 if clip_name == "run" else (-0.04 if clip_name == "walk" else 0.0))
		var end_lean := -0.10 if clip_name == "run" else (-0.04 if clip_name == "walk" else 0.0)
		var torso_reset := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(torso_reset, NodePath("Torso:rotation"))
		animation.track_insert_key(torso_reset, 0.0, Vector3(start_lean, 0.0, 0.0))
		animation.track_insert_key(torso_reset, animation.length, Vector3(end_lean, 0.0, 0.0))

		var recovery_lean := -0.5 if clip_name == "get_up" else 0.0
		for part in HEAD_PARTS:
			var part_reset := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(part_reset, NodePath("%s:transform" % part))
			var rest: Transform3D = get_node(part).transform
			var rotation := Basis(Vector3.RIGHT, recovery_lean)
			var pivot: Vector3 = $Torso.position
			animation.track_insert_key(part_reset, 0.0, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(part_reset, animation.length, rest)
		for accessory: MeshInstance3D in $Accessories.get_children():
			var reset := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(reset, NodePath("Accessories/%s:transform" % accessory.name))
			var rotation := Basis(Vector3.RIGHT, recovery_lean if accessory.get_meta("body") != "Pelvis" else 0.0)
			var pivot: Vector3 = $Torso.position
			var rest := accessory.transform
			animation.track_insert_key(reset, 0.0, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(reset, animation.length, rest)

	if clip_name == "shove":
		# Bounded forward arm thrust with a short lunge stance and wind-up/push;
		# one-shot returning cleanly to rest for locomotion handoff.
		var thrust := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(thrust, NodePath("LeftArm:rotation"))
		animation.track_insert_key(thrust, 0.0, Vector3(-0.35, 0.0, 0.15))
		animation.track_insert_key(thrust, 0.1, Vector3(1.35, 0.0, 0.55))
		animation.track_insert_key(thrust, animation.length, Vector3.ZERO)
		var thrust_mirror := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(thrust_mirror, NodePath("RightArm:rotation"))
		animation.track_insert_key(thrust_mirror, 0.0, Vector3(-0.35, 0.0, -0.15))
		animation.track_insert_key(thrust_mirror, 0.1, Vector3(1.35, 0.0, -0.55))
		animation.track_insert_key(thrust_mirror, animation.length, Vector3.ZERO)
		var lean := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(lean, NodePath("Torso:rotation"))
		animation.track_insert_key(lean, 0.0, Vector3(0.08, 0.0, 0.0))
		animation.track_insert_key(lean, 0.1, Vector3(-0.28, 0.0, 0.0))
		animation.track_insert_key(lean, animation.length, Vector3.ZERO)
		for part in HEAD_PARTS:
			var part_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(part_track, NodePath("%s:transform" % part))
			var rest: Transform3D = get_node(part).transform
			var pivot: Vector3 = $Torso.position
			var rotation := Basis(Vector3.RIGHT, -0.28)
			animation.track_insert_key(part_track, 0.0, rest)
			animation.track_insert_key(part_track, 0.1, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(part_track, animation.length, rest)
		for accessory: MeshInstance3D in $Accessories.get_children():
			if accessory.get_meta("body") == "Pelvis":
				continue
			var attachment := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(attachment, NodePath("Accessories/%s:transform" % accessory.name))
			var rest := accessory.transform
			var pivot := ($Torso as MeshInstance3D).position
			var rotation := Basis(Vector3.RIGHT, -0.28)
			animation.track_insert_key(attachment, 0.0, rest)
			animation.track_insert_key(attachment, 0.1, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(attachment, animation.length, rest)
		var lunge := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(lunge, NodePath("LeftLeg:rotation"))
		animation.track_insert_key(lunge, 0.0, Vector3.ZERO)
		animation.track_insert_key(lunge, 0.1, Vector3(0.3, 0.0, 0.0))
		animation.track_insert_key(lunge, animation.length, Vector3.ZERO)
		var lunge_mirror := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(lunge_mirror, NodePath("RightLeg:rotation"))
		animation.track_insert_key(lunge_mirror, 0.0, Vector3.ZERO)
		animation.track_insert_key(lunge_mirror, 0.1, Vector3(-0.3, 0.0, 0.0))
		animation.track_insert_key(lunge_mirror, animation.length, Vector3.ZERO)
		return animation

	if clip_name == "wave":
		var wave_arm := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(wave_arm, NodePath("RightArm:rotation"))
		animation.track_insert_key(wave_arm, 0.0, Vector3.ZERO)
		animation.track_insert_key(wave_arm, 0.15, Vector3(2.5, 0.0, -0.5))
		animation.track_insert_key(wave_arm, 0.4, Vector3(2.5, 0.0, -0.85))
		animation.track_insert_key(wave_arm, 0.65, Vector3(2.5, 0.0, -0.15))
		animation.track_insert_key(wave_arm, 0.9, Vector3(2.5, 0.0, -0.85))
		animation.track_insert_key(wave_arm, 1.05, Vector3(2.5, 0.0, -0.35))
		animation.track_insert_key(wave_arm, animation.length, Vector3.ZERO)
		return animation

	if clip_name == "cheer":
		var cheer_left := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(cheer_left, NodePath("LeftArm:rotation"))
		animation.track_insert_key(cheer_left, 0.0, Vector3.ZERO)
		animation.track_insert_key(cheer_left, 0.12, Vector3(2.7, 0.0, -0.55))
		animation.track_insert_key(cheer_left, 0.35, Vector3(2.35, 0.0, -0.45))
		animation.track_insert_key(cheer_left, 0.6, Vector3(2.7, 0.0, -0.55))
		animation.track_insert_key(cheer_left, 0.85, Vector3(2.35, 0.0, -0.45))
		animation.track_insert_key(cheer_left, animation.length, Vector3.ZERO)
		var cheer_right := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(cheer_right, NodePath("RightArm:rotation"))
		animation.track_insert_key(cheer_right, 0.0, Vector3.ZERO)
		animation.track_insert_key(cheer_right, 0.12, Vector3(2.7, 0.0, 0.55))
		animation.track_insert_key(cheer_right, 0.35, Vector3(2.35, 0.0, 0.45))
		animation.track_insert_key(cheer_right, 0.6, Vector3(2.7, 0.0, 0.55))
		animation.track_insert_key(cheer_right, 0.85, Vector3(2.35, 0.0, 0.45))
		animation.track_insert_key(cheer_right, animation.length, Vector3.ZERO)
		var cheer_left_leg := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(cheer_left_leg, NodePath("LeftLeg:rotation"))
		animation.track_insert_key(cheer_left_leg, 0.0, Vector3.ZERO)
		animation.track_insert_key(cheer_left_leg, 0.35, Vector3(0.12, 0.0, 0.0))
		animation.track_insert_key(cheer_left_leg, 0.6, Vector3.ZERO)
		animation.track_insert_key(cheer_left_leg, 0.85, Vector3(0.12, 0.0, 0.0))
		animation.track_insert_key(cheer_left_leg, animation.length, Vector3.ZERO)
		var cheer_right_leg := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(cheer_right_leg, NodePath("RightLeg:rotation"))
		animation.track_insert_key(cheer_right_leg, 0.0, Vector3.ZERO)
		animation.track_insert_key(cheer_right_leg, 0.35, Vector3(-0.12, 0.0, 0.0))
		animation.track_insert_key(cheer_right_leg, 0.6, Vector3.ZERO)
		animation.track_insert_key(cheer_right_leg, 0.85, Vector3(-0.12, 0.0, 0.0))
		animation.track_insert_key(cheer_right_leg, animation.length, Vector3.ZERO)
		return animation

	var arm_angle := 0.06 if clip_name == "idle" else 0.0
	var leg_angle := 0.0
	if clip_name in ["walk", "run"]:
		# AC12 plop-toddle: limbs stay at rest; the waddle is whole-body.
		arm_angle = 0.0
	elif clip_name == "jump_takeoff":
		arm_angle = -0.8
		leg_angle = 0.35
	elif clip_name == "falling":
		arm_angle = -0.45
		leg_angle = 0.20
	elif clip_name == "landing":
		arm_angle = 0.35
		leg_angle = 0.4
	elif clip_name == "get_up":
		arm_angle = 0.7
		leg_angle = 0.5
	var arm_motion := clip_name not in ["jump_takeoff", "falling"]
	_add_rotation_track(animation, "LeftArm", arm_angle, arm_motion)
	_add_rotation_track(animation, "RightArm", -arm_angle if arm_motion else arm_angle, arm_motion)
	if clip_name in ["walk", "run"]:
		_add_gait_tracks(animation, "Left", 0.0)
		_add_gait_tracks(animation, "Right", 0.5)
	else:
		_add_rotation_track(animation, "LeftLeg", -leg_angle, arm_motion)
		_add_rotation_track(animation, "RightLeg", leg_angle if arm_motion else -leg_angle, arm_motion)
	return animation


func _add_gait_tracks(animation: Animation, side: String, offset: float) -> void:
	var paths := ["rotation", "Mesh:scale", "Mesh:position", side + "Shoe:position", side + "Shoe:rotation"]
	var tracks: Array[int] = []
	for path: String in paths:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%sLeg%s%s" % [side, ":" if path == "rotation" else "/", path]))
		tracks.append(track)
	# Track paths are kept for blend/reset compatibility, keyed at rest (no leg swing).
	var values := [Vector3.ZERO, Vector3.ONE, Vector3(0, -0.16, 0), Vector3(0, -0.32, -0.045), Vector3.ZERO]
	for index in tracks.size():
		animation.track_insert_key(tracks[index], 0.0, values[index])
		animation.track_insert_key(tracks[index], animation.length, values[index])


func _add_rotation_track(animation: Animation, node_name: String, angle: float, oscillates := true) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("%s:rotation" % node_name))
	animation.track_insert_key(track, 0.0, Vector3(angle, 0.0, 0.0))
	animation.track_insert_key(track, animation.length * 0.5, Vector3(-angle if oscillates else angle, 0.0, 0.0))
	animation.track_insert_key(track, animation.length, Vector3(angle, 0.0, 0.0))


func get_clip_duration(clip_name: String) -> float:
	return _clip_duration(clip_name)


func _clip_duration(clip_name: String) -> float:
	match clip_name:
		"idle": return 2.0
		"shove": return 0.3
		"walk": return 0.8
		"run": return 0.55
		"jump_takeoff": return 0.15
		"landing": return 0.2
		"get_up": return 1.0
		"wave": return 1.2
		"cheer": return 1.0
		_: return 0.6


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.92
	return material
