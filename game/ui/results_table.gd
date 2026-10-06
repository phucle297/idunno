extends VBoxContainer

const UITokens = preload("res://game/ui/ui_tokens.gd")
const COLUMNS := {
	"Rank": ["RANK", 52],
	"Name": ["PLAYER", 210],
	"Time": ["TIME", 72],
	"Disasters": ["DISASTERS", 90],
	"Damage": ["DAMAGE", 74],
	"Outcome": ["OUTCOME", 0],
}

var rows: Dictionary = {}
var header: HBoxContainer
var scroll: ScrollContainer
var list: VBoxContainer
var award: Label
var _last_results: Dictionary = {}
var _reveal_tween: Tween
var reduced_motion := false:
	set(value):
		reduced_motion = value
		if value:
			_clear_reveal()


func _ready() -> void:
	header = HBoxContainer.new()
	scroll = ScrollContainer.new()
	list = VBoxContainer.new()
	award = Label.new()
	add_theme_constant_override("separation", UITokens.SPACE_MD)
	_build_cells(header)
	add_child(header)
	for column: String in COLUMNS:
		header.get_node(column).text = COLUMNS[column][0]
		header.get_node(column).add_theme_font_size_override("font_size", UITokens.FONT_CAPTION)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_scroll_input)
	add_child(scroll)
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UITokens.SPACE_SM)
	scroll.add_child(list)
	award.name = "Award"
	award.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	award.mouse_filter = Control.MOUSE_FILTER_PASS
	award.add_theme_font_size_override("font_size", UITokens.FONT_CAPTION)
	award.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	award.hide()
	add_child(award)
	visibility_changed.connect(_on_visibility_changed)


func _scroll_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		scroll.scroll_vertical += 48 if event.is_action_pressed("ui_down") else -48
		scroll.accept_event()


func present_results(players: Dictionary, winner_ids: Array, elapsed_time: float) -> void:
	var results := {"players": players, "winners": winner_ids, "time": elapsed_time}
	if results == _last_results:
		return
	_clear_reveal()
	_last_results = results.duplicate(true)
	for peer_id: int in rows.keys():
		if not players.has(peer_id):
			rows[peer_id].free()
			rows.erase(peer_id)
	var ranked_ids: Array = players.keys()
	ranked_ids.sort_custom(func(first: int, second: int) -> bool:
		var a: Dictionary = players[first]
		var b: Dictionary = players[second]
		if bool(a.alive) != bool(b.alive):
			return bool(a.alive)
		if not is_equal_approx(float(a.elimination_time), float(b.elimination_time)):
			return float(a.elimination_time) > float(b.elimination_time)
		if int(a.disasters_survived) != int(b.disasters_survived):
			return int(a.disasters_survived) > int(b.disasters_survived)
		if float(a.damage_taken) != float(b.damage_taken):
			return float(a.damage_taken) < float(b.damage_taken)
		return first < second
	)
	for index: int in ranked_ids.size():
		var peer_id: int = ranked_ids[index]
		if not rows.has(peer_id):
			var row := HBoxContainer.new()
			row.name = str(peer_id)
			row.custom_minimum_size.y = UITokens.CONTROL_HEIGHT
			_build_cells(row)
			list.add_child(row)
			rows[peer_id] = row
		var row: HBoxContainer = rows[peer_id]
		list.move_child(row, index)
		var player: Dictionary = players[peer_id]
		var time := int(elapsed_time if bool(player.alive) else maxf(float(player.elimination_time), 0.0))
		row.get_node("Rank").text = ("★ " if peer_id in winner_ids else "") + str(index + 1)
		row.get_node("Name").text = String(player.name)
		row.get_node("Name").tooltip_text = String(player.name)
		row.get_node("Time").text = "%02d:%02d" % [time / 60, time % 60]
		row.get_node("Disasters").text = str(int(player.disasters_survived))
		row.get_node("Damage").text = str(int(player.damage_taken))
		var outcome := "SURVIVED" if bool(player.alive) else String(player.cause_of_death)
		row.get_node("Outcome").text = outcome
		row.get_node("Outcome").tooltip_text = outcome
		for column: String in ["Rank", "Name"]:
			var cell: Label = row.get_node(column)
			var winner := peer_id in winner_ids
			cell.add_theme_font_size_override("font_size", UITokens.FONT_BODY + 2 if winner else UITokens.FONT_BODY)
			cell.add_theme_color_override("font_color", UITokens.DANGER if winner else UITokens.INK)
	_present_award(players)
	if not reduced_motion and not rows.is_empty():
		_reveal_tween = create_tween().set_parallel(true)
		for index: int in ranked_ids.size():
			var row: Control = rows[ranked_ids[index]]
			row.modulate.a = 0.85
			_reveal_tween.tween_property(row, "modulate:a", 1.0, 0.16).set_delay(mini(index, 7) * 0.035)
	scroll.scroll_vertical = 0
	if is_visible_in_tree():
		scroll.grab_focus()


func _present_award(players: Dictionary) -> void:
	var best_count := 0
	var leaders: Array[String] = []
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var count := int(players[peer_id].disasters_survived)
		if count > best_count:
			best_count = count
			leaders.clear()
		if count == best_count and count > 0:
			leaders.append(String(players[peer_id].name))
	award.text = "MOST DISASTERS SURVIVED · %d — %s" % [best_count, ", ".join(leaders)] if best_count > 0 else ""
	award.tooltip_text = award.text
	award.visible = best_count > 0


func _clear_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	for row: Control in rows.values():
		row.modulate.a = 1.0


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_reveal()
		_last_results.clear()


func _build_cells(container: HBoxContainer) -> void:
	container.add_theme_constant_override("separation", UITokens.SPACE_SM)
	for column: String in COLUMNS:
		var cell := Label.new()
		cell.name = column
		cell.custom_minimum_size.x = COLUMNS[column][1]
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if column in ["Name", "Outcome"]:
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
		if column == "Outcome":
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif column != "Name":
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(cell)
