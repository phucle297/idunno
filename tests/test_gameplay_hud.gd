extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
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

	hud.present_hazards(["FLOOD — REACH HIGH GROUND", "TORNADO — FIND COVER", "FIRE — AVOID BURNING ZONES"])
	_expect(hud.hazard_tray.visible, "Active hazards must show the hazard tray")
	_expect(hud.get_presented_hazards() == ["FLOOD — REACH HIGH GROUND", "TORNADO — FIND COVER"], "The hazard tray must preserve order and cap presentation at two entries")
	_expect(hud.hazard_chips[0].visible and hud.hazard_chips[1].visible, "Two active hazards must use two separate chips")
	hud.present_hazards([])
	_expect(not hud.hazard_tray.visible, "An empty hazard list must hide the hazard tray")

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
