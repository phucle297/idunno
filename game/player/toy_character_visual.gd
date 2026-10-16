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

var cosmetic_variant := 0
var current_clip := "idle"
var _animation_player: AnimationPlayer
var _clip_started := false


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
	if not is_instance_valid(_animation_player):
		return
	# Each planted foot travels twice the reach over half a cycle. Match
	# playback to distance, rather than dragging the sole at fixed clip speed.
	_animation_player.speed_scale = speed * _clip_duration(current_clip) / (4.0 * GAIT_REACH) if current_clip in ["walk", "run"] else 1.0


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
	animation.track_insert_key(squash, 0.0, rest_scale * Vector3(1, 0.92 if clip_name == "landing" else 1.0, 1))
	animation.track_insert_key(squash, 0.13 if clip_name == "landing" else animation.length, rest_scale)
	if clip_name != "shove":
		var recovery_lean := -0.5 if clip_name == "get_up" else 0.0
		var torso_reset := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(torso_reset, NodePath("Torso:rotation"))
		animation.track_insert_key(torso_reset, 0.0, Vector3(recovery_lean, 0, 0))
		animation.track_insert_key(torso_reset, animation.length, Vector3.ZERO)
		for part in ["FacePlate", "LeftEye", "RightEye", "Mouth"]:
			var face_reset := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(face_reset, NodePath("%s:transform" % part))
			var rest: Transform3D = get_node(part).transform
			var rotation := Basis(Vector3.RIGHT, recovery_lean)
			var pivot: Vector3 = $Torso.position
			animation.track_insert_key(face_reset, 0.0, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(face_reset, animation.length, rest)
		for accessory: MeshInstance3D in $Accessories.get_children():
			var reset := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(reset, NodePath("Accessories/%s:transform" % accessory.name))
			var rotation := Basis(Vector3.RIGHT, recovery_lean if accessory.get_meta("body") != "Pelvis" else 0.0)
			var pivot: Vector3 = $Torso.position
			var rest := accessory.transform
			animation.track_insert_key(reset, 0.0, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot)))
			animation.track_insert_key(reset, animation.length, rest)
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
	var arm_angle := 0.0
	var leg_angle := 0.0
	if clip_name == "walk":
		arm_angle = 0.55
	elif clip_name == "run":
		arm_angle = 0.9
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
	for sample in 33:
		var phase := fposmod(sample / 32.0 + offset, 1.0)
		var planted := phase <= 0.5
		var progress := phase * 2.0 if planted else (phase - 0.5) * 2.0
		var z := lerpf(-GAIT_REACH, GAIT_REACH, progress) if planted else lerpf(GAIT_REACH, -GAIT_REACH, progress)
		var lift := 0.0 if planted else sin(progress * PI) * 0.12
		var foot := Vector3(0.0, -0.32 + lift, z - 0.045)
		var length := foot.length()
		var angle := atan2(-foot.z, -foot.y)
		var values := [Vector3(angle, 0, 0), Vector3(1, length / 0.32, 1), Vector3(0, -length * 0.5, 0), Vector3(0, -length, 0), Vector3(-angle, 0, 0)]
		for index in tracks.size():
			animation.track_insert_key(tracks[index], sample / 32.0 * animation.length, values[index])


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
	material.roughness = 0.8
	return material
