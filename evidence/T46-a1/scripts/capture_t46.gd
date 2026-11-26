extends SceneTree
## T46 face captures + luminance (title, gameplay mid/close, front/back lit).
## Usage: godot --path <tree> --script res://evidence/T46-a1/scripts/capture_t46.gd -- --out=DIR --tag=A --mode=quick|full|title|gameplay
var out := "/tmp/t46"
var tag := "A"
var mode := "full"
const SPECIES := ["bear", "cat", "bunny"]


func _initialize() -> void:
	_run.call_deferred()


func _lum(c: Color) -> float:
	return 0.2126 * c.r * 255.0 + 0.7152 * c.g * 255.0 + 0.0722 * c.b * 255.0


func _rgb(c: Color) -> String:
	return "(%d,%d,%d)" % [round(c.r * 255.0), round(c.g * 255.0), round(c.b * 255.0)]


func _sat(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


func _sample_mean(img: Image, p: Vector2, r := 4) -> Color:
	var acc := Color(0, 0, 0, 0)
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var x := clampi(int(p.x) + dx, 0, w - 1)
			var y := clampi(int(p.y) + dy, 0, h - 1)
			acc += img.get_pixel(x, y)
			n += 1
	return acc / max(n, 1)


func _modal_face(img: Image, center: Vector2, box := 8) -> Color:
	# Tight mean around the unprojected plate centre, skipping dark feature pixels (eyes/mouth).
	# A large-box modal can pick hood/edge greys; centre pixel is the plate itself.
	var acc := Color(0, 0, 0, 0)
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	var r: int = maxi(int(box), 6)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var x := clampi(int(center.x) + dx, 0, w - 1)
			var y := clampi(int(center.y) + dy, 0, h - 1)
			var c := img.get_pixel(x, y)
			var L := _lum(c)
			if L < 50.0:
				continue
			if _sat(c) > 0.35:
				continue
			acc += c
			n += 1
	if n < 4:
		return _sample_mean(img, center, 4)
	return acc / n


func _hood_color(img: Image, face_px: Vector2, box := 70) -> Color:
	# Saturated (player-colour) pixels around the face, not the plate.
	var acc := Color(0, 0, 0, 0)
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	var x0 := clampi(int(face_px.x) - box, 0, w - 1)
	var x1 := clampi(int(face_px.x) + box, 0, w - 1)
	var y0 := clampi(int(face_px.y) - box, 0, h - 1)
	var y1 := clampi(int(face_px.y) + int(box * 0.6), 0, h - 1)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if Vector2(x, y).distance_to(face_px) < 22.0:
				continue
			var c := img.get_pixel(x, y)
			if _sat(c) >= 0.18 and _lum(c) >= 60.0:
				acc += c
				n += 1
	if n < 8:
		return _sample_mean(img, face_px + Vector2(36, -8), 5)
	return acc / n


func _plate_gradient(img: Image, cam: Camera3D, plate: MeshInstance3D) -> float:
	var aabb := plate.get_aabb()
	var ls: Array[float] = []
	for u in [-0.35, -0.15, 0.0, 0.15, 0.35]:
		for v in [-0.35, -0.1, 0.15, 0.35]:
			var local := aabb.get_center() + Vector3(aabb.size.x * u, aabb.size.y * v, 0)
			var px := cam.unproject_position(plate.global_transform * local)
			if px.x < 2 or px.y < 2 or px.x >= img.get_width() - 2 or px.y >= img.get_height() - 2:
				continue
			var c := _sample_mean(img, px, 2)
			if _lum(c) < 30.0 or _sat(c) > 0.28:
				continue
			ls.append(_lum(c))
	if ls.size() < 4:
		return 0.0
	var lo := ls[0]
	var hi := ls[0]
	for v in ls:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo


func _features_visible(img: Image, cam: Camera3D, face: Node) -> Dictionary:
	var outd := {"eyes": false, "mouth": false, "eye_L": 0.0, "eye_R": 0.0, "mouth_L": 0.0}
	for name in ["EyeBeadL", "EyeBeadR", "MouthDot"]:
		var n := face.get_node_or_null(name) as MeshInstance3D
		if n == null:
			continue
		var px := cam.unproject_position(n.global_transform * n.get_aabb().get_center())
		var c := _sample_mean(img, px, 2)
		var L := _lum(c)
		if name == "EyeBeadL":
			outd["eye_L"] = L
			outd["eyes"] = L < 80.0
		elif name == "EyeBeadR":
			outd["eye_R"] = L
			outd["eyes"] = bool(outd["eyes"]) and L < 80.0
		else:
			outd["mouth_L"] = L
			outd["mouth"] = L < 90.0
	return outd


func _px(cam: Camera3D, node: MeshInstance3D, local_off := Vector3.ZERO) -> Vector2:
	return cam.unproject_position(node.global_transform * (node.get_aabb().get_center() + local_off))


func _wait(n := 4) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--mode="):
			mode = a.trim_prefix("--mode=")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(out + "/title")
	DirAccess.make_dir_recursive_absolute(out + "/gameplay")
	var lines: PackedStringArray = []
	if mode in ["full", "title"]:
		var t := await _title(lines)
		lines.append_array(t)
	if mode in ["full", "gameplay", "quick"]:
		var g := await _gameplay(lines)
		lines.append_array(g)
	var path := out + "/measures_%s.txt" % tag
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("T46_CAPTURE_OK tag=%s mode=%s lines=%d out=%s" % [tag, mode, lines.size(), out])
	quit(0)


func _title(lines: PackedStringArray) -> PackedStringArray:
	var acc: PackedStringArray = []
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var hs = main.home_screen
	var preview: ToyCharacterVisual = hs.preview
	var cam: Camera3D = null
	for c in hs.town_stage.get_children():
		if c is Camera3D:
			cam = c
			break
	var species_outfits := [0, 1, 2] if mode != "quick" else [0]
	for outfit in species_outfits:
		var species: String = SPECIES[outfit % 3]
		preview.set_player_color(0)
		preview.set_cosmetic_variant(outfit)
		preview.play_clip("idle")
		await _wait(8)
		var win := root.get_texture().get_image()
		var vp: Image = hs.preview_viewport.get_texture().get_image()
		win.save_png("%s/title/%s_title_%s_o%d.png" % [out, tag, species, outfit])
		var plate := preview.get_node("Model/Rig/Skeleton3D/FaceAnchor/FaceCream") as MeshInstance3D
		var face_px := _px(cam, plate, Vector3(0, -plate.get_aabb().size.y * 0.2, 0))
		# Composite: SubViewportContainer is 1280x720, so vp px ~= window px.
		var fc := _modal_face(vp, face_px, 8)
		var hc := _hood_color(vp, face_px, 55)
		var fl := _lum(fc)
		var hl := _lum(hc)
		var feat := _features_visible(vp, cam, plate.get_parent())
		var row := "TITLE %s %s o%d face=%s L=%.1f hood=%s L=%.1f ratio=%.2f eyes=%s mouth=%s face_px=%d,%d" % [
			tag, species, outfit, _rgb(fc), fl, _rgb(hc), hl, (fl / max(hl, 1.0)),
			str(feat["eyes"]), str(feat["mouth"]), int(face_px.x), int(face_px.y)
		]
		print(row)
		acc.append(row)
	main.queue_free()
	await process_frame
	return acc


func _gameplay(_lines: PackedStringArray) -> PackedStringArray:
	var acc: PackedStringArray = []
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov = 65.0
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
	# Mid-distance street-ish spot (open ground); close uses the same origin.
	var pos := Vector3(0, 0, 2)
	player.global_position = pos
	var ch: ToyCharacterVisual = player.character
	var rig := ch.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var plate := rig.get_node("FaceAnchor/FaceCream") as MeshInstance3D
	var mitten := rig.get_node("Paw_l/Mitten") as MeshInstance3D
	camera.current = true
	var outfits: Array = range(12) if mode == "full" else ([0] if mode == "quick" else [0, 1, 2])
	var colors: Array = [0] if mode == "quick" else range(6)
	var views: Array = ["close_frontlit"] if mode == "quick" else ["close_frontlit", "close_backlit", "mid_frontlit", "mid_backlit"]
	for outfit in outfits:
		var species: String = SPECIES[outfit % 3]
		ch.set_cosmetic_variant(outfit)
		var belly := ch.get_node_or_null("Accessories/Belly_%02d" % outfit) as MeshInstance3D
		for color in colors:
			ch.set_player_color(color)
			for view in views:
				# Skip full 12x6 mid/back grid except representative stills: still measure all colors on close + mid for o0/1/2.
				if mode == "full" and outfit >= 3 and view != "close_frontlit":
					continue
				if view.begins_with("close"):
					camera.fov = 50.0
					if view.ends_with("frontlit"):
						player.visual.rotation = Vector3(0, PI, 0)
						camera.global_position = pos + Vector3(0.0, 1.15, 2.15)
					else:
						player.visual.rotation = Vector3.ZERO
						camera.global_position = pos + Vector3(0.0, 1.15, -2.15)
					camera.look_at(pos + Vector3(0.0, 0.72, 0.0))
				else:
					camera.fov = 60.0
					if view.ends_with("frontlit"):
						player.visual.rotation = Vector3(0, PI, 0)
						camera.global_position = pos + Vector3(0.0, 2.0, 6.2)
					else:
						player.visual.rotation = Vector3.ZERO
						camera.global_position = pos + Vector3(0.0, 2.0, -6.2)
					camera.look_at(pos + Vector3(0.0, 0.85, 0.0))
				await _wait(4)
				var img := root.get_texture().get_image()
				var save_still: bool = (int(color) == 0 and int(outfit) <= 2) or (mode == "quick")
				if save_still:
					img.save_png("%s/gameplay/%s_%s_%s_o%d_c%d.png" % [out, tag, view, species, outfit, color])
				var face_px := _px(camera, plate, Vector3(0, -plate.get_aabb().size.y * 0.28, 0))
				var fc := _modal_face(img, face_px, 8 if view.begins_with("close") else 5)
				var hc := _hood_color(img, face_px, 80 if view.begins_with("close") else 36)
				var fl := _lum(fc)
				var hl := _lum(hc)
				var grad := _plate_gradient(img, camera, plate)
				var feat := _features_visible(img, camera, plate.get_parent())
				var paw_c := _sample_mean(img, _px(camera, mitten), 4)
				var belly_c := Color(0, 0, 0, 0)
				var belly_l := -1.0
				if belly != null and belly.visible:
					belly_c = _sample_mean(img, _px(camera, belly), 4)
					belly_l = _lum(belly_c)
				var face_mat := plate.material_override as StandardMaterial3D
				var paw_mat := mitten.material_override as StandardMaterial3D
				var albedo_eq := false
				if face_mat and paw_mat:
					albedo_eq = face_mat.albedo_color.is_equal_approx(paw_mat.albedo_color)
				var paw_l := _lum(paw_c)
				var d_paw := 0.0
				if paw_l > 0.0:
					d_paw = maxf(abs(fc.r - paw_c.r), maxf(abs(fc.g - paw_c.g), abs(fc.b - paw_c.b))) * 255.0
				var d_belly := 0.0
				if belly_l >= 0.0:
					d_belly = maxf(abs(fc.r - belly_c.r), maxf(abs(fc.g - belly_c.g), abs(fc.b - belly_c.b))) * 255.0
				var row := "GAME %s %s %s o%d c%d face=%s L=%.1f hood=%s L=%.1f ratio=%.2f grad=%.1f eyes=%s mouth=%s paw=%s L=%.1f dPaw=%.1f belly=%s L=%.1f dBelly=%.1f albedo_eq=%s face_px=%d,%d" % [
					tag, view, species, outfit, color, _rgb(fc), fl, _rgb(hc), hl, (fl / max(hl, 1.0)),
					grad, str(feat["eyes"]), str(feat["mouth"]), _rgb(paw_c), paw_l, d_paw,
					_rgb(belly_c), belly_l, d_belly, str(albedo_eq), int(face_px.x), int(face_px.y)
				]
				print(row)
				acc.append(row)
	# Face material path / emission for the log header
	var mat := plate.material_override as StandardMaterial3D
	if mat:
		acc.insert(0, "MAT path_or_albedo=%s emission=%s e=%.3f shading=%d" % [
			str(mat.resource_path), _rgb(mat.albedo_color), mat.emission_energy_multiplier, mat.shading_mode
		])
	main.queue_free()
	await process_frame
	return acc
