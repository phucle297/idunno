extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	var panel: Panel = main.get_node("Interface/LobbyPanel")
	var hud: GameplayHud = main.gameplay_hud
	var snapshot: Dictionary = main._create_playable_snapshot().duplicate(true)
	hud.present_hazards(["FLOOD"])
	main._set_lobby_visible(true)
	await _settle()
	_expect(main._create_playable_snapshot() == snapshot, "Opening the lobby must not mutate gameplay state")
	_expect(main.get_node("Interface/LobbyBackdrop").visible and not hud.health_card.visible and not hud.timer_card.visible and not hud.get_node("AlivePill").visible and not hud.hazard_tray.visible, "Lobby must dim the world and suppress every gameplay metric/hazard card")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.local_input_blocked, "Opening lobby must release the cursor and block local gameplay input")
	_expect(panel.get_node("AddressLabel").text == "HOST IP ADDRESS" and panel.get_node("PortLabel").text == "UDP PORT", "Connection fields must have persistent labels")
	_expect(root.gui_get_focus_owner() == panel.get_node("Address"), "Offline lobby must focus address first")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == panel.get_node("Port"), "Tab must move from address to port")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_expect(root.gui_get_focus_owner() == panel.get_node("Host"), "Controller navigation must leave a field, not edit its caret")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == panel.get_node("Join"), "Tab must reach JOIN")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == panel.get_node("PlayerList"), "Offline focus must skip hidden ready/start controls")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(root.gui_get_focus_owner() == panel.get_node("Close"), "Controller right must reach CLOSE from roster")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == panel.get_node("Address"), "Focus must wrap inside the lobby, never into the underlying HUD")
	await _capture("offline")
	for value: String in ["0", "65536", "abc"]:
		panel.get_node("Port").text = value
		main._on_lobby_host_pressed()
		_expect(not main.is_network_session() and main._create_playable_snapshot() == snapshot, "Invalid port must not start a session or reset gameplay")
		_expect("valid UDP port" in panel.get_node("Status").text and root.gui_get_focus_owner() == panel.get_node("Port"), "Invalid port must explain the range and focus the field")
	panel.get_node("Port").text = "29730"
	panel.get_node("Address").text = "  "
	main._on_lobby_join_pressed()
	_expect(main._create_playable_snapshot() == snapshot and "host IP" in panel.get_node("Status").text, "Empty address must fail before removing the offline player")
	await _capture("field-error")
	panel.get_node("Address").text = "127.0.0.1"
	main.match_manager.prepare_lobby()
	_expect(main.host_game(0) == OK, "Host fixture must bind an ephemeral port")
	main._update_lobby_ui()
	await _settle()
	_expect(not panel.get_node("Address").editable and not panel.get_node("Port").editable and not panel.get_node("Host").visible and not panel.get_node("Join").visible, "Connected sessions must lock connection fields and hide create/join")
	_expect(panel.get_node("Start").visible and panel.get_node("Start").disabled and "at least 2" in panel.get_node("Status").text, "A solo host must see why starting is unavailable")
	_expect(root.gui_get_focus_owner() == panel.get_node("Ready"), "Host focus must skip locked fields")
	main.match_manager.register_player(2, "Teal Player")
	main.match_manager.register_player(3, "Coral Player")
	main.match_manager.register_player(4, "Amber Player")
	main.match_manager.set_player_ready(2, true)
	main.match_manager.set_player_ready(3, true)
	main._update_lobby_ui()
	_expect(panel.get_node("Start").disabled and "Waiting for all" in panel.get_node("Status").text, "Partially ready roster must not enable host start")
	_expect(not main.start_network_match(), "The authoritative start method must still reject an unready roster")
	await _joy(JOY_BUTTON_A)
	main._update_lobby_ui()
	_expect(main.match_manager.is_player_ready(1) and panel.get_node("Ready").text == "UNREADY", "Controller confirm must toggle actual host readiness")
	_expect(not main.match_manager.is_player_ready(4) and panel.get_node("Start").disabled, "Readiness toggle must affect only the local player")
	await _capture("host-waiting")
	main.match_manager.set_player_ready(4, true)
	main._update_lobby_ui()
	_expect(not panel.get_node("Start").disabled and "host can start" in panel.get_node("Status").text, "All-ready roster must explicitly enable host start")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == panel.get_node("Start"), "Newly enabled START must enter focus order")
	await _capture("host-ready")
	var before: Dictionary = main._create_playable_snapshot().duplicate(true)
	main._update_lobby_ui()
	_expect(main._create_playable_snapshot() == before, "Repeated presentation must preserve readiness/health/hazard authority")
	await _joy(JOY_BUTTON_A)
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE and not panel.visible, "Controller confirm on START must use the authoritative start path and close lobby")
	main.disaster_director.cleanup()
	main._set_lobby_visible(true)
	main.match_manager.tick_match(0.25)
	_expect(is_equal_approx(main.match_manager.elapsed_time, 0.25) and not paused, "Open lobby must not pause authoritative simulation")
	Input.action_press("move_right")
	main._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_expect(main._movement_inputs[1].direction == Vector2.ZERO, "Open lobby must submit neutral local movement while physics continues")
	await _key(KEY_ESCAPE)
	_expect(not panel.visible and not main.get_node("Interface/LobbyBackdrop").visible and not player.local_input_blocked and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "Escape must close lobby and restore cursor/input (cursor capture requires a display)")
	_expect(hud.health_card.visible and hud.timer_card.visible and hud.get_node("AlivePill").visible, "Closing active lobby must restore gameplay metrics")
	main._set_lobby_visible(true)
	panel.get_node("Close").grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(not panel.visible, "Controller confirm on CLOSE must dismiss lobby")
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	_finish()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	await _settle()


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	await _settle()


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("lobby-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Lobby review capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("LOBBY_PRESENTATION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
