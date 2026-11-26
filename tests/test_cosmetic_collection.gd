extends SceneTree

var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var main: Node
var review_size := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
		if argument == "--1080p":
			review_size = Vector2i(1920, 1080)
	main = preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if not capture_dir.is_empty():
		main.pause_settings.values.windowed_resolution = review_size
		main.pause_settings.values.fullscreen = false
		main.pause_settings.apply_preferences(true)
		DisplayServer.window_set_size(review_size)
		for frame in 8:
			await process_frame
		root.size = review_size
		await process_frame
		_expect(root.size == review_size, "Actual capture resolution matches requested size")
	# Offline starters must work with a configured but unreachable service too.
	main.room_client.service_url = "http://127.0.0.1:1"
	main.match_manager.prepare_lobby()
	main._set_lobby_visible(true)
	await process_frame
	var ui: Control = main.collection
	main._show_collection()
	await process_frame
	_expect(ui.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Collection opens with pointer available")
	_expect(not main.room_client.profile_client.busy and not ui.busy, "Offline collection never blocks equipment on a profile HTTP request")
	_expect(root.gui_get_focus_owner() == ui.outfit_buttons[0], "Collection owns keyboard focus")
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == ui.outfit_buttons[1], "Tab reaches the next outfit")
	ui.close_button.grab_focus()
	await _key(KEY_TAB)
	_expect(root.gui_get_focus_owner() == ui.outfit_buttons[0], "Tab wraps within modal, not the background lobby")
	_expect(ui.outfit_buttons.size() == 12 and ui.preview.get_outfit_id() == "plain", "All twelve stable previews available")
	_expect(ui.odds.text.contains("1/4") and ui.open_button.disabled, "Default exact odds and empty pending state")
	await _capture("default")
	ui.select_outfit("raincoat")
	_expect(ui.equip_button.disabled and ui.preview.get_outfit_id() == "raincoat", "Locked costume can be previewed, not equipped")
	await _capture("locked")
	ui.select_outfit("cap")
	ui.equip_button.pressed.emit()
	_expect(main.get_outfit_id() == "cap" and ui.profile.equipped == "cap", "Offline starter acknowledgement updates avatar and collection")
	for outfit: String in ["chef", "firefighter", "sailor", "pilot"]:
		ui.select_outfit(outfit)
		_expect(not ui.equip_button.disabled and ui.preview.get_outfit_id() == outfit, "New starter previews and can equip offline: " + outfit)
		ui.equip_button.pressed.emit()
		_expect(main.get_outfit_id() == outfit and main.get_node("Player").character.get_outfit_id() == outfit, "Acknowledged starter reaches actual avatar: " + outfit)
		ui.outfit_buttons[ToyCharacterVisual.catalog().items.find_custom(func(item: Dictionary) -> bool: return item.id == outfit)].grab_focus()
		await process_frame
		await process_frame
		await _capture(outfit)
	await _check_suit_colours(ui)
	ui.select_outfit("plain")
	ui.equip_button.pressed.emit() # Leave ordinary tests/users on default starter.
	ui.dismiss()
	ui = preload("res://game/ui/cosmetic_collection.gd").new()
	ui.theme = DisasterPartyUI.build_theme()
	main.get_node("Interface").add_child(ui)
	ui.show_collection()
	var starter: Array = main.STARTER_OUTFITS.duplicate()
	var fixture := {"owned": starter, "equipped": "plain", "pending": [{"box_id": "fixture-box",
		"round_id": "fixture-round", "pool": ["raincoat", "mechanic", "park_ranger", "meteor_observer"],
		"odds": {"numerator": 1, "denominator": 4}, "catalog_version": 1, "state": "sealed"}]}
	ui.reward_text = "Free sealed box earned! Rematch is never blocked."
	ui.present_profile(fixture, true, false)
	ui.select_outfit("raincoat")
	_expect(not ui.open_button.disabled and ui.equip_button.disabled, "Results allow free open but no equipment mutation")
	_expect(ui.odds.text.contains("1/3") and ui.reward.text.contains("1/4"), "Next pool odds differ from immutable grant-time odds")
	await _capture("sealed-results")
	var opens: Array[String] = []
	ui.open_requested.connect(func(box: String) -> void: opens.append(box))
	ui.open_button.pressed.emit()
	_expect(opens == ["fixture-box"] and ui.profile.owned.size() == starter.size() and ui.busy, "Opening intent does not optimistically unlock")
	ui.present_error("Opening unavailable. Retry the same box; keep your saved identity.")
	_expect(ui.profile.pending.size() == 1 and not ui.open_button.disabled, "Failure preserves sealed box and retry")
	await _capture("unavailable")
	ui.reduced_motion = true
	ui.present_open({"box_id": "fixture-box", "cosmetic_id": "raincoat"})
	_expect(ui.profile.owned.size() == starter.size() + 1 and ui.profile.pending.is_empty(), "Only acknowledged receipt unlocks item")
	_expect(ui.preview.get_outfit_id() == "raincoat" and ui.reward.text.contains("UNLOCKED"), "Reveal uses receipt item in faithful preview")
	_expect(not ui.skip_button.visible and ui.reward.modulate.a == 1.0, "Reduced motion has no reveal delay")
	await _capture("opened")
	ui.reduced_motion = false
	ui.present_open({"box_id": "fixture-box", "cosmetic_id": "raincoat"})
	_expect(ui.profile.owned.size() == starter.size() + 1, "Replaying receipt cannot duplicate ownership")
	ui.skip_button.pressed.emit()
	_expect(ui.reward.modulate.a == 1.0 and not ui.skip_button.visible, "Skip immediately completes presentation only")
	var all_owned: Array[String] = []
	for item: Dictionary in ToyCharacterVisual.catalog().items:
		all_owned.append(item.id)
	ui.present_profile({"owned": all_owned, "pending": [], "equipped": "raincoat"}, true, true)
	_expect(ui.odds.text.contains("All rewards earned") and ui.open_button.disabled, "Complete collection has no empty-box action")
	await _capture("complete")
	ui.dismiss()
	await process_frame
	_expect(not ui.visible and main.home_screen.is_visible_in_tree() and main.match_manager.state == MatchManager.MatchState.LOBBY, "Closing returns to Home, no match change")
	await main.start_local_match()
	main.match_manager.apply_damage(1, 100.0, "Review fixture")
	main._receive_reward_notice(1, {"reason": "round_too_short"})
	main._receive_reward_notice(1, {"reason": "earned"})
	_expect(main.collection.reward_text.contains("120 seconds"), "Repeated same-round notice cannot replace saved reason")
	await _capture("results-no-drop")
	var lobby_only_colour: int = main.get_suit_colour()
	main.request_suit_colour((lobby_only_colour + 1) % ToyCharacterVisual.SUIT_COLORS.size())
	_expect(main.get_suit_colour() == lobby_only_colour, "T51: colour cannot change outside the lobby")
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	if failures.is_empty():
		print("COSMETIC_COLLECTION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _suit_material(visual: ToyCharacterVisual) -> Material:
	return (visual.get_node("Torso") as MeshInstance3D).material_override


func _face_untouched(visual: ToyCharacterVisual) -> bool:
	var face := visual.find_child("FaceCream", true, false) as MeshInstance3D
	if face == null:
		return false
	var suit := _suit_material(visual)
	if face.material_override == suit:
		return false
	for surface: int in face.get_surface_override_material_count():
		if face.get_surface_override_material(surface) == suit:
			return false
	return true


func _head_accessories_carry_suit(visual: ToyCharacterVisual) -> bool:
	var suit := _suit_material(visual)
	for accessory: MeshInstance3D in visual.get_node("Accessories").get_children():
		if accessory.get_meta("body") == "Head" and accessory.get_surface_override_material(0) != suit:
			return false
	return true


func _check_suit_colours(ui: Control) -> void:
	# T51 AC1-AC3: swatches, local pick, preview + avatar colour, face untouched, 4P rule.
	var avatar: ToyCharacterVisual = main.get_node("Player").character
	_expect(ui.colour_buttons.size() == ToyCharacterVisual.SUIT_COLORS.size(), "T51: one swatch per existing suit colour")
	var colours_match := true
	for index: int in ui.colour_buttons.size():
		var box := ui.colour_buttons[index].get_theme_stylebox("normal") as StyleBoxFlat
		colours_match = colours_match and box != null and box.bg_color == ToyCharacterVisual.SUIT_COLORS[index]
	_expect(colours_match, "T51: swatch colours equal SUIT_COLORS")
	_expect(main.get_suit_colour() == 0 and ui.colour_current == 0, "T51: solo default stays colour 0")
	for pick: int in [3, 1]:
		ui.colour_buttons[pick].pressed.emit()
		await process_frame
		_expect(main.get_suit_colour() == pick and ui.colour_current == pick and ui.colour_buttons[pick].text == "✓", "T51: swatch pick %d acknowledged" % pick)
		var expected: Color = (ToyCharacterVisual.SUIT_COLORS[pick] as Color).lerp(ToyCharacterVisual.SUIT_SOFTEN, 0.28)
		_expect((_suit_material(avatar) as StandardMaterial3D).albedo_color == expected and _suit_material(ui.preview) == _suit_material(avatar), "T51: preview and avatar show colour %d" % pick)
		_expect(_face_untouched(avatar) and _face_untouched(ui.preview), "T51: suit colour %d does not paint FaceCream" % pick)
		main.home_screen.refresh()
		_expect(_suit_material(main.home_screen.preview) == _suit_material(avatar), "T51: home preview follows colour %d" % pick)
		await _capture("colour-c%d" % pick)
	var colour_a := _suit_material(avatar)
	main.request_outfit("cap")
	_expect(_suit_material(avatar) == colour_a and _head_accessories_carry_suit(avatar), "T51: colour then outfit keeps colour on head accessories")
	main.request_suit_colour(4)
	_expect(main.get_suit_colour() == 4 and _head_accessories_carry_suit(avatar) and main.get_outfit_id() == "cap", "T51: outfit then colour keeps outfit, accessories recoloured")
	# 4P: ids that collide under peer_id - 1 (mod 6) still get distinct defaults.
	var ids: Array[int] = [2, 3141592, 987654321]
	for index: int in ids.size():
		main._add_gameplay_demo_player(ids[index], "Demo %d" % index, Vector3(3 * index + 3, 0, 3))
	var four: Array[int] = []
	for peer: int in [1] + ids:
		if not main.get_suit_colour(peer) in four:
			four.append(main.get_suit_colour(peer))
	_expect(four.size() == 4, "T51: four players get four distinct colours (%s)" % str(four))
	var replies: Array[String] = []
	var on_reply := func(_colour: int, error: String) -> void: replies.append(error)
	main.suit_colour_replied.connect(on_reply)
	var held: int = main.get_suit_colour(ids[0])
	var before: int = main.get_suit_colour()
	main.request_suit_colour(held)
	_expect(replies.back() == "colour_taken" and main.get_suit_colour() == before, "T51: taken colour rejected, nothing changes")
	_expect(ui.colour_buttons[held].disabled, "T51: taken swatch is disabled")
	var free_colour := 0
	while free_colour in four:
		free_colour += 1
	main.request_suit_colour(free_colour)
	_expect(replies.back() == "" and main.get_suit_colour() == free_colour, "T51: free colour accepted")
	var extra: Array[int] = [11, 12, 13]
	for index: int in extra.size():
		main._add_gameplay_demo_player(extra[index], "Extra %d" % index, Vector3(3 * index + 3, 0, 6))
	main.request_suit_colour(main.get_suit_colour(ids[1]))
	_expect(replies.back() == "" and main.get_suit_colour() == main.get_suit_colour(ids[1]), "T51: with 7 players sharing is allowed")
	var freed: int = main.get_suit_colour(ids[2])
	for peer: int in ids + extra:
		main._remove_network_player(peer)
		main.match_manager.unregister_player(peer)
	main.request_suit_colour(freed)
	_expect(replies.back() == "" and main.get_suit_colour() == freed, "T51: colour freed on disconnect is reusable")
	main.suit_colour_replied.disconnect(on_reply)
	main.request_suit_colour(0)
	main.request_outfit("plain")
	_expect(main.get_suit_colour() == 0, "T51: restored default colour")


func _capture(state: String) -> void:
	if capture_dir.is_empty():
		return
	root.size = review_size
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_size() == review_size, "Framebuffer matches review size: " + state)
	var error := image.save_png("%s/%s.png" % [capture_dir, state])
	_expect(error == OK, "Capture saved: " + state)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
