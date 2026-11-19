extends SceneTree

# T24: the online (host) jump path follows the same focus rule as the offline
# jump cue. Space on a focused control is a UI confirm, not a jump: no jump cue
# and no jump. With no focused control, one Space = one jump = one jump cue,
# and shove still gives its one cue (parity with other action cues).

const WINDOW_FRAMES := 24

var checks := 0
var failures: Array[String] = []
var _state := {}
var starts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _scan() -> void:
	for player: AudioStreamPlayer in root.find_children("*", "AudioStreamPlayer", true, false):
		var key := player.get_instance_id()
		var prev: Dictionary = _state.get(key, {"playing": false, "stream": null, "pos": 0.0})
		var pos: float = player.get_playback_position() if player.playing else 0.0
		if player.playing and (not prev.playing or prev.stream != player.stream or pos + 0.001 < prev.pos):
			starts.append({"stream": player.stream, "bus": String(player.bus)})
		_state[key] = {"playing": player.playing, "stream": player.stream, "pos": pos}


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
		_scan()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _jump_cues() -> int:
	return starts.filter(func(s: Dictionary) -> bool: return s.bus == "Effects" and s.stream == GameplayAudioController.JumpSound).size()


# Returns [jump cues, highest vertical velocity seen] for one Space press.
func _press_space(actor: PartyPlayer) -> Array:
	starts.clear()
	var peak := -INF
	_key(KEY_SPACE, true)
	for index in 3:
		await _frames(1)
		peak = maxf(peak, actor.velocity.y)
	_key(KEY_SPACE, false)
	for index in WINDOW_FRAMES:
		await _frames(1)
		peak = maxf(peak, actor.velocity.y)
	return [_jump_cues(), peak]


func _wait_grounded(actor: PartyPlayer) -> void:
	for index in 180:
		if actor.is_on_floor() and absf(actor.velocity.y) < 0.01:
			break
		await _frames(1)
	await _frames(WINDOW_FRAMES)


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	_expect(main.host_game(0, 4) == OK, "Host starts an online session")
	_expect(main._network_mode and main.multiplayer.is_server(), "Online host mode")
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	main.disaster_director.cleanup()
	main.match_manager.state = MatchManager.MatchState.ACTIVE
	main._set_lobby_visible(false)
	if is_instance_valid(main.home_screen):
		main.home_screen.hide()
	var actor := main._player_nodes.get(1) as PartyPlayer
	_expect(is_instance_valid(actor), "Host avatar exists")
	actor.local_input_blocked = false
	actor.world_loaded = true
	main.gameplay_audio.reset_for_match()
	await _frames(60)
	# A focused control during the ACTIVE online match (e.g. a lingering button).
	var probe := Button.new()
	probe.text = "T24 probe"
	probe.focus_mode = Control.FOCUS_ALL
	main.get_node("Interface").add_child(probe)
	var confirms := [0]
	probe.pressed.connect(func() -> void: confirms[0] += 1)
	for case: String in ["focused", "unfocused", "focused", "unfocused"]:
		await _wait_grounded(actor)
		main.gameplay_audio.reset_for_match()
		if case == "focused":
			probe.grab_focus()
		else:
			root.gui_release_focus()
		await _frames(2)
		var confirms_before: int = confirms[0]
		var result := await _press_space(actor)
		print("T24_ONLINE_JUMP case=%s jump_cues=%d peak_vy=%.2f confirms=%d" % [case, result[0], result[1], confirms[0] - confirms_before])
		if case == "focused":
			_expect(confirms[0] - confirms_before == 1, "focused: Space confirms the control once")
			_expect(result[0] == 0, "focused: no jump cue (got %d)" % result[0])
			_expect(result[1] < 1.0, "focused: avatar does not jump (peak vy %.2f)" % result[1])
		else:
			_expect(result[0] == 1, "unfocused: exactly one jump cue (got %d)" % result[0])
			_expect(result[1] > 1.0, "unfocused: avatar jumps (peak vy %.2f)" % result[1])
	# Parity: with no focus the shove cue fires too (one per press).
	root.gui_release_focus()
	await _wait_grounded(actor)
	main.gameplay_audio.reset_for_match()
	var shoves_before: int = main.gameplay_audio.shove_play_count
	_key(KEY_G, true)
	await _frames(3)
	_key(KEY_G, false)
	await _frames(WINDOW_FRAMES)
	_expect(main.gameplay_audio.shove_play_count - shoves_before == 1, "unfocused: shove gives one cue online")
	probe.queue_free()
	main.multiplayer.multiplayer_peer.close()
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		print("T24_FAIL %s" % failure)
		push_error(failure)
	if failures.is_empty():
		print("ONLINE_JUMP_CUE_FOCUS_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
