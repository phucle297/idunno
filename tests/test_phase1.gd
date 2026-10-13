extends SceneTree

const Tuning = preload("res://game/player/player_tuning.gd")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_engine()
	_check_assets()
	_check_tuning()
	_check_scenes()
	await _capture_outfits()
	if failures.is_empty():
		print("PHASE1_TESTS_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_engine() -> void:
	_expect(Engine.get_version_info().major == 4, "Godot major version must be 4")


func _capture_outfits() -> void:
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	if directory.is_empty():
		return
	var preview := (load("res://scenes/asset_validation.tscn") as PackedScene).instantiate()
	root.add_child(preview)
	(preview.get_node("WorldEnvironment") as WorldEnvironment).environment.ambient_light_energy = 0.35
	(preview.get_node("Sun") as DirectionalLight3D).light_energy = 0.85
	(preview.get_node("CameraFill") as OmniLight3D).light_energy = 0.25
	for part in ["Character", "Wall", "Crate", "Meteor", "CharacterPlinth", "CratePlinth", "Interface"]:
		preview.get_node(part).queue_free()
	for outfit in 8:
		var character := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
		preview.add_child(character)
		character.position = Vector3((outfit % 4 - 1.5) * 1.6 + (0.8 if outfit >= 4 else 0.0), 0, float(outfit / 4) * 2.0 - 1.0)
		character.set_cosmetic_variant(outfit)
		character.set_player_color(outfit)
		character._animation_player.pause()
	var camera := preview.get_node("Camera3D") as Camera3D
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.8
	camera.look_at_from_position(Vector3(0.4, 5.5, -7), Vector3(0.4, 0.8, 0))
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	_expect(root.get_texture().get_image().save_png(directory.path_join("outfit-daylight-%dx%d.png" % [root.size.x, root.size.y])) == OK, "Daylight outfit render must save")
	camera.look_at_from_position(Vector3(0.4, 5.5, 7), Vector3(0.4, 0.8, 0))
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(directory.path_join("outfit-daylight-back-%dx%d.png" % [root.size.x, root.size.y])) == OK, "Rear accessory silhouettes must render")
	preview.free()


func _check_assets() -> void:
	for path in [
		"res://assets/generated/CHR_Base_v001.tscn",
		"res://assets/generated/ENV_Wall_2m_v001.tscn",
		"res://assets/generated/PROP_Crate_Small_v001.tscn",
		"res://assets/generated/VFX_MeteorTelegraph_v001.tscn"
	]:
		_expect(ResourceLoader.exists(path), "Generated asset missing: %s" % path)
	var character_scene := load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene
	var character := character_scene.instantiate()
	root.add_child(character)
	_expect(character.get_meta("generator_seed") == 297, "Character generation seed drifted")
	for path in ["LeftArm", "LeftArm/Mesh", "RightArm", "RightArm/Mesh", "LeftLeg", "LeftLeg/Mesh", "LeftLeg/LeftShoe", "RightLeg", "RightLeg/Mesh", "RightLeg/RightShoe"]:
		_expect(character.get_node(path).owner == character, "Nested pivots, meshes and shoes must be owned by the packed root")
	var head := character.get_node("Head") as MeshInstance3D
	_expect(is_equal_approx((head.mesh as SphereMesh).radius * 2.0, 0.56), "Soft Creature bean head must be 0.56 m wide")
	var right_arm := character.get_node("RightArm/Mesh") as MeshInstance3D
	_expect(is_equal_approx((character.to_local(right_arm.global_position).x + (right_arm.mesh as CapsuleMesh).radius) * 2.0, 0.66), "Soft Creature shoulder width must be 0.66 m")
	_expect(character.get_node("Head").position.y + (head.mesh as SphereMesh).height * 0.5 <= 1.71, "Soft Creature must stay within its 1.60 m capsule reach")
	_expect((character as ToyCharacterVisual).get_skeleton_bone_count() == 18, "Character must expose the canonical 18-bone skeleton")
	_expect((character as ToyCharacterVisual).get_animation_names().size() == 14, "Character must provide all 14 required animation clips")
	var catalog := ToyCharacterVisual.catalog()
	_expect(catalog.version == 1, "Catalog must preserve saved receipt version")
	var ids := ["plain", "cap", "hard_hat", "backpack", "raincoat", "mechanic", "park_ranger", "meteor_observer"]
	for index in ids.size():
		_expect(catalog.items[index].id == ids[index], "Ledger IDs and pool ordering must not drift")
		_expect(catalog.items[index].pool == ("starter" if index < 4 else "earned"), "Starter availability must not drift")
	var skeleton := character.get_node("Skeleton3D") as Skeleton3D
	for bone in skeleton.get_bone_count():
		_expect(skeleton.get_bone_rest(bone) == Transform3D.IDENTITY, "Every outfit must share identity bone rests")
	var base_triangles := _base_triangles(character)
	_expect(base_triangles == 1808, "Canonical Soft Creature base must remain 1808 triangles excluding accessories")
	for variant in 8:
		_expect(character.set_outfit_id(ids[variant]), "Catalog IDs must resolve to visible outfits")
		_expect((character as ToyCharacterVisual).cosmetic_variant == variant, "Character cosmetic variant %d must be selectable" % variant)
		_expect(character.get_outfit_id() == ids[variant], "Outfit IDs must round trip")
		_expect(not character.set_outfit_id("unknown") and character.get_outfit_id() == ids[variant], "Unknown catalog ID must retain current outfit")
		var triangles := base_triangles
		for accessory: MeshInstance3D in character.get_node("Accessories").get_children():
			if accessory.visible:
				var count := accessory.mesh.get_faces().size() / 3
				_expect(count < 800, "Each accessory must stay below 800 triangles")
				triangles += int(count)
		print("OUTFIT_TRIANGLES variant=%d total=%d" % [variant, triangles])
		for clip: String in ToyCharacterVisual.REQUIRED_CLIPS:
			_expect(character.play_clip(clip), "Every outfit must play %s" % clip)
			var animator := character.get_node("AnimationPlayer") as AnimationPlayer
			animator.pause()
			animator.seek(character.get_clip_duration(clip) * 0.5, true)
			var doll := CosmeticRagdoll.new()
			root.add_child(doll)
			character.set_player_color(variant)
			doll.copy_appearance(character)
			_expect(doll.body_count() == 11 and doll.joint_count() == 10, "Outfits must not add physics bodies")
			for accessory: MeshInstance3D in character.get_node("Accessories").get_children():
				if accessory.visible:
					var copy := doll.get_node("%s/%s" % [accessory.get_meta("body"), accessory.name]) as MeshInstance3D
					_expect(copy.mesh == accessory.mesh, "Ragdoll must retain exact accessory geometry")
					_expect(copy.position + (copy.get_parent() as Node3D).position == accessory.position, "Ragdoll attachment must preserve local placement")
			_expect((doll.get_node("Chest").get_child(0) as MeshInstance3D).material_override == (character.get_node("Torso") as MeshInstance3D).material_override, "Ragdoll must retain suit color")
			doll.free()
	# Shoes must travel with swinging legs rather than remain on the floor.
	var animation := character.get_node("AnimationPlayer") as AnimationPlayer
	(character as ToyCharacterVisual).play_clip("run")
	animation.pause()
	animation.seek(0.0, true)
	var left_shoe := character.find_child("LeftShoe", true, false) as Node3D
	var first_shoe_position := left_shoe.global_position
	animation.seek(0.275, true)
	_expect(left_shoe.global_position.distance_to(first_shoe_position) > 0.2, "Running shoes must follow the leg swing")
	for leg_name in ["LeftLeg", "RightLeg"]:
		var leg := character.get_node(leg_name) as Node3D
		var mesh := leg.get_node("Mesh") as MeshInstance3D
		var capsule := (mesh as MeshInstance3D).mesh as CapsuleMesh
		for phase in [0.0, 0.1375, 0.275]:
			animation.seek(phase, true)
			var top: Vector3 = character.to_local(mesh.to_global(Vector3(0, capsule.height * 0.5, 0)))
			_expect(top.distance_to(Vector3(leg.position.x, 0.70, 0)) < 0.001, "Leg must remain connected at the hip throughout running")
	character.free()
	var meteor := (load("res://assets/generated/VFX_MeteorTelegraph_v001.tscn") as PackedScene).instantiate()
	_expect(meteor.has_node("WarningFootprint"), "Packed meteor proxy must include its warning footprint")
	meteor.free()


func _base_triangles(node: Node) -> int:
	if node.name == "Accessories":
		return 0
	var result := 0
	if node is MeshInstance3D:
		result = int((node as MeshInstance3D).mesh.get_faces().size() / 3)
	for child in node.get_children():
		result += _base_triangles(child)
	return result


func _check_tuning() -> void:
	_expect(is_equal_approx(Tuning.JUMP_VELOCITY, sqrt(54.0)), "Jump velocity must derive from gravity and height")
	_expect(Tuning.SPRINT_SPEED > Tuning.WALK_SPEED, "Sprint must exceed walk speed")
	_expect(Tuning.COYOTE_TIME == Tuning.JUMP_BUFFER_TIME, "Input grace windows should match the bible baseline")


func _check_scenes() -> void:
	_expect(load("res://game/player/player.gd") != null, "Player script must compile")
	_expect(load("res://game/player/cosmetic_ragdoll.gd") != null, "Cosmetic ragdoll script must compile")
	_expect(ResourceLoader.exists("res://scenes/player.tscn"), "Player scene missing")
	_expect(ResourceLoader.exists("res://scenes/main.tscn"), "Main scene missing")
	_expect(ResourceLoader.exists("res://scenes/asset_validation.tscn"), "Asset validation scene missing")
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_expect(main.get_script() != null, "Instantiated main scene must retain its script")
	_expect(main.has_node("Player/CameraPivot/SpringArm3D/Camera3D"), "Third-person camera hierarchy missing")
	_expect(main.get_node("Player").get_script() != null, "Instantiated player must retain its script")
	_expect(main.has_node("MatchManager"), "Main scene must own the authoritative match state")
	_expect(main.has_node("Interface/HealthCard/Content/HealthBar"), "Main scene must expose a semantic health display in its HUD")
	_expect(not main.has_node("Interface/Title") and not main.has_node("Interface/Help"), "Main scene must not retain permanent prototype title or control copy")
	_expect(main.has_node("Interface/ContextPrompt/Content/Action"), "Main scene must expose a contextual interaction prompt")
	main.free()
	_expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphans_before, "Freeing an unmounted scene must not orphan preallocated UI children")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
