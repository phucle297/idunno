extends SceneTree
## T45 A1 AC3 clearance: per outfit (0..11) and clip/phase, the forearm-mid and wrist
## centre lines vs the torso surface (Rogue_Body rest verts + that outfit's Belly/Tail)
## in the un-waddled character-root frame. Gap = |x_arm| - max |x_body| within
## |dy| < 0.03 and |dz| < 0.06 of the point (same side). Gate = wrist (plan section 2A
## estimate); forearm-mid and elbow (next to the shoulder) are reported as Info.
const CLIPS := [["idle", 0.0], ["walk", 4.5], ["run", 6.5]]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var v := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	root.add_child(v)
	await process_frame
	v.ensure_runtime_setup()
	var rig := v.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var ap := v.get_node("AnimationPlayer") as AnimationPlayer
	var base := PackedVector3Array()
	for p in ((rig.get_node("Rogue_Body") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		base.append(ToyCharacterVisual.MODEL_BASE * p)
	var worst := INF
	var worst_elbow := INF
	var worst_mid := INF
	for outfit in 12:
		v.set_cosmetic_variant(outfit)
		var verts := base.duplicate()
		for part in ["Belly_%02d" % outfit, "Tail_%02d" % outfit]:
			var mi := v.get_node("Accessories/" + part) as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				for p in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					verts.append(mi.transform * p)
		for c in CLIPS:
			v.play_clip(c[0])
			v.set_locomotion_speed(c[1])
			v.sync_rig(0.5)
			ap.pause()
			var row_min := INF
			var row_elbow := INF
			var row_wrist := INF
			for i in 8:
				ap.seek(i / 8.0 * ap.current_animation_length, true)
				v.sync_rig()
				for side in ["l", "r"]:
					var e := ToyCharacterVisual.MODEL_BASE * rig.get_bone_global_pose(rig.find_bone("lowerarm." + side)).origin
					var w := ToyCharacterVisual.MODEL_BASE * rig.get_bone_global_pose(rig.find_bone("wrist." + side)).origin
					row_min = minf(row_min, minf(_gap(verts, (e + w) * 0.5), _gap(verts, w)))
					row_elbow = minf(row_elbow, _gap(verts, e))
					row_wrist = minf(row_wrist, _gap(verts, w))
			ap.play()
			worst = minf(worst, row_wrist)
			worst_mid = minf(worst_mid, row_min)
			worst_elbow = minf(worst_elbow, row_elbow)
			print("CLEAR outfit=%02d %s wrist_gap=%.3f forearm_mid_or_wrist_gap=%.3f elbow_gap=%.3f" % [outfit, c[0], row_wrist, row_min, row_elbow])
	print("CLEAR_SUMMARY worst_wrist=%.3f (gate >= 0.040: %s) info: worst_forearm_mid=%.3f worst_elbow=%.3f" % [worst, "PASS" if worst >= 0.04 else "FAIL", worst_mid, worst_elbow])
	quit()


func _gap(verts: PackedVector3Array, p: Vector3) -> float:
	var reach := 0.0
	for q in verts:
		if absf(q.y - p.y) < 0.03 and absf(q.z - p.z) < 0.06 and signf(q.x) == signf(p.x):
			reach = maxf(reach, absf(q.x))
	return absf(p.x) - reach
