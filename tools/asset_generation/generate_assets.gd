extends SceneTree

const OUTPUT_DIR := "res://assets/generated"
const MATERIAL_DIR := "res://assets/materials"
const GENERATOR_VERSION := 2
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


func _generate_character(materials: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "CHR_Base_v001"
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	_add_sphere(root, "Head", 0.24, 0.43, Vector3(0.0, 1.385, 0.0), materials.cream)
	_add_box(root, "Torso", Vector3(0.43, 0.52, 0.28), Vector3(0.0, 0.96, 0.0), materials.cyan)
	_add_capsule(root, "LeftArm", 0.09, 0.48, Vector3(-0.19, 0.94, 0.0), materials.cyan)
	_add_capsule(root, "RightArm", 0.09, 0.48, Vector3(0.19, 0.94, 0.0), materials.cyan)
	_add_capsule(root, "LeftLeg", 0.10, 0.50, Vector3(-0.13, 0.42, 0.0), materials.cyan)
	_add_capsule(root, "RightLeg", 0.10, 0.50, Vector3(0.13, 0.42, 0.0), materials.cyan)
	_add_box(root, "LeftShoe", Vector3(0.20, 0.16, 0.24), Vector3(-0.13, 0.10, -0.025), materials.slate)
	_add_box(root, "RightShoe", Vector3(0.20, 0.16, 0.24), Vector3(0.13, 0.10, -0.025), materials.slate)
	_add_sphere(root, "LeftEye", 0.035, 0.07, Vector3(-0.09, 1.43, -0.215), materials.ink)
	_add_sphere(root, "RightEye", 0.035, 0.07, Vector3(0.09, 1.43, -0.215), materials.ink)
	_add_box(root, "Mouth", Vector3(0.09, 0.025, 0.018), Vector3(0.0, 1.32, -0.229), materials.ink)
	_save_scene(root, "%s/CHR_Base_v001.tscn" % OUTPUT_DIR)


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


func _add_box(parent: Node, node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	instance.owner = parent


func _add_capsule(parent: Node, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	instance.owner = parent


func _add_sphere(parent: Node, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	instance.owner = parent


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
