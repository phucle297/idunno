extends SceneTree
## T45 A1: arm chain in character-root space (m) + elbow flexion / abduction (deg).
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var probe := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	var held_modes := [false, true] if probe.has_method("set_item_held") else [false]
	probe.free()
	for held in held_modes:
		# Fresh character per mode so clip cross-fades from the previous mode never leak in.
		var v := (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
		root.add_child(v)
		await process_frame
		v.ensure_runtime_setup()
		var rig := v.get_node("Model/Rig/Skeleton3D") as Skeleton3D
		var ap := v.get_node("AnimationPlayer") as AnimationPlayer
		if v.has_method("set_item_held"):
			v.set_item_held(held)
		for clip in ["idle", "walk", "run"]:
			v.play_clip(clip)
			v.set_locomotion_speed(4.5 if clip == "walk" else (6.5 if clip == "run" else 0.0))
			v.sync_rig(0.5)
			ap.pause()
			for ph in [0.0, 0.25, 0.5, 0.75]:
				ap.seek(ph * ap.current_animation_length, true)
				v.sync_rig()
				var out := "held=%s %s ph=%.2f" % [held, clip, ph]
				for s in ["l", "r"]:
					var pts := []
					for bn in ["upperarm.", "lowerarm.", "wrist.", "handslot."]:
						pts.append(v.to_local(rig.global_transform * rig.get_bone_global_pose(rig.find_bone(bn + s)).origin))
					var flex := rad_to_deg((pts[1] - pts[0]).angle_to(pts[2] - pts[1]))
					var abd := rad_to_deg(atan2(absf(pts[2].x - pts[0].x), pts[0].y - pts[2].y))
					out += "  %s: elbow(%.3f,%.3f,%.3f) wrist(%.3f,%.3f,%.3f) hand(%.4f,%.4f,%.4f) flex=%.1f abd=%.1f" % [s, pts[1].x, pts[1].y, pts[1].z, pts[2].x, pts[2].y, pts[2].z, pts[3].x, pts[3].y, pts[3].z, flex, abd]
				out += "  footL_z=%.3f anchor=%s" % [v.to_local(v.get_visible_foot_global("l")).z, v.to_local(v.get_hand_anchor().global_position)]
				print(out)
			ap.play()
		v.free()
	quit()
