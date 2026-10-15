class_name GameplayHud
extends CanvasLayer

signal warning_countdown_tick
signal spectator_cycle_requested(direction: int)

enum FloodExposure {
	SAFE,
	WADING,
	SUBMERGED,
	DROWNING,
	ELECTRIFIED,
}

const MAX_HAZARD_CHIPS := 2
const UITokens = preload("res://game/ui/ui_tokens.gd")
const WARNING_COPY := {
	"meteor": ["METEOR INCOMING", "MOVE OUT OF THE IMPACT RING"],
	"flood": ["FLOOD INCOMING", "REACH HIGH GROUND"],
	"tornado": ["TORNADO INCOMING", "FIND INDOOR COVER"],
	"earthquake": ["EARTHQUAKE INCOMING", "LEAVE CRACKS AND UNSTABLE ROOFS"],
	"lightning": ["LIGHTNING INCOMING", "LEAVE THE RING AND WATER"],
	"fire": ["FIRE INCOMING", "AVOID BURNING ZONES"],
	"rain": ["RAIN INCOMING", "EXPOSED GROUND GETS WET — FIRE COOLS"],
	"snowfall": ["SNOWFALL INCOMING", "WALK TO BRAKE — SHELTER STAYS DRY"],
	"rockslide": ["ROCKSLIDE INCOMING", "LEAVE THE DOWNHILL LANE — USE SOLID COVER"],
	"bees": ["BEE SWARM INCOMING", "RUN — BREAK PURSUIT UNDER COVER OR DIVE INTO WATER"],
	"ufo": ["UFO INCOMING", "LEAVE THE FIXED BEAM RING — TAKE OVERHEAD COVER"],
	"volcano": ["VOLCANO INCOMING", "EVACUATE THE OUTLINED DISTRICT — HOT GROUND FOR 60s"],
}

@onready var health_card: PanelContainer = $HealthCard
@onready var health_label: Label = $HealthCard/Content/MetricRow/Health
@onready var health_bar: ProgressBar = $HealthCard/Content/HealthBar
@onready var alive_label: Label = $AlivePill/Content/Alive
@onready var shove_pill: PanelContainer = $ShovePill
@onready var shove_state_label: Label = $ShovePill/Content/State
@onready var timer_card: PanelContainer = $TimerCard
@onready var timer_label: Label = $TimerCard/Content/Timer
@onready var state_label: Label = $TimerCard/Content/State
@onready var terrain_card: PanelContainer = $TerrainStatus
@onready var terrain_status: Label = $TerrainStatus/Content/Status
@onready var terrain_entry: Label = $TerrainStatus/Content/Entry
@onready var hazard_tray: VBoxContainer = $HazardTray
@onready var hazard_chips: Array[PanelContainer] = [
	$HazardTray/HazardChip1,
	$HazardTray/HazardChip2,
]
@onready var context_prompt: PanelContainer = $ContextPrompt
@onready var context_action_label: Label = $ContextPrompt/Content/Action
@onready var personal_danger: PanelContainer = $PersonalDanger
@onready var danger_status: Label = $PersonalDanger/Content/Status
@onready var danger_action: Label = $PersonalDanger/Content/Action
@onready var spectator_card: PanelContainer = $Spectating
@onready var spectating_label: Label = $Spectating/Content/TargetRow/Identity/Name
@onready var spectator_survivors: Label = $Spectating/Content/TargetRow/Identity/Survivors
@onready var spectator_previous: Button = $Spectating/Content/TargetRow/Previous
@onready var spectator_next: Button = $Spectating/Content/TargetRow/Next
@onready var elimination_label: Label = $Spectating/Content/Elimination
@onready var warning_banner: PanelContainer = $MajorWarning
@onready var warning_icon: Control = $MajorWarning/Content/Icon
@onready var warning_name: Label = $MajorWarning/Content/Copy/Name
@onready var warning_action: Label = $MajorWarning/Content/Copy/Action
@onready var warning_countdown: Label = $MajorWarning/Content/Countdown

var _presented_health := 0
var _presented_alive_counts := Vector2i.ZERO
var _presented_hazards: Array[String] = []
var _presented_context_action := ""
var _warning_id := ""
var _warning_seconds := 0
var _warning_tween: Tween
var _countdown_tween: Tween
var _lobby_open := false
var _results_visible := false
var _spectating := false
var _elimination_remaining := 0.0
var _spectator_tween: Tween
var reduced_motion := false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			$ResultsPanel/Table.reduced_motion = value
		if value and is_node_ready():
			_clear_warning_motion()
			_clear_spectator_motion()


func _ready() -> void:
	var timer_surface := timer_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	timer_surface.bg_color = Color(UITokens.INK, 0.94)
	timer_surface.border_color = UITokens.SLATE
	timer_card.add_theme_stylebox_override("panel", timer_surface)
	terrain_card.add_theme_stylebox_override("panel", timer_surface.duplicate())
	timer_label.add_theme_color_override("font_color", UITokens.WHITE)
	state_label.add_theme_color_override("font_color", UITokens.TEAL)
	for metric: Array in [["HealthCard/Content/MetricRow", "health"], ["AlivePill/Content", "survivors"]]:
		var row: HBoxContainer = get_node(metric[0])
		var icon := preload("res://game/ui/disaster_icon.gd").new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.disaster_id = metric[1]
		row.add_child(icon)
		row.move_child(icon, 0)
		row.add_theme_constant_override("separation", 10)
	spectator_previous.pressed.connect(func() -> void: spectator_cycle_requested.emit(-1))
	spectator_next.pressed.connect(func() -> void: spectator_cycle_requested.emit(1))
	spectator_previous.focus_next = spectator_previous.get_path_to(spectator_next)
	spectator_previous.focus_previous = spectator_previous.focus_next
	spectator_previous.focus_neighbor_right = spectator_previous.focus_next
	spectator_next.focus_next = spectator_next.get_path_to(spectator_previous)
	spectator_next.focus_previous = spectator_next.focus_next
	spectator_next.focus_neighbor_left = spectator_next.focus_next


func _process(delta: float) -> void:
	if _elimination_remaining > 0.0:
		_elimination_remaining = maxf(0.0, _elimination_remaining - delta)
		if _elimination_remaining == 0.0:
			elimination_label.hide()
			spectator_card.offset_top = -112.0


func present_vitals(health: float, alive_count: int, player_count: int) -> void:
	_presented_health = int(health)
	_presented_alive_counts = Vector2i(alive_count, player_count)
	health_label.text = "%d" % _presented_health
	health_bar.value = clampf(health, health_bar.min_value, health_bar.max_value)
	alive_label.text = "%d / %d" % [alive_count, player_count]


func present_shove_state(cooldown_remaining: float) -> void:
	shove_pill.visible = cooldown_remaining >= 0.0 and not _lobby_open and not _results_visible and not _spectating
	if not shove_pill.visible:
		return
	if cooldown_remaining <= 0.0:
		shove_state_label.text = "READY"
		shove_state_label.add_theme_color_override("font_color", UITokens.GRASS)
	else:
		shove_state_label.text = "%.1fs" % cooldown_remaining
		shove_state_label.add_theme_color_override("font_color", UITokens.WARNING)


func present_match_status(remaining_seconds: int, state_text: String, results_visible: bool) -> void:
	timer_label.text = "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	state_label.text = state_text
	_results_visible = results_visible
	present_lobby_overlay(_lobby_open)


func present_collapse(state: Dictionary, active: bool, point := Vector3.ZERO, personal := false) -> void:
	var pending := int(state.get("pending", -1))
	terrain_card.visible = active and pending >= 0 and not _lobby_open and not _results_visible
	_layout_pressure()
	if not terrain_card.visible:
		return
	var seconds := ceili(float(state.remaining))
	var countdown := "%d:%02d" % [seconds / 60, seconds % 60]
	terrain_status.text = "METEOR / DISTRICT COLLAPSE  •  %s" % countdown
	terrain_entry.text = "MARKED: %s" % String(state.get("region_name", "UNKNOWN DISTRICT"))
	var bounds: Rect2 = state.get("bounds", Rect2())
	var inside := personal and bounds.has_point(Vector2(point.x, point.z))
	terrain_status.add_theme_color_override("font_color", UITokens.WARNING if inside else UITokens.WHITE)
	terrain_entry.add_theme_color_override("font_color", UITokens.WARNING if inside else UITokens.CREAM)
	if inside:
		terrain_entry.text = "LEAVE MARKED GROUND  •  FALL IS LETHAL"
	elif not personal:
		terrain_entry.text = "MARKED: %s" % String(state.get("region_name", "UNKNOWN DISTRICT"))


func _layout_pressure() -> void:
	var shift := 64.0 if terrain_card.visible else 0.0
	warning_banner.offset_top = 112.0 + shift
	warning_banner.offset_bottom = 208.0 + shift
	hazard_tray.offset_top = (220.0 if warning_banner.visible else 120.0) + shift
	hazard_tray.offset_bottom = hazard_tray.offset_top + (88.0 if warning_banner.visible else 104.0)


func present_hazards(lines: Array[String]) -> void:
	_presented_hazards.clear()
	for index: int in mini(lines.size(), MAX_HAZARD_CHIPS):
		_presented_hazards.append(lines[index])
	for index: int in MAX_HAZARD_CHIPS:
		var chip := hazard_chips[index]
		var chip_visible := index < _presented_hazards.size()
		chip.visible = chip_visible
		if chip_visible:
			var line := _presented_hazards[index]
			(chip.get_node("Content/Text") as Label).text = line
			var names := line.get_slice(" — ", 0).split(" + ")
			var icon: Control = chip.get_node("Content/Icon")
			icon.disaster_id = names[0].to_lower()
			var second_icon: Control = chip.get_node("Content/SecondIcon")
			second_icon.visible = names.size() == 2
			second_icon.disaster_id = names[1].to_lower() if second_icon.visible else ""
	hazard_tray.visible = not _presented_hazards.is_empty() and not _lobby_open and not _results_visible


func present_context_action(action: String) -> void:
	_presented_context_action = action
	context_prompt.visible = not action.is_empty() and not personal_danger.visible and not _lobby_open and not _results_visible
	context_action_label.text = action


func present_major_warning(disaster_id: String, remaining_seconds: float = 0.0) -> void:
	var changed := disaster_id != _warning_id
	var seconds := maxi(1, ceili(remaining_seconds)) if not disaster_id.is_empty() else 0
	var countdown_decreased := not changed and seconds < _warning_seconds
	_warning_id = disaster_id
	# Snapshot corrections may increase the display, but must not replay an already heard tick.
	_warning_seconds = seconds if changed else mini(_warning_seconds, seconds)
	warning_banner.visible = not disaster_id.is_empty() and not _lobby_open and not _results_visible
	_layout_pressure()
	for chip: PanelContainer in hazard_chips:
		chip.custom_minimum_size.y = 40.0 if warning_banner.visible else 48.0
	if disaster_id.is_empty():
		_clear_warning_motion()
		return
	if warning_icon.disaster_id != disaster_id:
		warning_icon.disaster_id = disaster_id
	warning_name.text = WARNING_COPY[disaster_id][0]
	warning_action.text = WARNING_COPY[disaster_id][1]
	warning_countdown.text = "%d s" % seconds
	if changed:
		_clear_warning_motion()
		if not reduced_motion:
			warning_banner.modulate.a = 0.85
			_warning_tween = create_tween()
			_warning_tween.tween_property(warning_banner, "modulate:a", 1.0, 0.16)
	elif countdown_decreased and seconds <= 3:
		warning_countdown_tick.emit()
		if not reduced_motion:
			if _countdown_tween != null:
				_countdown_tween.kill()
			warning_countdown.modulate = DisasterPartyUI.CREAM
			_countdown_tween = create_tween()
			_countdown_tween.tween_property(warning_countdown, "modulate", Color.WHITE, 0.12)


func _clear_warning_motion() -> void:
	if _warning_tween != null:
		_warning_tween.kill()
	if _countdown_tween != null:
		_countdown_tween.kill()
	warning_banner.modulate = Color.WHITE
	warning_countdown.modulate = Color.WHITE


func present_flood_exposure(exposure: FloodExposure, grace_remaining: float = 0.0, damage_per_second: float = 0.0) -> void:
	personal_danger.visible = exposure != FloodExposure.SAFE and not _lobby_open and not _results_visible
	warning_action.visible = not personal_danger.visible
	context_prompt.visible = not _presented_context_action.is_empty() and not personal_danger.visible and not _lobby_open and not _results_visible
	danger_status.text = ""
	danger_action.text = ""
	match exposure:
		FloodExposure.WADING:
			danger_status.text = "IN FLOODWATER"
			danger_action.text = "KEEP YOUR HEAD ABOVE WATER"
		FloodExposure.SUBMERGED:
			danger_status.text = "HOLD BREATH — %.1f s" % maxf(0.0, grace_remaining)
			danger_action.text = "GET YOUR HEAD ABOVE WATER"
		FloodExposure.DROWNING:
			danger_status.text = "DROWNING — -%d HP/s" % int(damage_per_second)
			danger_action.text = "GET YOUR HEAD ABOVE WATER"
		FloodExposure.ELECTRIFIED:
			danger_status.text = "ELECTRIFIED WATER — -%d HP/s" % int(damage_per_second)
			danger_action.text = "LEAVE THE WATER"


func set_spectating_visible(visible: bool) -> void:
	_spectating = visible
	spectator_card.visible = visible and not _lobby_open and not _results_visible
	health_card.visible = not visible and not _lobby_open and not _results_visible
	if not visible:
		_elimination_remaining = 0.0
		elimination_label.hide()
		spectator_card.offset_top = -112.0
		_clear_spectator_motion()


func present_elimination(cause: String, survival_seconds: float) -> void:
	var seconds := maxi(0, int(survival_seconds))
	elimination_label.text = "ELIMINATED — %s  •  SURVIVED %02d:%02d" % [cause, seconds / 60, seconds % 60]
	elimination_label.show()
	_elimination_remaining = 2.5
	spectator_card.offset_top = -144.0
	_clear_spectator_motion()
	if not reduced_motion:
		spectator_card.modulate.a = 0.85
		_spectator_tween = create_tween()
		_spectator_tween.tween_property(spectator_card, "modulate:a", 1.0, 0.16)


func _clear_spectator_motion() -> void:
	if _spectator_tween != null:
		_spectator_tween.kill()
	spectator_card.modulate = Color.WHITE


func present_lobby_overlay(open: bool) -> void:
	_lobby_open = open
	health_card.visible = not open and not _spectating and not _results_visible
	spectator_card.visible = not open and _spectating and not _results_visible
	$AlivePill.visible = not open and not _results_visible
	timer_card.visible = not open and not _results_visible
	hazard_tray.visible = not open and not _presented_hazards.is_empty() and not _results_visible
	if open or _results_visible:
		terrain_card.hide()
		shove_pill.hide()
		present_major_warning("")
		present_context_action("")
		present_flood_exposure(FloodExposure.SAFE)


func present_spectator_target(player_name: String, survivor_count: int = 0) -> void:
	spectating_label.text = "NO SURVIVORS TO SPECTATE" if player_name.is_empty() else player_name
	spectating_label.tooltip_text = spectating_label.text
	spectator_survivors.text = "SPECTATING • %d %s" % [survivor_count, "SURVIVOR" if survivor_count == 1 else "SURVIVORS"]
	spectator_previous.disabled = player_name.is_empty() or survivor_count < 2
	spectator_next.disabled = spectator_previous.disabled


func get_presented_health() -> int:
	return _presented_health


func get_presented_alive_counts() -> Vector2i:
	return _presented_alive_counts


func get_presented_hazards() -> Array[String]:
	return _presented_hazards.duplicate()


func get_presented_context_action() -> String:
	return _presented_context_action
