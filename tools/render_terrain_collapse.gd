extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.match_manager.set_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.current = true
	var output := "res://.amp/in/artifacts/terrain-collapse"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		await physics_frame
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		main.disaster_director.cleanup()
		var terrain: TerrainCollapse = main.terrain_collapse
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			for state in ["intact", "warning", "indoor", "hole", "spectator", "reset", "center-warning", "center-hole", "north-warning", "north-hole"]:
				var district := 4 if state.begins_with("center-") else (1 if state.begins_with("north-") else 3)
				var center := terrain.regions[district].get_center()
				var at := Vector3(-42, 1.35, -7) if map_id == "toy_town" else Vector3(-17, 3.85, 9)
				if district != 3:
					at = Vector3(center.x, 0.1, center.y)
				terrain.reset()
				await physics_frame
				player.reset_for_match(at)
				if state.ends_with("hole"):
					# Stand on surviving ground, never over the gap.
					var safe := terrain.regions[0 if district == 4 else 4].get_center()
					var seat := Vector3(safe.x, 0, safe.y)
					seat.y = main.get_map_surface_height(seat) + 0.05
					player.reset_for_match(seat)
				main.match_manager.elapsed_time = 140
				if state.ends_with("warning") or state in ["indoor", "spectator"]:
					terrain.apply_snapshot(PackedFloat32Array([0, district, 150, 0]))
				elif state.ends_with("hole"):
					main.match_manager.elapsed_time = 150
					terrain.apply_snapshot(PackedFloat32Array([1 << district, -1, 0, 1]))
				elif state == "reset":
					terrain.apply_snapshot(PackedFloat32Array([1 << district, -1, 0, 1]))
					terrain.reset()
				var target := Vector3(center.x, 0, center.y)
				camera.position = target + (Vector3(44, 50, 60) if district == 4 and map_id == "toy_town" else Vector3(26, 27, 30))
				camera.look_at(target + Vector3.UP * 8)
				if state == "indoor":
					camera.position = at + Vector3(0, 2.1, 3)
					camera.look_at(at + Vector3.UP)
				main.get_node("Interface/LobbyPanel").hide()
				main.gameplay_hud.present_match_status(460, "SURVIVE", false)
				main.gameplay_hud.present_lobby_overlay(false)
				var chips: Array[String] = ["FLOOD", "TORNADO"]
				main.gameplay_hud.present_hazards(chips)
				main.gameplay_hud.present_collapse(terrain.describe(main.match_manager.elapsed_time), true, at, state != "spectator")
				terrain.present(main.match_manager.elapsed_time, 600, true)
				for frame in 10:
					await physics_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s-%s-%d.png" % [output, map_id, state, size.y])
	main.gameplay_audio.reset_for_match()
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	print("TERRAIN_COLLAPSE_RENDER_OK maps=2 widths=2 states=10 captures=40")
	quit(0)
