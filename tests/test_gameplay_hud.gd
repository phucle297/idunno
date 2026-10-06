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

	hud.present_vitals(73.9, 3, 8)
	_expect((hud.get_node("Health") as Label).text == "HP  73", "Vitals must format authoritative health through the HUD boundary")
	_expect((hud.get_node("Alive") as Label).text == "ALIVE  3 / 8", "Vitals must distinguish alive and total player counts")

	hud.present_match_status(125, "SURVIVE", false, true)
	_expect((hud.get_node("Timer") as Label).text == "02:05", "Match status must format the remaining clock")
	_expect((hud.get_node("State") as Label).text == "SURVIVE", "Match status must present semantic state copy")
	_expect((hud.get_node("Help") as Label).visible, "Active-player controls must remain visible when requested")
	hud.present_match_status(0, "ENTER TO REMATCH", true, false)
	_expect(not (hud.get_node("Timer") as Label).visible and not (hud.get_node("State") as Label).visible, "Results must suppress match status")
	_expect(not (hud.get_node("Help") as Label).visible, "Non-gameplay states must suppress controls")

	hud.present_hazards(["FLOOD — REACH HIGH GROUND", "TORNADO — FIND COVER"])
	_expect((hud.get_node("MeteorWarning") as Label).visible, "Active hazards must show the hazard channel")
	_expect((hud.get_node("MeteorWarning") as Label).text.count("\n") == 1, "Two hazards must remain separate readable lines")
	hud.present_hazards([])
	_expect(not (hud.get_node("MeteorWarning") as Label).visible, "An empty hazard list must hide the hazard channel")

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
