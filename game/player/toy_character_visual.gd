class_name ToyCharacterVisual
extends Node3D

const REQUIRED_CLIPS := [
	"idle", "walk", "run", "jump_takeoff", "falling", "landing",
	"crouch_idle", "crouch_walk", "holding_idle", "holding_walk", "get_up",
	"shove", "wave", "cheer",
]
const SUIT_COLORS := [
	Color("31c5df"), Color("f28a3c"), Color("9b72e8"),
	Color("8fcf4f"), Color("e66ba8"), Color("4f86e8"),
]

var cosmetic_variant := 0
var current_clip := "idle"
var _animation_player: AnimationPlayer


static func catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/cosmetic_catalog.json")) as Dictionary


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
	cosmetic_variant = posmod(variant, catalog().items.size())
	if has_node("Accessories/Cap"):
		for accessory in $Accessories.get_children():
			accessory.visible = accessory.get_meta("outfit", -1) == cosmetic_variant


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
	var material := StandardMaterial3D.new()
	material.albedo_color = SUIT_COLORS[posmod(color_index, SUIT_COLORS.size())]
	material.metallic = 0.0
	material.roughness = 0.8
	# The bean head, lower body, arms and legs are one continuous suit color;
	# only the cream face inset stays neutral so eyes/mouth remain readable.
	for part_name in ["Head", "Torso", "LeftArm/Mesh", "RightArm/Mesh", "LeftLeg/Mesh", "RightLeg/Mesh"]:
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
	cap_mesh.top_radius = 0.24
	cap_mesh.bottom_radius = 0.30
	cap_mesh.height = 0.12
	cap_mesh.radial_segments = 12
	cap_mesh.material = slate
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 1.71, 0.0)
	accessories.add_child(cap)
	var hard_hat := MeshInstance3D.new()
	hard_hat.name = "HardHat"
	var hard_hat_mesh := SphereMesh.new()
	hard_hat_mesh.radius = 0.28
	hard_hat_mesh.height = 0.24
	hard_hat_mesh.radial_segments = 12
	hard_hat_mesh.rings = 4
	hard_hat_mesh.material = amber
	hard_hat.mesh = hard_hat_mesh
	hard_hat.position = Vector3(0.0, 1.68, 0.0)
	accessories.add_child(hard_hat)
	var backpack := MeshInstance3D.new()
	backpack.name = "Backpack"
	var backpack_mesh := BoxMesh.new()
	backpack_mesh.size = Vector3(0.34, 0.40, 0.18)
	backpack_mesh.material = coral
	backpack.mesh = backpack_mesh
	backpack.position = Vector3(0.0, 1.05, 0.24)
	accessories.add_child(backpack)
	cap.set_meta("outfit", 1)
	hard_hat.set_meta("outfit", 2)
	backpack.set_meta("outfit", 3)
	# Open-front silhouettes retain the face and player-identification suit.
	_costume_box(accessories, "RainCape", 4, Vector3(0.50, 0.50, 0.08), Vector3(0, 0.95, 0.20), amber)
	_costume_ring(accessories, "RainHood", 4, 0.24, 0.32, Vector3(0, 1.18, 0.10), amber, true)
	_costume_box(accessories, "HoodBack", 4, Vector3(0.48, 0.42, 0.08), Vector3(0, 1.16, 0.26), amber)
	_costume_box(accessories, "HoodTop", 4, Vector3(0.48, 0.08, 0.38), Vector3(0, 1.71, 0.10), amber)
	_costume_box(accessories, "ToolBelt", 5, Vector3(0.48, 0.10, 0.34), Vector3(0, 0.78, 0), slate)
	_costume_box(accessories, "ToolPouch", 5, Vector3(0.13, 0.18, 0.12), Vector3(0.24, 0.74, 0.02), coral)
	_costume_box(accessories, "Goggles", 5, Vector3(0.30, 0.10, 0.06), Vector3(0, 1.26, -0.24), slate)
	for side in [-1, 1]:
		_costume_box(accessories, "GoggleLens%d" % side, 5, Vector3(0.10, 0.06, 0.025), Vector3(side * 0.085, 1.26, -0.278), _material(Color("73b7ad")))
	_costume_ring(accessories, "RangerBrim", 6, 0.14, 0.36, Vector3(0, 1.69, 0), _material(Color("d9b77e")))
	_costume_box(accessories, "RangerCrown", 6, Vector3(0.34, 0.14, 0.32), Vector3(0, 1.75, 0), _material(Color("d9b77e")))
	_costume_box(accessories, "FieldPack", 6, Vector3(0.30, 0.32, 0.14), Vector3(0, 1.0, 0.25), _material(Color("86a968")))
	_costume_ring(accessories, "ObserverHelmet", 7, 0.24, 0.31, Vector3(0, 1.21, 0.08), _material(Color("f4e6c8")), true)
	_costume_box(accessories, "ObservationPack", 7, Vector3(0.32, 0.34, 0.16), Vector3(0, 1.0, 0.26), slate)
	_costume_box(accessories, "Antenna", 7, Vector3(0.04, 0.24, 0.04), Vector3(0.13, 1.34, 0.26), amber)
	for accessory in accessories.get_children():
		# Fit the broader continuous creature without changing outfit IDs or
		# attachment ownership. Face equipment stays in front of the oval inset.
		accessory.scale.x *= 1.45
		accessory.scale.z *= 1.45
		accessory.position.x *= 1.45
		accessory.position.z *= 1.5
		if accessory.position.y > 1.6:
			accessory.position.y -= 0.18
		if accessory.name == "ToolBelt":
			accessory.scale.x = 1.8
			accessory.scale.z = 2.05
		accessory.set_meta("body", "Head" if accessory.position.y > 1.45 else ("Pelvis" if accessory.position.y < 0.85 else "Chest"))


func _costume_box(parent: Node3D, part: String, outfit: int, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part
	instance.mesh = mesh
	instance.position = at
	instance.set_meta("outfit", outfit)
	parent.add_child(instance)


func _costume_ring(parent: Node3D, part: String, outfit: int, inner: float, outer: float, at: Vector3, material: Material, vertical := false) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 12
	mesh.ring_segments = 6
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part
	instance.mesh = mesh
	instance.position = at
	if vertical:
		instance.rotation.x = PI * 0.5
	instance.set_meta("outfit", outfit)
	parent.add_child(instance)


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
	if clip_name != "shove":
		var torso_reset := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(torso_reset, NodePath("Torso:rotation"))
		animation.track_insert_key(torso_reset, 0.0, Vector3.ZERO)
		for part in ["FacePlate", "LeftEye", "RightEye", "Mouth"]:
			var face_reset := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(face_reset, NodePath("%s:transform" % part))
			animation.track_insert_key(face_reset, 0.0, get_node(part).transform)
		for accessory: MeshInstance3D in $Accessories.get_children():
			var reset := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(reset, NodePath("Accessories/%s:transform" % accessory.name))
			animation.track_insert_key(reset, 0.0, accessory.transform)
	if clip_name == "shove":
		# One bounded forward arm thrust with a short lunge stance; the clip is
		# one-shot and returns to ordinary locomotion on the next frame pick.
		# The arm spread and torso lean keep the cue readable from the rear
		# gameplay camera, where a pure forward thrust hides behind the torso.
		var thrust := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(thrust, NodePath("LeftArm:rotation"))
		animation.track_insert_key(thrust, 0.0, Vector3.ZERO)
		animation.track_insert_key(thrust, 0.1, Vector3(1.35, 0.0, 0.55))
		animation.track_insert_key(thrust, animation.length, Vector3.ZERO)
		var thrust_mirror := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(thrust_mirror, NodePath("RightArm:rotation"))
		animation.track_insert_key(thrust_mirror, 0.0, Vector3.ZERO)
		animation.track_insert_key(thrust_mirror, 0.1, Vector3(1.35, 0.0, -0.55))
		animation.track_insert_key(thrust_mirror, animation.length, Vector3.ZERO)
		var lean := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(lean, NodePath("Torso:rotation"))
		animation.track_insert_key(lean, 0.0, Vector3.ZERO)
		animation.track_insert_key(lean, 0.1, Vector3(-0.28, 0.0, 0.0))
		animation.track_insert_key(lean, animation.length, Vector3.ZERO)
		for part in ["FacePlate", "LeftEye", "RightEye", "Mouth"]:
			var face_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(face_track, NodePath("%s:transform" % part))
			var rest: Transform3D = get_node(part).transform
			var pivot: Vector3 = $Torso.position
			var rotation := Basis(Vector3.RIGHT, -0.28)
			animation.track_insert_key(face_track, 0.0, rest)
			animation.track_insert_key(face_track, 0.1, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(face_track, animation.length, rest)
		for accessory: MeshInstance3D in $Accessories.get_children():
			if accessory.get_meta("body") != "Chest":
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
		# One-shot social emote: right arm raised with a bounded side-to-side
		# wave, returning to rest so locomotion resumes cleanly.
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
		# One-shot social emote: both arms bounce up in a V with a small
		# counter-swing in the legs; ends at rest for locomotion handoff.
		var cheer_left := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(cheer_left, NodePath("LeftArm:rotation"))
		animation.track_insert_key(cheer_left, 0.0, Vector3.ZERO)
		# Negative z splays the raised left arm outward; positive z would
		# fold it across the face like the holding pose.
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
	if clip_name in ["holding_idle", "holding_walk"]:
		var hold_base := 1.05 if clip_name == "holding_idle" else 1.15
		var hold_swing := 0.04 if clip_name == "holding_idle" else 0.08
		_add_holding_track(animation, "LeftArm", hold_base, hold_swing, 0.22)
		_add_holding_track(animation, "RightArm", hold_base, hold_swing, -0.22)
		var holding_leg_angle := 0.0 if clip_name == "holding_idle" else 0.45
		_add_rotation_track(animation, "LeftLeg", -holding_leg_angle)
		_add_rotation_track(animation, "RightLeg", holding_leg_angle)
		return animation
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


func _add_holding_track(animation: Animation, node_name: String, base_angle: float, swing: float, inward: float) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("%s:rotation" % node_name))
	animation.track_insert_key(track, 0.0, Vector3(base_angle + swing, 0.0, inward))
	animation.track_insert_key(track, animation.length * 0.5, Vector3(base_angle - swing, 0.0, inward))
	animation.track_insert_key(track, animation.length, Vector3(base_angle + swing, 0.0, inward))


func get_clip_duration(clip_name: String) -> float:
	return _clip_duration(clip_name)


func _clip_duration(clip_name: String) -> float:
	match clip_name:
		"idle", "holding_idle", "crouch_idle": return 2.0
		"shove": return 0.3
		"walk", "holding_walk", "crouch_walk": return 0.8
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
	material.roughness = 0.8
	return material
