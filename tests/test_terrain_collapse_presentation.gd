extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_expect(await main.start_local_match(), "Collapse HUD fixture explicitly starts solo")
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	var hud: GameplayHud = main.gameplay_hud
	var state := {
		"pending": 2,
		"region_name": "MARKET DISTRICT",
		"remaining": 9.1,
		"bounds": Rect2(-8, -6, 16, 12),
		"destroyed_count": 1,
		"stage": 2,
	}
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		hud.present_match_status(120, "SURVIVE", false)
		hud.present_major_warning("meteor", 3)
		hud.present_hazards(["FLOOD", "TORNADO"])
		hud.present_collapse(state, true, Vector3(0, 47, 0), true)
		await process_frame
		_expect(hud.terrain_card.visible and "METEOR / DISTRICT COLLAPSE" in hud.terrain_status.text and "0:10" in hud.terrain_status.text, "Pending collapse names the meteor event and rounds up its countdown")
		_expect(hud.terrain_entry.text == "LEAVE MARKED GROUND  •  FALL IS LETHAL", "An alive local player inside marked terrain gets the lethal escape instruction")
		_expect(not hud.terrain_card.get_global_rect().intersects(hud.warning_banner.get_global_rect()) and not hud.warning_banner.get_global_rect().intersects(hud.hazard_tray.get_global_rect()), "Terrain row and both hazard chips remain separate at each supported width")
		hud.present_collapse(state, true, Vector3(20, 4, 0), true)
		_expect("MARKED: MARKET DISTRICT" == hud.terrain_entry.text and "LETHAL" not in hud.terrain_entry.text, "Outside players keep district identity without a false personal danger claim")
		hud.present_collapse(state, true, Vector3.ZERO, false)
		_expect("LETHAL" not in hud.terrain_entry.text and "MARKET DISTRICT" in hud.terrain_entry.text, "Spectators never receive a personal terrain danger claim")
	hud.present_collapse(state, false)
	_expect(not hud.terrain_card.visible, "Inactive collapse hides the terrain row")
	hud.present_collapse({"pending": -1}, true)
	_expect(not hud.terrain_card.visible, "No pending district hides the terrain row")
	hud.present_lobby_overlay(true)
	hud.present_collapse(state, true, Vector3(0, 47, 0), true)
	_expect(not hud.terrain_card.visible, "Lobby suppresses collapse presentation")
	hud.present_lobby_overlay(false)
	hud.present_match_status(0, "RESULTS", true)
	hud.present_collapse(state, true, Vector3(0, 47, 0), true)
	_expect(not hud.terrain_card.visible, "Results suppress collapse presentation")
	var audio: GameplayAudioController = main.gameplay_audio
	audio.set_process(false)
	audio.reset_collapse_notices()
	audio.play_warning("flood")
	var reserved := audio._warning_voice.stream
	for stage in 4:
		audio.queue_collapse_notice(stage)
		audio.queue_collapse_notice(stage)
	audio._process(0)
	_expect(audio.collapse_notice_play_count == 0 and audio._warning_voice.stream == reserved, "Collapse cues wait behind the reserved disaster warning")
	audio._warning_voice.stop()
	for notice in 4:
		audio._process(0)
	_expect(audio.collapse_notice_play_count == 4 and audio._warning_voice.stream == reserved, "Each of four collapse stages plays once without replacing disaster audio")
	audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("TERRAIN_COLLAPSE_PRESENTATION_OK checks=%d widths=2" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
