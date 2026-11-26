extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var label := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	root.size = Vector2i(1280, 720)
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	for peer_id in main.match_manager.players:
		main.match_manager.set_player_ready(peer_id, true)
	main.match_manager.start_match()
	main.disaster_director.cleanup()
	main.get_node("Sandbox").show()
	main.get_node("Interface").visible = false
	var player: Node3D = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3(-1.8, 0.0, 2.0)
	player.rotation = Vector3.ZERO
	var char_scene: PackedScene = load("res://assets/generated/CHR_Base_v001.tscn")
	var visual_script: Script = load("res://game/player/toy_character_visual.gd")
	for i in range(1, 4):
		var holder := Node3D.new()
		holder.position = Vector3(-1.8 + float(i) * 1.2, 0.0, 2.0)
		var model: Node3D = char_scene.instantiate()
		model.set_script(visual_script)
		holder.add_child(model)
		main.add_child(holder)
		model.set_player_color(i)
		model.set_cosmetic_variant(i * 3)
	var cam := Camera3D.new()
	cam.fov = 65.0
	main.add_child(cam)
	cam.global_position = Vector3(0.0, 2.2, -3.2)
	cam.look_at(Vector3(0.0, 0.9, 2.0), Vector3.UP)
	cam.current = true
	# A3 top-up: all 4 players move on a scripted circle (2 walk 4.5 m/s, 2 sprint 6.5 m/s).
	var movers: Array = []
	var chars: Array = []
	var centre := Vector3(0.0, 0.0, 2.0)
	var holders: Array[Node3D] = [player]
	chars.append(player.character)
	for child in main.get_children():
		if child is Node3D and child.get_child_count() > 0 and child.get_child(0).has_method("set_player_color") and child != player:
			holders.append(child)
			chars.append(child.get_child(0))
	for index in holders.size():
		var speed := 4.5 if index < 2 else 6.5
		var radius := 2.2 + 0.7 * index
		movers.append({"node": holders[index], "char": chars[index], "speed": speed, "radius": radius, "angle": index * PI * 0.5})
		(chars[index] as Node).play_clip("walk" if index < 2 else "run")
		(chars[index] as Node).set_locomotion_speed(speed)
	var planted_toggles := 0
	var planted_prev := {}
	var has_planted: bool = chars[0].has_method("is_foot_planted")
	for _i in range(12):
		await process_frame
	var times: Array[float] = []
	var prev_us := Time.get_ticks_usec()
	var phys_sum := 0.0
	for frame in range(90):
		for mover in movers:
			mover.angle += mover.speed / mover.radius * (1.0 / 60.0) * 8.0
			var node: Node3D = mover.node
			node.global_position = centre + Vector3(cos(mover.angle), 0.0, sin(mover.angle)) * mover.radius
			node.rotation.y = -mover.angle
			if has_planted:
				var now: bool = mover.char.is_foot_planted("l")
				if planted_prev.get(mover.char, now) != now:
					planted_toggles += 1
				planted_prev[mover.char] = now
		await process_frame
		phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		var now_us := Time.get_ticks_usec()
		times.append(float(now_us - prev_us) / 1000.0)
		prev_us = now_us
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	var avg := total / float(times.size())
	var p95 := times[int(floor(float(times.size() - 1) * 0.95))]
	var max_t := times[times.size() - 1]
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("MOVING players=%d walk_clip=%s run_clip=%s planted_toggles=%d" % [movers.size(), chars[0].current_clip, chars[3].current_clip if chars.size() > 3 else "-", planted_toggles])
	print("PERF_4P label=%s avg_ms=%.2f p95_ms=%.2f max_ms=%.2f draw_calls=%d primitives=%d phys_ms=%.4f nodes=%d active3d=%d" % [label, avg, p95, max_t, int(draws), int(prims), phys_sum / float(times.size()) * 1000.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))])
	quit(0)
