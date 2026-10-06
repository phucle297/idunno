extends SceneTree

const UITokens = preload("res://game/ui/ui_tokens.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var theme := UITokens.build_theme()
	_expect(theme.get_color("ink", "ToyBroadcast") == Color("202a38"), "UI ink must match the design bible")
	_expect(theme.get_color("warning", "ToyBroadcast") == Color("ffbf3f"), "Warning token must match the design bible")
	_expect(theme.get_color("lightning", "ToyBroadcast") == Color("b892ff"), "Lightning token must match the design bible")
	_expect(theme.get_constant("safe_margin", "ToyBroadcast") == 24, "Safe margin must remain 24 px")
	_expect(theme.get_constant("space_sm", "ToyBroadcast") == 8, "Small spacing must remain 8 px")
	_expect(theme.get_constant("font_display", "ToyBroadcast") == 30, "Display typography must remain 30 px")

	var button_normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var button_focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	var line_edit_focus := theme.get_stylebox("focus", "LineEdit") as StyleBoxFlat
	var panel := theme.get_stylebox("panel", "Panel") as StyleBoxFlat
	_expect(button_normal != null and button_normal.bg_color == UITokens.SLATE, "Buttons must use the slate primary surface")
	_expect(button_focus != null and button_focus.border_color == UITokens.WARNING, "Button focus must use a non-color-independent visible ring")
	_expect(line_edit_focus != null and line_edit_focus.border_width_left == UITokens.FOCUS_WIDTH, "Focused fields must use the shared focus width")
	_expect(panel != null and panel.corner_radius_top_left == UITokens.PANEL_RADIUS, "Panels must use the shared rounded radius")
	_expect(panel != null and panel.content_margin_left == UITokens.SPACE_XL, "Panels must use shared internal spacing")

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var lobby_button := main.get_node("Interface/LobbyToggle") as Button
	var lobby_panel := main.get_node("Interface/LobbyPanel") as Panel
	var address_field := main.get_node("Interface/LobbyPanel/Address") as LineEdit
	_expect(lobby_button.theme != null, "Top-level controls must receive the shared theme")
	_expect(lobby_panel.theme == lobby_button.theme, "Panels and buttons must share one theme resource")
	_expect(address_field.get_theme_stylebox("focus") is StyleBoxFlat, "Nested fields must inherit the shared focus style")
	main._set_lobby_visible(true)
	await process_frame
	_expect(root.gui_get_focus_owner() == address_field, "Opening the lobby must place keyboard focus in the first field")
	main.free()
	await process_frame

	if failures.is_empty():
		print("UI_THEME_OK checks=%d" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
