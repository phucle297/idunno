extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.disaster_director.cleanup()
	main.match_manager.prepare_lobby()
	main.get_node("Player").set_physics_process(false)
	main._set_lobby_visible(true)
	var roster: ScrollContainer = main.get_node("Interface/LobbyPanel/PlayerList")
	# Deliberately insert out of order and distinguish host from local client.
	var players := {
		8: {"name": "Long player name that must not displace the readiness badge", "ready": false},
		1: {"name": "Host", "ready": true},
		3: {"name": "Local Player", "ready": false},
		2: {"name": "Guest", "ready": true},
	}
	var before := players.duplicate(true)
	roster.present_players(players, 3)
	await _settle()
	_expect(players == before, "Presentation must not mutate supplied authoritative records")
	_expect(roster.list.get_child_count() == 4, "Four records must create four rows")
	_expect(roster.list.get_child(0) == roster.rows[1] and roster.list.get_child(3) == roster.rows[8], "Rows must sort by numeric peer ID, not insertion or readiness")
	_expect(_label(roster, 1, "Identity/Markers").text == "HOST", "A remote host must not be marked YOU")
	_expect(_label(roster, 3, "Identity/Markers").text == "YOU", "The local client must not be marked HOST")
	_expect(not _label(roster, 2, "Identity/Markers").visible, "Ordinary guests must not have role markers")
	_expect(_label(roster, 8, "Ready").text == "WAITING" and _label(roster, 2, "Ready").text == "READY", "Asymmetric readiness must map to explicit badge copy")
	_check_geometry(roster)
	for row: Control in roster.list.get_children():
		_expect(roster.get_global_rect().encloses(row.get_global_rect()), "All four players must fit without scrolling")
	await _capture("four-client")
	var retained: PanelContainer = roster.rows[3]
	players[3].ready = true
	players[3].name = "Renamed Player"
	players.erase(2)
	roster.present_players(players, 1)
	await _settle()
	_expect(roster.rows[3] == retained, "Updates must reuse rows rather than rebuild the scene")
	_expect(not roster.rows.has(2) and roster.list.get_child_count() == 3, "Disconnected players must disappear immediately")
	_expect(_label(roster, 3, "Ready").text == "READY" and _label(roster, 3, "Identity/Name").text == "Renamed Player", "Existing rows must update names and readiness")
	_expect(_label(roster, 1, "Identity/Markers").text == "HOST · YOU", "The local host must have both markers")
	_expect(not _label(roster, 3, "Identity/Markers").visible, "A changed local identity must clear stale YOU markers")
	for peer_id: int in range(2, 21):
		players[peer_id] = {"name": "Player %02d" % peer_id, "ready": peer_id % 3 == 0}
	roster.present_players(players, 20)
	await _settle()
	_expect(roster.list.get_child_count() == 20, "Full roster must contain twenty rows")
	_expect(roster.get_v_scroll_bar().visible and roster.get_v_scroll_bar().max_value > roster.size.y, "Twenty rows must overflow into a vertical scrollbar")
	_expect(not roster.get_h_scroll_bar().visible, "Names must not force horizontal scrolling")
	_check_geometry(roster)
	await _capture("twenty-top")
	roster.grab_focus()
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	root.push_input(down)
	await _settle()
	_expect(root.gui_get_focus_owner() == roster and roster.scroll_vertical > 0, "Controller down must scroll the focused roster without leaving it")
	var scrolled: int = roster.scroll_vertical
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	root.push_input(up)
	await _settle()
	_expect(root.gui_get_focus_owner() == roster and roster.scroll_vertical < scrolled, "Keyboard up must scroll the focused roster backward")
	roster.scroll_vertical = int(roster.get_v_scroll_bar().max_value)
	await _settle()
	_expect(roster.get_global_rect().encloses(roster.rows[20].get_global_rect()), "The final row must be fully reachable by scrolling")
	_expect(_label(roster, 20, "Identity/Markers").text == "YOU", "The final player's local marker must remain visible")
	await _capture("twenty-bottom")
	roster.present_players({}, 1)
	await _settle()
	_expect(roster.rows.is_empty() and roster.list.get_child_count() == 0, "An empty roster must clear stale rows")
	main.match_manager.register_player(7, "Integrated Guest")
	var snapshot: Dictionary = main._create_playable_snapshot().duplicate(true)
	main._update_lobby_ui()
	_expect(roster.rows.has(7) and _label(roster, 7, "Identity/Name").text == "Integrated Guest", "Main presenter must pass actual match records to the roster")
	_expect(main._create_playable_snapshot() == snapshot, "Lobby updates must preserve authoritative state")
	main.free()
	await process_frame
	if failures.is_empty():
		print("LOBBY_ROSTER_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _label(roster: ScrollContainer, peer_id: int, path: String) -> Label:
	return roster.rows[peer_id].get_node("Content/" + path)


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _check_geometry(roster: ScrollContainer) -> void:
	var previous: Control
	for row: Control in roster.list.get_children():
		_expect(row.size.x <= roster.size.x, "Rows must fit roster width")
		_expect(row.get_global_rect().encloses(row.get_node("Content/Ready").get_global_rect()), "Readiness badges must fit their row")
		_expect(not row.get_node("Content/Identity").get_global_rect().intersects(row.get_node("Content/Ready").get_global_rect()), "Long names must not overlap readiness badges")
		if previous != null:
			_expect(not previous.get_global_rect().intersects(row.get_global_rect()), "Adjacent rows must not overlap")
		previous = row
	var panel: Control = roster.get_parent()
	_expect(panel.get_global_rect().encloses(roster.get_global_rect()), "Roster must remain inside lobby panel")
	_expect(not roster.get_global_rect().intersects(panel.get_node("Status").get_global_rect()), "Scrollable rows must not overlap connection status")


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("lobby-roster-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Lobby capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
