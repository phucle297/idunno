extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var hud := main.get_node("Interface") as GameplayHud
	_expect(not hud.has_node("Title") and not hud.has_node("Help"), "The gameplay HUD must not retain permanent prototype title or control copy")

	hud.present_vitals(73.9, 3, 8)
	_expect(hud.get_presented_health() == 73, "Vitals must retain authoritative health through the HUD boundary")
	_expect(hud.get_presented_alive_counts() == Vector2i(3, 8), "Vitals must distinguish alive and total player counts")
	_expect(hud.health_bar.value == 73.9, "The health display must visualize fractional authoritative health")
	_expect(hud.health_card.anchor_top == 1.0 and hud.health_card.offset_bottom == -24.0, "The health card must remain anchored to the safe bottom edge")

	hud.present_match_status(125, "SURVIVE", false)
	_expect(hud.timer_label.text == "02:05", "Match status must format the remaining clock")
	_expect(hud.state_label.text == "SURVIVE", "Match status must present semantic state copy")
	hud.present_match_status(0, "ENTER TO REMATCH", true)
	_expect(not hud.timer_card.visible, "Results must suppress the complete timer card")

	hud.present_hazards(["FLOOD", "TORNADO", "FIRE"])
	_expect(hud.hazard_tray.visible, "Active hazards must show the hazard tray")
	_expect(hud.get_presented_hazards() == ["FLOOD", "TORNADO"], "The hazard tray must preserve order and cap presentation at two entries")
	_expect(hud.hazard_chips[0].visible and hud.hazard_chips[1].visible, "Two active hazards must use two separate chips")
	hud.present_hazards([])
	_expect(not hud.hazard_tray.visible, "An empty hazard list must hide the hazard tray")

	var warning_cases := [
		["meteor", "METEOR INCOMING", "MOVE OUT OF THE IMPACT RING"],
		["flood", "FLOOD INCOMING", "REACH HIGH GROUND"],
		["tornado", "TORNADO INCOMING", "FIND INDOOR COVER"],
		["earthquake", "EARTHQUAKE INCOMING", "AVOID BREAKING STRUCTURES"],
		["lightning", "LIGHTNING INCOMING", "LEAVE THE RING AND WATER"],
		["fire", "FIRE INCOMING", "AVOID BURNING ZONES"],
	]
	for entry: Array in warning_cases:
		hud.present_major_warning(entry[0], 2.01)
		hud.present_hazards([String(entry[0]).to_upper()])
		_expect(hud.hazard_chips[0].get_node("Content/Icon").disaster_id == entry[0], "Each compact chip must use its own hazard icon")
		_expect(hud.hazard_chips[0].get_node("Content/Text").text == String(entry[0]).to_upper(), "A persistent chip must not duplicate warning countdowns or actions")
		_expect(hud.warning_banner.visible and hud.warning_icon.disaster_id == entry[0], "Each incoming disaster must show its own icon")
		_expect(hud.warning_name.text == entry[1] and hud.warning_action.text == entry[2], "Each warning must name the hazard and give a concise action")
		_expect(hud.warning_countdown.text == "3 s", "A fractional warning must round up rather than announce an early impact")
		await _capture(entry[0])
	hud.present_major_warning("flood", 2.0)
	_expect(hud.warning_countdown.text == "2 s", "An exact countdown boundary must not gain a second")
	hud.present_major_warning("flood", 0.0)
	_expect(hud.warning_countdown.text == "1 s", "A live warning must never display zero before the phase changes")
	hud.present_major_warning("")
	_expect(not hud.warning_banner.visible and hud.hazard_tray.offset_top == 120.0, "Clearing a warning must hide the banner and restore the tray")
	main.disaster_director.cleanup()
	main.meteor_shower.start_warning(Vector3.ZERO)
	main.flood.start_warning()
	main.meteor_shower.warning_remaining = 2.8
	main.flood.warning_remaining = 1.4
	main._update_major_warning()
	_expect(hud.warning_icon.disaster_id == "flood" and hud.warning_countdown.text == "2 s", "The nearest warning must win even when later in disaster order")
	hud.present_match_status(125, "SURVIVE", false)
	hud.present_hazards(main._active_disaster_lines())
	_expect(hud.get_presented_hazards() == ["METEOR", "FLOOD"], "Incoming hazards must retain compact identity without repeating the major warning")
	await process_frame
	_expect(hud.hazard_tray.get_global_rect().position.y > hud.warning_banner.get_global_rect().end.y, "Overlap chips must stay below the full warning banner")
	await _capture("overlap")
	main.flood.warning_remaining = 2.8
	main._update_major_warning()
	_expect(hud.warning_icon.disaster_id == "meteor", "Equal countdowns must use stable priority")
	main.meteor_shower.cleanup()
	main._update_major_warning()
	_expect(hud.warning_icon.disaster_id == "flood", "An expired priority warning must hand off to the remaining warning")
	main.get_node("Interface/LobbyPanel").show()
	main._update_major_warning()
	_expect(not hud.warning_banner.visible, "The lobby must suppress the major warning")
	main.get_node("Interface/LobbyPanel").hide()
	main.match_manager.state = MatchManager.MatchState.RESULTS
	main._update_major_warning()
	_expect(not hud.warning_banner.visible, "Results must suppress incoming warnings")
	main.match_manager.state = MatchManager.MatchState.ACTIVE
	main.flood.cleanup()
	main._update_major_warning()
	_expect(not hud.warning_banner.visible, "No warning phases must leave no stale banner")

	for disaster: Node in [main.meteor_shower, main.flood, main.tornado, main.earthquake, main.lightning, main.fire]:
		disaster.set_process(false)
	main.meteor_shower.phase = MeteorShower.Phase.WARNING
	main.flood.phase = Flood.Phase.HOLDING
	main.flood.electrified_remaining = 1.5
	main.lightning.phase = Lightning.Phase.IDLE
	var before: Dictionary = main._create_playable_snapshot().duplicate(true)
	hud.present_hazards(main._active_disaster_lines())
	_expect(hud.get_presented_hazards() == ["FLOOD + LIGHTNING — ELECTRIFIED WATER", "METEOR"], "A lingering combination must precede other hazards without a duplicate Flood chip")
	_expect(main._create_playable_snapshot() == before, "Building and presenting chips must not mutate authoritative state")
	_expect(hud.hazard_chips[0].get_node("Content/Icon").disaster_id == "flood" and hud.hazard_chips[0].get_node("Content/SecondIcon").disaster_id == "lightning", "Electrified water must show both constituent icons even after the flash expires")
	hud.present_major_warning("meteor", 1.5)
	await _capture("electric-combination")
	main.flood.electrified_remaining = 0.0
	main.meteor_shower.phase = MeteorShower.Phase.IDLE
	hud.present_hazards(main._active_disaster_lines())
	_expect(hud.get_presented_hazards() == ["FLOOD"] and not hud.hazard_chips[0].get_node("Content/SecondIcon").visible, "Expiring electrification must restore the single Flood icon and clear the pair")
	main.flood.phase = Flood.Phase.IDLE
	main.tornado.phase = Tornado.Phase.ACTIVE
	main.fire.phase = Fire.Phase.WARNING
	main.fire.wind_active = true
	hud.present_hazards(main._active_disaster_lines())
	_expect(hud.get_presented_hazards() == ["TORNADO", "FIRE"], "A warned fire must not announce spreading flames before activation")
	main.fire.phase = Fire.Phase.ACTIVE
	hud.present_hazards(main._active_disaster_lines())
	_expect(hud.get_presented_hazards() == ["TORNADO + FIRE — WIND IS SPREADING FLAMES"], "Wind-driven Fire must replace both constituents with one combination chip")
	_expect(hud.hazard_chips[0].get_node("Content/Icon").disaster_id == "tornado" and hud.hazard_chips[0].get_node("Content/SecondIcon").disaster_id == "fire", "Wind-driven Fire must show both constituent icons")
	await _capture("wind-combination-warning")
	hud.present_major_warning("")
	await _capture("wind-combination")
	main.fire.wind_active = false
	hud.present_hazards(main._active_disaster_lines())
	_expect(hud.get_presented_hazards() == ["TORNADO", "FIRE"] and not hud.hazard_chips[0].get_node("Content/SecondIcon").visible, "Ending wind interaction must restore two independent identities")
	main.tornado.cleanup()
	main.fire.cleanup()
	hud.present_hazards(main._active_disaster_lines())
	_expect(not hud.hazard_tray.visible, "Cleanup must remove all persistent chips")

	hud.present_context_action("GRAB OBJECT")
	_expect(hud.context_prompt.visible and hud.get_presented_context_action() == "GRAB OBJECT", "A relevant interaction must show one contextual action")
	_expect(hud.context_prompt.anchor_bottom == 1.0 and hud.context_prompt.offset_bottom == -24.0, "The contextual action must remain anchored to the bottom safe edge")
	hud.present_context_action("")
	_expect(not hud.context_prompt.visible, "No available interaction must hide the contextual action")

	hud.present_flood_exposure(GameplayHud.FloodExposure.WADING)
	_expect((hud.get_node("FloodDanger") as Label).visible and not (hud.get_node("FloodOverlay") as ColorRect).visible, "Wading must warn without implying head submersion")
	hud.present_flood_exposure(GameplayHud.FloodExposure.SUBMERGED, 1.3)
	_expect((hud.get_node("FloodOverlay") as ColorRect).visible and "1.3 s" in (hud.get_node("FloodDanger") as Label).text, "Submersion must show the breathing grace")
	hud.present_flood_exposure(GameplayHud.FloodExposure.DROWNING, 0.0, 12.0)
	_expect("-12 HP/s" in (hud.get_node("FloodDanger") as Label).text, "Drowning must show the damage rate")
	hud.present_flood_exposure(GameplayHud.FloodExposure.SAFE)
	_expect(not (hud.get_node("FloodDanger") as Label).visible and not (hud.get_node("FloodOverlay") as ColorRect).visible, "Safe exposure must clear all flood feedback")

	hud.present_spectator_target("Teal Player")
	_expect("Teal Player" in (hud.get_node("Spectating") as Label).text, "Spectator presentation must name the selected player")
	hud.present_spectator_target("")
	_expect((hud.get_node("Spectating") as Label).text == "NO SURVIVORS TO SPECTATE", "Empty spectator targets must have explicit fallback copy")

	main.gameplay_audio.reset_for_match()
	await process_frame
	main.free()
	await process_frame
	if failures.is_empty():
		print("GAMEPLAY_HUD_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await process_frame
			await RenderingServer.frame_post_draw
			for chip: PanelContainer in root.get_node("Main/Interface").hazard_chips:
				if chip.visible:
					_expect(chip.get_global_rect().encloses(chip.get_node("Content").get_global_rect()), "Chip icons and copy must fit inside their panel")
			var path := argument.trim_prefix("--capture-dir=").path_join("warning-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "The warning review capture must save successfully")
