extends SceneTree
## T47 A1 evidence captures (QA proof a,b,c,d,f,g). Runs on A (feat) and B (f395fe84) trees.
## --out=<dir> --tag=A|B
var out := "/tmp/t47"
var tag := "A"
var lines := PackedStringArray()
var main
var volcano
var player
var cam: Camera3D
var is_a := true


func _initialize() -> void:
	_run.call_deferred()


func _snap(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	lines.append("shot %s" % name)


func _start(seed_value: int, elapsed: float) -> void:
	volcano.cleanup()
	main.match_manager.prepare_lobby()
	main.match_manager.set_player_ready(1, true)
	main.match_manager.start_match()
	main.match_manager.elapsed_time = elapsed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	assert(volcano.start_disaster(rng))
	volcano.environment = func() -> Dictionary: return {}


func _top(extent: float) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = extent * 2.05
	cam.position = Vector3(0, 60, 0)
	cam.rotation = Vector3(-PI / 2, 0, 0)


func _persp(pos: Vector3, at: Vector3) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 70
	cam.position = pos
	cam.look_at(at)


var _markers: Array[Node3D] = []
func _spawn_markers() -> void:
	for m in _markers:
		m.free()
	_markers.clear()
	var spawns: Array = [main.map_anchors.spawn_origin]
	for g in main.map_anchors.get("spawn_groups", []):
		spawns.append(g.spawn)
	for s: Vector3 in spawns:
		var mi := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.2
		mesh.bottom_radius = 1.2
		mesh.height = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.4, 1.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = mat
		mi.mesh = mesh
		main.add_child(mi)
		mi.global_position = s + Vector3.UP * 3
		_markers.append(mi)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	main.disaster_director.set_process(false)
	main.match_manager.set_process(false)
	volcano = main.volcano
	volcano.set_physics_process(false)
	is_a = "stage" in volcano
	player = main.get_node("Player")
	player.set_physics_process(false)
	cam = Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.far = 400
	for map_id in ["toy_town", "toy_harbor"]:
		main.match_manager.prepare_lobby()
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		await physics_frame
		await physics_frame
		main.get_node("Sandbox").show()
		main.get_node("Interface").visible = false
		var extent: float = main.get_map_half_extent()
		# (a) shot-3 style: FLOOD at flow 40 s, same camera B vs A.
		_start(3000, 500.0)
		volcano.tick(12.0)
		volcano.tick(28.0 if map_id == "toy_town" else 14.0)
		player.global_position = Vector3(0, 40, 0)
		var a_pos := Vector3(-22, 7, 30) if map_id == "toy_town" else Vector3(-14, 7, 10)
		_persp(a_pos, a_pos + Vector3(14, -6, -14))
		lines.append("%s %s a-flood flow_elapsed=%.1f vent=%s heat=%.1f" % [tag, map_id, volcano.flow_elapsed, volcano.district_center, volcano.flow_heat])
		await _snap("%s-%s-a-flood-street" % [tag, map_id])
		_top(extent)
		await _snap("%s-%s-a-flood-top" % [tag, map_id])
		if not is_a:
			continue
		# (b)/(g) ZONES at 2:30 for seeds 3000-3002 top-down with spawn markers; 3:30... K=3 at 5:50.
		_spawn_markers()
		for entry in [[3000, 150.0], [3001, 150.0], [3002, 150.0], [3000, 350.0]]:
			_start(entry[0], entry[1])
			volcano.tick(12.0)
			volcano.tick(6.0)
			await physics_frame
			_top(extent)
			lines.append("%s %s zones seed=%d elapsed=%.0f vent=%s zones=%s tiles=%d" % [tag, map_id, entry[0], entry[1], volcano.district_center, volcano.zones, volcano.flow_tile_count()])
			await _snap("%s-%s-zones-seed%d-at%d-top" % [tag, map_id, entry[0], entry[1]])
			if entry[0] == 3000 and entry[1] == 150.0:
				var c := Vector3(volcano.zones[0], 0, volcano.zones[1])
				_persp(c + Vector3(-volcano.zone_radius - 8, 9, volcano.zone_radius + 8), c)
				await _snap("%s-%s-zones-seed3000-gameplay" % [tag, map_id])
				var v: Vector3 = volcano.district_center
				_persp(v + Vector3(10, 9, 12), v)
				await _snap("%s-%s-crater-seed3000" % [tag, map_id])
		for m in _markers:
			m.visible = false
		# (c) late FLOOD at 8:20: warning -> 10 s -> 34 s -> cooled.
		_start(3000, 500.0)
		_top(extent)
		volcano.tick(6.0)
		await _snap("%s-%s-flood-1-warning" % [tag, map_id])
		volcano.tick(6.0)
		volcano.tick(10.0)
		await _snap("%s-%s-flood-2-10s" % [tag, map_id])
		volcano.tick(24.0)
		await _snap("%s-%s-flood-3-34s" % [tag, map_id])
		volcano.tick(volcano.flow_heat - 20.0 + 0.05)
		lines.append("%s %s flood cooled flow_heat=%.2f burning=%s tiles=%d" % [tag, map_id, volcano.flow_heat, volcano.is_burning(volcano.flow_heat), volcano.flow_tile_count()])
		await _snap("%s-%s-flood-4-cooled" % [tag, map_id])
		# (f) cooled-lava capture: player on the flow; frames at heat 21, 20, 19 + HP.
		_start(3000, 150.0)
		volcano.tick(12.0)
		volcano.tick(8.0)
		var c := Vector3(volcano.zones[0], 0, volcano.zones[1])
		c.y = main.get_map_support_height(Vector3(c.x, 2, c.z))
		player.reset_for_match(c + Vector3.UP * 0.05)
		for i in 12:
			player.apply_movement_input(Vector2.ZERO, false, false, 1.0 / 60)
			await physics_frame
		_persp(c + Vector3(-6, 5, 7), c + Vector3.UP)
		volcano.flow_heat = 21.0
		volcano.heat.fill(21.0)
		var vent: Vector3 = volcano.district_center
		for target in [21.0, 20.0, 19.0]:
			var hp0: float = main.match_manager.get_health(1)
			while volcano.flow_heat > target + 0.0001:
				volcano.tick(minf(1.0 / 60, volcano.flow_heat - target))
			var hp1: float = main.match_manager.get_health(1)
			# 1 s idle at this heat (no cooling) to read damage.
			var probe_hp: float = hp1
			lines.append("%s %s cooled-trace heat=%.2f burning=%s hp_during_step=%.2f->%.2f tiles=%d escape='%s'" % [tag, map_id, volcano.flow_heat, volcano.is_burning(volcano.flow_heat), hp0, hp1, volcano.flow_tile_count(), volcano.get_escape_context(player.global_position)])
			await _snap("%s-%s-f-cooled-heat%d-flow" % [tag, map_id, int(target)])
		_persp(vent + Vector3(9, 8, 11), vent)
		await _snap("%s-%s-f-cooled-heat19-crater" % [tag, map_id])
		volcano.cleanup()
		main._reset_sandbox()
	# Shelf HP trace at heat 21/20/19 (crater, Town) is in test_lava_zones; summary here.
	var f := FileAccess.open("%s/capture_%s.txt" % [out, tag], FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	main.gameplay_audio.reset_for_match()
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	print("T47_CAPTURE_OK tag=%s" % tag)
	quit()
