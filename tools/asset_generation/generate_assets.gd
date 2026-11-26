extends SceneTree

const OUTPUT_DIR := "res://assets/generated"
const MATERIAL_DIR := "res://assets/materials"
const GENERATOR_VERSION := 13
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


const KAYKIT_GLB := "res://assets/characters/kaykit_adventurers/Rogue_Hooded.glb"
const CRITTER_MATERIAL_DIR := "res://assets/models/critter/materials"
const CritterParts = preload("res://tools/asset_generation/critter_parts.gd")


func _critter_materials() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CRITTER_MATERIAL_DIR))
	var specs := {
		"Suit": CharacterVisualScript.critter_material("suit"),
		"Cream": CharacterVisualScript.critter_material("cream"),
		"Bead": CharacterVisualScript.critter_material("bead"),
		"Shine": CharacterVisualScript.critter_material("shine"),
		"Face": CharacterVisualScript.critter_material("face"),
		"Pattern": CharacterVisualScript.critter_material("pattern"),
	}
	var result := {}
	for key in specs:
		var path := "%s/MAT_Critter_%s_v002.tres" % [CRITTER_MATERIAL_DIR, key]
		assert(ResourceSaver.save(specs[key], path) == OK)
		result[key] = load(path)
	return result


func _part(parent: Node, owner_node: Node, node_name: String, part: String, position: Vector3, scale: Vector3, material: Material, visible := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = load(CritterParts.part_path(part)) as Mesh
	assert(instance.mesh != null, "missing part %s (run critter_parts.gd)" % part)
	instance.position = position
	instance.scale = scale
	instance.material_override = material
	instance.visible = visible
	parent.add_child(instance)
	instance.owner = owner_node
	return instance


func _bone_attachment(skeleton: Skeleton3D, owner_node: Node, node_name: String, bone: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	attachment.owner = owner_node
	return attachment


## Spike/concept-sheet coordinates (model units, front -Z) -> bone-local (model is yawed 180).
static func _spike_to_bone(spike: Vector3, bone_rest_origin: Vector3) -> Vector3:
	return Vector3(-spike.x, spike.y, -spike.z) - bone_rest_origin


func _generate_character(_materials: Dictionary) -> void:
	# T44 A2: KayKit Rogue_Hooded (CC0) critter hoodie, concept-sheet look.
	# Visible body = KayKit skinned meshes driven by the pivot proxies via
	# ToyCharacterVisual.sync_rig(); every contract node path stays.
	var root := Node3D.new()
	root.name = "CHR_Base_v001"
	root.set_script(CharacterVisualScript)
	root.set_meta("generator_seed", seed_value)
	root.set_meta("generator_version", GENERATOR_VERSION)
	var mat := _critter_materials()

	var model := (load(KAYKIT_GLB) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.transform = CharacterVisualScript.MODEL_BASE
	root.add_child(model)
	model.owner = root
	# Face/paw/foot bone attachments are added under the instanced rig.
	root.set_editable_instance(model, true)
	var skeleton := model.get_node("Rig/Skeleton3D") as Skeleton3D
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat.Suit
	var hood := skeleton.get_node("Rogue_Head_Hooded") as MeshInstance3D
	var hood_aabb := CharacterVisualScript.MODEL_BASE * hood.get_aabb()
	root.set_meta("head_top_y", hood_aabb.end.y)
	root.set_meta("head_bottom_y", hood_aabb.position.y)
	root.set_meta("source_glb", KAYKIT_GLB)

	# T46 F1: FaceCream uses the existing shaded cream (MAT_Critter_Cream_v002, same as
	# paws/feet) so the plate reads as a lit face, not a flat unshaded grey mask.
	# Big bead eyes with one highlight each and a tiny mouth dot; no blush.
	# All face parts sit +0.08 outward (spike z -0.46/-0.61/-0.665/-0.625 -> -0.54/-0.69/-0.745/-0.705)
	# so the plate clears the open hood rim.
	var head_origin := skeleton.get_bone_global_rest(skeleton.find_bone("head")).origin
	var face := _bone_attachment(skeleton, root, "FaceAnchor", "head")
	_part(face, root, "FaceCream", "Ellipsoid", _spike_to_bone(Vector3(0, 1.62, -0.54), head_origin), Vector3(0.62, 0.52, 0.34), mat.Cream)
	for sx in [-1.0, 1.0]:
		var tag := "L" if sx < 0.0 else "R"
		_part(face, root, "EyeBead" + tag, "Bead", _spike_to_bone(Vector3(sx * 0.165, 1.66, -0.69), head_origin), Vector3(0.15, 0.17, 0.09), mat.Bead)
		_part(face, root, "EyeShine" + tag, "Bead", _spike_to_bone(Vector3(sx * 0.165 + 0.035, 1.705, -0.745), head_origin), Vector3(0.045, 0.045, 0.03), mat.Shine)
	_part(face, root, "MouthDot", "Bead", _spike_to_bone(Vector3(0, 1.52, -0.705), head_origin), Vector3(0.05, 0.035, 0.03), mat.Bead)
	for side in ["l", "r"]:
		var paw := _bone_attachment(skeleton, root, "Paw_" + side, "hand." + side)
		# T45 A2: 1.3x mitten pushed out of the KayKit hand (bone-local; x mirrored per side) so the cream paw shows.
		_part(paw, root, "Mitten", "Mitten", Vector3(0.02 if side == "l" else -0.02, 0.05, 0.05), Vector3(0.26, 0.26, 0.26), mat.Cream)
		var foot := _bone_attachment(skeleton, root, "Foot_" + side, "foot." + side)
		_part(foot, root, "Bootie", "Bead", Vector3(0, -0.07, -0.07), Vector3(0.24, 0.16, 0.34), mat.Cream)

	# Hidden contract proxies (paths, pivots, owners and clips unchanged).
	var to_root := func(bone: String) -> Vector3: return CharacterVisualScript.MODEL_BASE * skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin
	# Torso = lean pivot; pinned to the accessory origin (chest bone at 0.60301).
	var torso := _part(root, root, "Torso", "Proxy", CritterParts.ACCESSORY_ORIGIN, Vector3.ONE, mat.Suit, false)
	torso.set_meta("proxy", true)
	# Head stays visible for the contract but is a tiny bar sealed inside the hood.
	_part(root, root, "Head", "Proxy", to_root.call("head") + Vector3(0, 0.25, 0), Vector3(0.5, 0.3, 0.5), mat.Suit)
	_part(root, root, "FacePlate", "Proxy", Vector3(0, 1.004, -0.285), Vector3.ONE * 0.5, mat.Cream, false)
	for side in ["Left", "Right"]:
		var dir := -1.0 if side == "Left" else 1.0
		_part(root, root, side + "Eye", "Proxy", Vector3(dir * 0.102, 1.03, -0.378), Vector3.ONE * 0.2, mat.Bead, false)
	_part(root, root, "Mouth", "Proxy", Vector3(0, 0.942, -0.388), Vector3.ONE * 0.2, mat.Bead, false)
	for side in ["Left", "Right"]:
		var bone_side := "l" if side == "Left" else "r"
		var arm := Node3D.new()
		arm.name = side + "Arm"
		arm.position = to_root.call("upperarm." + bone_side)
		root.add_child(arm)
		arm.owner = root
		_part(arm, root, "Mesh", "Proxy", Vector3(0, -0.16, 0), Vector3.ONE, mat.Suit, false)
		_part(arm, root, side + "Hand", "Proxy", Vector3(0, -0.33, 0), Vector3.ONE * 0.3, mat.Cream, false)
		if side == "Right":
			var hand_anchor := Marker3D.new()
			hand_anchor.name = "HandAnchor"
			hand_anchor.position = Vector3(0, -0.33, -0.03)
			arm.add_child(hand_anchor)
			hand_anchor.owner = root
		var leg := Node3D.new()
		leg.name = side + "Leg"
		leg.position = to_root.call("upperleg." + bone_side)
		root.add_child(leg)
		leg.owner = root
		var leg_mesh := _part(leg, root, "Mesh", "Proxy", Vector3(0, -0.16, 0), Vector3.ONE, mat.Suit, false)
		leg_mesh.set_meta("root_cap_y", 0.16)
		_part(leg, root, side + "Shoe", "Proxy", Vector3(0, -0.32, -0.045), Vector3.ONE * 0.3, mat.Cream, false)

	root.ensure_runtime_setup()
	# Per-outfit total height including the critter ears (head:height uses the hood).
	var totals := PackedFloat32Array()
	for outfit in CritterParts.OUTFITS.size():
		var top: float = hood_aabb.end.y
		for accessory: MeshInstance3D in root.get_node("Accessories").get_children():
			if accessory.get_meta("outfit") == outfit:
				top = maxf(top, (accessory.transform * accessory.get_aabb()).end.y)
		totals.append(snappedf(top, 0.001))
	root.set_meta("total_height_by_outfit", totals)
	_set_owners_keep_instance(root, root)
	_save_scene(root, "%s/CHR_Base_v001.tscn" % OUTPUT_DIR)


func _set_owners_keep_instance(node: Node, root: Node) -> void:
	# Like _set_owners, but leaves the instanced KayKit scene's own nodes alone.
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
		if child.scene_file_path.is_empty() and (child.owner == root):
			_set_owners_keep_instance(child, root)
		elif not child.scene_file_path.is_empty():
			_owner_added_children(child, root)


func _owner_added_children(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
		_owner_added_children(child, root)


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
