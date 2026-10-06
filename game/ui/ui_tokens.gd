class_name DisasterPartyUI
extends RefCounted

const CREAM := Color("f4e6c8")
const SAND := Color("d9b77e")
const SLATE := Color("49566a")
const TEAL := Color("73b7ad")
const CORAL := Color("d98d7d")
const GRASS := Color("86a968")
const WATER := Color("42b8e8")
const WARNING := Color("ffbf3f")
const DANGER := Color("f06438")
const LIGHTNING := Color("b892ff")
const INK := Color("202a38")
const WHITE := Color("fffaf0")
const COLORS := {
	"cream": CREAM,
	"sand": SAND,
	"slate": SLATE,
	"teal": TEAL,
	"coral": CORAL,
	"grass": GRASS,
	"water": WATER,
	"warning": WARNING,
	"danger": DANGER,
	"lightning": LIGHTNING,
	"ink": INK,
	"white": WHITE,
}

const FONT_DISPLAY := 30
const FONT_TITLE := 24
const FONT_METRIC := 26
const FONT_BODY := 16
const FONT_CAPTION := 14

const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24
const SAFE_MARGIN := 24
const CONTROL_HEIGHT := 40
const PANEL_RADIUS := 20
const CONTROL_RADIUS := 12
const FOCUS_WIDTH := 3


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY

	_set_color_tokens(theme)
	_set_size_tokens(theme)
	_set_label_theme(theme)
	_set_button_theme(theme)
	_set_line_edit_theme(theme)
	_set_panel_theme(theme)
	return theme


static func _set_color_tokens(theme: Theme) -> void:
	for token: StringName in COLORS:
		theme.set_color(token, "ToyBroadcast", COLORS[token])


static func _set_size_tokens(theme: Theme) -> void:
	var constants := {
		"font_display": FONT_DISPLAY,
		"font_title": FONT_TITLE,
		"font_metric": FONT_METRIC,
		"font_body": FONT_BODY,
		"font_caption": FONT_CAPTION,
		"space_xs": SPACE_XS,
		"space_sm": SPACE_SM,
		"space_md": SPACE_MD,
		"space_lg": SPACE_LG,
		"space_xl": SPACE_XL,
		"safe_margin": SAFE_MARGIN,
		"control_height": CONTROL_HEIGHT,
		"panel_radius": PANEL_RADIUS,
		"control_radius": CONTROL_RADIUS,
		"focus_width": FOCUS_WIDTH,
	}
	for token: StringName in constants:
		theme.set_constant(token, "ToyBroadcast", constants[token])


static func _set_label_theme(theme: Theme) -> void:
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_shadow_color", "Label", Color(INK, 0.16))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_font_size("font_size", "Label", FONT_BODY)


static func _set_button_theme(theme: Theme) -> void:
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", CREAM)
	theme.set_color("font_disabled_color", "Button", Color(INK, 0.72))
	theme.set_font_size("font_size", "Button", FONT_BODY)
	theme.set_stylebox("normal", "Button", _control_style(SLATE, SLATE))
	theme.set_stylebox("hover", "Button", _control_style(TEAL, INK))
	theme.set_stylebox("pressed", "Button", _control_style(WARNING, INK))
	theme.set_stylebox("disabled", "Button", _control_style(Color(SAND, 0.68), Color(SLATE, 0.38)))
	theme.set_stylebox("focus", "Button", _focus_style())


static func _set_line_edit_theme(theme: Theme) -> void:
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_selected_color", "LineEdit", INK)
	theme.set_color("font_uneditable_color", "LineEdit", Color(INK, 0.52))
	theme.set_color("font_placeholder_color", "LineEdit", Color(SLATE, 0.72))
	theme.set_color("caret_color", "LineEdit", DANGER)
	theme.set_color("selection_color", "LineEdit", Color(TEAL, 0.55))
	theme.set_font_size("font_size", "LineEdit", FONT_BODY)
	theme.set_stylebox("normal", "LineEdit", _control_style(Color(CREAM, 0.96), SLATE))
	theme.set_stylebox("focus", "LineEdit", _control_style(Color(CREAM, 1.0), WARNING, FOCUS_WIDTH))
	theme.set_stylebox("read_only", "LineEdit", _control_style(Color(CREAM, 0.6), Color(SLATE, 0.45)))


static func _set_panel_theme(theme: Theme) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(CREAM, 0.96)
	panel.border_color = SLATE
	_set_border_width(panel, 4)
	_set_corner_radius(panel, PANEL_RADIUS)
	_set_content_margin(panel, SPACE_XL, SPACE_LG)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	theme.set_type_variation("HudMetricCard", "PanelContainer")
	var metric_card := panel.duplicate() as StyleBoxFlat
	_set_content_margin(metric_card, SPACE_LG, SPACE_SM)
	theme.set_stylebox("panel", "HudMetricCard", metric_card)

	theme.set_type_variation("HudPill", "PanelContainer")
	var pill := _control_style(Color(CREAM, 0.96), SLATE, 3)
	theme.set_stylebox("panel", "HudPill", pill)

	theme.set_type_variation("HazardChip", "PanelContainer")
	var hazard_chip := _control_style(Color(SLATE, 0.96), WARNING, 3)
	theme.set_stylebox("panel", "HazardChip", hazard_chip)

	var health_background := _control_style(Color(SLATE, 0.28), Color(SLATE, 0.6), 2)
	var health_fill := _control_style(TEAL, SLATE, 2)
	theme.set_stylebox("background", "HudHealthBar", health_background)
	theme.set_stylebox("fill", "HudHealthBar", health_fill)
	theme.set_type_variation("HudHealthBar", "ProgressBar")


static func _control_style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	_set_border_width(style, width)
	_set_corner_radius(style, CONTROL_RADIUS)
	_set_content_margin(style, SPACE_LG, SPACE_SM)
	return style


static func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = WARNING
	_set_border_width(style, FOCUS_WIDTH)
	_set_corner_radius(style, CONTROL_RADIUS + FOCUS_WIDTH)
	style.expand_margin_left = FOCUS_WIDTH
	style.expand_margin_top = FOCUS_WIDTH
	style.expand_margin_right = FOCUS_WIDTH
	style.expand_margin_bottom = FOCUS_WIDTH
	return style


static func _set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width


static func _set_corner_radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius


static func _set_content_margin(style: StyleBoxFlat, horizontal: int, vertical: int) -> void:
	style.content_margin_left = horizontal
	style.content_margin_top = vertical
	style.content_margin_right = horizontal
	style.content_margin_bottom = vertical
