extends SceneTree
## T44 A4 face evidence (Architect A4 QA-proof framing = sheet.png framing).
## toy_town, spot (0,0,2), visual yaw 0, cam = spot+(0,1.1,-2.3) look_at spot+(0,0.8,0), fov 65, 1280x720.
## Outputs: 18 frames (outfits 0-2 x player colours 0-5), front-lit set (yaw PI, cam +Z) for colours 0 and 4,
## sheet-colour set (suit tinted like the sheet; capture-only override), numeric table, side-by-side vs sheet.
## Run: godot --path . --resolution 1280x720 --script res://.scratch/capture_t44_a4_face.gd -- --out=DIR
const SHEET := "/home/box/game-factory/evidence/T44-a2-spike/renders/%s_front.png"
const SPECIES := ["bear", "cat", "bunny"]
const SHEET_SUIT := [Color("a98466"), Color("7d93a8"), Color("d4a5ad")]
# Spike sheet measurements (Architect A4 README): plate n=6136 bbox 108x90; eyes n=1223 bbox 88x31 (both);
# eye centres (609,307)/(670,307); patch RGB bear (130,135,129).
const SHEET_PLATE_N := 6136
const SHEET_EYE_N := 1223
var out := "user://t44_a4"
var main: Node
var player: Node3D
var camera: Camera3D
var rows := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _grab() -> Image:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _um(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _px(mi: MeshInstance3D) -> Rect2:
	var a := mi.get_aabb()
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in 8:
		var p := camera.unproject_position(mi.global_transform * (a.position + a.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)))
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


func _mask(img: Image, pred: Callable, x_lo := 450, x_hi := 830) -> Dictionary:
	var n := 0
	var x0 := 9999
	var y0 := 9999
	var x1 := -1
	var y1 := -1
	for y in range(150, 520):
		for x in range(x_lo, x_hi):
			if pred.call(img.get_pixel(x, y)):
				n += 1
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	return {"n": n, "w": x1 - x0 + 1, "h": y1 - y0 + 1, "cx": (x0 + x1) * 0.5, "cy": (y0 + y1) * 0.5}


func _measure(tag: String, image: Image, fa: Node, frontlit: bool) -> void:
	var plate := fa.get_node("FaceCream") as MeshInstance3D
	var pr := _px(plate)
	var c := pr.get_center() + Vector2(0, pr.size.y * 0.28)
	var acc := Vector3.ZERO
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var col := image.get_pixelv(Vector2i(int(c.x) + dx, int(c.y) + dy))
			acc += Vector3(col.r, col.g, col.b)
	acc = acc / 49.0 * 255.0
	var eye_l := fa.get_node("EyeBeadL") as MeshInstance3D
	var eye_r := fa.get_node("EyeBeadR") as MeshInstance3D
	var saved := [plate.material_override, eye_l.material_override, eye_r.material_override]
	plate.material_override = _um(Color(1, 0, 1))
	eye_l.material_override = _um(Color(0, 1, 0))
	eye_r.material_override = _um(Color(0, 1, 0))
	for s in fa.get_children():
		if s.name.begins_with("EyeShine") or s.name == "MouthDot":
			(s as MeshInstance3D).visible = false
	var mask := await _grab()
	for s in fa.get_children():
		if s.name.begins_with("EyeShine") or s.name == "MouthDot":
			(s as MeshInstance3D).visible = true
	plate.material_override = saved[0]
	eye_l.material_override = saved[1]
	eye_r.material_override = saved[2]
	var mag := func(col: Color) -> bool: return col.r > 0.9 and col.g < 0.1 and col.b > 0.9
	var grn := func(col: Color) -> bool: return col.g > 0.9 and col.r < 0.1 and col.b < 0.1
	var pm := _mask(mask, mag)
	var em := _mask(mask, grn)
	var el := _mask(mask, grn, 450, int(em.cx))
	var er := _mask(mask, grn, int(em.cx), 830)
	var blush: bool = fa.find_child("Blush*", true, false) != null
	var row := "%s,%s,%.0f,%.0f,%.0f,%d,%d,%d,%d,%d,%d,%d,%.0f,%.0f,%.0f,%.0f,%.2f,%d" % [tag, "frontlit" if frontlit else "sheet_framing", acc.x, acc.y, acc.z, pm.n, pm.w, pm.h, em.n, em.w, em.h, el.n, el.cx, el.cy, er.cx, er.cy, float(em.h) / float(pm.h), int(blush)]
	rows.append(row)
	print("FACE ", row)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	camera = Camera3D.new()
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
	player = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	var pos := Vector3(0, 0, 2)
	player.global_position = pos
	var ch: ToyCharacterVisual = player.character
	var fa: Node = ch.get_node("Model/Rig/Skeleton3D/FaceAnchor")
	camera.current = true
	rows.append("tag,lighting,patch_r,patch_g,patch_b,plate_px,plate_w,plate_h,eyes_px,eyes_w,eyes_h,eyeL_px,eyeL_cx,eyeL_cy,eyeR_cx,eyeR_cy,eye_h_over_plate_h,blush_node")
	ch.play_clip("idle")
	for outfit in 3:
		ch.set_cosmetic_variant(outfit)
		for colour in 6:
			ch.set_player_color(colour)
			player.visual.rotation = Vector3.ZERO
			camera.global_position = pos + Vector3(0.0, 1.1, -2.3)
			camera.look_at(pos + Vector3(0.0, 0.8, 0.0))
			var image := await _grab()
			image.save_png("%s/%s_c%d_front.png" % [out, SPECIES[outfit], colour])
			await _measure("%s_c%d" % [SPECIES[outfit], colour], image, fa, false)
	# Front-lit: character turned to +Z, camera on +Z, colours 0 and 4.
	for outfit in [0, 1, 2]:
		ch.set_cosmetic_variant(outfit)
		for colour in [0, 4]:
			ch.set_player_color(colour)
			player.visual.rotation = Vector3(0.0, PI, 0.0)
			camera.global_position = pos + Vector3(0.0, 1.1, 2.3)
			camera.look_at(pos + Vector3(0.0, 0.8, 0.0))
			var image := await _grab()
			image.save_png("%s/%s_c%d_frontlit.png" % [out, SPECIES[outfit], colour])
			await _measure("%s_c%d_frontlit" % [SPECIES[outfit], colour], image, fa, true)
	# Sheet-colour set (suit tinted as in the sheet; capture-only override, no game code change).
	player.visual.rotation = Vector3.ZERO
	camera.global_position = pos + Vector3(0.0, 1.1, -2.3)
	camera.look_at(pos + Vector3(0.0, 0.8, 0.0))
	var sheet_shots: Array[Image] = []
	for outfit in 3:
		ch.set_cosmetic_variant(outfit)
		ch.set_player_color(0)
		var suit := ToyCharacterVisual.critter_material("suit")
		suit.albedo_color = SHEET_SUIT[outfit]
		for mesh in ch.get_node("Model/Rig/Skeleton3D").get_children():
			if mesh is MeshInstance3D:
				(mesh as MeshInstance3D).material_override = suit
		for accessory: MeshInstance3D in ch.get_node("Accessories").get_children():
			if accessory.get_meta("body") == "Head":
				accessory.set_surface_override_material(0, suit)
		var image := await _grab()
		image.save_png("%s/sheetcolour_%s.png" % [out, SPECIES[outfit]])
		sheet_shots.append(image)
	_side_by_side(sheet_shots)
	FileAccess.open("%s/face_measurements.csv" % out, FileAccess.WRITE).store_string("\n".join(rows) + "\n")
	print("T44_A4_FACE_CAPTURE_OK out=%s rows=%d" % [out, rows.size() - 1])
	quit(0)


func _side_by_side(shots: Array[Image]) -> void:
	var tile_w := 640
	var tile_h := 360
	var crop := Rect2i(450, 130, 380, 400)
	var canvas := Image.create(tile_w * 3, tile_h * 2 + 400 * 2, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.WHITE)
	for i in 3:
		var ref := Image.load_from_file(SHEET % SPECIES[i])
		ref.convert(Image.FORMAT_RGBA8)
		var mine := shots[i].duplicate() as Image
		mine.convert(Image.FORMAT_RGBA8)
		var ref_crop := ref.get_region(crop)
		var mine_crop := mine.get_region(crop)
		ref_crop.resize(380, 400)
		ref.resize(tile_w, tile_h)
		mine.resize(tile_w, tile_h)
		canvas.blit_rect(ref, Rect2i(0, 0, tile_w, tile_h), Vector2i(i * tile_w, 0))
		canvas.blit_rect(mine, Rect2i(0, 0, tile_w, tile_h), Vector2i(i * tile_w, tile_h))
		canvas.blit_rect(ref_crop, Rect2i(0, 0, 380, 400), Vector2i(i * tile_w + 130, tile_h * 2))
		canvas.blit_rect(mine_crop, Rect2i(0, 0, 380, 400), Vector2i(i * tile_w + 130, tile_h * 2 + 400))
	canvas.save_png("%s/side_by_side_vs_sheet.png" % out)
