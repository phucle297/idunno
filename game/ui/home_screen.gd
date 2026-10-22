extends Control
## Dedicated, full-canvas preparation pages; gameplay remains owned by main.

const UI = preload("res://game/ui/ui_tokens.gd")
const MAP_TEXTURES := [preload("res://assets/ui/toy_town.png"), preload("res://assets/ui/toy_harbor.png")]
var page := "home"
var _main: Node
var canvas: Control
var home: Control
var maps: Control
var solo: Button
var start: Button
var outfits: Button
var settings: Button
var multiplayer_button: Button
var map_buttons: Array[Button] = []
var map_labels: Array[Label] = []
var mode_buttons: Array[Button] = []
var summary: Label
var preview: ToyCharacterVisual
var preview_viewport: SubViewport
var town_stage: Node3D
var _outfit := ""
var _selection := ""


func _ready() -> void:
	_main = get_parent().get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 5
	canvas = Control.new()
	canvas.size = Vector2(1280, 720)
	add_child(canvas)
	var background := ColorRect.new()
	background.color = UI.CREAM
	background.size = canvas.size
	canvas.add_child(background)
	home = Control.new()
	home.size = canvas.size
	canvas.add_child(home)
	_build_home()
	maps = Control.new()
	maps.size = canvas.size
	canvas.add_child(maps)
	_build_maps()
	resized.connect(_layout)
	_layout()
	show_page("home")


func _layout() -> void:
	if not is_instance_valid(canvas):
		return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - canvas.size * factor) * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.CREAM)


func _label(parent: Control, text: String, rect: Rect2, font_size: int, color := UI.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 28:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Arial", "DejaVu Sans"])
		font.font_weight = 800
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, rect: Rect2, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", UI.INK)
	button.add_theme_color_override("font_focus_color", UI.INK)
	button.add_theme_stylebox_override("normal", _style(UI.WARNING if primary else UI.WHITE))
	button.add_theme_stylebox_override("hover", _style(UI.SAND))
	button.add_theme_stylebox_override("pressed", _style(UI.TEAL))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UI.SAND
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(UI.INK, 0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	return style


func _picture(parent: Control, texture: Texture2D, rect: Rect2) -> void:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)


func _build_home() -> void:
	_build_character_stage()
	var title := _label(home, "DISASTER\nPARTY", Rect2(40, 40, 580, 210), 84)
	title.add_theme_color_override("font_outline_color", UI.WHITE)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_constant_override("line_spacing", -20)
	var tagline := _label(home, "Tiny town. Big trouble.", Rect2(48, 254, 460, 40), 28)
	tagline.add_theme_color_override("font_outline_color", UI.WHITE)
	tagline.add_theme_constant_override("outline_size", 8)
	solo = _button(home, "▶  PLAY SOLO", Rect2(48, 332, 390, 82), func() -> void: show_page("maps"), true)
	solo.add_theme_font_size_override("font_size", 32)
	multiplayer_button = _button(home, "MULTIPLAYER", Rect2(48, 430, 350, 64), func() -> void:
		page = "room"
		_main._set_lobby_visible(true))
	outfits = _button(home, "OUTFITS", Rect2(48, 510, 300, 64), _main._show_collection)
	settings = _button(home, "SETTINGS", Rect2(1050, 24, 200, 48), _main.pause_settings.show_settings)
	_button(home, "QUIT", Rect2(48, 644, 130, 44), func() -> void: get_tree().quit())


func _build_character_stage() -> void:
	var container := SubViewportContainer.new()
	container.size = Vector2(1280, 720)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(container)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(1280, 720)
	preview_viewport.own_world_3d = true
	preview_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(preview_viewport)
	town_stage = preload("res://game/ui/home_town_stage.gd").new()
	preview_viewport.add_child(town_stage)
	town_stage.build(_main)
	preview = town_stage.character


func _build_maps() -> void:
	_button(maps, "←  BACK", Rect2(48, 24, 160, 48), func() -> void: show_page("home"))
	_label(maps, "CHOOSE YOUR MAP", Rect2(48, 96, 1100, 64), 48)
	_label(maps, "SOLO  /  Pick your playground", Rect2(52, 168, 1100, 28), 20, UI.SLATE)
	var descriptions := ["Streets, rooftops and sheltered interiors.", "Docks, warehouses and open waterfronts."]
	for index in 2:
		var x := 48 + index * 600
		var button := _button(maps, "", Rect2(x, 220, 584, 322), func() -> void:
			_main.get_node("Interface/LobbyPanel/MapSelect").item_selected.emit(index)
			refresh())
		button.tooltip_text = _main.MAP_TITLES[_main.MAP_IDS[index]]
		map_buttons.append(button)
		_picture(button, MAP_TEXTURES[index], Rect2(12, 12, 560, 222))
		map_labels.append(_label(button, _main.MAP_TITLES[_main.MAP_IDS[index]].to_upper(), Rect2(20, 244, 540, 36), 28))
		_label(button, descriptions[index], Rect2(20, 285, 540, 26), 18, UI.SLATE)
	_label(maps, "MATCH MODE", Rect2(52, 574, 400, 28), 20)
	for index in 2:
		mode_buttons.append(_button(maps, ["NORMAL", "HARD"][index], Rect2(48 + index * 180, 616, 164, 58), func() -> void:
			_main.get_node("Interface/LobbyPanel/PresetSelect").item_selected.emit(index)
			refresh()))
	summary = _label(maps, "", Rect2(840, 574, 390, 28), 20, UI.SLATE)
	start = _button(maps, "START SOLO   →", Rect2(900, 616, 332, 64), func() -> void: _main.start_local_match(), true)


func show_page(value: String) -> void:
	page = value
	if page == "maps" and _main.get_match_preset() == "hot_potato":
		_main.request_match_preset("normal") # Multiplayer-only rules cannot remain as a hidden solo selection.
	refresh()
	if is_instance_valid(_main.room_client):
		_main._update_lobby_ui()
	focus_default()


func focus_default() -> void:
	var target := solo if page == "home" else map_buttons[0]
	target.grab_focus()


func refresh() -> void:
	home.visible = page == "home"
	maps.visible = page == "maps"
	var active: bool = visible and home.visible and not _main.collection.visible and not _main.pause_settings.visible
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	town_stage.set_motion(active, _main.pause_settings.values.reduced_motion)
	var outfit: String = _main.get_outfit_id()
	if outfit != _outfit:
		_outfit = outfit
		preview.set_outfit_id(outfit)
	start.disabled = not _main._outfit_pending.is_empty()
	var selection: String = _main.get_map_id() + _main.get_match_preset()
	if selection == _selection:
		return
	_selection = selection
	for index in map_buttons.size():
		var selected: bool = _main.get_map_id() == _main.MAP_IDS[index]
		map_buttons[index].add_theme_stylebox_override("normal", _style(UI.WARNING if selected else UI.WHITE))
		map_labels[index].text = _main.MAP_TITLES[_main.MAP_IDS[index]].to_upper() + ("  ✓" if selected else "")
	for index in mode_buttons.size():
		var selected: bool = _main.get_match_preset() == _main.MATCH_PRESETS[index]
		mode_buttons[index].add_theme_stylebox_override("normal", _style(UI.WARNING if selected else UI.WHITE))
		mode_buttons[index].text = ("✓  " if selected else "") + ["NORMAL", "HARD"][index]
	summary.text = _main.MAP_TITLES[_main.get_map_id()] + " / " + _main.MATCH_PRESET_TITLES[_main.get_match_preset()]
