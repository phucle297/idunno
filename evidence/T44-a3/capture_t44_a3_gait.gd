extends SceneTree
## T44 A3 hop-step evidence: side + 3/4 walk/run frame strips of a moving critter and a
## side-view foot trace (world z vs height) showing each planted foot is world-fixed.
## Run: copy to res://.scratch/ and `godot --path . --script res://.scratch/capture_t44_a3_gait.gd -- --out=DIR`

var out := "user://t44_a3"
var character: ToyCharacterVisual
var anim: AnimationPlayer
var camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fc6e8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, PI - 0.5, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 80)
	ground.mesh = plane
	var checker := StandardMaterial3D.new()
	checker.albedo_color = Color("c9c2b0")
	ground.material_override = checker
	stage.add_child(ground)
	for i in 80:  # 0.5 m floor ticks so the planted foot can be read against the ground
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 0.002, 0.02)
		tick.mesh = box
		tick.position = Vector3(0.0, 0.001, 20.0 - i * 0.5)
		stage.add_child(tick)
	character = (load("res://assets/generated/CHR_Base_v001.tscn") as PackedScene).instantiate() as ToyCharacterVisual
	stage.add_child(character)
	character.set_player_color(1)
	character.set_cosmetic_variant(1)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.current = true
	await process_frame
	anim = character.get_node("AnimationPlayer") as AnimationPlayer
	character.set_process(false)
	for clip in ["walk", "run"]:
		var speed := 4.5 if clip == "walk" else 6.5
		await _strip(clip, speed, "side", Vector3(3.4, 0.55, 0.0))
		await _strip(clip, speed, "3q", Vector3(2.4, 0.9, -2.4))
		_trace(clip, speed)
	print("T44_A3_GAIT_CAPTURE_OK out=%s" % out)
	quit(0)


func _start(clip: String, speed: float) -> void:
	character.play_clip("idle")
	character.sync_rig(1.0)
	character.play_clip(clip)
	character.set_locomotion_speed(speed)
	anim.seek(0.0, true)
	character.sync_rig(1.0)
	anim.pause()


func _pose(t: float, speed: float) -> void:
	character.position = Vector3(0.0, 0.0, -speed * t)
	anim.seek(fposmod(t * anim.speed_scale, anim.current_animation_length), true)
	character.sync_rig()


func _strip(clip: String, speed: float, view: String, offset: Vector3) -> void:
	_start(clip, speed)
	var cycle := anim.current_animation_length / anim.speed_scale
	var frames := 10
	var strip := Image.create(256 * frames, 300, false, Image.FORMAT_RGBA8)
	strip.fill(Color.WHITE)
	for frame in frames:
		var t := frame / float(frames) * cycle
		_pose(t, speed)
		var focus := character.position + Vector3(0.0, 0.62, 0.0)
		camera.look_at_from_position(focus + offset, focus)
		for i in 3:
			await process_frame
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var crop := shot.get_region(Rect2i(390, 40, 500, 640))
		crop.resize(256, 300)
		strip.blit_rect(crop, Rect2i(0, 0, 256, 300), Vector2i(frame * 256, 0))
		var planted := ("L" if character.is_foot_planted("l") else "") + ("R" if character.is_foot_planted("r") else "")
		_label(strip, Vector2i(frame * 256 + 4, 4), planted)
	strip.save_png("%s/strip_%s_%s_cycle%.3fs.png" % [out, clip, view, cycle])


func _label(image: Image, at: Vector2i, planted: String) -> void:
	# Red block = left planted, blue block = right planted (no font in headless images).
	if planted.contains("L"):
		image.fill_rect(Rect2i(at, Vector2i(22, 14)), Color.RED)
	if planted.contains("R"):
		image.fill_rect(Rect2i(at + Vector2i(26, 0), Vector2i(22, 14)), Color.BLUE)


func _trace(clip: String, speed: float) -> void:
	_start(clip, speed)
	var cycle := anim.current_animation_length / anim.speed_scale
	var dt := 1.0 / 960.0
	var samples := int(2.0 * cycle / dt)
	var rows := PackedStringArray(["t,side,world_z,world_y,planted"])
	var points := {"l": [], "r": []}
	var worst := {"l": 0.0, "r": 0.0}
	var start := {}
	var steps := {"l": [], "r": []}
	var last_planted := {"l": false, "r": false}
	for sample in samples:
		var t := sample * dt
		_pose(t, speed)
		for side in ["l", "r"]:
			var foot := character.get_visible_foot_global(side)
			var planted := character.is_foot_planted(side)
			points[side].append([foot.z, foot.y, planted])
			rows.append("%.5f,%s,%.5f,%.5f,%d" % [t, side, foot.z, foot.y, int(planted)])
			if planted and not last_planted[side]:
				start[side] = foot
				steps[side].append(foot.z)
			if planted:
				worst[side] = maxf(worst[side], Vector2(foot.x - start[side].x, foot.z - start[side].z).length())
			last_planted[side] = planted
	FileAccess.open("%s/foot_trace_%s.csv" % [out, clip], FileAccess.WRITE).store_string("\n".join(rows) + "\n")
	# Side-view plot: x = world z travelled (forward to the right), y = foot height.
	var width := 1600
	var height := 360
	var plot := Image.create(width, height, false, Image.FORMAT_RGBA8)
	plot.fill(Color.WHITE)
	var z_min := INF
	var z_max := -INF
	for side in points:
		for p in points[side]:
			z_min = minf(z_min, p[0])
			z_max = maxf(z_max, p[0])
	var y_scale := 2000.0  # px per metre of height (exaggerated)
	var ground_px := height - 40
	plot.fill_rect(Rect2i(0, ground_px, width, 1), Color.BLACK)
	for side in points:
		var colour := Color(0.85, 0.1, 0.1) if side == "l" else Color(0.1, 0.25, 0.9)
		for p in points[side]:
			var x := int((z_max - p[0]) / maxf(z_max - z_min, 0.001) * (width - 40)) + 20
			var y := ground_px - int((p[1] - 0.09) * y_scale) - (0 if side == "l" else 0)
			var size := 5 if p[2] else 1
			plot.fill_rect(Rect2i(x - size / 2, clampi(y - size / 2, 0, height - 1), size, size), colour)
	plot.save_png("%s/foot_trace_side_%s.png" % [out, clip])
	var step_len := []
	for side in steps:
		var list: Array = steps[side]
		for i in range(1, list.size()):
			step_len.append(absf(list[i] - list[i - 1]))
	var summary := "%s speed=%.1f cycle=%.3fs step_half=%.3f duty=%.3f stance_s=%.4f max_slide_l=%.5f max_slide_r=%.5f world_step_m=%s" % [clip, speed, cycle, character.get_step_half(), character.get_stance_duty(), character.get_stance_duty() * cycle, worst["l"], worst["r"], str(step_len)]
	FileAccess.open("%s/foot_trace_%s_summary.txt" % [out, clip], FileAccess.WRITE).store_string(summary + "\n")
	print("T44_A3_TRACE ", summary)
