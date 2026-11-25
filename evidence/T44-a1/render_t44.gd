extends SceneTree
## M23.4 character evidence capture (front, 3/4, rear gameplay camera, daylight + indoor, Town + Harbor, held item).

var out := "/tmp/x"
var camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	root.size = Vector2i(1280, 720)
	camera = Camera3D.new()
	camera.fov = 55.0
	main.add_child(camera)

	var toy_visuals = preload("res://game/session/toy_sabotage_visuals.gd").new()
	main.add_child(toy_visuals)
	await process_frame

	for map_id: String in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		for peer_id in main.match_manager.players:
			main.match_manager.set_player_ready(peer_id, true)
		main.match_manager.start_match()
		main.disaster_director.cleanup()
		main.get_node("Sandbox").show()
		main.get_node("Interface").visible = false
		var player: Node3D = main.get_node("Player")
		player.set_physics_process(false)
		player.visual.rotation = Vector3.ZERO
		player.character.set_player_color(0)
		player.character.set_cosmetic_variant(0)
		player.character.play_clip("idle")
		var anim: AnimationPlayer = player.character.get_node("AnimationPlayer")
		anim.pause()
		anim.seek(0.0, true)

		var outdoor_pos := Vector3(0.0, 0.0, 2.0) if map_id == "toy_town" else Vector3(0.0, 0.0, 4.0)
		player.global_position = outdoor_pos
		var held_snap := {"pickups": [], "effects": [], "slots": {1: {"kind": "hammer"}}}
		var players_dict := {1: player}
		toy_visuals.present(held_snap, players_dict, true, 0.0)

		camera.current = true
		# 1. Front close-up (-Z is character forward)
		_place(outdoor_pos + Vector3(0.0, 1.05, -2.5), outdoor_pos + Vector3(0.0, 0.82, 0.0))
		await _snap("%s_daylight_front" % map_id)
		# 2. 3/4 view (front-right so held item in right hand is clearly visible)
		_place(outdoor_pos + Vector3(1.85, 1.25, -1.85), outdoor_pos + Vector3(0.0, 0.82, 0.0))
		await _snap("%s_daylight_3q" % map_id)
		# 3. Rear gameplay camera
		_place(outdoor_pos + Vector3(0.0, 2.35, 3.6), outdoor_pos + Vector3(0.0, 0.90, 0.0))
		await _snap("%s_daylight_rear" % map_id)

		# 4. Indoor view inside first shelter with walls
		var shelter: Node3D = null
		for child in main.get_node("Sandbox").get_children():
			if child is Node3D and child.is_in_group("shelter") and child.has_node("WestWall"):
				shelter = child
				break
		if shelter != null:
			var indoor_pos := shelter.global_position + Vector3(0.0, 0.0, 0.0)
			player.global_position = indoor_pos
			toy_visuals.present(held_snap, players_dict, true, 0.0)
			_place(indoor_pos + Vector3(1.5, 1.25, -1.7), indoor_pos + Vector3(0.0, 0.82, 0.0))
			await _snap("%s_indoor_3q" % map_id)
			_place(indoor_pos + Vector3(0.0, 1.9, 2.8), indoor_pos + Vector3(0.0, 0.88, 0.0))
			await _snap("%s_indoor_rear" % map_id)

	main.free()
	await create_timer(0.1).timeout
	print("T44_CAPTURE_OK out=%s" % out)
	quit(0)


func _place(from: Vector3, target: Vector3) -> void:
	camera.global_position = from
	camera.look_at(target)


func _snap(name: String) -> void:
	for i in 4:
		await process_frame
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	print("CAPTURED %s" % path)
