class_name ToyCharacterVisual
extends Node3D

const REQUIRED_CLIPS := [
	"idle", "walk", "run", "jump_takeoff", "falling", "landing",
	"crouch_idle", "crouch_walk", "holding_idle", "holding_walk", "get_up",
]
const SUIT_COLORS := [
	Color("31c5df"), Color("f28a3c"), Color("9b72e8"),
	Color("8fcf4f"), Color("e66ba8"), Color("4f86e8"),
]

var cosmetic_variant := 0
var current_clip := "idle"
var _animation_player: AnimationPlayer


func _ready() -> void:
	ensure_runtime_setup()
	play_clip("idle")


func ensure_runtime_setup() -> void:
	_build_skeleton_contract()
	_build_accessories()
	_build_animation_library()
	set_cosmetic_variant(cosmetic_variant)


func play_clip(clip_name: String) -> bool:
	if not clip_name in REQUIRED_CLIPS or not is_instance_valid(_animation_player):
		return false
	if current_clip != clip_name or not _animation_player.is_playing():
		current_clip = clip_name
		_animation_player.play(clip_name)
	return true


func set_cosmetic_variant(variant: int) -> void:
	cosmetic_variant = posmod(variant, 4)
	if has_node("Accessories/Cap"):
		$Accessories/Cap.visible = cosmetic_variant == 1
		$Accessories/HardHat.visible = cosmetic_variant == 2
		$Accessories/Backpack.visible = cosmetic_variant == 3


func set_player_color(color_index: int) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = SUIT_COLORS[posmod(color_index, SUIT_COLORS.size())]
	material.metallic = 0.0
	material.roughness = 0.8
	for part_name in ["Torso", "LeftArm/Mesh", "RightArm/Mesh", "LeftLeg/Mesh", "RightLeg/Mesh"]:
		(get_node(part_name) as MeshInstance3D).material_override = material


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
	var slate := _material(Color("49566a"))
	var amber := _material(Color("ffbf3f"))
	var coral := _material(Color("d98d7d"))
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.22
	cap_mesh.bottom_radius = 0.25
	cap_mesh.height = 0.12
	cap_mesh.radial_segments = 12
	cap_mesh.material = slate
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 1.62, 0.0)
	accessories.add_child(cap)
	var hard_hat := MeshInstance3D.new()
	hard_hat.name = "HardHat"
	var hard_hat_mesh := SphereMesh.new()
	hard_hat_mesh.radius = 0.27
	hard_hat_mesh.height = 0.22
	hard_hat_mesh.radial_segments = 12
	hard_hat_mesh.rings = 4
	hard_hat_mesh.material = amber
	hard_hat.mesh = hard_hat_mesh
	hard_hat.position = Vector3(0.0, 1.58, 0.0)
	accessories.add_child(hard_hat)
	var backpack := MeshInstance3D.new()
	backpack.name = "Backpack"
	var backpack_mesh := BoxMesh.new()
	backpack_mesh.size = Vector3(0.34, 0.40, 0.18)
	backpack_mesh.material = coral
	backpack.mesh = backpack_mesh
	backpack.position = Vector3(0.0, 1.0, 0.22)
	accessories.add_child(backpack)


func _build_animation_library() -> void:
	if has_node("AnimationPlayer"):
		_animation_player = $AnimationPlayer
		return
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for clip_name in REQUIRED_CLIPS:
		library.add_animation(clip_name, _create_clip(clip_name))
	_animation_player.add_animation_library("", library)


func _create_clip(clip_name: String) -> Animation:
	var animation := Animation.new()
	animation.length = _clip_duration(clip_name)
	animation.loop_mode = Animation.LOOP_LINEAR if clip_name in ["idle", "walk", "run", "falling", "crouch_idle", "crouch_walk", "holding_idle", "holding_walk"] else Animation.LOOP_NONE
	var arm_angle := 0.0
	var leg_angle := 0.0
	if clip_name in ["walk", "holding_walk", "crouch_walk"]:
		arm_angle = 0.55
		leg_angle = 0.45
	elif clip_name == "run":
		arm_angle = 0.9
		leg_angle = 0.75
	elif clip_name == "jump_takeoff":
		arm_angle = -0.8
		leg_angle = 0.25
	elif clip_name == "falling":
		arm_angle = -0.45
	elif clip_name == "landing":
		arm_angle = 0.35
		leg_angle = 0.4
	elif clip_name == "get_up":
		arm_angle = 0.7
		leg_angle = 0.5
	_add_rotation_track(animation, "LeftArm", arm_angle)
	_add_rotation_track(animation, "RightArm", -arm_angle)
	_add_rotation_track(animation, "LeftLeg", -leg_angle)
	_add_rotation_track(animation, "RightLeg", leg_angle)
	return animation


func _add_rotation_track(animation: Animation, node_name: String, angle: float) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("%s:rotation" % node_name))
	animation.track_insert_key(track, 0.0, Vector3(angle, 0.0, 0.0))
	animation.track_insert_key(track, animation.length * 0.5, Vector3(-angle, 0.0, 0.0))
	animation.track_insert_key(track, animation.length, Vector3(angle, 0.0, 0.0))


func _clip_duration(clip_name: String) -> float:
	match clip_name:
		"idle", "holding_idle", "crouch_idle": return 2.0
		"walk", "holding_walk", "crouch_walk": return 0.8
		"run": return 0.55
		"jump_takeoff": return 0.15
		"landing": return 0.2
		"get_up": return 1.0
		_: return 0.6


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.8
	return material
