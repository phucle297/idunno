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
	for hazard in [main.rain, main.snowfall, main.fire, main.flood]:
		hazard.set_process(false)
	main.rockslide.set_physics_process(false)
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.current = true
	var output := "res://.amp/in/artifacts/phase9"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await physics_frame
		await physics_frame
		main._configure_weather_patches()
		main.match_manager.set_player_ready(1, true)
		main.match_manager.start_match()
		var at := Vector3(2, 0.06, -5) if map_id == "toy_town" else Vector3(-12, 0, -8.5)
		player.reset_for_match(at + Vector3(0, 0.03, 0))
		camera.position = at + Vector3(7, 6, 10)
		camera.look_at(at + Vector3(0, 0.8, 0))
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			for state in ["dry", "rain-warning", "rain", "snow-warning", "snow", "melt", "rock-warning", "rock", "rain-rock", "snow-rock"]:
				if "--rock-only" in OS.get_cmdline_user_args() and not state.contains("rock"):
					continue
				main.rain.cleanup()
				main.snowfall.cleanup()
				main.rockslide.cleanup()
				main.weather_surfaces.cleanup()
				player.reset_for_match(at + Vector3.UP * 0.03)
				camera.position = at + Vector3(7, 6, 10)
				camera.look_at(at + Vector3(0, 0.8, 0))
				var rng := RandomNumberGenerator.new()
				rng.seed = 901
				if state.begins_with("rain"):
					main.rain.start_disaster(rng)
					if state != "rain-warning":
						main.rain.tick(5)
						main.tick_weather(4)
				elif state.begins_with("snow") or state == "melt":
					main.snowfall.start_disaster(rng)
					if state != "snow-warning":
						main.snowfall.tick(5)
						main.tick_weather(20)
						if state == "melt":
							main.snowfall.cleanup()
							main.tick_weather(40)
				if state.contains("rock"):
					var low: Vector3 = main.rockslide.lane.low
					player.reset_for_match(low + Vector3(3.5, 0.03, -1))
					# Harbor's east perimeter wall must not sit between the review
					# camera and the player on the authored lateral exit.
					camera.position = low + (Vector3(3.5, 8, 9) if map_id == "toy_harbor" else Vector3(6, 7, 9))
					camera.look_at(low + Vector3(0, 1, -6))
					main.rockslide.start_disaster(rng)
					if state != "rock-warning":
						main.rockslide.tick(5)
						for frame in 150:
							main.rockslide.tick(1.0 / 60)
							await physics_frame
				main.gameplay_hud.present_match_status(570, "SURVIVE", false)
				main.gameplay_hud.present_lobby_overlay(false)
				main.get_node("Interface/LobbyPanel").hide()
				main._update_major_warning()
				main.gameplay_hud.present_hazards(main._active_disaster_lines())
				for frame in 8:
					await process_frame
				await RenderingServer.frame_post_draw
				var path := "%s/%s-%s-%d.png" % [output, map_id, state, size.y]
				root.get_texture().get_image().save_png(path)
				print("PHASE9_RENDER_CAPTURE path=%s" % path)
	main.free()
	await process_frame
	print("PHASE9_RENDER_OK maps=2 sizes=2 states=10")
	quit()
