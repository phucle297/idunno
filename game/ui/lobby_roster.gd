extends ScrollContainer

const UITokens = preload("res://game/ui/ui_tokens.gd")

var rows: Dictionary = {}
var list: VBoxContainer


func _ready() -> void:
	list = VBoxContainer.new()
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UITokens.SPACE_SM)
	add_child(list)
	get_v_scroll_bar().focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		scroll_vertical += 64 if event.is_action_pressed("ui_down") else -64
		accept_event()


func present_players(players: Dictionary, local_peer_id: int, owner_peer_id: int = 1, owner_label: String = "HOST") -> void:
	for peer_id: int in rows.keys():
		if not players.has(peer_id):
			rows[peer_id].free()
			rows.erase(peer_id)
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	for index: int in peer_ids.size():
		var peer_id: int = peer_ids[index]
		if not rows.has(peer_id):
			rows[peer_id] = _create_row()
			list.add_child(rows[peer_id])
		var row: PanelContainer = rows[peer_id]
		list.move_child(row, index)
		var identity: VBoxContainer = row.get_node("Content/Identity")
		identity.get_node("Name").text = String(players[peer_id].name)
		var markers: Array[String] = []
		if peer_id == owner_peer_id:
			markers.append(owner_label)
		if peer_id == local_peer_id:
			markers.append("YOU")
		identity.get_node("Markers").text = " · ".join(markers)
		identity.get_node("Markers").visible = not markers.is_empty()
		var badge: Label = row.get_node("Content/Ready")
		var ready := bool(players[peer_id].ready)
		badge.text = "READY" if ready else "WAITING"
		badge.add_theme_color_override("font_color", UITokens.INK if ready else UITokens.SLATE)
		badge.add_theme_stylebox_override("normal", badge.get_meta("ready_style" if ready else "waiting_style"))


func _create_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = "LobbyPlayerRow"
	row.custom_minimum_size.y = 56
	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", UITokens.SPACE_SM)
	row.add_child(content)
	var identity := VBoxContainer.new()
	identity.name = "Identity"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 0)
	content.add_child(identity)
	var player_name := Label.new()
	player_name.name = "Name"
	player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(player_name)
	var markers := Label.new()
	markers.name = "Markers"
	markers.add_theme_font_size_override("font_size", UITokens.FONT_CAPTION)
	identity.add_child(markers)
	var badge := Label.new()
	badge.name = "Ready"
	badge.custom_minimum_size.x = 82
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_font_size_override("font_size", UITokens.FONT_CAPTION)
	for ready: bool in [true, false]:
		var style := StyleBoxFlat.new()
		style.bg_color = UITokens.TEAL if ready else UITokens.SAND
		style.set_corner_radius_all(UITokens.SPACE_SM)
		style.content_margin_top = UITokens.SPACE_SM
		style.content_margin_bottom = UITokens.SPACE_SM
		badge.set_meta("ready_style" if ready else "waiting_style", style)
	content.add_child(badge)
	return row
