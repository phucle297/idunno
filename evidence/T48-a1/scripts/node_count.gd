extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var label := "x"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.start_local_match()
	main.set_process(false); main.set_physics_process(false)
	for map_id in ["toy_town", "toy_harbor"]:
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		main.disaster_director.cleanup()
		await physics_frame; await physics_frame
		var n := 0
		var stack := [main.get_node("Sandbox")]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			n += 1
			stack.append_array(node.get_children())
		print("NODES label=%s map=%s sandbox_nodes=%d solid_detail=%d active3d=%d" % [label, map_id, n, get_nodes_in_group("solid_map_detail").size(), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))])
	quit(0)
