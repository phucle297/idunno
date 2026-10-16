extends SceneTree

var checks := 0
var failures: Array[String] = []
var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY, "Normal launch waits in preparation, not solo gameplay")
	_expect(panel.is_visible_in_tree() and player.local_input_blocked, "Startup menu is visible and blocks movement")
	_expect(not main.disaster_director.running and main.match_manager.elapsed_time == 0, "No timer or disasters run before choosing play")
	_expect(panel.get_node("Start").text == "PLAY SOLO" and panel.get_node("Host").visible and panel.get_node("Join").visible, "Solo and multiplayer choices are available")
	_expect(panel.get_node("MapSelect").visible and panel.get_node("PresetSelect").visible, "Map and mode selectors are available before starting")
	_expect(panel.get_node("PresetSelect") in main._lobby_focus_controls(), "Keyboard/controller focus reaches match mode")
	main._set_lobby_visible(false)
	_expect(panel.visible, "Dismiss cannot bypass preparation into a non-running world")
	await _capture("startup")
	main.room_client.service_url = "" # Offline equipment must not require HTTP.
	panel.get_node("Collection").pressed.emit()
	await process_frame
	_expect(main.collection.visible and main.collection.lobby, "Outfit chooser opens in equippable lobby state")
	main.collection.select_outfit("cap")
	main.collection.equip_button.pressed.emit()
	_expect(main.get_outfit_id() == "cap" and player.character.get_outfit_id() == "cap", "Acknowledged starter equip changes the actual player")
	main._update_lobby_ui()
	_expect(player.local_input_blocked, "Collection retains movement blocking during UI refresh")
	await _capture("outfit-equipped")
	main.collection.dismiss()
	panel.get_node("MapSelect").item_selected.emit(main.MAP_IDS.find("toy_harbor"))
	panel.get_node("PresetSelect").item_selected.emit(1)
	_expect(main.get_map_id() == "toy_harbor" and main.get_match_preset() == main.MATCH_PRESETS[1], "Menu choices update authoritative map and match preset")
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY and not main.disaster_director.running, "Changing map and mode never starts a round")
	await _capture("map-mode-selected")
	panel.get_node("Start").pressed.emit()
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE and main.disaster_director.running, "Solo button explicitly starts match and director")
	_expect(not panel.visible and not player.local_input_blocked, "Start closes menu and releases gameplay input")
	_expect(player.character.get_outfit_id() == "cap" and main.get_map_id() == "toy_harbor", "Selected outfit and map survive the start boundary")
	main.disaster_director.cleanup()
	main.match_manager.apply_damage(1, 100, "Menu regression")
	_expect(main.return_to_lobby(), "Results can return to preparation")
	main.request_outfit(original_outfit)
	_expect(main.get_outfit_id() == original_outfit, "Restore original saved starter after test")
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
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
	var directory := "res://.amp/in/artifacts/character-menu"
	if "--1080p" in OS.get_cmdline_user_args():
		directory = directory.path_join("1080p")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.get_texture().get_image().save_png(directory.path_join(state + ".png"))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
