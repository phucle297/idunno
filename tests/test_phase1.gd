extends SceneTree

const Tuning = preload("res://game/player_tuning.gd")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_engine()
	_check_assets()
	_check_tuning()
	_check_scenes()
	if failures.is_empty():
		print("PHASE1_TESTS_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_engine() -> void:
	_expect(Engine.get_version_info().major == 4, "Godot major version must be 4")


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
	var head := character.get_node("Head") as MeshInstance3D
	_expect(is_equal_approx((head.mesh as SphereMesh).radius * 2.0, 0.48), "Character head width must be 0.48 m")
	var right_arm := character.get_node("RightArm/Mesh") as MeshInstance3D
	_expect(is_equal_approx((character.to_local(right_arm.global_position).x + (right_arm.mesh as CapsuleMesh).radius) * 2.0, 0.56), "Character shoulder width must be 0.56 m")
	_expect(character.get_node("Head").position.y + 0.215 <= 1.605, "Character exceeds 1.60 m tolerance")
	_expect((character as ToyCharacterVisual).get_skeleton_bone_count() == 18, "Character must expose the canonical 18-bone skeleton")
	_expect((character as ToyCharacterVisual).get_animation_names().size() == 12, "Character must provide all 12 required animation clips")
	for variant in 4:
		(character as ToyCharacterVisual).set_cosmetic_variant(variant)
		_expect((character as ToyCharacterVisual).cosmetic_variant == variant, "Character cosmetic variant %d must be selectable" % variant)
	# Shoes must travel with swinging legs rather than remain on the floor.
	var animation := character.get_node("AnimationPlayer") as AnimationPlayer
	(character as ToyCharacterVisual).play_clip("run")
	animation.pause()
	animation.seek(0.0, true)
	var left_shoe := character.find_child("LeftShoe", true, false) as Node3D
	var first_shoe_position := left_shoe.global_position
	animation.seek(0.275, true)
	_expect(left_shoe.global_position.distance_to(first_shoe_position) > 0.4, "Running shoes must follow the full leg swing")
	for leg_name in ["LeftLeg", "RightLeg"]:
		var leg := character.get_node(leg_name) as Node3D
		var mesh := leg.get_node("Mesh") as MeshInstance3D
		var capsule := (mesh as MeshInstance3D).mesh as CapsuleMesh
		for phase in [0.0, 0.1375, 0.275]:
			animation.seek(phase, true)
			var hip: Vector3 = character.to_local(mesh.to_global(Vector3(0, capsule.height * 0.5, 0)))
			_expect(hip.distance_to(Vector3(leg.position.x, 0.70, 0)) < 0.001, "Leg must remain connected at the hip throughout running")
	character.free()
	var meteor := (load("res://assets/generated/VFX_MeteorTelegraph_v001.tscn") as PackedScene).instantiate()
	_expect(meteor.has_node("WarningFootprint"), "Packed meteor proxy must include its warning footprint")
	meteor.free()


func _check_tuning() -> void:
	_expect(is_equal_approx(Tuning.JUMP_VELOCITY, sqrt(54.0)), "Jump velocity must derive from gravity and height")
	_expect(Tuning.SPRINT_SPEED > Tuning.WALK_SPEED, "Sprint must exceed walk speed")
	_expect(Tuning.COYOTE_TIME == Tuning.JUMP_BUFFER_TIME, "Input grace windows should match the bible baseline")


func _check_scenes() -> void:
	_expect(load("res://game/player.gd") != null, "Player script must compile")
	_expect(load("res://game/cosmetic_ragdoll.gd") != null, "Cosmetic ragdoll script must compile")
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
