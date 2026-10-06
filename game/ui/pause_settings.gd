extends Control

# Local presentation only: never pauses the tree or sends session RPCs.
const DEFAULTS := {
	"master_volume": 1.0, "effects_volume": 1.0, "warning_volume": 1.0,
	"mouse_sensitivity": 1.0, "invert_y": false, "camera_shake": 1.0,
	"fullscreen": false, "reduced_motion": false,
}
var values := DEFAULTS.duplicate()
var config_path := "user://settings.cfg"
var controls: Dictionary = {}
var panel: PanelContainer
var settings_page: VBoxContainer
var pause_page: VBoxContainer
var resume: Button
var status: Label
var _main: Node
var _return_focus: Control
var _from_pause := false

func _ready() -> void:
	_main = get_parent().get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20
	var backdrop := ColorRect.new()
	backdrop.color = Color(DisasterPartyUI.INK, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -302
	panel.offset_bottom = 302
	var style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	style.bg_color.a = 1.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var title := Label.new()
	title.text = "LOCAL MENU"
	title.add_theme_font_size_override("font_size", DisasterPartyUI.FONT_TITLE)
	content.add_child(title)
	var note := Label.new()
	note.text = "The match keeps running — stay safe!"
	content.add_child(note)
	pause_page = VBoxContainer.new()
	content.add_child(pause_page)
	var settings := Button.new()
	settings.text = "SETTINGS"
	pause_page.add_child(settings)
	settings.pressed.connect(show_settings)
	settings_page = VBoxContainer.new()
	settings_page.add_theme_constant_override("separation", 6)
	content.add_child(settings_page)
	for key: String in DEFAULTS:
		var row := HBoxContainer.new()
		settings_page.add_child(row)
		var label := Label.new()
		label.text = key.replace("_", " ").capitalize()
		label.custom_minimum_size.x = 190
		row.add_child(label)
		var control: Control
		if DEFAULTS[key] is bool:
			var toggle := CheckButton.new()
			toggle.text = "ON / OFF"
			toggle.toggled.connect(func(value: bool) -> void: _change(key, value))
			control = toggle
		else:
			var slider := HSlider.new()
			slider.min_value = 0.2 if key == "mouse_sensitivity" else 0.0
			slider.max_value = 3.0 if key == "mouse_sensitivity" else 1.0
			slider.step = 0.01
			slider.value_changed.connect(func(value: float) -> void: _change(key, value))
			control = slider
		control.name = key
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.y = 34
		control.tooltip_text = label.text
		row.add_child(control)
		if control is HSlider:
			# HSlider has no native focus StyleBox slot; draw the shared ring explicitly.
			control.draw.connect(func() -> void:
				if control.has_focus():
					control.draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, control.size))
			)
			control.focus_entered.connect(control.queue_redraw)
			control.focus_exited.connect(control.queue_redraw)
		var value_label := Label.new()
		value_label.name = "Value"
		value_label.custom_minimum_size.x = 58
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		controls[key] = control
	var reset := Button.new()
	reset.text = "RESTORE DEFAULTS"
	settings_page.add_child(reset)
	controls["defaults"] = reset
	reset.pressed.connect(func() -> void:
		values = DEFAULTS.duplicate()
		_sync_controls()
		_save()
		apply_preferences()
	)
	status = Label.new()
	status.text = "Changes save automatically"
	content.add_child(status)
	resume = Button.new()
	resume.text = "BACK"
	content.add_child(resume)
	resume.pressed.connect(back)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--settings-path="):
			config_path = argument.trim_prefix("--settings-path=")
	load_preferences(config_path)
	_sync_controls()
	apply_preferences()
	hide()
	settings_page.hide()

func load_preferences(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for key: String in DEFAULTS:
		var value: Variant = config.get_value("preferences", key, DEFAULTS[key])
		if DEFAULTS[key] is bool:
			values[key] = value if value is bool else DEFAULTS[key]
		elif (value is float or value is int) and is_finite(float(value)):
			values[key] = clampf(float(value), 0.2 if key == "mouse_sensitivity" else 0.0, 3.0 if key == "mouse_sensitivity" else 1.0)

func _sync_controls() -> void:
	for key: String in DEFAULTS:
		if controls[key] is CheckButton:
			controls[key].set_pressed_no_signal(values[key])
		else:
			controls[key].set_value_no_signal(values[key])
		controls[key].get_parent().get_node("Value").text = ("ON" if values[key] else "OFF") if values[key] is bool else ("%.2f×" % values[key] if key == "mouse_sensitivity" else "%d%%" % roundi(values[key] * 100.0))
		controls[key].tooltip_text = "%s: %s" % [key.replace("_", " ").capitalize(), values[key]]

func _change(key: String, value: Variant) -> void:
	values[key] = value
	_sync_controls()
	_save()
	apply_preferences()

func _save() -> void:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value("preferences", key, values[key])
	var error := config.save(config_path)
	status.text = "Changes saved" if error == OK else "Could not save settings: %s" % error_string(error)
	if error != OK:
		_main.gameplay_audio.play_ui("error")

func apply_preferences() -> void:
	for bus: String in ["Master", "Effects", "Warnings"]:
		var key := "master_volume" if bus == "Master" else ("effects_volume" if bus == "Effects" else "warning_volume")
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), values[key])
	_main.gameplay_hud.reduced_motion = values.reduced_motion
	for player: PartyPlayer in _main._player_nodes.values():
		apply_player_preferences(player)
	apply_player_preferences(_main.get_node("Player"))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func apply_player_preferences(player: PartyPlayer) -> void:
	player.mouse_sensitivity = values.mouse_sensitivity
	player.invert_y = values.invert_y
	player.camera_shake_level = 0.0 if values.reduced_motion else values.camera_shake

func open_pause() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	_from_pause = true
	pause_page.show()
	settings_page.hide()
	resume.text = "RESUME"
	status.hide()
	panel.offset_top = -110
	panel.offset_bottom = 110
	panel.size.y = 220
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_focus()
	_main._update_lobby_ui()

func show_settings() -> void:
	if not visible:
		_return_focus = get_viewport().gui_get_focus_owner()
		_from_pause = false
	pause_page.hide()
	settings_page.show()
	resume.text = "BACK"
	status.show()
	panel.offset_top = -302
	panel.offset_bottom = 302
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_focus()
	_main._update_lobby_ui()

func back() -> void:
	_main.gameplay_audio.play_ui("back")
	if settings_page.visible and _from_pause:
		settings_page.hide()
		pause_page.show()
		resume.text = "RESUME"
		status.hide()
		panel.offset_top = -110
		panel.offset_bottom = 110
		panel.size.y = 220
		_refresh_focus()
		return
	hide()
	_main._set_lobby_visible(_main.get_node("Interface/LobbyPanel").visible)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	elif _main.match_manager.state == MatchManager.MatchState.RESULTS:
		_main.get_node("Interface/ResultsPanel/Table").scroll.grab_focus()

func _refresh_focus() -> void:
	var focusable: Array[Control] = []
	if settings_page.visible:
		for control: Control in controls.values():
			focusable.append(control)
	else:
		focusable.append(pause_page.get_child(0))
	focusable.append(resume)
	for index in focusable.size():
		var control := focusable[index]
		control.focus_previous = control.get_path_to(focusable[wrapi(index - 1, 0, focusable.size())])
		control.focus_next = control.get_path_to(focusable[(index + 1) % focusable.size()])
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
	focusable[0].grab_focus()
