extends SceneTree

var checks := 0
var failures: Array[String] = []
var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_3d_disabled := root.disable_3d
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if "--1080p" in OS.get_cmdline_user_args():
		main.pause_settings.values.fullscreen = false
		main.pause_settings.values.windowed_resolution = Vector2i(1920, 1080)
		main.pause_settings.apply_preferences(true)
		root.size = Vector2i(1920, 1080)
		await process_frame
	var panel: Panel = main.get_node("Interface/LobbyPanel")
	var player: PartyPlayer = main.get_node("Player")
	var original_outfit: String = main.get_outfit_id()
	_expect(main.music.context == "menu", "Home starts with menu music context")
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY, "Normal launch waits in preparation, not solo gameplay")
	_expect(main.home_screen.is_visible_in_tree() and not panel.visible and player.local_input_blocked, "Dedicated Home replaces the room dialog and blocks movement")
	_expect(main.get_node("Sandbox").get_child_count() == 0, "Normal Home startup leaves the gameplay Sandbox empty")
	_expect(root.disable_3d and main.home_screen.preview_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Opaque Home suppresses gameplay rendering without suppressing its separate live preview")
	var original_reduced: bool = main.pause_settings.values.reduced_motion
	main.pause_settings.values.reduced_motion = false
	main._update_lobby_ui()
	var stage: Node3D = main.home_screen.town_stage
	var moving_cloud: Vector3 = stage.clouds[1].position
	var moving_car: Vector3 = stage.cars[1].position
	await create_timer(0.08).timeout
	_expect(stage.clouds[1].position != moving_cloud and stage.cars[1].position != moving_car, "Home renders a live town: clouds and traffic actually advance")
	_expect(not player.world_loaded and player.position == main.get_map_spawn_origin() and player.velocity == Vector3.ZERO, "An unloaded gameplay avatar must not fall while Home is open")
	_expect(stage.find_children("*", "CollisionObject3D", true, false).is_empty(), "Home diorama must not add gameplay collision or authority")
	await _capture_motion()
	main.pause_settings.values.reduced_motion = true
	main._update_lobby_ui()
	var frozen: float = stage.elapsed
	var frozen_pose: float = main.home_screen.preview.get_node("AnimationPlayer").current_animation_position
	await create_timer(0.08).timeout
	_expect(stage.elapsed == frozen and main.home_screen.preview.get_node("AnimationPlayer").current_animation_position == frozen_pose, "Reduced motion freezes scenery and the avatar, not just the viewport")
	main.pause_settings.values.reduced_motion = original_reduced
	main._update_lobby_ui()
	_expect(not main.disaster_director.running and main.match_manager.elapsed_time == 0, "No timer or disasters run before choosing play")
	_expect(panel.get_node("Start").text == "PLAY SOLO" and panel.get_node("Host").visible and panel.get_node("Join").visible, "Solo and multiplayer choices are available")
	_expect(panel.get_node("MapSelect").visible and panel.get_node("PresetSelect").visible, "Map and mode selectors are available before starting")
	_expect(panel.get_node("PresetSelect") in main._lobby_focus_controls(), "Keyboard/controller focus reaches match mode")
	main._set_lobby_visible(false)
	_expect(main.home_screen.visible, "Dismiss cannot bypass Home into a non-running world")
	await _capture("startup")
	main.home_screen.settings.pressed.emit()
	_expect(main.pause_settings.visible and player.local_input_blocked, "Home settings opens without releasing gameplay input")
	await _capture("settings")
	main.pause_settings.back()
	main.home_screen.multiplayer_button.pressed.emit()
	_expect(panel.visible and not main.home_screen.visible, "Multiplayer opens the real create/join room flow")
	await _capture("multiplayer")
	_expect(main.request_match_preset("hot_potato"), "Room can select the multiplayer bomb variant")
	panel.get_node("Close").pressed.emit()
	_expect(main.home_screen.visible and main.home_screen.page == "home", "Closing offline room returns to Home")
	main.home_screen.solo.pressed.emit()
	_expect(main.home_screen.page == "maps" and main.home_screen.maps.visible, "Play Solo opens a separate Choose Map page without starting")
	_expect(main.get_match_preset() == "normal" and main.home_screen.mode_buttons[0].text.begins_with("✓"), "Solo preparation clears multiplayer-only bomb rules and shows a real selected mode")
	frozen = stage.elapsed
	await create_timer(0.08).timeout
	_expect(stage.elapsed == frozen and main.home_screen.preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Choose Map stops hidden Home animation and rendering")
	await _capture("choose-map")
	main.home_screen.show_page("home")
	main.room_client.service_url = "" # Offline equipment must not require HTTP.
	main.home_screen.outfits.pressed.emit()
	await process_frame
	_expect(main.collection.visible and main.collection.lobby, "Outfit chooser opens in equippable lobby state")
	_expect(main.music.context == "menu", "Outfit selection keeps menu theme without switching context")
	main.collection.select_outfit("cap")
	main.collection.equip_button.pressed.emit()
	_expect(main.get_outfit_id() == "cap" and player.character.get_outfit_id() == "cap", "Acknowledged starter equip changes the actual player")
	main._update_lobby_ui()
	_expect(player.local_input_blocked, "Collection retains movement blocking during UI refresh")
	await _capture("outfit-equipped")
	main.collection.dismiss()
	main._update_lobby_ui()
	_expect(main.home_screen.preview.get_outfit_id() == "cap", "Home preview reflects acknowledged equipment")
	await _capture("home-equipped")
	main.home_screen.solo.pressed.emit()
	main.home_screen.map_buttons[1].pressed.emit()
	main.home_screen.mode_buttons[1].pressed.emit()
	_expect(main.get_map_id() == "toy_harbor" and main.get_match_preset() == main.MATCH_PRESETS[1], "Menu choices update authoritative map and match preset")
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY and not main.disaster_director.running, "Changing map and mode never starts a round")
	_expect(main.get_node("Sandbox").get_child_count() == 0, "Map selection remains metadata-only while Home is open")
	await _capture("map-mode-selected")
	main.home_screen.show_page("home")
	main.home_screen.solo.pressed.emit()
	_expect(main.get_map_id() == "toy_harbor" and main.get_match_preset() == "hard", "Back preserves map and difficulty")
	await main.start_local_match()
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE and main.disaster_director.running, "Solo button explicitly starts match and director")
	_expect(main.get_node("Sandbox").get_child_count() > 0 and main.get_node("Sandbox").get_meta("map_anchors").map_id == "toy_harbor", "Start prepares selected gameplay geometry and anchors")
	_expect(main.music.context == "gameplay", "Starting a match switches the real music owner to gameplay")
	_expect(not panel.visible and not main.home_screen.visible and not player.local_input_blocked, "Start closes preparation pages and releases gameplay input")
	_expect(root.disable_3d == original_3d_disabled, "Start restores the caller's gameplay rendering state")
	_expect(player.character.get_outfit_id() == "cap" and main.get_map_id() == "toy_harbor", "Selected outfit and map survive the start boundary")
	_expect(player.world_loaded, "Start enables avatar simulation only after loading gameplay collision")
	await _capture("started")
	main.disaster_director.cleanup()
	main.match_manager.apply_damage(1, 100, "Menu regression")
	var loaded_world_id: int = main.get_node("Sandbox").get_child(0).get_instance_id()
	_expect(main.return_to_lobby(), "Results can return to preparation")
	_expect(root.disable_3d and main.get_node("Sandbox").get_child(0).get_instance_id() == loaded_world_id, "Returning Home hides gameplay rendering without rebuilding retained geometry")
	_expect(main.music.context == "menu", "Results/lobby restores menu theme")
	main.request_outfit(original_outfit)
	_expect(main.get_outfit_id() == original_outfit, "Restore original saved starter after test")
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	_expect(root.disable_3d == original_3d_disabled, "Scene departure restores the viewport rather than leaving the next scene blank")
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("STARTUP_MENU_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _capture(state: String) -> void:
	if not "--capture-menu" in OS.get_cmdline_user_args():
		return
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://.amp/in/artifacts/homepage"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	if "--1080p" in OS.get_cmdline_user_args():
		directory = directory.path_join("1080p")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.get_texture().get_image().save_png(directory.path_join(state + ".png"))


func _capture_motion() -> void:
	if not "--capture-motion" in OS.get_cmdline_user_args():
		return
	var directory := "res://.scratch/home-motion-frames"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--motion-dir="):
			directory = argument.trim_prefix("--motion-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for frame in 60:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("frame-%03d.png" % frame))
		await create_timer(1.0 / 30.0).timeout


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
