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
	main.disaster_director.cleanup()
	var player := main.get_node("Player") as PartyPlayer
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var hud := main.get_node("Interface") as GameplayHud
	var shared_theme: Theme = main.get_node("Interface/LobbyToggle").theme
	for child: Node in hud.get_children():
		if child is Control:
			_expect(child.theme == shared_theme, "Every top-level UI control must use the same theme resource: %s" % child.name)
	_expect(not hud.has_node("Title") and not hud.has_node("Help"), "Permanent prototype copy must be absent")
	var before: Dictionary = main._create_playable_snapshot().duplicate(true)
	hud.present_vitals(17.25, 1, 20)
	hud.present_match_status(601, "SURVIVE", false)
	hud.present_hazards(["FLOOD", "TORNADO", "FIRE"])
	hud.present_context_action("RELEASE TO RESTORE SPEED")
	_expect(main._create_playable_snapshot() == before, "HUD presentation must not mutate authoritative match, health, or disaster state")
	_expect(hud.timer_label.text == "10:01" and hud.alive_label.text == "1 / 20", "Clock and survivor values must remain distinct and correctly formatted")
	hud.present_hazards(["FLOOD"])
	_expect(hud.hazard_chips[0].visible and not hud.hazard_chips[1].visible, "Two-to-one hazard transition must clear the stale second chip")
	var returned_lines := hud.get_presented_hazards()
	returned_lines.clear()
	_expect(hud.get_presented_hazards().size() == 1, "HUD state must not expose a mutable hazard array")
	for entry: Array in [[-3.0, 0.0], [0.0, 0.0], [100.0, 100.0], [105.0, 100.0]]:
		hud.present_vitals(entry[0], 20, 20)
		_expect(hud.health_bar.value == entry[1], "Health visualization must respect both bar boundaries")

	var grab_manager := main.get_node("GrabManager") as GrabManager
	var crate := main.get_node("Sandbox/PhysicsCrate") as RigidBody3D
	crate.freeze = true
	crate.global_position = player.get_grab_origin() + player.get_grab_direction()
	main._update_context_prompt(1)
	_expect(hud.get_presented_context_action() == "GRAB — CARRY SLOWS YOU 25%", "An eligible unowned prop must show acquisition and the carry tradeoff")
	_expect(grab_manager.request_grab(1, crate), "The fixture must actually grab the eligible prop")
	main._update_context_prompt(1)
	_expect(hud.get_presented_context_action() == "RELEASE TO RESTORE SPEED", "A held prop must show release/restored speed")
	main.get_node("Interface/LobbyPanel").show()
	main._update_context_prompt(1)
	_expect(not hud.context_prompt.visible, "Lobby must suppress the context prompt even with a held prop")
	main.get_node("Interface/LobbyPanel").hide()
	main.match_manager.state = MatchManager.MatchState.RESULTS
	main._update_context_prompt(1)
	_expect(not hud.context_prompt.visible, "Results must suppress the context prompt")
	main.match_manager.state = MatchManager.MatchState.ACTIVE
	main.spectator_controller.active = true
	main._update_context_prompt(1)
	_expect(not hud.context_prompt.visible, "Spectating must suppress the context prompt")
	main.spectator_controller.active = false
	grab_manager.release_grab(1)
	player.set_eliminated(true)
	main._update_context_prompt(1)
	_expect(not hud.context_prompt.visible, "An eliminated player must not be offered a grab action")
	player.set_eliminated(false)
	crate.global_position = Vector3(30, 0.5, 30)
	main._update_context_prompt(1)
	_expect(not hud.context_prompt.visible, "No eligible nearby object must leave no context prompt")

	hud.present_vitals(73.9, 20, 20)
	hud.present_match_status(125, "SURVIVE", false)
	hud.present_hazards(["FLOOD", "TORNADO"])
	player.camera_pivot.rotation = Vector3(-0.14, 0.35, 0.0)
	for dark: bool in [false, true]:
		var environment: Environment = main.get_node("WorldEnvironment").environment
		environment.background_color = Color("202a38") if dark else Color("9fc8df")
		environment.ambient_light_energy = 0.1 if dark else 0.5
		main.get_node("Sun").light_energy = 0.1 if dark else 1.0
		hud.present_context_action("RELEASE TO RESTORE SPEED")
		await process_frame
		_check_layout(hud)
		await _capture("dark" if dark else "light")
	hud.present_context_action("")
	hud.present_hazards([])
	await process_frame
	_expect(not hud.hazard_tray.visible and not hud.context_prompt.visible, "Empty context and hazard states must remove their panels")
	await _capture("empty")
	main.match_manager.prepare_lobby()
	main._update_lobby_ui()
	# Expose the disabled start control only to inspect its shared-theme style offline.
	var start_button := main.get_node("Interface/LobbyPanel/Start") as Button
	main._set_lobby_visible(true)
	start_button.show()
	start_button.disabled = true
	_expect(start_button.disabled, "The explicit disabled fixture must show the shared button style; solo Start is normally enabled")
	await process_frame
	_expect(root.gui_get_focus_owner() == main.get_node("Interface/LobbyPanel/RoomId"), "Lobby opening must provide keyboard field focus")
	await _capture("lobby-focus")
	main.get_node("Interface/LobbyPanel/Host").grab_focus()
	await process_frame
	_expect(root.gui_get_focus_owner() == main.get_node("Interface/LobbyPanel/Host"), "Buttons must support visible keyboard focus")
	await _capture("button-focus")
	main.get_node("Interface/LobbyToggle").pressed.emit()
	_expect(not main.get_node("Interface/LobbyPanel").visible, "The persistent lobby button must actually close the lobby")
	main.get_node("Interface/LobbyToggle").pressed.emit()
	await process_frame
	_expect(main.get_node("Interface/LobbyPanel").visible and root.gui_get_focus_owner() == main.get_node("Interface/LobbyPanel/RoomId"), "The persistent lobby button must reopen the lobby and restore field focus")
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	if failures.is_empty():
		print("MILESTONE_1_1_OK checks=%d resolution=%dx%d" % [checks, root.size.x, root.size.y])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _check_layout(hud: GameplayHud) -> void:
	# Canvas stretching keeps all control geometry in the 1280x720 design space.
	var safe := Rect2(24, 24, 1232, 672)
	var panels: Array[Control] = [hud.health_card, hud.timer_card, hud.get_node("AlivePill"), hud.hazard_tray, hud.context_prompt]
	for index: int in panels.size():
		var panel := panels[index]
		_expect(safe.encloses(panel.get_global_rect()), "HUD panel must remain inside the safe area: %s" % panel.name)
		for other: int in range(index + 1, panels.size()):
			_expect(not panel.get_global_rect().intersects(panels[other].get_global_rect()), "HUD panels must not overlap: %s / %s" % [panel.name, panels[other].name])
	for label: Label in [hud.health_label, hud.timer_label, hud.state_label, hud.alive_label, hud.context_action_label, hud.hazard_chips[0].get_node("Content/Text"), hud.hazard_chips[1].get_node("Content/Text")]:
		_expect(label.size.x >= label.get_minimum_size().x, "HUD copy must not be horizontally clipped: %s" % label.text)


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("milestone-1-1-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Milestone capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
