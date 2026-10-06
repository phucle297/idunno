extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.disaster_director.cleanup()
	main.get_node("Player").set_physics_process(false)
	var saved_name: String = main.match_manager.players[1].name
	main.match_manager.players[1].name = "Host"
	_expect(main.match_manager.create_authoritative_snapshot().player_names.is_empty(), "An entirely default roster must omit name entries rather than inflate every snapshot")
	main.match_manager.players[1].name = saved_name
	main.match_manager.tick_match(main.match_manager.match_duration)
	main._process(0.0)
	_expect(main.get_node("Player").local_input_blocked, "Surviving winners must not keep gameplay input active beneath results")
	var hud: GameplayHud = main.gameplay_hud
	for control: Control in [hud.health_card, hud.get_node("AlivePill"), hud.timer_card, hud.hazard_tray, hud.context_prompt, hud.personal_danger, hud.warning_banner, hud.spectator_card]:
		_expect(not control.visible, "Every gameplay HUD component must be hidden in results: %s" % control.name)
	var panel: Panel = main.get_node("Interface/ResultsPanel")
	_expect(panel.has_node("Actions/Rematch") and panel.has_node("Actions/Lobby"), "Results must expose actionable rematch and return-to-lobby buttons")
	if not panel.has_node("Actions/Rematch"):
		main.free()
		_finish()
		return
	var rematch: Button = panel.get_node("Actions/Rematch")
	var lobby: Button = panel.get_node("Actions/Lobby")
	_expect(rematch.visible and lobby.visible and not rematch.disabled and not lobby.disabled, "Solo results must enable both actions")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Results must release the cursor even for a surviving winner")
	await _settle()
	var table: VBoxContainer = panel.get_node("Table")
	_expect(table.scroll.has_focus(), "Results must initially focus the scrollable rankings")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await _settle()
	_expect(rematch.has_focus(), "Tab must leave rankings for Rematch")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	root.push_input(right)
	await _settle()
	_expect(lobby.has_focus(), "Controller right must reach Return to Lobby")
	for control: Control in [rematch, lobby]:
		_expect(panel.get_global_rect().encloses(control.get_global_rect()) and not table.get_global_rect().intersects(control.get_global_rect()), "Results actions must fit without overlapping rankings")
	await _capture("solo")
	rematch.grab_focus()
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	root.push_input(confirm)
	await _settle()
	main._process(0.0)
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE and not panel.visible and hud.health_card.visible and hud.get_node("AlivePill").visible, "Rematch button must restore gameplay and its HUD")
	_expect(DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Rematch must recapture the cursor when a display is available")
	_expect(not main.return_to_lobby(), "Return to Lobby must reject ACTIVE state")
	main.disaster_director.cleanup()
	main.match_manager.apply_damage(1, 100.0, "Second result")
	lobby.pressed.emit()
	main._process(0.0)
	_expect(main.match_manager.state == MatchManager.MatchState.LOBBY and main.get_node("Interface/LobbyPanel").visible and not panel.visible, "Return to Lobby must stop at an accessible lobby, not auto-start")
	_expect(not main.disaster_director.running and not main.spectator_controller.active and main.match_manager.get_health(1) == 100.0 and not main.match_manager.is_player_ready(1), "Returning must clean hazards, spectating, health and readiness")
	_expect(main.get_node("Player").visual.visible and not hud.health_card.visible, "Lobby must reset the player while suppressing gameplay HUD")
	var start: Button = main.get_node("Interface/LobbyPanel/Start")
	_expect(start.visible and not start.disabled, "Solo return lobby must provide a way back into play")
	start.pressed.emit()
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE, "Solo lobby Start must resume a fresh match")
	main.disaster_director.cleanup()
	main.match_manager.apply_damage(1, 100.0, "Client fixture")
	# Real non-server ENet peer: authority checks must reject calls, not just hide buttons.
	var peer := ENetMultiplayerPeer.new()
	_expect(peer.create_client("127.0.0.1", 29989) == OK, "Client authority fixture must initialize")
	root.multiplayer.multiplayer_peer = peer
	main._network_mode = true
	main._network_role = "client"
	var no_winners: Array[int] = []
	main._on_match_finished(no_winners)
	main._process(0.0)
	var before: Dictionary = main.match_manager.create_authoritative_snapshot().duplicate(true)
	var original_name: String = main.match_manager.players[1].name
	main.match_manager.apply_authoritative_snapshot(before)
	_expect(main.match_manager.players[1].name == original_name, "Replicated results must preserve authoritative player names, including UI-created hosts")
	var malformed := before.duplicate(true)
	malformed.player_names = PackedStringArray(["First", "Extra"])
	_expect(not main.match_manager.apply_authoritative_snapshot(malformed), "Name array length must be validated before mutating client records")
	_expect(not rematch.visible and not lobby.visible, "Clients must not see host-owned results actions")
	_expect(not main.restart_network_match() and not main.return_to_lobby() and before == main.match_manager.create_authoritative_snapshot(), "Client calls must not mutate results or readiness")
	var terminal: Dictionary = main._create_playable_snapshot()
	terminal.match_sequence = 2
	main._apply_match_snapshot(terminal)
	var stale := terminal.duplicate(true)
	stale.match_sequence = 1
	stale.state = MatchManager.MatchState.ACTIVE
	main._apply_match_snapshot(stale)
	_expect(main.match_manager.state == MatchManager.MatchState.RESULTS, "An older live snapshot must not roll back newer reliable results")
	stale.match_sequence = 3
	main._apply_match_snapshot(stale)
	main._apply_session_snapshot(terminal)
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE, "Delayed reliable results must not reopen a completed round after rematch")
	terminal.match_sequence = 4
	main._apply_session_snapshot(terminal)
	await _settle()
	await _capture("client-waiting")
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()
	main._network_mode = false
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	_finish()


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("results-actions-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Results actions capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RESULTS_ACTIONS_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
