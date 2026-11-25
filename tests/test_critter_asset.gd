extends SceneTree
## T44 plush critter asset gates (Architect plan section 7).

const Sculpt = preload("res://tools/asset_generation/sculpt_critter.gd")
const GLB := "res://assets/models/critter/CHR_Critter_v001.glb"
const GAP_TOLERANCE := 0.005
const LIMB_SINK := 0.04

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var character := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	root.add_child(character)
	await process_frame
	_check_provenance(character)
	_check_uvs_and_triangles(character)
	_check_determinism()
	_check_outfits(character)
	_check_hand_anchor(character)
	_check_limb_gaps(character)
	character.free()
	if failures.is_empty():
		print("CRITTER_ASSET_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_provenance(character: Node) -> void:
	_expect(FileAccess.file_exists(GLB), "Sculpted glTF source must be committed")
	var import_text := FileAccess.get_file_as_string(GLB + ".import")
	var torso := character.get_node("Torso") as MeshInstance3D
	_expect(torso.mesh.resource_path == Sculpt.mesh_path("Body"), "Body (Torso) must load the extracted Body.res mesh")
	var trace := RegEx.create_from_string("\"save_to_file/fallback_path\": \"%s\",\\s*\"save_to_file/path\": \"([^\"]+)\"" % Sculpt.mesh_path("Body"))
	var found := trace.search(import_text)
	var saved_to := "" if found == null else found.get_string(1)
	if saved_to.begins_with("uid://"):
		saved_to = ResourceUID.get_id_path(ResourceUID.text_to_id(saved_to))
	_expect(saved_to == Sculpt.mesh_path("Body"), "Body.res must trace to the .glb import (save_to_file -> %s)" % saved_to)
	_expect(import_text.contains("meshes/generate_lods=true") or import_text.contains("\"generate/lods\": 1"), "Critter import keeps LODs on")
	for path in ["Head", "FacePlate", "LeftEye", "RightEye", "Mouth", "LeftArm/Mesh", "LeftArm/LeftHand", "RightArm/Mesh", "RightArm/RightHand", "LeftLeg/Mesh", "LeftLeg/LeftShoe", "RightLeg/Mesh", "RightLeg/RightShoe", "Torso/BellyPatch"]:
		var part := character.get_node(path) as MeshInstance3D
		var source := part.mesh.resource_path
		_expect(source.begins_with("res://assets/models/critter/meshes/") and source.ends_with(".res"), "%s must come from an extracted sculpt .res" % path)
		_expect(not (part.mesh is PrimitiveMesh), "%s must not be a Godot primitive mesh" % path)
		_expect(import_text.contains(source), "%s mesh must be listed in the .glb import" % path)
	var materials := {}
	for part in _base_meshes(character):
		for surface in part.mesh.get_surface_count():
			var material := part.get_surface_override_material(surface)
			if material != null:
				materials[material] = true
	_expect(materials.size() <= 6, "At most 6 shared critter materials")
	for material: StandardMaterial3D in materials:
		_expect(material.metallic == 0.0 and material.normal_texture != null, "Critter materials are matte fabric with the knit normal map")
	var normal_map := load(Sculpt.NORMAL_MAP_PATH) as Texture2D
	_expect(normal_map != null and normal_map.get_width() <= 256 and normal_map.get_height() <= 256, "Fabric normal map is in-repo and <= 256 px")
	var suit := character.get_node("Torso").get_surface_override_material(0) as StandardMaterial3D
	_expect(suit.roughness >= 0.85 and suit.roughness <= 0.95 and suit.rim >= 0.2 and suit.rim <= 0.3, "Suit fabric roughness 0.85-0.95, rim 0.2-0.3")


func _base_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node.name == "Accessories":
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_base_meshes(child))
	return result


func _check_uvs_and_triangles(character: Node) -> void:
	var meshes: Array[Mesh] = []
	for part in _base_meshes(character):
		meshes.append(part.mesh)
	for accessory: MeshInstance3D in character.get_node("Accessories").get_children():
		if accessory.has_meta("critter_part"):
			meshes.append(accessory.mesh)
	for mesh in meshes:
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			_expect(uvs is PackedVector2Array and (uvs as PackedVector2Array).size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "%s surface %d must have UVs" % [mesh.resource_path, surface])
			var in_range := true
			for uv: Vector2 in uvs:
				if uv.x < -0.001 or uv.y < -0.001 or uv.x > 1.001 or uv.y > 1.001:
					in_range = false
					break
			_expect(in_range, "%s UVs must stay in 0..1" % mesh.resource_path)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var degenerate := 0
			for t in range(0, indices.size(), 3):
				var a := vertices[indices[t]]
				if (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a).length() < 1e-10:
					degenerate += 1
			_expect(degenerate == 0, "%s must have no degenerate triangles (found %d)" % [mesh.resource_path, degenerate])


func _check_determinism() -> void:
	var first := Sculpt.build_part("Body", {})
	var second := Sculpt.build_part("Body", {})
	var a := first.surface_get_arrays(0)
	var b := second.surface_get_arrays(0)
	_expect((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "Sculpt generator must give the same vertex count twice")
	_expect(hash(var_to_bytes(a[Mesh.ARRAY_VERTEX])) == hash(var_to_bytes(b[Mesh.ARRAY_VERTEX])) and hash(var_to_bytes(a[Mesh.ARRAY_INDEX])) == hash(var_to_bytes(b[Mesh.ARRAY_INDEX])), "Sculpt generator must give the same mesh hash twice")
	var committed := load(Sculpt.mesh_path("Body")) as Mesh
	var committed_tris: int = committed.surface_get_array_index_len(0) / 3
	var rebuilt_tris: int = first.surface_get_array_index_len(0) / 3
	_expect(committed_tris == rebuilt_tris, "Committed Body.res triangle count must match a fresh sculpt (%d vs %d)" % [committed_tris, rebuilt_tris])
	print("CRITTER_BODY verts=%d tris=%d hash=%d" % [(a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), rebuilt_tris, hash(var_to_bytes(a[Mesh.ARRAY_VERTEX]))])


func _check_outfits(character: ToyCharacterVisual) -> void:
	var signatures := {}
	for variant in ToyCharacterVisual.catalog().items.size():
		character.set_cosmetic_variant(variant)
		var ears: MeshInstance3D = null
		var tail: MeshInstance3D = null
		for accessory: MeshInstance3D in character.get_node("Accessories").get_children():
			if accessory.visible and accessory.get_meta("critter_part", "") == "ears":
				ears = accessory
			if accessory.visible and accessory.get_meta("critter_part", "") == "tail":
				tail = accessory
		_expect(ears != null and ears.mesh.get_faces().size() > 0, "Outfit %d must show sculpted ears" % variant)
		_expect(tail != null and tail.mesh.get_faces().size() > 0, "Outfit %d must show a sculpted tail" % variant)
		if ears == null or tail == null:
			continue
		_expect(ears.get_meta("body") == "Head" and tail.get_meta("body") == "Pelvis", "Ears ride the Head body, tails the Pelvis body")
		signatures["%s|%s|%s" % [Sculpt.OUTFIT_EARS[variant], Sculpt.OUTFIT_TAILS[variant], Sculpt.OUTFIT_PATTERN[variant]]] = true
		# Ears sunk >= 0.02 m into the hood: every ear root lies inside the body.
		var spec_kind: String = Sculpt.OUTFIT_EARS[variant]
		var spec := Sculpt._ear_shapes(spec_kind)
		for side in [-1.0, 1.0]:
			var frame := Sculpt.ear_frame(side, spec.spread, spec.lift, spec.tilt)
			var torso_local := frame.origin + Sculpt.HOOD_CENTER
			_expect(Sculpt.body_sdf(torso_local) <= -0.02, "Outfit %d ears sink >= 0.02 m into the hood" % variant)
		var tail_root: Vector3 = Sculpt._tail_chain(Sculpt.OUTFIT_TAILS[variant])[0][0] + ToyCharacterVisual.TAIL_ORIGIN - Vector3(0, Sculpt.TORSO_Y, 0)
		_expect(Sculpt.body_sdf(tail_root) <= -0.02, "Outfit %d tail root sinks >= 0.02 m into the body" % variant)
		var belly := character.get_node("Torso/BellyPatch") as MeshInstance3D
		_expect(belly.mesh.resource_path == Sculpt.mesh_path("Belly_%02d" % variant), "Outfit %d swaps the belly pattern patch" % variant)
	_expect(signatures.size() == ToyCharacterVisual.catalog().items.size(), "All 12 outfits have distinct ear/tail/pattern combinations")
	character.set_cosmetic_variant(0)


func _check_hand_anchor(character: ToyCharacterVisual) -> void:
	var anchor := character.get_hand_anchor()
	var paw := character.get_node("RightArm/RightHand") as MeshInstance3D
	var radius: float = paw.get_meta("paw_radius")
	_expect(anchor != null and anchor.get_parent().name == "RightArm", "HandAnchor stays at RightArm/HandAnchor")
	_expect(anchor.position.distance_to(paw.position) < radius, "Hand anchor sits inside the paw (%.3f m < %.3f m)" % [anchor.position.distance_to(paw.position), radius])


func _check_limb_gaps(character: ToyCharacterVisual) -> void:
	var animation := character.get_node("AnimationPlayer") as AnimationPlayer
	var torso := character.get_node("Torso") as Node3D
	var worst := -1.0
	var worst_label := ""
	for clip: String in ToyCharacterVisual.REQUIRED_CLIPS:
		character.play_clip(clip)
		animation.pause()
		var duration := character.get_clip_duration(clip)
		for step in 9:
			animation.seek(duration * step / 8.0, true)
			for side in ["Left", "Right"]:
				var arm := character.get_node(side + "Arm") as Node3D
				var leg := character.get_node(side + "Leg") as Node3D
				var leg_mesh := leg.get_node("Mesh") as MeshInstance3D
				var roots := {
					side + "Arm": arm.global_position,
					side + "Leg": leg_mesh.to_global(Vector3(0, leg_mesh.get_meta("root_cap_y"), 0)),
				}
				for limb: String in roots:
					var local := torso.to_local(roots[limb])
					var depth := Sculpt.body_sdf(local)
					if depth > worst:
						worst = depth
						worst_label = "%s %s t=%.2f" % [clip, limb, duration * step / 8.0]
	print("CRITTER_LIMB_ROOT worst_sdf=%.4f at %s" % [worst, worst_label])
	_expect(worst <= -LIMB_SINK + GAP_TOLERANCE, "Limb root caps stay >= 0.04 m inside the Body at every clip extreme (worst %.4f at %s)" % [worst, worst_label])
	_expect(worst <= GAP_TOLERANCE, "No limb gap over 0.005 m at clip extremes")
	character.play_clip("idle")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
