extends SceneTree

const OUTPUT_DIR := "res://assets/generated"
const MATERIAL_DIR := "res://assets/materials"
const GENERATOR_VERSION := 11
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


func _toy_material(color: Color, roughness := 0.48, clearcoat := 0.15, clearcoat_roughness := 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = roughness
	material.clearcoat = clearcoat
	material.clearcoat_roughness = clearcoat_roughness
	return material


func _generate_character(_materials: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "CHR_Base_v001"
	root.set_script(CharacterVisualScript)
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)

	# Matte-satin painted vinyl / wooden toy figurine palette (shared instances).
	var suit_mat := _toy_material(PALETTE.cyan, 0.48, 0.15, 0.35)
	var wood_skin := _toy_material(Color("f2d5b1"), 0.50, 0.15, 0.35)
	var face_cream := _toy_material(Color("faf0de"), 0.52, 0.12, 0.38)
	var cheek_blush := _toy_material(Color("e59b8c"), 0.54, 0.10, 0.40)
	var collar_cream := _toy_material(PALETTE.cream, 0.48, 0.15, 0.35)
	var slate_trim := _toy_material(Color("3d495c"), 0.46, 0.15, 0.35)
	var amber_trim := _toy_material(PALETTE.amber, 0.36, 0.25, 0.25)
	var pack_sand := _toy_material(PALETTE.sand, 0.50, 0.15, 0.35)
	var pack_coral := _toy_material(PALETTE.coral, 0.48, 0.15, 0.35)
	var eye_gloss := _toy_material(Color("1b2432"), 0.14, 0.55, 0.10)
	var eye_spark := _toy_material(Color("ffffff"), 0.15, 0.40, 0.12)
	var mouth_ink := _toy_material(Color("1b2432"), 0.26, 0.20, 0.30)

	# Chunky Vinyl / Wooden Toy Figurine (~1.56 m total height, ~1:2.44 head ratio).
	# 1. Rounded figurine head (visible = true) with sculpted ears and rosy cheeks.
	var head := _add_sphere(root, "Head", 0.31, 0.64, Vector3(0.0, 1.24, 0.0), wood_skin, 24, 10)
	head.scale = Vector3(1.03, 1.0, 0.96)
	for side in ["Left", "Right"]:
		var dir := -1.0 if side == "Left" else 1.0
		var ear := _add_sphere(head, side + "Ear", 0.068, 0.13, Vector3(dir * 0.295, -0.02, 0.01), wood_skin, 12, 5)
		ear.scale.z = 0.65
		var cheek := _add_sphere(head, side + "Cheek", 0.044, 0.056, Vector3(dir * 0.145, -0.055, -0.256), cheek_blush, 10, 4)
		cheek.scale.z = 0.25

	# 2. Chunky tapered/rounded vinyl-wood torso + collar, waist belt, and rear cue.
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = _make_figurine_torso_mesh(suit_mat)
	torso.position = Vector3(0.0, 0.66, 0.0)
	root.add_child(torso)
	torso.owner = root

	var collar := MeshInstance3D.new()
	collar.name = "NeckCollar"
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 0.115
	collar_mesh.outer_radius = 0.185
	collar_mesh.rings = 16
	collar_mesh.ring_segments = 8
	collar_mesh.material = collar_cream
	collar.mesh = collar_mesh
	collar.position = Vector3(0.0, 0.26, 0.0)
	torso.add_child(collar)

	var belt := MeshInstance3D.new()
	belt.name = "WaistBelt"
	var belt_mesh := TorusMesh.new()
	belt_mesh.inner_radius = 0.215
	belt_mesh.outer_radius = 0.262
	belt_mesh.rings = 18
	belt_mesh.ring_segments = 6
	belt_mesh.material = slate_trim
	belt.mesh = belt_mesh
	belt.position = Vector3(0.0, -0.11, 0.0)
	belt.scale = Vector3(1.0, 1.05, 0.85)
	torso.add_child(belt)
	_add_box(belt, "Buckle", Vector3(0.088, 0.070, 0.038), Vector3(0.0, 0.0, -0.255), amber_trim)

	# Default rear silhouette cue (mini wooden knapsack); hidden when back outfits are equipped.
	var rear_cue := _add_box(torso, "RearCue", Vector3(0.24, 0.24, 0.11), Vector3(0.0, 0.05, 0.235), pack_sand)
	_add_box(rear_cue, "Flap", Vector3(0.252, 0.075, 0.124), Vector3(0.0, 0.095, 0.004), pack_coral)
	_add_box(rear_cue, "Clasp", Vector3(0.052, 0.052, 0.03), Vector3(0.0, 0.055, 0.066), amber_trim)

	# 3. High-contrast toy face on -Z (direct children of root for animation contracts).
	var face_plate := _add_sphere(root, "FacePlate", 0.210, 0.33, Vector3(0.0, 1.21, -0.256), face_cream, 24, 8)
	face_plate.scale.z = 0.24
	for side in ["Left", "Right"]:
		var dir := -1.0 if side == "Left" else 1.0
		var eye := _add_sphere(root, side + "Eye", 0.036, 0.086, Vector3(dir * 0.092, 1.255, -0.296), eye_gloss, 12, 6)
		eye.scale.z = 0.55
		_add_sphere(eye, "Catchlight", 0.010, 0.020, Vector3(0.011, 0.015, -0.030), eye_spark, 8, 4)
	_add_smile(root, mouth_ink)

	# 4. Distinct rounded limbs with hands, shoes, and RightArm/HandAnchor.
	for side in ["Left", "Right"]:
		var direction := -1.0 if side == "Left" else 1.0
		var arm := Node3D.new()
		arm.name = side + "Arm"
		arm.position = Vector3(direction * 0.275, 0.84, 0.0)
		root.add_child(arm)
		arm.owner = root
		_add_capsule(arm, "Mesh", 0.078, 0.34, Vector3(direction * 0.035, -0.14, 0.0), suit_mat, 16, 3)
		_add_sphere(arm, side + "Hand", 0.074, 0.148, Vector3(direction * 0.042, -0.305, -0.015), wood_skin, 12, 6)
		if side == "Right":
			var hand_anchor := Marker3D.new()
			hand_anchor.name = "HandAnchor"
			hand_anchor.position = Vector3(0.055, -0.295, -0.14)
			arm.add_child(hand_anchor)

		var leg := Node3D.new()
		leg.name = side + "Leg"
		leg.position = Vector3(direction * 0.145, 0.42, 0.0)
		root.add_child(leg)
		leg.owner = root
		_add_capsule(leg, "Mesh", 0.095, 0.32, Vector3(0.0, -0.16, 0.0), suit_mat, 16, 3)
		var shoe := _add_sphere(leg, side + "Shoe", 0.112, 0.20, Vector3(0.0, -0.32, -0.045), slate_trim, 16, 6)
		shoe.scale = Vector3(1.0, 1.0, 1.32)

	root.ensure_runtime_setup()
	_set_owners(root, root)
	_save_scene(root, "%s/CHR_Base_v001.tscn" % OUTPUT_DIR)


func _make_figurine_torso_mesh(material: Material) -> ArrayMesh:
	# Revolved wooden/vinyl figurine body centered at local y = 0 (world y = 0.66).
	# Profile points: [local_y, radius_x] from bottom hip (-0.28) to neck seat (+0.27).
	var profile := [
		[-0.28, 0.0],
		[-0.275, 0.155],
		[-0.23, 0.235],
		[-0.16, 0.255],
		[-0.08, 0.242],
		[0.04, 0.258],
		[0.15, 0.264],
		[0.22, 0.225],
		[0.265, 0.145],
		[0.27, 0.0],
	]
	var radial := 20
	var z_scale := 0.85
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for ring_idx in profile.size() - 1:
		var y0: float = profile[ring_idx][0]
		var r0: float = profile[ring_idx][1]
		var y1: float = profile[ring_idx + 1][0]
		var r1: float = profile[ring_idx + 1][1]
		for seg in radial:
			var a0 := TAU * float(seg) / float(radial)
			var a1 := TAU * float(seg + 1) / float(radial)
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0 * z_scale)
			var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0 * z_scale)
			var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1 * z_scale)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1 * z_scale)
			if r0 > 0.0:
				st.add_vertex(p00)
				st.add_vertex(p10)
				st.add_vertex(p01)
			if r1 > 0.0:
				st.add_vertex(p10)
				st.add_vertex(p11)
				st.add_vertex(p01)
	st.generate_normals()
	return st.commit()


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
		var outer_a := Vector3(cos(a) * 0.056, -sin(a) * 0.044, 0)
		var outer_b := Vector3(cos(b) * 0.056, -sin(b) * 0.044, 0)
		var inner_a := Vector3(cos(a) * 0.040, -sin(a) * 0.025, 0)
		var inner_b := Vector3(cos(b) * 0.040, -sin(b) * 0.025, 0)
		for vertex in [outer_a, inner_a, outer_b, outer_b, inner_a, inner_b]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var smile := MeshInstance3D.new()
	smile.name = "Mouth"
	smile.mesh = surface.commit()
	smile.material_override = material
	smile.position = Vector3(0.0, 1.155, -0.309)
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


func _add_capsule(parent: Node, node_name: String, radius: float, height: float, position: Vector3, material: Material, radial_segments := 20, rings := 3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
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
