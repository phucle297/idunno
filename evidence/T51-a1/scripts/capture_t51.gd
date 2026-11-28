extends SceneTree
## T51 A1 evidence: Outfits swatch UI, title preview and in-match shots for two picked colours
## (second pick made after returning to the lobby, shot mid-match), 4P distinct colours, face-plate check.
## Usage: xvfb-run godot --path . --script res://evidence/T51-a1/scripts/capture_t51.gd -- --out=DIR
var out := "/tmp/t51"
var face_lines: PackedStringArray = []
var four_lines: PackedStringArray = []
var ok := true
const CREAM_PATH := "res://assets/models/critter/materials/MAT_Critter_Cream_v002.tres"
const COLOUR_A := 3
const COLOUR_B := 1


func _initialize() -> void:
	_run.call_deferred()


func _lum(c: Color) -> float:
	return 0.2126 * c.r * 255.0 + 0.7152 * c.g * 255.0 + 0.0722 * c.b * 255.0


func _sat(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


func _rgb(c: Color) -> String:
	return "(%d,%d,%d)" % [round(c.r * 255.0), round(c.g * 255.0), round(c.b * 255.0)]


func _mean(img: Image, p: Vector2, r := 4, skip_dark := true) -> Color:
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var c := img.get_pixel(clampi(int(p.x) + dx, 0, img.get_width() - 1), clampi(int(p.y) + dy, 0, img.get_height() - 1))
			if skip_dark and _lum(c) < 50.0:
				continue # eyes / mouth beads
			acc += c
			n += 1
	return acc / maxi(n, 1)


func _wait(n := 6) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(img: Image, name: String) -> void:
	var err := img.save_png("%s/%s" % [out, name])
	print("SHOT %s err=%d" % [name, err])
	ok = ok and err == OK


func _face_check(label: String, img: Image, cam: Camera3D, visual: ToyCharacterVisual, colour: int) -> void:
	var plate := visual.get_node("Model/Rig/Skeleton3D/FaceAnchor/FaceCream") as MeshInstance3D
	var torso := visual.get_node("Torso") as MeshInstance3D
	var suit := torso.material_override as StandardMaterial3D
	var face_mat := plate.material_override if plate.material_override != null else plate.get_active_material(0)
	var path := face_mat.resource_path if face_mat != null else "none"
	var face_px := cam.unproject_position(plate.global_transform * (plate.get_aabb().get_center() + Vector3(0, -plate.get_aabb().size.y * 0.2, 0)))
	var face_c := _mean(img, face_px, 5)
	var suit_c := (ToyCharacterVisual.SUIT_COLORS[colour] as Color).lerp(ToyCharacterVisual.SUIT_SOFTEN, 0.28)
	var delta := maxf(absf(face_c.r - suit_c.r), maxf(absf(face_c.g - suit_c.g), absf(face_c.b - suit_c.b))) * 255.0
	var suit_ok := suit != null and suit.albedo_color.is_equal_approx(suit_c)
	# Pixel: plate reads as light low-saturation cream and is far from the suit albedo.
	var unpainted := path == CREAM_PATH and face_mat != suit and _sat(face_c) < 0.28 and _lum(face_c) > 150.0 and delta > 40.0
	var row := "FACE %s colour=c%d face_material=%s face_is_suit_material=%s suit_albedo_ok=%s face_px_rgb=%s suit_albedo=%s face_lum=%.1f face_sat=%.2f max_channel_delta_vs_suit=%.1f -> %s" % [
		label, colour, path, str(face_mat == suit), str(suit_ok), _rgb(face_c), _rgb(suit_c), _lum(face_c), _sat(face_c), delta,
		"CREAM_UNPAINTED" if unpainted and suit_ok else "CHECK"]
	print(row)
	face_lines.append(row)
	ok = ok and unpainted and suit_ok


func _pick_in_outfits(main: Node, colour: int) -> void:
	main._show_collection()
	await _wait(4)
	main.collection.colour_buttons[colour].grab_focus()
	main.collection.colour_buttons[colour].pressed.emit()
	await _wait(10)
	var picked: bool = main.get_suit_colour() == colour and main.collection.colour_current == colour
	print("PICK c%d via Outfits swatch -> get_suit_colour=%d %s" % [colour, main.get_suit_colour(), "OK" if picked else "FAIL"])
	ok = ok and picked
	_save(root.get_texture().get_image(), "ui-outfits-c%d.png" % colour)
	main.collection.dismiss()
	await _wait(4)


func _title(main: Node, colour: int) -> void:
	main.home_screen.refresh()
	await _wait(30)
	var win := root.get_texture().get_image()
	_save(win, "title-c%d.png" % colour)
	var cam: Camera3D = null
	for c in main.home_screen.town_stage.get_children():
		if c is Camera3D:
			cam = c
	var vp: Image = main.home_screen.preview_viewport.get_texture().get_image()
	_face_check("title-c%d" % colour, vp, cam, main.home_screen.preview, colour)


func _in_match(main: Node, colour: int, close_name: String) -> void:
	var player := main.get_node("Player") as PartyPlayer
	# Match stays ACTIVE (timer running); disasters are cleared so the critter stands for the stills (as T46 capture).
	main.disaster_director.cleanup()
	main.disaster_director.set_physics_process(false)
	await _wait(90)
	print("MATCH state=%d elapsed=%.1fs colour=c%d" % [main.match_manager.state, main.match_manager.elapsed_time, main.get_suit_colour()])
	_save(root.get_texture().get_image(), "game-c%d.png" % colour)
	# Close still on the same live match (extra camera), face check from it.
	var camera := Camera3D.new()
	camera.fov = 50.0
	main.add_child(camera)
	player.set_physics_process(false)
	var pos := player.global_position
	player.visual.rotation = Vector3(0, PI, 0)
	camera.global_position = pos + Vector3(0.0, 1.15, 2.15)
	camera.look_at(pos + Vector3(0.0, 0.72, 0.0))
	camera.current = true
	main.get_node("Interface").visible = false
	await _wait(6)
	var img := root.get_texture().get_image()
	_save(img, close_name)
	_face_check(close_name.get_basename(), img, camera, player.character, colour)
	main.get_node("Interface").visible = true
	player.set_physics_process(true)
	camera.current = false
	player.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	camera.queue_free()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(90)
	main.room_client.service_url = "http://127.0.0.1:1"
	# Colour A: outfit first, then colour (outfit-then-colour order).
	main.request_outfit("chef")
	await _pick_in_outfits(main, COLOUR_A)
	await _title(main, COLOUR_A)
	main.set_map_id("toy_town")
	var started: bool = await main.start_local_match()
	print("MATCH1 started=%s" % str(started))
	await _in_match(main, COLOUR_A, "game-c%d-close.png" % COLOUR_A)
	# End match 1 and go back to the lobby.
	main.match_manager.apply_damage(1, 1000.0, "T51 capture")
	for i in 240:
		if main.match_manager.state == MatchManager.MatchState.RESULTS:
			break
		await process_frame
	var back: bool = main.return_to_lobby()
	await _wait(30)
	print("LOBBY back=%s state=%d colour=c%d" % [str(back), main.match_manager.state, main.get_suit_colour()])
	ok = ok and back
	# Colour B: picked after returning to the lobby, then outfit (colour-then-outfit order).
	await _pick_in_outfits(main, COLOUR_B)
	main.request_outfit("cap")
	await _title(main, COLOUR_B)
	started = await main.start_local_match()
	print("MATCH2 started=%s" % str(started))
	await _in_match(main, COLOUR_B, "game-c%d-close.png" % COLOUR_B)
	var player := main.get_node("Player") as PartyPlayer
	var head_ok := true
	for acc: MeshInstance3D in player.character.get_node("Accessories").get_children():
		if acc.get_meta("body") == "Head" and acc.get_surface_override_material(0) != player.character.get_node("Torso").material_override:
			head_ok = false
	print("OUTFIT_ORDER outfit=%s colour=c%d head_accessories_carry_suit=%s" % [main.get_outfit_id(), main.get_suit_colour(), str(head_ok)])
	face_lines.append("OUTFIT_ORDER match1 chef-then-c%d, match2 c%d-then-%s head_accessories_carry_suit=%s" % [COLOUR_A, COLOUR_B, main.get_outfit_id(), str(head_ok)])
	ok = ok and head_ok and main.get_outfit_id() == "cap"
	# 4P mid-match: ids that collide under peer_id - 1 (mod 6).
	var ids: Array[int] = [2, 3141592, 987654321]
	var pos := player.global_position
	player.set_physics_process(false)
	var outfits := ["sailor", "pilot", "firefighter"]
	for i in ids.size():
		main._add_gameplay_demo_player(ids[i], "Demo %d" % i, pos + Vector3(1.4 * (i + 1), 0, 0))
		main._apply_outfit(ids[i], outfits[i])
	var seen: Array[int] = []
	for peer: int in [1] + ids:
		var c: int = main.get_suit_colour(peer)
		four_lines.append("peer=%d colour=c%d legacy_peer_id-1_mod6=c%d outfit=%s" % [peer, c, posmod(peer - 1, 6), main.get_outfit_id(peer)])
		if not c in seen:
			seen.append(c)
	four_lines.append("distinct=%d of 4 -> %s" % [seen.size(), "PASS" if seen.size() == 4 else "FAIL"])
	ok = ok and seen.size() == 4
	var camera := Camera3D.new()
	camera.fov = 55.0
	main.add_child(camera)
	for p: Node3D in main._player_nodes.values():
		(p as PartyPlayer).visual.rotation = Vector3(0, PI, 0)
	var mid := pos + Vector3(2.1, 0, 0)
	camera.global_position = mid + Vector3(0.0, 1.8, 5.2)
	camera.look_at(mid + Vector3(0, 0.8, 0))
	camera.current = true
	main.get_node("Interface").visible = false
	await _wait(6)
	_save(root.get_texture().get_image(), "four-p.png")
	var close := Camera3D.new()
	close.fov = 50.0
	main.add_child(close)
	close.global_position = pos + Vector3(0.0, 1.15, 2.15)
	close.look_at(pos + Vector3(0.0, 0.72, 0.0))
	close.current = true
	await _wait(6)
	_save(root.get_texture().get_image(), "outfit-order.png")
	print("\n".join(four_lines))
	var f := FileAccess.open(out + "/face-cream.log", FileAccess.WRITE)
	f.store_string("# T51 A1 face check (FaceCream must stay %s, never the suit material)\n" % CREAM_PATH + "\n".join(face_lines) + "\n")
	f.close()
	f = FileAccess.open(out + "/four-p-distinct.capture.log", FileAccess.WRITE)
	f.store_string("# T51 A1 4P mid-match colours (capture run)\n" + "\n".join(four_lines) + "\n")
	f.close()
	print("T51_CAPTURE_%s" % ("OK" if ok else "FAIL"))
	main.gameplay_audio.reset_for_match()
	main.queue_free()
	await process_frame
	quit(0 if ok else 1)
