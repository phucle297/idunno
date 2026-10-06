extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sound_paths := [
		"res://assets/audio/generated/warning.wav",
		"res://assets/audio/generated/impact.wav",
		"res://assets/audio/generated/jump.wav",
		"res://assets/audio/generated/death.wav",
		"res://assets/audio/generated/victory.wav",
		"res://assets/audio/generated/flood_warning.wav",
		"res://assets/audio/generated/meteor_warning.wav",
		"res://assets/audio/generated/tornado_warning.wav",
	]
	for sound_path: String in sound_paths:
		var stream := load(sound_path) as AudioStream
		_expect(stream != null, "%s must import as an AudioStream" % sound_path)
		_expect(stream != null and stream.get_length() >= 0.2, "%s must contain audible-duration samples" % sound_path)

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var audio := main.get_node("GameplayAudio") as GameplayAudioController
	_expect(audio.get_child_count() == 5, "Audio must use one reserved warning voice and four capped effect voices")
	audio.play_warning("meteor")
	var reserved_stream := audio._warning_voice.stream
	for effect_index: int in 8:
		audio.play_effect(load("res://assets/audio/generated/impact.wav"))
	_expect(audio.warning_voice_is_reserved(), "Effect overlap must not take the dedicated warning voice")
	_expect(audio._warning_voice.stream == reserved_stream, "Effect overlap must preserve the active warning stream")
	_expect(audio.effect_play_count == 8, "Effect pool must accept overlap through bounded voice reuse")
	audio.play_warning_countdown()
	_expect(audio._effect_voices[0].volume_db == -16.0, "Countdown cue must remain quieter than the dedicated warning voice")
	for effect_index: int in 4:
		audio.play_effect(load("res://assets/audio/generated/impact.wav"))
	_expect(audio._effect_voices[0].volume_db == -7.0, "Reused countdown voice must restore the normal effect volume")
	_expect(audio._warning_voice.stream == reserved_stream and audio.get_child_count() == 5, "Countdown audio must not replace warning audio or expand the voice pool")

	var meteor := main.get_node("MeteorShower") as MeteorShower
	var warning_count := audio.warning_play_count
	_expect(meteor.start_warning(Vector3.ZERO), "Representative Meteor warning must start")
	await process_frame
	_expect(audio.warning_play_count == warning_count + 1 and audio.active_warning_name == "meteor", "Hazard warning transition must select its synthesized cue")
	meteor.tick(meteor.warning_duration)
	await process_frame
	_expect(audio.effect_play_count >= 9, "Hazard activation must play an impact cue")

	var manager := main.get_node("MatchManager") as MatchManager
	_expect(manager.apply_damage(1, 100.0, "Phase 7 Test"), "Lethal result setup must apply")
	await process_frame
	var results_panel := main.get_node("Interface/ResultsPanel") as Panel
	var row: HBoxContainer = main.get_node("Interface/ResultsPanel/Table").rows[1]
	_expect(results_panel.visible, "Results panel must become visible when the match finishes")
	_expect(row.get_node("Name").text == "Local Player", "Results must identify the player")
	_expect(row.get_node("Outcome").text == "Phase 7 Test", "Results must show cause of death")
	_expect(row.get_node("Damage").text == "100" and row.get_node("Time").text == "00:00", "Results must show damage and survival duration")
	_expect((main.get_node("Interface/ResultsPanel/Prompt") as Label).text == "PRESS ENTER TO REMATCH", "Offline results must explain rematch input")
	_expect(main.restart_local_match(), "Offline rematch must restart from complete results")
	await process_frame
	_expect(manager.state == MatchManager.MatchState.ACTIVE and not results_panel.visible, "Rematch must restore active play and hide results")
	audio.reset_for_match()
	main.free()
	await process_frame

	if failures.is_empty():
		print("PHASE7_POLISH_OK checks=%d sounds=%d voices=5" % [checks, sound_paths.size()])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
