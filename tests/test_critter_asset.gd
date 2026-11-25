extends SceneTree
## T44 A2 critter asset gates (Architect A2 plan section 4): KayKit Rogue_Hooded
## (CC0) base + generated critter parts + sync_rig bone adapter.

const Parts = preload("res://tools/asset_generation/critter_parts.gd")
const KAYKIT_DIR := "res://assets/characters/kaykit_adventurers"
const KAYKIT_GLB := KAYKIT_DIR + "/Rogue_Hooded.glb"
const KAYKIT_COMMIT := "672074b73ba276876a19e8816ecdc5241817ab47"
const LICENSE_SHA256 := "ae3221418"
const BASE_TRI_BUDGET := 6000
const OUTFIT_TRI_BUDGET := 7000
const ACCESSORY_TRI_LIMIT := 800
const EAR_SINK := 0.02

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var character := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	root.add_child(character)
	await process_frame
	_check_provenance()
	_check_budgets(character)
	_check_no_primitives(character)
	_check_ratio(character)
	_check_ears_sink(character)
	_check_rig_adapter(character)
	_check_part_determinism()
	character.free()
	if failures.is_empty():
		print("CRITTER_ASSET_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_provenance() -> void:
	var license := FileAccess.get_file_as_string(KAYKIT_DIR + "/LICENSE.txt")
	_expect(license.contains("CC0") or license.contains("Creative Commons"), "KayKit LICENSE.txt (CC0) must be committed verbatim")
	_expect(FileAccess.get_sha256(KAYKIT_DIR + "/LICENSE.txt").begins_with(LICENSE_SHA256), "KayKit LICENSE.txt must match the upstream file byte-for-byte")
	var source := FileAccess.get_file_as_string(KAYKIT_DIR + "/SOURCE.md")
	_expect(source.contains(KAYKIT_COMMIT) and source.contains("Rogue_Hooded.glb"), "SOURCE.md must pin the KayKit commit and file")
	var third_party := FileAccess.get_file_as_string("res://assets/THIRD_PARTY.md")
	_expect(third_party.contains("KayKit") and third_party.contains("672074b"), "THIRD_PARTY.md must list the KayKit asset")
	var import_text := FileAccess.get_file_as_string(KAYKIT_GLB + ".import")
	_expect(import_text.contains("animation/import=false"), "KayKit clips must not be imported")
	var model := (load(KAYKIT_GLB) as PackedScene).instantiate()
	_expect(model.find_children("*", "AnimationPlayer", true, false).is_empty(), "0 KayKit clips/AnimationPlayers imported")
	_expect(model.find_children("*", "BoneAttachment3D", true, false).is_empty(), "KayKit cape/weapon attachments must be skipped at import")
	model.free()


func _tris(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices = arrays[Mesh.ARRAY_INDEX]
		total += (indices as PackedInt32Array).size() / 3 if indices != null and (indices as PackedInt32Array).size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _base_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node.name == "Accessories":
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_base_meshes(child))
	return result


func _check_budgets(character: ToyCharacterVisual) -> void:
	var base := 0
	for part in _base_meshes(character):
		base += _tris(part.mesh)
	_expect(base <= BASE_TRI_BUDGET, "Base critter (KayKit + face/paws/feet + proxies) must stay <= %d tris (got %d)" % [BASE_TRI_BUDGET, base])
	var per_outfit := {}
	for accessory: MeshInstance3D in character.get_node("Accessories").get_children():
		var tris := _tris(accessory.mesh)
		_expect(tris < ACCESSORY_TRI_LIMIT, "%s must stay < %d tris (got %d)" % [accessory.name, ACCESSORY_TRI_LIMIT, tris])
		var outfit: int = accessory.get_meta("outfit")
		per_outfit[outfit] = per_outfit.get(outfit, 0) + tris
	for outfit: int in per_outfit:
		_expect(base + per_outfit[outfit] <= OUTFIT_TRI_BUDGET, "Outfit %d must stay <= %d tris" % [outfit, OUTFIT_TRI_BUDGET])
	print("CRITTER_TRIS base=%d max_outfit=%d" % [base, base + per_outfit.values().max()])
	var materials := {}
	for part in _base_meshes(character):
		if part.material_override != null and part.visible:
			materials[part.material_override.resource_path if not part.material_override.resource_path.is_empty() else str(part.material_override.get_instance_id())] = true
	_expect(materials.size() <= 6, "At most 6 critter materials on the base (got %d)" % materials.size())


func _check_no_primitives(character: Node) -> void:
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		_expect(mesh != null and not (mesh is PrimitiveMesh), "%s must not use a Godot primitive mesh" % character.get_path_to(node))


func _check_ratio(character: ToyCharacterVisual) -> void:
	var hood := character.get_node("Model/Rig/Skeleton3D/Rogue_Head_Hooded") as MeshInstance3D
	var aabb: AABB = ToyCharacterVisual.MODEL_BASE * hood.get_aabb()
	var ratio := aabb.end.y / aabb.size.y
	_expect(ratio >= 2.0 and ratio <= 2.4, "Head:height must be 1:2.0..1:2.4 (got 1:%.2f)" % ratio)
	print("CRITTER_RATIO 1:%.3f head_h=%.3f top=%.3f" % [ratio, aabb.size.y, aabb.end.y])


func _check_ears_sink(character: ToyCharacterVisual) -> void:
	# The deepest ear-base vertex sits >= EAR_SINK below the hood surface (no floating ears).
	var hood := character.get_node("Model/Rig/Skeleton3D/Rogue_Head_Hooded") as MeshInstance3D
	var faces := hood.mesh.get_faces()
	var to_root := ToyCharacterVisual.MODEL_BASE
	for i in faces.size():
		faces[i] = to_root * faces[i]
	for accessory: MeshInstance3D in character.get_node("Accessories").get_children():
		if accessory.get_meta("body") != "Head":
			continue
		var vertices: PackedVector3Array = accessory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for side in [-1.0, 1.0]:
			# Ear base = centroid of the side's bottom 20% height band.
			var min_y := INF
			var max_y := -INF
			for v in vertices:
				if signf(v.x) == side:
					min_y = minf(min_y, v.y)
					max_y = maxf(max_y, v.y)
			var lowest := Vector3.ZERO
			var count := 0
			for v in vertices:
				if signf(v.x) == side and v.y <= min_y + (max_y - min_y) * 0.2:
					lowest += v
					count += 1
			lowest /= maxi(count, 1)
			var depth := _depth_below_surface(faces, accessory.transform * lowest)
			_expect(depth >= EAR_SINK, "%s ear base (side %d) must sink >= %.2f m into the hood (got %.3f)" % [accessory.name, side, EAR_SINK, depth])


func _depth_below_surface(faces: PackedVector3Array, point: Vector3) -> float:
	# Count hits straight up; odd = inside. Depth = distance to the first hit.
	var hits := 0
	var nearest := INF
	for t in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(point, Vector3.UP, faces[t], faces[t + 1], faces[t + 2])
		if hit != null:
			hits += 1
			nearest = minf(nearest, (hit as Vector3).y - point.y)
	return nearest if hits > 0 else -1.0


func _check_rig_adapter(character: ToyCharacterVisual) -> void:
	var rig := character.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var animation := character.get_node("AnimationPlayer") as AnimationPlayer
	var handslot := rig.find_bone("handslot.r")
	var flip := Quaternion(Vector3.UP, PI)
	var worst_hand := 0.0
	var worst_angle := 0.0
	for clip in ToyCharacterVisual.REQUIRED_CLIPS:
		character.play_clip(clip)
		if clip in ["walk", "run"]:
			character.set_locomotion_speed(4.5 if clip == "walk" else 6.5)
		character.sync_rig(1.0)
		animation.pause()
		for sample in 8:
			animation.seek(sample / 8.0 * animation.current_animation_length, true)
			character.sync_rig()
			var slot := rig.global_transform * rig.get_bone_global_pose(handslot).origin
			worst_hand = maxf(worst_hand, character.get_hand_anchor().global_position.distance_to(slot))
			for proxy: String in ToyCharacterVisual.BONE_MAP:
				var bone := rig.find_bone(ToyCharacterVisual.BONE_MAP[proxy])
				var rest_q := rig.get_bone_global_rest(bone).basis.get_rotation_quaternion()
				if proxy == "LeftArm":
					rest_q = Quaternion(Vector3.BACK, -ToyCharacterVisual.ARM_DOWN_ANGLE) * rest_q
				elif proxy == "RightArm":
					rest_q = Quaternion(Vector3.BACK, ToyCharacterVisual.ARM_DOWN_ANGLE) * rest_q
				var expected := flip * (character.get_node(proxy) as Node3D).basis.get_rotation_quaternion() * flip * rest_q
				var actual := rig.get_bone_global_pose(bone).basis.get_rotation_quaternion()
				worst_angle = maxf(worst_angle, rad_to_deg(expected.angle_to(actual)))
		animation.play()
	_expect(worst_hand <= 0.03, "HandAnchor must stay within 0.03 m of handslot.r for every clip (got %.4f)" % worst_hand)
	_expect(worst_angle <= 1.0, "Mapped KayKit bones must track their pivots within 1 degree (got %.3f)" % worst_angle)
	print("CRITTER_RIG hand=%.4f angle=%.3f" % [worst_hand, worst_angle])


func _check_part_determinism() -> void:
	# Regenerate every part and compare the serialized surface data byte-for-byte
	# with the committed .res (the .res header carries a per-path UID).
	for part in Parts.part_names():
		var fresh := Parts.build(part)
		var committed := load(Parts.part_path(part)) as Mesh
		var same := fresh.get_surface_count() == committed.get_surface_count()
		for surface in fresh.get_surface_count() if same else 0:
			same = same and var_to_bytes(fresh.surface_get_arrays(surface)) == var_to_bytes(committed.surface_get_arrays(surface))
		_expect(same, "%s.res must regenerate byte-identically (surface arrays)" % part)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
