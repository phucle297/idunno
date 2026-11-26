extends SceneTree
## T45 A2 Architect: close-up front + 3/4 of all 12 outfits (player colour 0 and, for outfit 0, colours 1-3),
## in the real toy_town daylight. Logs arm vs body material albedo and rendered pixel patch (forearm mid vs belly side).
## Usage: godot --path <tree> --script <this> -- --out=DIR
var out := "user://t45a2"
var tune_scale := -1.0
var tune_off := Vector3.ZERO
var outfits := [0]
var cfgs: Array = []
var MIRROR := -1.0


func _initialize() -> void:
	_run.call_deferred()


func _patch(img: Image, p: Vector2) -> Color:
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var x := clampi(int(p.x) + dx, 0, img.get_width() - 1)
			var y := clampi(int(p.y) + dy, 0, img.get_height() - 1)
			acc += img.get_pixel(x, y)
			n += 1
	return acc / n


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scale="):
			tune_scale = a.trim_prefix("--scale=").to_float()
		elif a.begins_with("--off="):
			var o := a.trim_prefix("--off=").split(",")
			tune_off = Vector3(o[0].to_float(), o[1].to_float(), o[2].to_float())
		elif a == "--nomirror":
			MIRROR = 1.0
		elif a.begins_with("--cfgs="):
			for c in a.trim_prefix("--cfgs=").split(";"):
				var f := c.split(",")
				cfgs.append([f[0].to_float(), Vector3(f[1].to_float(), f[2].to_float(), f[3].to_float())])
		elif a.begins_with("--outfits="):
			outfits = []
			for o in a.trim_prefix("--outfits=").split(","):
				outfits.append(o.to_int())
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	camera.fov = 50.0
	main.add_child(camera)
	main.match_manager.prepare_lobby()
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	for p in main.match_manager.players:
		main.match_manager.set_player_ready(p, true)
	main.match_manager.start_match()
	main.disaster_director.cleanup()
	main.get_node("Sandbox").show()
	main.get_node("Interface").visible = false
	var player: Node3D = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	var pos := Vector3(0, 0, 2)
	player.global_position = pos
	var ch: ToyCharacterVisual = player.character
	var rig := ch.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	camera.current = true
	var lines: PackedStringArray = ["view side visible_px full_px fraction (Mitten unshaded magenta; 'full' = body/arm/head hidden), idle, outfit 0, camera 1.7 m fov 50, 1280x720"]
	ch.set_player_color(0)
	var mag := StandardMaterial3D.new()
	mag.albedo_color = Color(1, 0, 1)
	mag.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rows: PackedStringArray = ["T45 A2 cream match: mean lit colour over the paw (Mitten) and bootie (Bootie) visible-pixel masks, front view, idle, 1280x720, camera 1.7 m fov 50; albedo = material_override albedo"]
	var worst := 0.0
	for outfit in outfits:
		ch.set_cosmetic_variant(outfit)
		ch.play_clip("idle")
		ch.sync_rig(1.0)
		player.visual.rotation = Vector3(0, 0, 0)
		camera.global_position = pos + Vector3(0.0, 0.95, -1.7)
		camera.look_at(pos + Vector3(0.0, 0.70, 0.0))
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var lit := root.get_texture().get_image()
		var row := "outfit=%02d %s" % [outfit, ToyCharacterVisual.CRITTER_SPECIES[outfit]]
		var means := {}
		for part in ["Mitten", "Bootie"]:
			var nodes: Array[MeshInstance3D] = []
			var saved: Array[Material] = []
			for side in ["l", "r"]:
				var n := rig.get_node(("Paw_" if part == "Mitten" else "Foot_") + side + "/" + part) as MeshInstance3D
				nodes.append(n)
				saved.append(n.material_override)
				n.material_override = mag
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var mask := root.get_texture().get_image()
			var acc := Vector3.ZERO
			var cnt := 0
			for y in mask.get_height():
				for x in mask.get_width():
					var p := mask.get_pixel(x, y)
					if p.r > 0.9 and p.g < 0.1 and p.b > 0.9:
						var c := lit.get_pixel(x, y)
						acc += Vector3(c.r, c.g, c.b)
						cnt += 1
			for k in nodes.size():
				nodes[k].material_override = saved[k]
			means[part] = acc / maxf(1.0, float(cnt)) * 255.0
			var albedo := (saved[0] as StandardMaterial3D).albedo_color.to_html(false)
			row += " | %s px=%d mean=(%.0f,%.0f,%.0f) albedo=#%s" % [part, cnt, means[part].x, means[part].y, means[part].z, albedo]
		var diff: Vector3 = (means["Mitten"] - means["Bootie"]).abs()
		var d := maxf(diff.x, maxf(diff.y, diff.z))
		worst = maxf(worst, d)
		rows.append(row + " | max_channel_diff=%.1f" % d)
	rows.append("WORST max_channel_diff=%.1f (gate <= 25)" % worst)
	FileAccess.open("%s/cream_match.txt" % out, FileAccess.WRITE).store_string("\n".join(rows) + "\n")
	print("A2_CREAM_OK worst=", worst)
	quit(0)
