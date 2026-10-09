extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func settle() -> void:
	for frame in 8:
		await process_frame

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	main.disaster_director.cleanup()
	var menu = main.pause_settings
	menu.config_path = "user://window-resolution-test.cfg"
	expect(menu.controls.has("windowed_resolution"), "Settings must offer persistent windowed resolution")
	if not menu.controls.has("windowed_resolution"):
		main.free()
		_finish()
		return
	var option: OptionButton = menu.controls.windowed_resolution
	expect(menu.available_window_resolutions(Vector2i(1365, 768)) == [Vector2i(1280, 720)], "1366 preset must not fit a 1365-wide desktop")
	expect(menu.available_window_resolutions(Vector2i(1366, 768)) == [Vector2i(1280, 720), Vector2i(1366, 768)], "Exact fitting preset must be included")
	expect(menu.available_window_resolutions(Vector2i(1024, 600)) == [Vector2i(1024, 600)], "Small desktop needs a fitting fallback, not an oversized 720p window")
	expect(menu.available_window_resolutions(Vector2i(2560, 1440)) == [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)], "All five supported resolutions must be available when they fit")
	expect(menu.fit_window_resolution(Vector2i(0, -2), Vector2i(1366, 768)) == Vector2i(1280, 720), "Invalid saved dimensions must fall back safely")
	expect(menu.fit_window_resolution(Vector2i(8000, 4000), Vector2i(1024, 600)) == Vector2i(1024, 600), "Oversized saved dimensions must fit a small desktop")
	expect(menu.fit_window_resolution(Vector2i(1111, 666), Vector2i(1366, 768)) == Vector2i(1111, 666), "Valid manual sizes must not be forced to a preset")
	var config := ConfigFile.new()
	config.set_value("preferences", "windowed_resolution", "1920x1080")
	expect(config.save(menu.config_path) == OK, "Malformed preference fixture must save")
	menu.values.windowed_resolution = Vector2i(1280, 720)
	menu.load_preferences(menu.config_path)
	expect(menu.values.windowed_resolution == Vector2i(1280, 720), "Wrong-type saved resolution must be ignored")
	if DisplayServer.get_name() != "headless":
		menu.values.fullscreen = false
		menu.apply_preferences()
		menu.show_settings()
		await settle()
		var target: Vector2i = option.get_item_metadata(0)
		option.item_selected.emit(0)
		await settle()
		expect(DisplayServer.window_get_size() == target, "Selecting preset must resize the actual client window")
		DisplayServer.window_set_position(Vector2i(-500, -400))
		menu._apply_windowed_size()
		await settle()
		var desktop := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var frame := Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())
		expect(desktop.encloses(frame), "Native window frame/title bar must remain reachable after offscreen restore")
		expect(menu.panel.get_global_rect().encloses(option.get_global_rect()) and menu.panel.get_global_rect().encloses(menu.resume.get_global_rect()), "Resolution control and footer must fit settings panel")
		var manual := Vector2i(1000, 600)
		DisplayServer.window_set_size(manual)
		await settle()
		expect(menu.values.windowed_resolution == manual, "Manual resize must update remembered client dimensions")
		menu.controls.warning_volume.value = 0.43
		await settle()
		expect(DisplayServer.window_get_size() == manual, "Unrelated audio changes must not undo manual resize")
		menu.controls.fullscreen.button_pressed = true
		await settle()
		expect(option.disabled and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Windowed selector must be disabled in fullscreen")
		menu.controls.fullscreen.button_pressed = false
		await settle()
		expect(not option.disabled and DisplayServer.window_get_size() == manual, "Fullscreen round trip must restore remembered manual dimensions")
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-dir="):
				var directory := argument.trim_prefix("--capture-dir=")
				root.gui_embed_subwindows = true
				for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
					if menu.fit_window_resolution(size, menu._available_window_rect().size) != size:
						continue
					menu.values.windowed_resolution = size
					menu.apply_preferences(true)
					menu.show_settings()
					await capture(directory, "settings-%dx%d" % [size.x, size.y])
					if size == Vector2i(1280, 720):
						option.show_popup()
						await capture(directory, "resolution-open")
						option.get_popup().hide()
					menu.back()
					main._set_lobby_visible(true)
					await capture(directory, "lobby-%dx%d" % [size.x, size.y])
					main._set_lobby_visible(false)
					await capture(directory, "hud-%dx%d" % [size.x, size.y])
				menu.show_settings()
				menu.controls.fullscreen.button_pressed = true
				await capture(directory, "fullscreen-disabled")
				menu.controls.fullscreen.button_pressed = false
				menu.back()
				main.match_manager.tick_match(main.match_manager.match_duration)
				await capture(directory, "results")
	var reloaded = load("res://game/ui/pause_settings.gd").new()
	reloaded.load_preferences(menu.config_path)
	expect(reloaded.values.windowed_resolution == menu.values.windowed_resolution, "Fresh settings instance must restore remembered dimensions")
	reloaded.free()
	DirAccess.remove_absolute(menu.config_path)
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	_finish()

func capture(directory: String, name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "Rendered %s capture must save" % name)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("WINDOWED_RESOLUTION_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
