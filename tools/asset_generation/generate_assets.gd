extends SceneTree

const OUTPUT_DIR := "res://assets/generated"
const MATERIAL_DIR := "res://assets/materials"
const GENERATOR_VERSION := 10
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


func _generate_character(materials: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "CHR_Base_v001"
	root.set_script(CharacterVisualScript)
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	# Soft Creature B: broad uninterrupted suit, oval inset and stubby limbs.
	# A single uninterrupted capsule surface, not intersecting head/body bulbs.
	# Keep the named Head anchor for existing appearance and ragdoll contracts.
	_add_sphere(root, "Head", 0.01, 0.02, Vector3(0.0, 1.25, 0.0), materials.cyan)
	root.get_node("Head").visible = false
	_add_capsule(root, "Torso", 0.40, 1.28, Vector3(0.0, 0.96, 0.0), materials.cyan)
	root.get_node("Torso").scale.z = 0.82
	# Flattened cream face inset on the front of the bean.
	_add_sphere(root, "FacePlate", 0.29, 0.48, Vector3(0.0, 1.18, -0.332), materials.cream)
	root.get_node("FacePlate").scale.z = 0.10
	for side in ["Left", "Right"]:
		var direction := -1.0 if side == "Left" else 1.0
		var arm := Node3D.new()
		arm.name = side + "Arm"
		arm.position = Vector3(direction * 0.36, 1.02, 0.0)
		root.add_child(arm)
		arm.owner = root
		_add_capsule(arm, "Mesh", 0.115, 0.43, Vector3(direction * 0.065, -0.17, 0.0), materials.cyan)
		arm.get_node("Mesh").owner = root
		var leg := Node3D.new()
		leg.name = side + "Leg"
		leg.position = Vector3(direction * 0.20, 0.43, 0.0)
		root.add_child(leg)
		leg.owner = root
		_add_capsule(leg, "Mesh", 0.115, 0.32, Vector3(0.0, -0.16, 0.0), materials.cyan)
		leg.get_node("Mesh").owner = root
		_add_sphere(leg, side + "Shoe", 0.155, 0.22, Vector3(0.0, -0.32, -0.045), materials.slate)
		leg.get_node(side + "Shoe").scale.z = 1.12
		leg.get_node(side + "Shoe").owner = root
	# Eyes and mouth sit on the cream face inset, not directly on the bean body.
	_add_sphere(root, "LeftEye", 0.035, 0.10, Vector3(-0.105, 1.22, -0.353), materials.ink)
	_add_sphere(root, "RightEye", 0.035, 0.10, Vector3(0.105, 1.22, -0.353), materials.ink)
	_add_smile(root, materials.ink)
	for part in ["LeftEye", "RightEye"]:
		root.get_node(part).scale.z = 0.22
	root.ensure_runtime_setup()
	_set_owners(root, root)
	_save_scene(root, "%s/CHR_Base_v001.tscn" % OUTPUT_DIR)


func _set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owners(child, root)


func _add_smile(root: Node3D, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 12:
		var a := PI * (0.15 + 0.70 * step / 12.0)
		var b := PI * (0.15 + 0.70 * (step + 1) / 12.0)
		var outer_a := Vector3(cos(a) * 0.057, -sin(a) * 0.047, 0)
		var outer_b := Vector3(cos(b) * 0.057, -sin(b) * 0.047, 0)
		var inner_a := Vector3(cos(a) * 0.042, -sin(a) * 0.027, 0)
		var inner_b := Vector3(cos(b) * 0.042, -sin(b) * 0.027, 0)
		for vertex in [outer_a, inner_a, outer_b, outer_b, inner_a, inner_b]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var smile := MeshInstance3D.new()
	smile.name = "Mouth"
	smile.mesh = surface.commit()
	smile.material_override = material
	smile.position = Vector3(0, 1.12, -0.365)
	root.add_child(smile)
	smile.owner = root


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
	mesh.radial_segments = 32 if node_name == "Torso" else 24
	mesh.rings = 4 if node_name == "Torso" else 3
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
	mesh.radial_segments = 48 if node_name == "FacePlate" else (8 if node_name == "Head" else 24)
	mesh.rings = 12 if node_name == "FacePlate" else 6
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
