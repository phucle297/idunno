extends SceneTree
## T17 capture: top-down view of every pickup spawn over 8:00 for 2 seeds per
## map (yellow = powerup, red = toy, black = hot potato), through Main's placer.
## Usage: godot --path . --script res://tools/render_pickup_placement.gd -- --out=/abs/dir

const COLORS := {"powerup": Color(1.0, 0.85, 0.1), "toy": Color(0.9, 0.15, 0.15), "potato": Color(0.05, 0.05, 0.05)}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://pickup-placement"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(2, "Second", Vector3(2, 0.05, 7))
	for player: PartyPlayer in main._player_nodes.values():
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	root.size = Vector2i(1200, 1200)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main.add_child(camera)
	camera.current = true
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		for peer_id: int in main.match_manager.players:
			main.match_manager.set_player_ready(peer_id, true)
		main.match_manager.start_match()
		main.disaster_director.cleanup()
		camera.size = 60.0
		camera.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, 0)), Vector3(0, 60, 0))
		for seed_value in [1000, 8919]:
			var markers := Node3D.new()
			main.add_child(markers)
			var points := _simulate(main, seed_value)
			for entry: Array in points:
				var mesh := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.55
				sphere.height = 1.1
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = COLORS[entry[0]]
				sphere.material = material
				mesh.mesh = sphere
				markers.add_child(mesh)
				mesh.global_position = entry[1] + Vector3.UP * 0.6
			for frame in 6:
				await process_frame
			var path := "%s/%s_seed%d.png" % [out, map_id, seed_value]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("PICKUP_CAPTURE %s spawns=%d" % [path, points.size()])
			markers.free()
	main.free()
	await create_timer(0.15).timeout
	print("PICKUP_CAPTURE_OK")
	quit(0)


func _simulate(main, seed_value: int) -> Array:
	var points: Array = []
	var seen := {}
	main.disaster_director.last_seed = seed_value
	main.pickup_placement.begin_round(seed_value)
	main.powerups.begin_round()
	main.toy_sabotage.begin_round()
	main.hot_potato.reset()
	var parcel := 0
	var t := 0.0
	while t <= 480.0:
		main.match_manager.elapsed_time = t
		if fmod(t - 3.0, 40.0) == 0.0 and t >= 3.0:
			main.hot_potato.phase = HotPotato.Phase.IDLE
			parcel += 1
			var point: Vector3 = main._place_pickup(&"potato", parcel)
			if point.is_finite():
				main.hot_potato.position_world = point
				main.hot_potato.phase = HotPotato.Phase.GROUND
				points.append(["potato", point])
		main.powerups.tick(main.match_manager, main._player_nodes, seed_value)
		main.toy_sabotage.tick(0.0, seed_value)
		for family in ["powerup", "toy"]:
			for pickup: Dictionary in (main.powerups.pickups if family == "powerup" else main.toy_sabotage.pickups):
				if not seen.has("%s%d" % [family, pickup.id]):
					seen["%s%d" % [family, pickup.id]] = true
					points.append([family, pickup.position])
		t += 0.5
	main.hot_potato.reset()
	return points
