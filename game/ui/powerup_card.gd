extends PanelContainer

signal collection_feedback

var title: Label
var notice: Label
var icon: Control
var _kind := 0
var _id := 0
var _round := -1
var _notice_remaining := 0.0


func _ready() -> void:
	name = "PowerupCard"
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 24
	offset_right = 310
	offset_top = -184
	offset_bottom = -104
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = "HudMetricCard"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	icon = preload("res://game/ui/disaster_icon.gd").new()
	icon.custom_minimum_size = Vector2(28, 28)
	row.add_child(icon)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)
	notice = Label.new()
	notice.add_theme_font_size_override("font_size", 14)
	content.add_child(notice)
	hide()


func _process(delta: float) -> void:
	_notice_remaining = maxf(0, _notice_remaining - delta)


func present(kind: int, remaining: float, pickup_id: int, round_sequence: int, allowed: bool) -> void:
	if not allowed or round_sequence != _round:
		_kind = 0
		_id = 0
		_notice_remaining = 0
	_round = round_sequence
	if not allowed:
		hide()
		return
	if kind != 0 and pickup_id != _id:
		var action := "PICKED UP" if _kind == 0 else ("REFRESHED" if kind == _kind else "REPLACED " + _name_for(_kind))
		notice.text = "%s  •  +20%%" % action
		_notice_remaining = 2.0
		collection_feedback.emit()
	elif kind == 0 and _kind != 0:
		notice.text = "EXPIRED  •  BASE MOVEMENT"
		_notice_remaining = 2.0
	_kind = kind
	_id = pickup_id
	visible = kind != 0 or _notice_remaining > 0
	icon.disaster_id = "speed" if kind == MatchPowerups.Kind.SPEED else "jump"
	icon.visible = kind != 0
	title.text = "%s  •  %ds" % [_name_for(kind), ceili(remaining)] if kind != 0 else "POWER-UP ENDED"
	if kind != 0 and _notice_remaining <= 0:
		notice.text = "+20% MOVE SPEED" if kind == MatchPowerups.Kind.SPEED else "+20% JUMP HEIGHT"


func _name_for(kind: int) -> String:
	return "SPEED" if kind == MatchPowerups.Kind.SPEED else "JUMP"
