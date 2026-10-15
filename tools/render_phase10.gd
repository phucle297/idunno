extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	for hazard in [main.rain, main.snowfall, main.flood]:
		hazard.set_process(false)
	for hazard in [main.bee_swarm, main.ufo, main.volcano]:
		hazard.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.current = true
	var volcano_only := "--volcano-only" in OS.get_cmdline_user_args()
	var output := "res://.amp/in/artifacts/phase10-rough-terrain" if volcano_only else "res://.amp/in/artifacts/phase10"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		await physics_frame
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			for state in ["before", "bees-warning", "bees", "ufo-warning", "ufo", "volcano-warning", "volcano-hot", "volcano-warm", "volcano-cooled", "volcano-partial-flood"]:
				if volcano_only and state != "before" and not state.begins_with("volcano"):
					continue
				main.bee_swarm.cleanup()
				main.ufo.cleanup()
				main.volcano.cleanup()
				main.flood.cleanup()
				var center: Vector3 = main.volcano.district_center
				var at: Vector3 = main.map_anchors.spawn_origin
				player.reset_for_match(at)
				camera.position = at + Vector3(7, 5, 10)
				camera.look_at(at + Vector3.UP)
				var rng := RandomNumberGenerator.new()
				rng.seed = 1003
				if state.begins_with("bees"):
					assert(main.bee_swarm.start_disaster(rng))
					if state == "bees":
						main.bee_swarm.tick(5.2)
				elif state.begins_with("ufo"):
					assert(main.ufo.start_disaster(rng))
					camera.position = at + Vector3(8, 7, 12)
					camera.look_at(at + Vector3.UP * 2)
					if state == "ufo":
						for step in 40:
							main.ufo.tick(5 if step == 0 else 1.0 / 60)
							player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
							await physics_frame
				elif state.begins_with("volcano") or state == "before":
					player.reset_for_match(center + Vector3(0, 0.04, 0))
					camera.position = center + (Vector3(13, 12, 17) if map_id == "toy_town" else Vector3(12, 12, -16))
					camera.look_at(center + Vector3.UP)
					if state != "before":
						assert(main.volcano.start_disaster(rng))
						if state != "volcano-warning":
							main.volcano.tick(12)
							# Advance thermal presentation without leaving the fixture
							# avatar standing in lethal heat for45–60 simulated seconds.
							player.position.y = main.volcano.centers[4].y + 5
						if state == "volcano-warm":
							main.volcano.tick(45)
						elif state == "volcano-cooled":
							main.volcano.tick(60)
						elif state == "volcano-partial-flood":
							main.flood.start_warning()
							main.flood.tick(6)
							main.flood.target_level = center.y + 0.3
							main.flood.tick(main.flood.rise_duration)
							main.volcano.tick(6)
						if state != "volcano-warning":
							player.position.y = main.volcano.centers[4].y + 0.03
				main.gameplay_hud.present_match_status(450, "SURVIVE", false)
				main.gameplay_hud.present_lobby_overlay(false)
				main.get_node("Interface/LobbyPanel").hide()
				main._update_major_warning()
				main.gameplay_hud.present_hazards(main._active_disaster_lines())
				main._update_flood_feedback(1)
				main._update_context_prompt(1)
				for frame in 8:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s-%s-%d.png" % [output, map_id, state, size.y])
	main.gameplay_audio.reset_for_match()
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	print("PHASE10_RENDER_OK maps=2 sizes=2 states=%d" % (6 if volcano_only else 10))
	quit()
