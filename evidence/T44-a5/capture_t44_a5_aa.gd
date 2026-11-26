extends SceneTree
## T44 A5 AA evidence. Native 1280x720, no upscale. Town daylight + House interior.
## A4 sheet framing and the gameplay camera. AA-off vs AA-on (root.msaa_3d 0 vs 1).
## Also 2560x1440 captures for a Lanczos-down reference (composed in Python).
## Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --script res://.scratch/capture_t44_a5_aa.gd -- --out=DIR
var out := "user://t44_a5"
var main: Node
var player: Node3D
var sheet_cam: Camera3D
var game_cam: Camera3D
var log_lines := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _log(msg: String) -> void:
	print(msg)
	log_lines.append(msg)


func _snap(name: String) -> void:
	for i in 4:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	_log("SNAP %s size=%dx%d msaa_3d=%d" % [name, root.size.x, root.size.y, int(root.msaa_3d)])


func _aa(msaa: int) -> void:
	root.msaa_3d = msaa


func _place_sheet(spot: Vector3) -> void:
	player.global_position = spot
	player.visual.rotation = Vector3.ZERO
	sheet_cam.global_position = spot + Vector3(0.0, 1.1, -2.3)
	sheet_cam.look_at(spot + Vector3(0.0, 0.80, 0.0))
	var pivot := player.get_node("CameraPivot") as Node3D
	pivot.rotation = Vector3(-0.28, 0, 0)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	# Log the project default BEFORE any script override (AC13: fresh launch default).
	var setting = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")
	_log("MSAA_DEFAULT project_setting=%s root.msaa_3d=%s expect=1" % [str(setting), str(root.msaa_3d)])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	sheet_cam = Camera3D.new()
	sheet_cam.fov = 65.0
	main.add_child(sheet_cam)
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	for p in main.match_manager.players:
		main.match_manager.set_player_ready(p, true)
	main.match_manager.start_match()
	main.disaster_director.cleanup()
	main.get_node("Sandbox").show()
	main.get_node("Interface").visible = false
	player = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	var ch = player.character
	ch.set_cosmetic_variant(0)
	ch.set_player_color(0)
	ch.play_clip("idle")
	ch.sync_rig(1.0)
	game_cam = player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	_log("MSAA_AFTER_SCENE root.msaa_3d=%s" % str(root.msaa_3d))

	# --- Town daylight ---
	var town := Vector3(0, 0, 2)
	_place_sheet(town)
	root.size = Vector2i(1280, 720)
	for pair in [["off", Viewport.MSAA_DISABLED], ["on", Viewport.MSAA_2X]]:
		_aa(pair[1])
		sheet_cam.current = true
		player.visual.rotation = Vector3.ZERO
		await _snap("town_sheet_aa%s" % pair[0])
		game_cam.current = true
		player.visual.rotation = Vector3(0, PI, 0)
		await _snap("town_game_aa%s" % pair[0])
	# 2560x1440 reference (AA-off and AA-on, both cameras)
	root.size = Vector2i(2560, 1440)
	for pair in [["off", Viewport.MSAA_DISABLED], ["on", Viewport.MSAA_2X]]:
		_aa(pair[1])
		sheet_cam.current = true
		player.visual.rotation = Vector3.ZERO
		await _snap("town_sheet_2560_aa%s" % pair[0])
		game_cam.current = true
		player.visual.rotation = Vector3(0, PI, 0)
		await _snap("town_game_2560_aa%s" % pair[0])

	# --- House interior (HOME at (-18,0,27), 8x8) ---
	root.size = Vector2i(1280, 720)
	var house: Node3D = main.get_node_or_null("Sandbox/House")
	var interior := Vector3(-18.0, 0.0, 27.0)
	if house != null:
		interior = house.global_position
		_log("INTERIOR shelter=House pos=%s" % str(interior))
	else:
		_log("INTERIOR House missing, using fallback %s" % str(interior))
	_place_sheet(interior)
	for pair in [["off", Viewport.MSAA_DISABLED], ["on", Viewport.MSAA_2X]]:
		_aa(pair[1])
		sheet_cam.current = true
		player.visual.rotation = Vector3.ZERO
		await _snap("interior_sheet_aa%s" % pair[0])
		game_cam.current = true
		player.visual.rotation = Vector3(0, PI, 0)
		await _snap("interior_game_aa%s" % pair[0])
	root.size = Vector2i(2560, 1440)
	for pair in [["off", Viewport.MSAA_DISABLED], ["on", Viewport.MSAA_2X]]:
		_aa(pair[1])
		sheet_cam.current = true
		player.visual.rotation = Vector3.ZERO
		await _snap("interior_sheet_2560_aa%s" % pair[0])
		game_cam.current = true
		player.visual.rotation = Vector3(0, PI, 0)
		await _snap("interior_game_2560_aa%s" % pair[0])

	# Restore default and re-log.
	root.size = Vector2i(1280, 720)
	_aa(Viewport.MSAA_2X)
	_log("MSAA_RESTORE root.msaa_3d=%s" % str(root.msaa_3d))
	var f := FileAccess.open("%s/msaa_3d.log" % out, FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	f.close()
	print("A5_CAPTURE_OK")
	quit(0)
