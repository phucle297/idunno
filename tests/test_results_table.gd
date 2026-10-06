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
	main.get_node("Player").set_physics_process(false)
	var panel: Panel = main.get_node("Interface/ResultsPanel")
	_expect(panel.has_node("Table"), "Results must replace the space-aligned summary with a structured table")
	if not panel.has_node("Table"):
		main.free()
		_finish()
		return
	var table: VBoxContainer = panel.get_node("Table")
	main.match_manager.apply_damage(1, 100.0, "Integrated result")
	main._process(0.0)
	await _settle()
	_expect(_cell(table, 1, "Outcome").text == "Integrated result", "Actual match completion must present authoritative records")
	# Asymmetric records distinguish every ranking key and time formatting.
	var players := {
		8: _record("Long player name that must not displace other columns", false, 125.9, 9, 15.8, "A very long custom cause that must remain contained"),
		4: _record("Earlier", false, 59.9, 12, 1.0, "Flood"),
		2: _record("Survivor", true, -1.0, 1, 80.0, ""),
		3: _record("Later", false, 125.9, 9, 14.2, "Meteor"),
	}
	var before := players.duplicate(true)
	table.present_results(players, [2], 187.9)
	panel.get_node("Title").text = "SURVIVOR WINS!"
	panel.show()
	await _settle()
	_expect(players == before, "Results presentation must not mutate authoritative records")
	_expect(_order(table) == [2, 3, 8, 4], "Survivors, time, disasters and damage must preserve ranking priority")
	_expect(_cell(table, 2, "Rank").text == "★ 1", "Existing winner marker must remain visible")
	_expect(_cell(table, 2, "Time").text == "03:07" and _cell(table, 4, "Time").text == "00:59", "Time must floor fractional seconds and use elapsed time only for survivors")
	_expect(_cell(table, 8, "Damage").text == "15" and _cell(table, 8, "Disasters").text == "9", "Numeric columns must preserve existing integer presentation")
	_expect(_cell(table, 2, "Outcome").text == "SURVIVED" and _cell(table, 3, "Outcome").text == "Meteor", "Outcome must distinguish survivors and death cause")
	for column: String in ["Name", "Outcome"]:
		var cell := _cell(table, 8, column)
		_expect(cell.tooltip_text == cell.text and cell.mouse_filter != Control.MOUSE_FILTER_IGNORE, "Ellipsized text must have a mouse-accessible full-text tooltip")
	_check_geometry(table)
	for row: Control in table.list.get_children():
		_expect(table.scroll.get_global_rect().encloses(row.get_global_rect()), "Four results must be fully visible without scrolling")
	await _capture("four")
	var retained: Control = table.rows[8]
	players[8].disasters_survived = 10
	table.present_results(players, [], 187.9)
	await _settle()
	_expect(_order(table) == [2, 8, 3, 4], "Disaster count must break equal elimination times before damage")
	_expect(table.rows[8] == retained and _cell(table, 2, "Rank").text == "1", "Updates must reuse rows and clear stale winner markers")
	players[8] = players[3].duplicate(true)
	table.present_results(players, [3, 8], 187.9)
	_expect(_order(table) == [2, 3, 8, 4], "Exact ties must use numeric peer ID, independent of insertion order")
	var reversed := {4: players[4], 3: players[3], 2: players[2], 8: players[8]}
	table.present_results(reversed, [3, 8], 187.9)
	_expect(_order(table) == [2, 3, 8, 4], "Different peer dictionary order must produce identical rankings")
	for id: int in range(1, 21):
		players[id] = _record("Player %02d" % id, false, 600.0 - id, id % 5, 100.0, "Fire")
	players[1].name = "Another extremely long player name for a twenty-player results panel"
	table.present_results(players, [1], 600.0)
	panel.get_node("Title").text = "MATCH RESULTS"
	await _settle()
	_expect(table.rows.size() == 20 and table.scroll.get_v_scroll_bar().visible, "Twenty results must use vertical scrolling")
	_expect(not table.scroll.get_h_scroll_bar().visible, "Long names must not force horizontal scrolling")
	_check_geometry(table)
	await _capture("twenty-top")
	table.scroll.grab_focus()
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	root.push_input(down)
	await _settle()
	_expect(table.scroll.scroll_vertical > 0, "Controller down must scroll the focused results")
	table.scroll.scroll_vertical = int(table.scroll.get_v_scroll_bar().max_value)
	await _settle()
	_expect(table.scroll.get_global_rect().encloses(table.rows[20].get_global_rect()), "Player twenty must be fully reachable")
	await _capture("twenty-bottom")
	table.present_results({}, [], 0.0)
	_expect(table.rows.is_empty() and table.list.get_child_count() == 0, "Empty results must clear old rows")
	main.gameplay_audio.reset_for_match()
	main.free()
	await process_frame
	_finish()


func _record(player_name: String, alive: bool, time: float, disasters: int, damage: float, cause: String) -> Dictionary:
	return {"name": player_name, "alive": alive, "elimination_time": time, "disasters_survived": disasters, "damage_taken": damage, "cause_of_death": cause}


func _order(table: VBoxContainer) -> Array:
	return table.list.get_children().map(func(row: Node) -> int: return int(row.name))


func _cell(table: VBoxContainer, id: int, column: String) -> Label:
	return table.rows[id].get_node(column)


func _check_geometry(table: VBoxContainer) -> void:
	for row: Control in table.list.get_children():
		var previous: Control
		for cell: Control in row.get_children():
			_expect(row.get_global_rect().encloses(cell.get_global_rect()), "Every result cell must fit its row")
			var heading: Control = table.header.get_node(NodePath(cell.name))
			_expect(is_equal_approx(cell.global_position.x, heading.global_position.x), "Headers and row columns must align even with a scrollbar")
			if previous != null:
				_expect(not previous.get_global_rect().intersects(cell.get_global_rect()), "Adjacent columns must not overlap")
			previous = cell
	_expect(not table.get_global_rect().intersects(table.get_parent().get_node("Prompt").get_global_rect()), "Results table must not overlap rematch prompt")


func _settle() -> void:
	for frame: int in 4:
		await process_frame


func _capture(state: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-dir=").path_join("results-%s-%dx%d.png" % [state, root.size.x, root.size.y])
			_expect(root.get_texture().get_image().save_png(path) == OK, "Results capture must save")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RESULTS_TABLE_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
