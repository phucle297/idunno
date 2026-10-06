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
	main.match_manager.prepare_lobby()
	main._add_gameplay_demo_player(12, "Coral Player", Vector3(4, 0.05, -4))
	main._add_gameplay_demo_player(2, "Teal Player", Vector3(-3, 0.05, -2))
	main._add_gameplay_demo_player(7, "A deliberately long survivor name for truncation", Vector3(3, 0.05, 2))
	for peer_id: int in main.match_manager.players:
		main.match_manager.set_player_ready(peer_id, true)
	main.match_manager.start_match()
	var player: PartyPlayer = main.get_node("Player")
	player.set_physics_process(false)
	var hud: GameplayHud = main.gameplay_hud
	hud.set_process(false)
	main.match_manager.tick_match(127.8)
	_expect(main.match_manager.apply_damage(1, 100, "Meteor"), "Fixture must actually eliminate the local player through authoritative damage")
	main._process(0.0)
	_expect(main.match_manager.state == MatchManager.MatchState.ACTIVE and main.spectator_controller.active and main.spectator_controller.current_target_id == 2, "Death must immediately spectate the first living numeric target without ending a four-player match")
	_expect(hud.spectator_card.visible and not hud.health_card.visible and not player.visual.visible, "Spectating must replace own health presentation and eliminated visual")
	_expect(hud.elimination_label.text == "ELIMINATED — Meteor  •  SURVIVED 02:07" and hud.elimination_label.visible, "Elimination notice must use the actual cause and floored survival duration")
	_expect(hud.spectating_label.text == "Teal Player" and hud.spectator_survivors.text == "SPECTATING • 3 SURVIVORS", "Target card must name the target and show remaining eligible survivors")
	_expect(root.gui_get_focus_owner() == hud.spectator_previous and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Death must make spectator controls keyboard/controller and mouse accessible")
	_expect(is_equal_approx(hud.spectator_card.modulate.a, 0.85), "Elimination must use a bounded readable-opacity entrance")
	var snapshot: Dictionary = main._create_playable_snapshot().duplicate(true)
	for repetition: int in 20:
		main._process(0.0)
	_expect(is_equal_approx(hud._elimination_remaining, 2.5), "Repeated snapshots/presentation must not restart the notice or consume simulation time")
	hud._spectator_tween.custom_step(0.2)
	_expect(is_equal_approx(hud.spectator_card.modulate.a, 1.0), "Entrance must settle to full opacity")
	await _capture("elimination", hud)
	await _key(KEY_E)
	_expect(main.spectator_controller.current_target_id == 7, "Keyboard E must cycle to the next numeric living target")
	await _joy(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(main.spectator_controller.current_target_id == 12, "Controller RB must cycle forward")
	await _key(KEY_Q)
	_expect(main.spectator_controller.current_target_id == 7, "Keyboard Q must cycle backward")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == hud.spectator_next, "Tab must navigate between previous/next controls")
	await _joy(JOY_BUTTON_A)
	_expect(main.spectator_controller.current_target_id == 12, "Controller confirm must activate the focused NEXT button")
	await _joy(JOY_BUTTON_LEFT_SHOULDER)
	_expect(main.spectator_controller.current_target_id == 7, "Controller LB must cycle backward")
	await _capture("long-name", hud)
	hud.spectator_previous.grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(main.spectator_controller.current_target_id == 2, "Focused PREV button must cycle backward")
	if DisplayServer.get_name() != "headless":
		await _click(hud.spectator_previous)
		_expect(main.spectator_controller.current_target_id == 12, "Mouse PREV must wrap to the final target")
	main.spectator_controller._process(0.0)
	var target: Node3D = main._player_nodes[main.spectator_controller.current_target_id]
	_expect(player.camera_pivot.global_position.is_equal_approx(target.global_position + Vector3(0, 1.2, 0)), "Spectator camera must follow the selected live target")
	_expect(main._create_playable_snapshot() == snapshot, "All spectator controls must leave health, readiness, hazards, winners and match timing unchanged")
	hud._process(2.49)
	_expect(hud.elimination_label.visible, "Notice must remain readable before its timeout")
	hud._process(0.02)
	_expect(not hud.elimination_label.visible and hud.spectator_card.offset_top == -112.0, "Expired notice must collapse to the compact card")
	await _capture("compact", hud)
	hud.present_hazards(["FLOOD", "TORNADO"])
	hud.present_major_warning("tornado", 3.0)
	main.get_node("Sun").light_energy = 0.1
	main.get_node("WorldEnvironment").environment.ambient_light_energy = 0.1
	main.get_node("WorldEnvironment").environment.background_color = Color("202a38")
	await _capture("dark-overlap", hud)
	hud.reduced_motion = true
	hud.present_elimination("Meteor", 127.8)
	_expect(hud.spectator_card.modulate == Color.WHITE and hud.elimination_label.visible, "Reduced motion must preserve death information without fading")
	await _capture("reduced-motion", hud)
	main._set_lobby_visible(true)
	var previous_id: int = main.spectator_controller.current_target_id
	main._cycle_spectator(1)
	_expect(not hud.spectator_card.visible and main.spectator_controller.current_target_id == previous_id, "Lobby must suppress spectator controls and cycling without losing the target")
	main._set_lobby_visible(false)
	_expect(hud.spectator_card.visible and not hud.health_card.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Closing lobby must restore spectator card and retain accessible cursor, not own health")
	main.spectator_controller.cycle(1)
	# Remove whichever target is selected while preserving two live participants.
	var removed_id: int = main.spectator_controller.current_target_id
	var removed_node: Node = main._player_nodes[removed_id]
	main._player_nodes.erase(removed_id)
	main.match_manager.unregister_player(removed_id)
	removed_node.free()
	main._update_spectator_ui()
	_expect(main.spectator_controller.current_target_id != removed_id and hud.spectator_survivors.text == "SPECTATING • 2 SURVIVORS", "Disconnected current target must fall back immediately with updated count")
	var living_ids: Array = main._living_spectator_targets().keys()
	var final_damage: Array[Dictionary] = [
		{"peer_id": living_ids[0], "amount": 100, "cause": "Flood"},
		{"peer_id": living_ids[1], "amount": 100, "cause": "Flood"},
	]
	main.match_manager.apply_damage_batch(final_damage)
	main._process(0.0)
	_expect(main.match_manager.state == MatchManager.MatchState.RESULTS and not hud.spectator_card.visible and not hud.elimination_label.visible, "Final eliminations/results must suppress and clear stale spectator notice")
	# Explicit presentation fallbacks; an actual no-survivor match correctly shows results instead.
	main.get_node("Interface/ResultsPanel").hide()
	hud.set_spectating_visible(true)
	hud.present_vitals(0, 1, 3)
	hud.present_spectator_target("Last Survivor", 1)
	_expect(hud.spectator_previous.disabled and hud.spectator_next.disabled, "One survivor must disable meaningless cycling")
	await _capture("one-survivor", hud)
	hud.present_vitals(0, 0, 3)
	hud.present_spectator_target("", 0)
	_expect(hud.spectating_label.text == "NO SURVIVORS TO SPECTATE" and hud.spectator_previous.disabled and hud.spectator_next.disabled, "Empty targets must explicitly state no survivors and disable cycling")
	await _capture("empty-targets", hud)
	# The offline rematch contract resets its single local participant, not demo peers.
	for peer_id: int in main._player_nodes.keys():
		if peer_id != 1:
			main.match_manager.unregister_player(peer_id)
			main._player_nodes[peer_id].free()
			main._player_nodes.erase(peer_id)
	_expect(main.restart_local_match(), "Local rematch must still succeed")
	main.disaster_director.cleanup()
	main._process(0.0)
	_expect(not main.spectator_controller.active and not player.camera_pivot.top_level and not hud.spectator_card.visible and not hud.elimination_label.visible and hud.health_card.visible, "Rematch must restore camera/health and remove all elimination presentation")
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await process_frame
	if failures.is_empty():
		print("SPECTATOR_PRESENTATION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
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


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	await _settle()


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _capture(state: String, hud: GameplayHud) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await _settle()
			await RenderingServer.frame_post_draw
			var card := hud.spectator_card.get_global_rect()
			var design_rect := Rect2(24, 24, 1232, 672)
			_expect(design_rect.encloses(card), "Spectator card must stay in the 720p design safe area")
			for control: Control in [hud.spectator_previous, hud.spectator_next, hud.spectating_label, hud.spectator_survivors]:
				_expect(card.encloses(control.get_global_rect()), "Spectator card contents must not clip")
			_expect(not hud.spectating_label.get_global_rect().intersects(hud.spectator_next.get_global_rect()), "Long names must not overlap cycle controls")
			var path := argument.trim_prefix("--capture-dir=").path_join("spectator-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Spectator review capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
