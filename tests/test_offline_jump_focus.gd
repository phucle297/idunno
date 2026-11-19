extends SceneTree

# T35: offline (solo), Space on a focused control is a UI confirm only: no jump
# and no jump cue (same shared focus gate as T24 online). With nothing focused,
# one Space = one jump = one jump cue. Driven through real InputEventKey events.
# T36: jumps are counted as takeoff impulses (expect 0 / 1), and the focused
# control is the real in-match ROOM MENU button (Interface/LobbyToggle) from
# scenes/main.tscn, the control main.gd itself hands focus to.

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
			starts.append({"stream": player.stream, "bus": String(player.bus), "db": player.volume_db})
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


# The real menu button's UI confirm reuses JumpSound at UI_CONFIRM_DB; the jump
# cue is JumpSound at JUMP_DB.
func _jump_cues() -> int:
	return starts.filter(func(s: Dictionary) -> bool: return s.bus == "Effects" and s.stream == GameplayAudioController.JumpSound and is_equal_approx(float(s.db), GameplayAudioController.JUMP_DB)).size()


func _ui_confirm_cues() -> int:
	return starts.filter(func(s: Dictionary) -> bool: return s.bus == "Effects" and s.stream == GameplayAudioController.JumpSound and is_equal_approx(float(s.db), GameplayAudioController.UI_CONFIRM_DB)).size()


# A takeoff: vertical speed rises by more than half a jump impulse between two
# samples (gravity only lowers it; landing only zeroes it).
const JUMP_IMPULSE := sqrt(2.0 * PlayerTuning.GRAVITY * PlayerTuning.JUMP_HEIGHT)


# Returns [jump cues, jumps (takeoffs), highest vertical velocity seen] for one Space press.
func _press_space(actor: PartyPlayer) -> Array:
	starts.clear()
	var peak := -INF
	var jumps := 0
	var previous := actor.velocity.y
	for step in 3 + WINDOW_FRAMES:
		if step == 0:
			_key(KEY_SPACE, true)
		elif step == 3:
			_key(KEY_SPACE, false)
		await _frames(1)
		if actor.velocity.y - previous > JUMP_IMPULSE * 0.5:
			jumps += 1
		previous = actor.velocity.y
		peak = maxf(peak, actor.velocity.y)
	return [_jump_cues(), jumps, peak]


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
	_expect(await main.start_local_match(), "Solo match starts")
	_expect(not main._network_mode, "Offline mode")
	main.set_map_id("toy_town")
	await main.prepare_gameplay_map()
	main.disaster_director.cleanup()
	main.match_manager.state = MatchManager.MatchState.ACTIVE
	var actor := main.get_node("Player") as PartyPlayer
	_expect(is_instance_valid(actor), "Offline avatar exists")
	main.gameplay_audio.reset_for_match()
	await _frames(60)
	# A focused real menu control during the ACTIVE solo match: the ROOM MENU
	# button from the game's own main scene (not a test-made control).
	var probe := main.get_node("Interface/LobbyToggle") as Button
	_expect(probe != null and probe.is_visible_in_tree() and not probe.disabled and probe.focus_mode != Control.FOCUS_NONE, "Real ROOM MENU button is visible and focusable in the solo match")
	var confirms := [0]
	probe.pressed.connect(func() -> void: confirms[0] += 1)
	for case: String in ["focused", "unfocused", "focused", "unfocused"]:
		await _wait_grounded(actor)
		main.gameplay_audio.reset_for_match()
		if case == "focused":
			probe.grab_focus()
			_expect(root.gui_get_focus_owner() == probe, "focused: ROOM MENU button holds focus")
		else:
			root.gui_release_focus()
		await _frames(2)
		var confirms_before: int = confirms[0]
		var result := await _press_space(actor)
		print("T36_OFFLINE_JUMP case=%s jump_cues=%d jumps=%d peak_vy=%.2f confirms=%d ui_confirm_cues=%d" % [case, result[0], result[1], result[2], confirms[0] - confirms_before, _ui_confirm_cues()])
		if case == "focused":
			_expect(confirms[0] - confirms_before == 1, "focused: Space confirms the ROOM MENU button once")
			_expect(result[0] == 0, "focused: no jump cue (got %d)" % result[0])
			_expect(result[1] == 0, "focused: avatar does not jump (jumps %d)" % result[1])
			# The confirm opened the room menu; close it for the next case.
			main._set_lobby_visible(false)
			root.gui_release_focus()
		else:
			_expect(confirms[0] - confirms_before == 0, "unfocused: no control confirmed")
			_expect(result[0] == 1, "unfocused: exactly one jump cue (got %d)" % result[0])
			_expect(result[1] == 1, "unfocused: exactly one jump (jumps %d)" % result[1])
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		print("T35_FAIL %s" % failure)
		push_error(failure)
	if failures.is_empty():
		print("OFFLINE_JUMP_FOCUS_OK checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
