extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.disaster_director.cleanup()
	_expect(main.get_node("Interface").has_node("PauseSettings"), "Pause/settings overlay must exist")
	if not main.get_node("Interface").has_node("PauseSettings"):
		main.free()
		_finish()
		return
	var menu = main.get_node("Interface/PauseSettings")
	if menu.config_path == "user://settings.cfg":
		menu.config_path = "user://test-milestone-1-5.cfg"
	if "--verify-restart" in OS.get_cmdline_user_args():
		_expect(is_equal_approx(menu.values.master_volume, 0.31) and is_equal_approx(menu.values.mouse_sensitivity, 1.7) and menu.values.invert_y and menu.values.reduced_motion, "New process must restore persisted settings at startup")
		_expect(menu.values.windowed_resolution == Vector2i(1111, 666) and (DisplayServer.get_name() == "headless" or DisplayServer.window_get_size() == Vector2i(1111, 666)), "New process must restore custom windowed dimensions to the actual window")
		DirAccess.remove_absolute(menu.config_path)
		main.free()
		_finish()
		return
	var before: float = main.match_manager.elapsed_time
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	root.push_input(cancel)
	await process_frame
	_expect(menu.visible and main.get_node("Player").local_input_blocked and not paused, "Escape blocks local input without pausing SceneTree")
	main._process(0.75)
	_expect(main.match_manager.elapsed_time >= before + 0.75, "Authority timer must continue under pause")
	await _capture("pause")
	menu.show_settings()
	await process_frame
	_expect(menu.controls.size() == 10, "All preferences including windowed resolution must be editable")
	_expect(menu.controls.master_volume.has_focus(), "Settings starts on master-volume focus")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_expect(menu.controls.effects_volume.has_focus(), "Keyboard Tab reaches next setting")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	root.push_input(down)
	await process_frame
	_expect(menu.controls.warning_volume.has_focus(), "Controller down reaches warning setting")
	menu.controls.master_volume.value = 0.31
	menu.controls.effects_volume.value = 0.67
	menu.controls.warning_volume.value = 0.83
	menu.controls.mouse_sensitivity.value = 1.7
	menu.controls.invert_y.button_pressed = true
	menu.controls.camera_shake.value = 0.0
	menu.controls.reduced_motion.button_pressed = true
	await process_frame
	_expect(main.gameplay_hud.reduced_motion and main.get_node("Player").invert_y and is_equal_approx(main.get_node("Player").mouse_sensitivity, 1.7), "Settings apply to real HUD and controller")
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Warnings")), 0.83) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Effects")), 0.67), "Warning and effects gains must remain independent")
	main.gameplay_audio.play_warning("flood")
	for index in 25:
		main.gameplay_audio.play_ui("focus")
	_expect(main.gameplay_audio._effect_voices.size() == 4 and main.gameplay_audio.warning_voice_is_reserved(), "UI bursts cannot allocate voices or steal the warning")
	main.gameplay_audio.play_warning_countdown()
	_expect(main.gameplay_audio._effect_voices[main.gameplay_audio._next_effect_voice - 1].bus == "Warnings", "Countdown must follow warning volume")
	main.gameplay_audio.play_jump()
	_expect(main.gameplay_audio._effect_voices[main.gameplay_audio._next_effect_voice - 1].bus == "Effects", "Reused countdown voice must restore effects routing")
	await _capture("settings")
	var script = load("res://game/ui/pause_settings.gd")
	var reloaded = script.new()
	reloaded.load_preferences(menu.config_path)
	_expect(is_equal_approx(reloaded.values.master_volume, 0.31) and is_equal_approx(reloaded.values.warning_volume, 0.83) and reloaded.values.invert_y and reloaded.values.reduced_motion, "Fresh instance must load saved asymmetric preferences")
	reloaded.free()
	root.push_input(cancel)
	await process_frame
	_expect(menu.visible and not menu.settings_page.visible, "Escape from settings returns to pause")
	root.push_input(cancel)
	await process_frame
	_expect(not menu.visible and not main.get_node("Player").local_input_blocked, "Escape from pause restores gameplay input")
	_expect(DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Resume recaptures gameplay cursor")
	var player: PartyPlayer = main.get_node("Player")
	if DisplayServer.get_name() != "headless":
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(12, 7)
		var yaw: float = player._camera_yaw
		var pitch: float = player._camera_pitch
		player._unhandled_input(motion)
		_expect(is_equal_approx(player._camera_yaw - yaw, -0.051) and is_equal_approx(player._camera_pitch - pitch, 0.02975), "Asymmetric actual mouse deltas must honor sensitivity and inverted Y")
		menu.controls.fullscreen.button_pressed = true
		await process_frame
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen setting applies to the real display")
		menu.controls.fullscreen.button_pressed = false
		await process_frame
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Windowed setting restores display mode")
	player._knockdown_remaining = 0.13
	player._process(0.0)
	_expect(is_zero_approx(player.get_node("CameraPivot/SpringArm3D/Camera3D").h_offset), "Reduced motion removes camera shake")
	player.camera_shake_level = 1.0
	player._process(0.0)
	_expect(absf(player.get_node("CameraPivot/SpringArm3D/Camera3D").h_offset) > 0.005, "Camera shake setting affects bounded cosmetic feedback")
	player._knockdown_remaining = 0.0
	menu.open_pause()
	var menu_focus: Control = root.gui_get_focus_owner()
	main.match_manager.tick_match(main.match_manager.match_duration)
	main._process(0.0)
	_expect(menu.visible and root.gui_get_focus_owner() == menu_focus, "Match completion underneath pause cannot steal local focus")
	menu.back()
	_expect(main.get_node("Interface/ResultsPanel/Table").scroll.has_focus(), "Closing gameplay pause after match completion focuses results")
	var settings: Button = main.get_node("Interface/ResultsPanel/Actions/Settings")
	settings.grab_focus()
	settings.pressed.emit()
	await process_frame
	_expect(menu.visible and menu.settings_page.visible and main.match_manager.state == MatchManager.MatchState.RESULTS, "Results settings cannot restart or change session state")
	root.push_input(cancel)
	await process_frame
	_expect(not menu.visible and settings.has_focus() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Results settings returns to invoking focus and visible cursor")
	if "--save-for-restart" in OS.get_cmdline_user_args():
		menu.values.windowed_resolution = Vector2i(1111, 666)
		menu._save()
		main.gameplay_audio.reset_for_match()
		main.free()
		_finish()
		return
	menu.values = menu.DEFAULTS.duplicate()
	menu.apply_preferences()
	DirAccess.remove_absolute(menu.config_path)
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	_finish()

func _capture(state: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var menu = root.get_node("Main/Interface/PauseSettings")
			_expect(menu.panel.get_global_rect().encloses(menu.resume.get_global_rect()), "Menu footer must fit panel")
			for control in menu.controls.values():
				if control.is_visible_in_tree():
					_expect(menu.panel.get_global_rect().encloses(control.get_global_rect()), "Settings control must fit panel")
			var path := argument.trim_prefix("--capture-dir=").path_join("%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Capture must save")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PAUSE_SETTINGS_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
