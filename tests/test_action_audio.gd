extends SceneTree

# M23.3 AC1/AC2: instrumented per-press cue count. Every AudioStreamPlayer in
# the tree is polled each frame; a "start" is playing && (was stopped, stream
# changed, or playback position rewound). Action cues = starts on the Effects
# bus inside a short window after one press. Run on Toy Town and Toy Harbor.

const WINDOW_FRAMES := 24

var checks := 0
var failures: Array[String] = []
var _state := {}
var starts: Array[Dictionary] = []
var _max_frame_ms := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _scan() -> void:
	for player: AudioStreamPlayer in root.find_children("*", "AudioStreamPlayer", true, false):
		var key := player.get_instance_id()
		var prev: Dictionary = _state.get(key, {"playing": false, "stream": null, "pos": 0.0})
		var pos: float = player.get_playback_position() if player.playing else 0.0
		if player.playing and (not prev.playing or prev.stream != player.stream or pos + 0.001 < prev.pos):
			var path := ""
			if player.stream:
				path = player.stream.resource_path if player.stream.resource_path != "" else "generated:%s" % player.stream.get_instance_id()
			starts.append({"node": String(player.get_path()).get_file(), "stream": path, "db": player.volume_db, "bus": String(player.bus)})
		_state[key] = {"playing": player.playing, "stream": player.stream, "pos": pos}


func _frames(count: int) -> void:
	for index in count:
		var before := Time.get_ticks_usec()
		await process_frame
		_max_frame_ms = maxf(_max_frame_ms, float(Time.get_ticks_usec() - before) / 1000.0)
		_scan()


# T25: polled HotPotatoVoice starts vs the emitter counter, plus the longest
# frame in the window (the 0.09 s bomb tone is shorter than a slow frame).
func _bomb_diag(label: String, main: Node, before: int) -> void:
	var polled := _action_cues().filter(func(s: Dictionary) -> bool: return String(s.node).begins_with("HotPotatoVoice")).size()
	print("T25_BOMB %s polled=%d counter=%d max_frame_ms=%.1f warning_playing=%s" % [label, polled, main.bomb_visuals.cue_play_count - before, _max_frame_ms, main.gameplay_audio.is_warning_playing()])


func _settle() -> void:
	await _frames(WINDOW_FRAMES)
	starts.clear()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _press_key(code: Key) -> void:
	_key(code, true)
	await _frames(3)
	_key(code, false)
	await _frames(WINDOW_FRAMES)


func _press_lmb() -> void:
	var center: Vector2 = root.get_visible_rect().size * 0.5
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = center
		event.global_position = center
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(WINDOW_FRAMES)


func _click(control: Control) -> void:
	var center: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = center
		event.global_position = center
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(WINDOW_FRAMES)


func _action_cues() -> Array[Dictionary]:
	return starts.filter(func(s: Dictionary) -> bool: return s.bus == "Effects")


func _report(label: String, expected_max: int = 1, expected_min: int = 1, emitter_count: int = -1, emitter_prefix: String = "ToyEffectVoice") -> void:
	var cues := _action_cues()
	if emitter_count >= 0:
		# Very short generated clips (0.07-0.09 s) can finish between two polled
		# frames on a loaded box; the emitter's own play counter is authoritative.
		# Other Effects-bus starts still count, so a double cue still fails.
		cues = cues.filter(func(s: Dictionary) -> bool: return not String(s.node).begins_with(emitter_prefix))
		for index in emitter_count:
			cues.append({"node": "%s(counter)" % emitter_prefix})
	print("M23.3_CUES %s count=%d starts=%s" % [label, cues.size(), JSON.stringify(starts)])
	_expect(cues.size() >= expected_min and cues.size() <= expected_max, "%s: one press must give %d..%d action cue(s), got %d %s" % [label, expected_min, expected_max, cues.size(), JSON.stringify(starts)])
	starts.clear()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	# UI: keyboard confirm on the focused home control, then a mouse click.
	var focused := root.gui_get_focus_owner() as BaseButton
	_expect(focused != null, "Home screen starts with a focused button")
	if focused:
		await _press_key(KEY_ENTER)
		_report("ui_enter_focused_button")
		await _settle()
	var focused_space := root.gui_get_focus_owner() as BaseButton
	if focused_space:
		await _press_key(KEY_SPACE)
		_report("ui_space_focused_button")
		await _settle()
	var clickable := _first_clickable_button(root)
	_expect(clickable != null, "A visible clickable button exists for the mouse-click probe")
	if clickable:
		root.gui_release_focus()
		await _settle()
		await _click(clickable)
		_expect(clickable.has_focus() or not clickable.is_visible_in_tree(), "Mouse click reached the button")
		_report("ui_mouse_click:%s" % clickable.name)
		await _settle()
	_expect(await main.start_local_match(), "Solo match starts")
	for map_id in ["toy_town", "toy_harbor"]:
		main.set_map_id(map_id)
		await main.prepare_gameplay_map()
		main.disaster_director.cleanup()
		main.gameplay_audio.reset_for_match()
		var actor := main.get_node("Player") as PartyPlayer
		await _frames(40)
		await _settle()
		root.gui_release_focus()
		# Jump (Space) while grounded.
		for attempt in 3:
			if actor.is_on_floor():
				break
			await _frames(30)
		starts.clear()
		await _press_key(KEY_SPACE)
		_report("%s:jump" % map_id)
		await _frames(90)
		starts.clear()
		# T23 Shove (G): exactly one soft cue per press, miss and hit alike.
		await _probe_shove(main, actor, map_id)
		# Power-up pickup: the HUD card is the only pickup cue emitter.
		await _settle()
		main.gameplay_hud.powerup_card.present(MatchPowerups.Kind.SPEED, 8.0, 900 + checks, main.gameplay_hud.powerup_card._round, true)
		await _frames(WINDOW_FRAMES)
		_report("%s:powerup_pickup" % map_id)
		# Toy pickup (F) at the actor.
		await _settle()
		main.toy_sabotage.slots.erase(1)
		main.toy_sabotage.pickups.append({"id": 7000 + checks, "kind": "foam_blaster", "position": actor.global_position, "expires": main.match_manager.elapsed_time + 30.0})
		await _frames(2)
		await _press_key(KEY_F)
		_expect(String(main.toy_sabotage.slots.get(1, {}).get("kind", "")) == "foam_blaster", "%s: F picks the toy up" % map_id)
		_report("%s:toy_pickup" % map_id)
		# Toy use: a real left-click event through main._unhandled_input (T25 AC1).
		# Headless cannot grab the OS pointer, so the test seam stands in for capture.
		await _settle()
		main.match_manager.elapsed_time = maxf(main.match_manager.elapsed_time, ToySabotage.OPENING_PROTECTION + 0.5)
		main.gameplay_audio.reset_for_match()
		var muted_before: int = main.toy_audio.muted_warning_count
		var effects_before: int = main.toy_sabotage.effects.size()
		var toy_plays_before: int = main.toy_audio.sound_play_count
		PartyPlayer.headless_pointer_captured = true
		await _press_lmb()
		PartyPlayer.headless_pointer_captured = false
		_expect(main.toy_sabotage.effects.size() > effects_before, "%s: left click uses the held toy" % map_id)
		print("M23.3_TOY %s effects %d->%d muted %d->%d far=%d debounce=%d warning_playing=%s" % [map_id, effects_before, main.toy_sabotage.effects.size(), muted_before, main.toy_audio.muted_warning_count, main.toy_audio.skipped_distance_count, main.toy_audio.skipped_debounce_count, main.gameplay_audio.is_warning_playing()])
		_report("%s:toy_use" % map_id, 1, 1, main.toy_audio.sound_play_count - toy_plays_before)
		await _frames(120)
		starts.clear()
		main.toy_sabotage.slots.erase(1)
		# Hot potato pickup (F) and throw.
		main.hot_potato._enabled = true
		main.hot_potato.phase = HotPotato.Phase.GROUND
		main.hot_potato.position_world = actor.global_position
		main.hot_potato._deadline = INF
		await _settle()
		# Toy/bomb cues yield to a playing warning by design (collapse notices keep
		# ticking in this fixture); silence warnings so the probe measures the action.
		main.gameplay_audio.reset_for_match()
		var bomb_before: int = main.bomb_visuals.cue_play_count
		_max_frame_ms = 0.0
		await _press_key(KEY_F)
		_expect(main.hot_potato.is_carrier(1), "%s: F picks the bomb up" % map_id)
		_bomb_diag("%s:bomb_pickup" % map_id, main, bomb_before)
		_report("%s:bomb_pickup" % map_id, 1, 1, main.bomb_visuals.cue_play_count - bomb_before, "HotPotatoVoice")
		await _settle()
		main.gameplay_audio.reset_for_match()
		bomb_before = main.bomb_visuals.cue_play_count
		_max_frame_ms = 0.0
		main.hot_potato.local_request(1, false, actor.get_forward_direction())
		await _frames(WINDOW_FRAMES)
		_bomb_diag("%s:bomb_throw" % map_id, main, bomb_before)
		_report("%s:bomb_throw" % map_id, 1, 1, main.bomb_visuals.cue_play_count - bomb_before, "HotPotatoVoice")
		main.hot_potato.reset()
		await _frames(30)
	# AC2: warnings are on a separate bus and voice, louder than any action cue.
	_check_warning_distinct(main)
	main.gameplay_audio.reset_for_match()
	await create_timer(0.1).timeout
	main.free()
	await create_timer(0.1).timeout
	for failure in failures:
		print("M23.3_FAIL %s" % failure)
		push_error(failure)
	if failures.is_empty():
		print("ACTION_AUDIO_OK checks=%d maps=2" % checks)
	quit(0 if failures.is_empty() else 1)


func _probe_shove(main: Node, actor: PartyPlayer, map_id: String) -> void:
	var shove_manager: ShoveManager = main.get_node("ShoveManager")
	var hits := [0]
	var on_hit := func(_shover: int, _victim: int) -> void: hits[0] += 1
	shove_manager.shove_effect_applied.connect(on_hit)
	# Miss: no other player in range.
	main.gameplay_audio.reset_for_match()
	await _settle()
	var shoves_before: int = main.gameplay_audio.shove_play_count
	await _press_key(KEY_G)
	_expect(hits[0] == 0, "%s: shove with no target is a miss" % map_id)
	_expect(main.gameplay_audio.shove_play_count - shoves_before == 1, "%s: miss shove calls play_shove once" % map_id)
	_report("%s:shove_miss" % map_id)
	# Hit: a passive dummy player right in front of the shover.
	await _frames(int(Engine.physics_ticks_per_second * 1.5))  # past shove cooldown
	var dummy := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PartyPlayer
	dummy.local_input_blocked = true
	main.add_child(dummy)
	var forward := actor.get_forward_direction()
	forward.y = 0.0
	dummy.global_position = actor.global_position + forward.normalized() * 1.0
	main.match_manager.players[2] = main.match_manager._new_player_state("T23 Dummy")
	shove_manager.register_player(2, dummy)
	main.gameplay_audio.reset_for_match()
	await _settle()
	shoves_before = main.gameplay_audio.shove_play_count
	await _press_key(KEY_G)
	_expect(hits[0] == 1, "%s: shove with a target in front is a hit (hits=%d)" % [map_id, hits[0]])
	_expect(main.gameplay_audio.shove_play_count - shoves_before == 1, "%s: hit shove calls play_shove once" % map_id)
	var hit_starts := _action_cues().duplicate()
	_report("%s:shove_hit" % map_id)
	for cue: Dictionary in hit_starts:
		_expect(String(cue.stream).begins_with("generated:") and is_equal_approx(float(cue.db), GameplayAudioController.SHOVE_DB), "%s: hit cue is the same shove cue as a miss %s" % [map_id, JSON.stringify(cue)])
	shove_manager.shove_effect_applied.disconnect(on_hit)
	shove_manager.unregister_player(2)
	main.match_manager.players.erase(2)
	dummy.queue_free()
	await _frames(30)
	starts.clear()


func _rms_dbfs(stream: AudioStreamWAV) -> float:
	# Imported WAVs may be compressed; measure the source PCM16 (44-byte header
	# from tools/audio_generation) or, for generated in-memory tones, raw data.
	var data := stream.data
	var offset := 0
	if stream.resource_path.ends_with(".wav"):
		data = FileAccess.get_file_as_bytes(stream.resource_path)
		offset = 44
	var total := 0.0
	var count := (data.size() - offset) / 2
	for index in count:
		var sample := float(data.decode_s16(offset + index * 2)) / 32768.0
		total += sample * sample
	return linear_to_db(sqrt(total / maxf(1.0, float(count))))


func _check_warning_distinct(main: Node) -> void:
	var audio: GameplayAudioController = main.gameplay_audio
	var warning_db: float = audio._warning_voice.volume_db
	_expect(audio._warning_voice.bus == "Warnings", "Disaster warnings route to the Warnings bus")
	# Effective level = voice volume_db + stream RMS (dBFS). Warnings must sit >= 6 dB above every action cue.
	var warning_level := INF
	for stream: AudioStreamWAV in [GameplayAudioController.WarningSound, GameplayAudioController.MeteorWarningSound, GameplayAudioController.FloodWarningSound, GameplayAudioController.TornadoWarningSound, GameplayAudioController.RainWarningSound, GameplayAudioController.SnowWarningSound, GameplayAudioController.RockWarningSound, GameplayAudioController.BeeWarningSound, GameplayAudioController.UFOWarningSound, GameplayAudioController.VolcanoWarningSound]:
		warning_level = minf(warning_level, warning_db + _rms_dbfs(stream))
	var actions := {
		"jump": GameplayAudioController.JUMP_DB + _rms_dbfs(GameplayAudioController.JumpSound),
		"pickup": GameplayAudioController.PICKUP_DB + _rms_dbfs(GameplayAudioController.PickupSound),
		"shove": GameplayAudioController.SHOVE_DB + _rms_dbfs(audio.shove_sound),
		"ui_confirm": GameplayAudioController.UI_CONFIRM_DB + _rms_dbfs(GameplayAudioController.JumpSound),
		"ui_focus": GameplayAudioController.UI_FOCUS_DB + _rms_dbfs(GameplayAudioController.PickupSound),
	}
	var toy_loudest := -INF
	for stream: AudioStreamWAV in main.toy_audio._streams.values():
		toy_loudest = maxf(toy_loudest, ToySabotageAudio.VOICE_DB + _rms_dbfs(stream))
	actions["toy_loudest"] = toy_loudest
	var bomb_loudest := -INF
	for stream: AudioStreamWAV in main.bomb_visuals._tones.values():
		bomb_loudest = maxf(bomb_loudest, -18.0 + _rms_dbfs(stream))
	actions["bomb_loudest"] = bomb_loudest
	for action: String in actions:
		_expect(warning_level - float(actions[action]) >= 6.0, "Quietest warning (%.1f dB eff) is >= 6 dB above %s (%.1f dB eff)" % [warning_level, action, actions[action]])
	_expect(GameplayAudioController.COUNTDOWN_DB + _rms_dbfs(GameplayAudioController.ImpactSound) > float(actions.jump), "Countdown tick (warning family) is louder than the jump cue")
	for stream: AudioStream in [GameplayAudioController.WarningSound, GameplayAudioController.MeteorWarningSound, GameplayAudioController.FloodWarningSound]:
		for action: AudioStream in [GameplayAudioController.JumpSound, GameplayAudioController.PickupSound]:
			_expect(stream != action, "Warning stream %s is not reused as an action cue" % stream.resource_path)
	# Timbre/shape: warning stems are long (>= 0.8 s) patterned tones; action cues are short blips.
	for stream: AudioStream in [GameplayAudioController.WarningSound, GameplayAudioController.MeteorWarningSound, GameplayAudioController.FloodWarningSound, GameplayAudioController.TornadoWarningSound]:
		_expect(stream.get_length() >= 0.79, "Warning %s lasts >= 0.8 s" % stream.resource_path)
	for stream: AudioStream in [GameplayAudioController.JumpSound, GameplayAudioController.PickupSound]:
		_expect(stream.get_length() <= 0.25, "Action cue %s is a short blip" % stream.resource_path)
	var parts: Array[String] = []
	for action: String in actions:
		parts.append("%s=%.1f" % [action, actions[action]])
	print("M23.3_LEVELS warning_voice_db=%.1f quietest_warning_eff=%.1f countdown_eff=%.1f %s" % [warning_db, warning_level, GameplayAudioController.COUNTDOWN_DB + _rms_dbfs(GameplayAudioController.ImpactSound), " ".join(parts)])


func _first_clickable_button(node: Node) -> BaseButton:
	for button: BaseButton in node.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE and button.get_global_rect().size.x > 10 and not (button is OptionButton) and not (button is CheckButton):
			var name_lower := String(button.text).to_lower()
			if "quit" in name_lower or "exit" in name_lower:
				continue
			return button
	return null


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
