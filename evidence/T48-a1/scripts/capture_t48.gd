extends SceneTree
## T48 AC4: gameplay camera at the garage deck north edge (Owner shot-2 view), player presses +z.
## Usage: godot --path TREE --script res://... -- --out=DIR --label=before|after
var out := ""
var label := "x"
func _initialize() -> void:
	_run.call_deferred()
func _snap(main: Node, name: String) -> void:
	for i in 4:
		await physics_frame
		await process_frame
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, label, name])
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.start_local_match()
	main.set_process(false); main.set_physics_process(false)
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	main.disaster_director.cleanup(); main.disaster_director.set_physics_process(false)
	main.match_manager.set_process(false)
	main.get_node("Sandbox").show()
	main.get_node("Interface").visible = false
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false); player.set_process_unhandled_input(false)
	var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	camera.current = true
	(player.get_node("CameraPivot") as Node3D).rotation = Vector3(-0.28, 0.0, 0.0)
	var log_lines := PackedStringArray()
	# Free camera: the garage roof/pillars make the spring arm useless right at the sign.
	var cam := Camera3D.new()
	cam.fov = 65.0
	main.add_child(cam)
	cam.current = true
	player.reset_for_match(Vector3(-15.0, 2.75, 18.0))
	player.set_camera_yaw(PI)
	for tick in 180:
		player.apply_movement_input(Vector2(0, -1), false, false, 1.0 / 60.0)
		await physics_frame
	log_lines.append("%s end pos=%s on_floor=%s (sign front z=21.01, deck edge z=21.0)" % [label, player.position, player.is_on_floor()])
	var views := {"rear": [Vector3(-15.0, 4.3, 15.2), Vector3(-15.0, 3.0, 21.0)], "side": [Vector3(-10.0, 4.0, 17.5), Vector3(-15.0, 2.8, 21.0)]}
	for view in views:
		cam.global_position = views[view][0]
		cam.look_at(views[view][1], Vector3.UP)
		await _snap(main, "garage_%s" % view)
	var f := FileAccess.open("%s/%s_garage.txt" % [out, label], FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	for l in log_lines: print("CAPTURE ", l)
	quit(0)
