extends SceneTree
## T52 A1 evidence: pick a suit colour, persist it, and restore it on a fresh launch.
## Phases: pick | restore | taken
## Usage: xvfb-run godot --path . --script res://evidence/T52-a1/scripts/restart_t52.gd -- --out=DIR --phase=pick

var out := "/tmp/t52"
var phase := "pick"
const COLOUR := 4
var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _wait(n := 6) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _log(line: String) -> void:
	print(line)
	var path := "%s/restart.partial.log" % out
	if phase == "taken":
		path = "%s/colour-taken-save.partial.log" % out
	var existing := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		ok = false
		return
	file.store_string(existing + line + "\n")
	file.close()


func _save_title(name: String) -> void:
	var err := root.get_texture().get_image().save_png("%s/%s" % [out, name])
	_log("SHOT %s err=%d" % [name, err])
	ok = ok and err == OK


func _file_raw() -> String:
	if not FileAccess.file_exists("user://starter-suit-colour.txt"):
		return "<missing>"
	return FileAccess.get_file_as_string("user://starter-suit-colour.txt")


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--phase="):
			phase = a.trim_prefix("--phase=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	if phase == "taken":
		await _phase_taken()
	elif phase == "restore":
		await _phase_restore()
	else:
		await _phase_pick()
	_log("PHASE %s -> %s" % [phase, "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)


func _phase_pick() -> void:
	if FileAccess.file_exists("user://starter-suit-colour.txt"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://starter-suit-colour.txt"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(90)
	main.room_client.service_url = "http://127.0.0.1:1"
	_log("PICK start userdata=%s colour_before=%s file=%s" % [OS.get_user_data_dir(), str(main.get_suit_colour()), _file_raw()])
	main.request_suit_colour(COLOUR)
	await _wait(8)
	main.home_screen.refresh()
	await _wait(30)
	var colour: int = main.get_suit_colour()
	var raw := _file_raw().strip_edges()
	_log("PICK after request colour=%d file=%s user://=%s" % [colour, raw, OS.get_user_data_dir()])
	ok = ok and colour == COLOUR and raw == str(COLOUR)
	_save_title("title-before.png")
	main.free()
	await _wait(4)


func _phase_restore() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(90)
	main.room_client.service_url = "http://127.0.0.1:1"
	main.home_screen.refresh()
	main._set_lobby_visible(true)
	await _wait(30)
	var colour: int = main.get_suit_colour()
	var raw := _file_raw().strip_edges()
	_log("RESTORE colour=%d file=%s userdata=%s" % [colour, raw, OS.get_user_data_dir()])
	# Home preview should match the restored request.
	var preview: ToyCharacterVisual = main.home_screen.preview
	var avatar: ToyCharacterVisual = main.get_node("Player").character
	var preview_match: bool = preview.get_node("Torso").material_override == avatar.get_node("Torso").material_override
	_log("RESTORE home_preview_matches_avatar=%s" % str(preview_match))
	ok = ok and colour == COLOUR and raw == str(COLOUR) and preview_match
	_save_title("title-after.png")
	main.free()
	await _wait(4)


func _phase_taken() -> void:
	var file := FileAccess.open("user://starter-suit-colour.txt", FileAccess.WRITE)
	file.store_string("4")
	file.close()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(90)
	_log("TAKEN loaded colour=%d file=%s" % [main.get_suit_colour(), _file_raw().strip_edges()])
	main._apply_suit_colour(1, 0)
	main._add_gameplay_demo_player(2, "Holder", Vector3(3, 0, 3))
	main._apply_suit_colour(2, 4)
	var replies: Array[String] = []
	main.suit_colour_replied.connect(func(_c: int, error: String) -> void: replies.append(error))
	main.request_suit_colour(4)
	await _wait(4)
	var session: int = main.get_suit_colour()
	var raw := _file_raw().strip_edges()
	var error: String = replies.back() if not replies.is_empty() else "<no-reply>"
	_log("TAKEN request_4 error=%s session=%d file=%s holder=%d" % [error, session, raw, main.get_suit_colour(2)])
	ok = ok and error == "colour_taken" and session == 0 and raw == "4" and main.get_suit_colour(2) == 4
	main.free()
	await _wait(4)
