extends SceneTree

const OUTPUT_DIR := "res://assets/generated"
const MATERIAL_DIR := "res://assets/materials"
const GENERATOR_VERSION := 12
const CharacterVisualScript = preload("res://game/player/toy_character_visual.gd")
const PALETTE := {
	"cream": Color("f4e6c8"), "sand": Color("d9b77e"), "slate": Color("49566a"),
	"teal": Color("73b7ad"), "coral": Color("d98d7d"), "grass": Color("86a968"),
	"amber": Color("ffbf3f"), "orange": Color("f06438"), "ink": Color("202a38"),
	"cyan": Color("31c5df")
}
var seed_value := 297


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = argument.trim_prefix("--seed=").to_int()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_DIR))
	var materials := _generate_materials()
	_generate_character(materials)
	if "--character-only" in OS.get_cmdline_user_args():
		print("CHARACTER_GENERATION_OK seed=%d version=%d" % [seed_value, GENERATOR_VERSION])
		quit()
		return
	_generate_wall(materials)
	_generate_crate(materials)
	_generate_meteor_proxy(materials)
	print("ASSET_GENERATION_OK seed=%d assets=4 materials=%d" % [seed_value, materials.size()])
	quit()


func _generate_materials() -> Dictionary:
	var materials := {}
	for key in PALETTE:
		var material := StandardMaterial3D.new()
		material.albedo_color = PALETTE[key]
		material.metallic = 0.0
		material.roughness = 0.8
		if key == "amber":
			material.emission_enabled = true
			material.emission = PALETTE[key]
			material.emission_energy_multiplier = 0.35
		var path := "%s/MAT_%s_v001.tres" % [MATERIAL_DIR, key.capitalize()]
		assert(ResourceSaver.save(material, path) == OK)
		materials[key] = load(path)
	return materials


const CRITTER_MESH_DIR := "res://assets/models/critter/meshes"
const CRITTER_MATERIAL_DIR := "res://assets/models/critter/materials"
const SculptCritter = preload("res://tools/asset_generation/sculpt_critter.gd")


func _critter_materials() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CRITTER_MATERIAL_DIR))
	var specs := {
		"Suit": CharacterVisualScript.fabric_material(PALETTE.cyan),
		"Skin": CharacterVisualScript.fabric_material(Color("fbe7cf"), 0.88, 0.22),
		"Pattern": CharacterVisualScript.fabric_material(Color.WHITE, 0.9, 0.25, true),
		"Bead": CharacterVisualScript.fabric_material(Color("1b2432"), 0.3, 0.1),
	}
	var result := {}
	for key in specs:
		var path := "%s/MAT_Critter_%s_v001.tres" % [CRITTER_MATERIAL_DIR, key]
		assert(ResourceSaver.save(specs[key], path) == OK)
		result[key] = load(path)
	return result


func _critter_part(parent: Node, node_name: String, part: String, position: Vector3, surface_materials: Array) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = load("%s/%s.res" % [CRITTER_MESH_DIR, part]) as Mesh
	assert(instance.mesh != null, "missing sculpted mesh %s (run sculpt_critter.gd + tools/godot-import.sh)" % part)
	instance.position = position
	for surface in mini(instance.mesh.get_surface_count(), surface_materials.size()):
		instance.set_surface_override_material(surface, surface_materials[surface])
	parent.add_child(instance)
	instance.owner = parent if parent.owner == null else parent.owner
	return instance


func _generate_character(_materials: Dictionary) -> void:
	# T44 Plush Critter / Animal-Hoodie: every body part is a sculpted mesh
	# extracted from assets/models/critter/CHR_Critter_v001.glb (no primitives).
	var root := Node3D.new()
	root.name = "CHR_Base_v001"
	root.set_script(CharacterVisualScript)
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	root.set_meta("head_top_y", SculptCritter.HEAD_TOP_Y)
	root.set_meta("head_bottom_y", SculptCritter.HEAD_BOTTOM_Y)
	root.set_meta("source_glb", SculptCritter.GLB_PATH)
	var mat := _critter_materials()

	var torso := _critter_part(root, "Torso", "Body", Vector3(0.0, SculptCritter.TORSO_Y, 0.0), [mat.Suit])
	_critter_part(torso, "BellyPatch", "Belly_00", Vector3.ZERO, [mat.Pattern])
	_critter_part(root, "Head", "Face", Vector3(0.0, 1.12, -0.17), [mat.Skin])
	_critter_part(root, "FacePlate", "Muzzle", Vector3(0.0, 1.075, -0.287), [mat.Skin, mat.Bead])
	for side in ["Left", "Right"]:
		var dir := -1.0 if side == "Left" else 1.0
		_critter_part(root, side + "Eye", "Eye", Vector3(dir * 0.088, 1.158, -0.288), [mat.Bead])
	_critter_part(root, "Mouth", "Mouth", Vector3(0.0, 1.043, -0.311), [mat.Bead])

	for side in ["Left", "Right"]:
		var direction := -1.0 if side == "Left" else 1.0
		var suffix := "L" if side == "Left" else "R"
		var arm := Node3D.new()
		arm.name = side + "Arm"
		arm.position = Vector3(direction * 0.18, 0.78, 0.0)
		root.add_child(arm)
		arm.owner = root
		_critter_part(arm, "Mesh", "Arm" + suffix, Vector3.ZERO, [mat.Suit])
		var paw := _critter_part(arm, side + "Hand", "Paw" + suffix, Vector3(direction * 0.112, -0.27, -0.016), [mat.Skin])
		paw.set_meta("paw_radius", SculptCritter.PAW_RADIUS)
		if side == "Right":
			# Seated in the paw grip (inside the paw, slightly forward).
			var hand_anchor := Marker3D.new()
			hand_anchor.name = "HandAnchor"
			hand_anchor.position = paw.position + Vector3(0.0, -0.01, -0.035)
			arm.add_child(hand_anchor)

		var leg := Node3D.new()
		leg.name = side + "Leg"
		leg.position = Vector3(direction * 0.12, 0.42, 0.0)
		root.add_child(leg)
		leg.owner = root
		var leg_mesh := _critter_part(leg, "Mesh", "Leg", Vector3(0.0, -0.16, 0.0), [mat.Suit])
		leg_mesh.set_meta("root_cap_y", SculptCritter.LEG_ROOT_Y)
		_critter_part(leg, side + "Shoe", "Foot", Vector3(0.0, -0.32, -0.045), [mat.Skin])

	root.ensure_runtime_setup()
	_set_owners(root, root)
	_save_scene(root, "%s/CHR_Base_v001.tscn" % OUTPUT_DIR)


func _set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owners(child, root)


func _generate_wall(materials: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "ENV_Wall_2m_v001"
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	_add_box(root, "Wall", Vector3(2.0, 2.5, 0.20), Vector3(0.0, 1.25, 0.0), materials.cream)
	_add_box(root, "Trim", Vector3(2.0, 0.12, 0.24), Vector3(0.0, 2.40, -0.01), materials.teal)
	_save_scene(root, "%s/ENV_Wall_2m_v001.tscn" % OUTPUT_DIR)


func _generate_crate(materials: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "PROP_Crate_Small_v001"
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	_add_box(root, "Body", Vector3(0.6, 0.6, 0.6), Vector3(0.0, 0.3, 0.0), materials.sand)
	_add_box(root, "Band", Vector3(0.64, 0.10, 0.64), Vector3(0.0, 0.3, 0.0), materials.slate)
	_save_scene(root, "%s/PROP_Crate_Small_v001.tscn" % OUTPUT_DIR)


func _generate_meteor_proxy(materials: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "VFX_MeteorTelegraph_v001"
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	var ring := MeshInstance3D.new()
	ring.name = "WarningFootprint"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.34
	torus.outer_radius = 1.50
	torus.rings = 32
	torus.ring_segments = 8
	torus.material = materials.amber
	ring.mesh = torus
	ring.position.y = 0.04
	root.add_child(ring)
	ring.owner = root
	_add_sphere(root, "Meteor", 0.42, 0.84, Vector3(0.0, 2.4, 0.0), materials.orange)
	_save_scene(root, "%s/VFX_MeteorTelegraph_v001.tscn" % OUTPUT_DIR)


func _add_box(parent: Node, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	instance.owner = parent
	return instance


func _add_sphere(parent: Node, node_name: String, radius: float, height: float, position: Vector3, material: Material, radial_segments := 24, rings := 6) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	instance.owner = parent
	return instance


func _save_scene(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	assert(scene.pack(root) == OK)
	assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES) == OK)
	var generated_text := FileAccess.get_file_as_string(path)
	var unique_ids := RegEx.new()
	assert(unique_ids.compile("\\sunique_id=\\d+") == OK)
	generated_text = unique_ids.sub(generated_text, "", true)
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(generated_text)
	root.free()
