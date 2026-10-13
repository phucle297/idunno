extends Control
## Presentation only. Inventory, open receipts and equip acknowledgements come from owners.

signal closed
signal equip_requested(outfit_id: String)
signal open_requested(box_id: String)
signal refresh_requested

var profile: Dictionary = {"owned": ["plain", "cap", "hard_hat", "backpack"], "pending": [], "equipped": "plain"}
var managed := false
var lobby := true
var reduced_motion := false
var busy := false:
	set(value):
		busy = value
		if is_inside_tree():
			_render()
var selected := "plain"
var reward_text := "Offline and player-hosted matches do not award boxes."
var title: Label
var status: Label
var description: Label
var odds: Label
var reward: Label
var equip_button: Button
var open_button: Button
var box_select: OptionButton
var close_button: Button
var skip_button: Button
var outfit_buttons: Array[Button] = []
var preview: ToyCharacterVisual
var viewport: SubViewport
var _return_focus: Control
var _reveal: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 15
	var backdrop := ColorRect.new()
	backdrop.color = Color(DisasterPartyUI.INK, 0.75)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 600)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	title = Label.new()
	title.text = "YOUR TOY COLLECTION"
	title.add_theme_font_size_override("font_size", DisasterPartyUI.FONT_TITLE)
	content.add_child(title)
	status = Label.new()
	content.add_child(status)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	content.add_child(columns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	columns.add_child(grid)
	for item: Dictionary in ToyCharacterVisual.catalog().items:
		var button := Button.new()
		button.custom_minimum_size = Vector2(215, 58)
		button.pressed.connect(func() -> void: select_outfit(item.id))
		grid.add_child(button)
		outfit_buttons.append(button)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 375
	columns.add_child(right)
	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(375, 240)
	preview_container.stretch = true
	right.add_child(preview_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(375, 240)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview_container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = DisasterPartyUI.SLATE
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	world.add_child(light)
	preview = preload("res://assets/generated/CHR_Base_v001.tscn").instantiate()
	world.add_child(preview)
	preview.set_player_color(0)
	var camera := Camera3D.new()
	camera.position = Vector3(2.3, 1.8, -3.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0))
	var rotation_row := HBoxContainer.new()
	right.add_child(rotation_row)
	for direction: int in [-1, 1]:
		var rotate := Button.new()
		rotate.text = "ROTATE LEFT" if direction < 0 else "ROTATE RIGHT"
		rotate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rotate.pressed.connect(func() -> void: preview.rotate_y(direction * PI / 4.0))
		rotation_row.add_child(rotate)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 48
	right.add_child(description)
	equip_button = Button.new()
	equip_button.pressed.connect(func() -> void:
		busy = true
		status.text = "Saving equipment — waiting for acknowledgement…"
		_render()
		equip_requested.emit(selected))
	right.add_child(equip_button)
	odds = Label.new()
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds.custom_minimum_size.y = 42
	content.add_child(odds)
	reward = Label.new()
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.custom_minimum_size.y = 42
	content.add_child(reward)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	box_select = OptionButton.new()
	box_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_select.item_selected.connect(func(_index: int) -> void: _render_box())
	actions.add_child(box_select)
	open_button = Button.new()
	open_button.text = "OPEN FREE BOX"
	open_button.pressed.connect(func() -> void:
		if not profile.pending.is_empty():
			busy = true
			status.text = "Opening — waiting for the saved receipt…"
			_render()
			open_requested.emit(profile.pending[box_select.selected].box_id))
	actions.add_child(open_button)
	skip_button = Button.new()
	skip_button.text = "SKIP ANIMATION"
	skip_button.pressed.connect(_finish_reveal)
	actions.add_child(skip_button)
	skip_button.hide()
	var refresh := Button.new()
	refresh.text = "REFRESH"
	refresh.pressed.connect(func() -> void: refresh_requested.emit())
	actions.add_child(refresh)
	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(dismiss)
	actions.add_child(close_button)
	visible = false
	_render()


func show_collection() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_render()
	outfit_buttons[0].grab_focus()


func dismiss() -> void:
	_finish_reveal()
	hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	closed.emit()


func present_profile(value: Dictionary, is_managed: bool, in_lobby: bool) -> void:
	profile = value.duplicate(true)
	managed = is_managed
	lobby = in_lobby
	busy = false
	status.text = "Saved service inventory" if managed else "Starter equipment only outside a profile-enabled room"
	_render()


func select_outfit(outfit_id: String) -> void:
	selected = outfit_id
	preview.set_outfit_id(outfit_id)
	_render()


func present_error(message: String) -> void:
	busy = false
	status.text = message
	_render()


func present_open(receipt: Dictionary) -> void:
	busy = false
	status.text = "Saved receipt acknowledged — ownership restored"
	var item_id: String = receipt.cosmetic_id
	if not item_id in profile.owned:
		profile.owned.append(item_id)
	profile.pending = profile.pending.filter(func(box: Dictionary) -> bool: return box.box_id != receipt.box_id)
	select_outfit(item_id)
	reward_text = "UNLOCKED: %s — yours to keep. Equip in the lobby." % _item_name(item_id)
	_render()
	_finish_reveal()
	if not reduced_motion and visible:
		reward.modulate.a = 0.35
		_reveal = create_tween()
		_reveal.tween_property(reward, "modulate:a", 1.0, 0.25)
		_reveal.finished.connect(func() -> void: skip_button.hide())
		skip_button.show()
		_refresh_focus()


func _finish_reveal() -> void:
	if is_instance_valid(_reveal):
		_reveal.kill()
	if is_instance_valid(reward):
		reward.modulate.a = 1.0
	if is_instance_valid(skip_button):
		skip_button.hide()


func _item_name(outfit_id: String) -> String:
	for item: Dictionary in ToyCharacterVisual.catalog().items:
		if item.id == outfit_id:
			return item.name
	return outfit_id


func _render() -> void:
	if not is_instance_valid(preview):
		return
	var remaining: Array[String] = []
	for index: int in outfit_buttons.size():
		var item: Dictionary = ToyCharacterVisual.catalog().items[index]
		var owned: bool = item.id in profile.owned
		outfit_buttons[index].text = "%s\n%s" % [item.name, "EQUIPPED" if item.id == profile.equipped else ("OWNED" if owned else "LOCKED")]
		outfit_buttons[index].tooltip_text = item.description
		if item.id == selected:
			description.text = "%s — %s" % [item.name, item.description]
		if item.pool == "earned" and not owned:
			remaining.append(item.name)
	# Sealed items stay private. Count reservation slots without claiming which item is reserved.
	var pool_count := maxi(0, remaining.size() - profile.pending.size())
	odds.text = "All rewards earned or reserved. No duplicates or empty boxes." if pool_count == 0 else "Next drop: equal 1/%d odds across %d available outfits. Owned items and sealed reservations excluded. Free only; no rarity tiers." % [pool_count, pool_count]
	if profile.pending.is_empty() and pool_count > 0:
		odds.text += " Pool: " + ", ".join(remaining)
	reward.text = reward_text
	var can_equip: bool = selected in profile.owned and (managed or selected in ["plain", "cap", "hard_hat", "backpack"])
	equip_button.text = "EQUIPPED" if selected == profile.equipped else ("EQUIP IN LOBBY" if not lobby else ("EQUIP" if can_equip else "LOCKED"))
	equip_button.disabled = busy or not lobby or not can_equip or selected == profile.equipped
	var previous := box_select.selected
	box_select.clear()
	for index: int in profile.pending.size():
		box_select.add_item("Sealed box %d — saved 1/%d odds" % [index + 1, profile.pending[index].odds.denominator])
	if profile.pending.is_empty():
		box_select.add_item("No sealed boxes")
	else:
		box_select.select(clampi(previous, 0, profile.pending.size() - 1))
	box_select.disabled = busy or profile.pending.is_empty()
	open_button.disabled = busy or profile.pending.is_empty()
	_render_box()
	_refresh_focus()


func _refresh_focus() -> void:
	var controls: Array[Control] = []
	for button: BaseButton in find_children("*", "BaseButton", true, false):
		if button.visible and not button.disabled:
			controls.append(button)
	for index: int in controls.size():
		var control := controls[index]
		control.focus_previous = control.get_path_to(controls[wrapi(index - 1, 0, controls.size())])
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_right = control.focus_next
		control.focus_neighbor_bottom = control.focus_next


func _render_box() -> void:
	if profile.pending.is_empty():
		return
	var box: Dictionary = profile.pending[box_select.selected]
	reward.text = "%s\nSelected box: equal 1/%d odds at grant among %s. Opening never rerolls." % [reward_text, box.odds.denominator, ", ".join(box.pool)]


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
