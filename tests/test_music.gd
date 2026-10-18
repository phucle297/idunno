extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var music := PartyMusicController.new()
	root.add_child(music)
	await process_frame
	music.set_process(false)
	_expect(AudioServer.get_bus_index("Music") >= 0, "Music bus exists even without presentation")
	for stream: AudioStreamWAV in [PartyMusicController.MENU_STREAM, PartyMusicController.GAMEPLAY_STREAM]:
		_expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(stream.get_length(), 32.0), "Both imported original themes are 32-second loops")
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		_expect(music.get_child_count() == 0, "Headless/dedicated controller creates no music players")
		music.set_context(true)
		music.set_warning_active(true)
		music.stop()
	else:
		_expect(music.context == "menu" and music.get_child_count() == 2, "Graphical ready starts menu with exactly two bounded voices")
		var first: AudioStreamPlayer = music.get_child(0)
		var second: AudioStreamPlayer = music.get_child(1)
		_expect(first.playing and not second.playing, "Menu playback starts on one voice")
		music.set_context(false)
		_expect(first.playing and not second.playing, "Repeated menu context does not restart or allocate playback")
		music.set_context(true)
		music._process(0.15)
		_expect(music.context == "gameplay" and first.playing and second.playing and music.get_child_count() == 2, "Context switch crossfades using the bounded voice pair")
		music.set_warning_active(true)
		music._process(0.3)
		_expect(second.volume_db < -20.0, "Warning promptly ducks the active incoming music")
		music.set_warning_active(false)
		music._process(1.2)
		_expect(second.playing and not first.playing and second.volume_db > -20.0, "Crossfade stops old voice and warning release restores level")
		for rematch in 5:
			music.set_context(false)
			music._process(0.4)
			var before := Vector2(first.volume_db, second.volume_db)
			music.set_context(true)
			music._process(0.0)
			_expect(before.is_equal_approx(Vector2(first.volume_db, second.volume_db)), "Interrupted transition retains both current volumes")
			music._process(1.0)
			_expect(music.get_child_count() == 2 and second.playing and not first.playing, "Rematches reuse two voices and stop the outgoing theme")
		second.seek(31.95)
		await create_timer(0.2).timeout
		_expect(second.playing and second.get_playback_position() < 1.0, "Imported gameplay music wraps at its loop endpoint")
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
		_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music bus remains independently mute-compatible")
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
		music.stop()
		_expect(not first.playing and not second.playing, "Stop ends both voices without allocating replacements")
	music.free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("MUSIC_OK checks=%d graphical=%s" % [checks, str(DisplayServer.get_name() != "headless")])
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
