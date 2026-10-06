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
const WARNING_COPY := {
	"meteor": ["METEOR INCOMING", "MOVE OUT OF THE IMPACT RING"],
	"flood": ["FLOOD INCOMING", "REACH HIGH GROUND"],
	"tornado": ["TORNADO INCOMING", "FIND INDOOR COVER"],
	"earthquake": ["EARTHQUAKE INCOMING", "AVOID BREAKING STRUCTURES"],
	"lightning": ["LIGHTNING INCOMING", "LEAVE THE RING AND WATER"],
	"fire": ["FIRE INCOMING", "AVOID BURNING ZONES"],
}

@onready var health_card: PanelContainer = $HealthCard
@onready var health_label: Label = $HealthCard/Content/MetricRow/Health
@onready var health_bar: ProgressBar = $HealthCard/Content/HealthBar
@onready var alive_label: Label = $AlivePill/Content/Alive
@onready var timer_card: PanelContainer = $TimerCard
@onready var timer_label: Label = $TimerCard/Content/Timer
@onready var state_label: Label = $TimerCard/Content/State
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
		if value and is_node_ready():
			_clear_warning_motion()
			_clear_spectator_motion()


func _ready() -> void:
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


func present_match_status(remaining_seconds: int, state_text: String, results_visible: bool) -> void:
	timer_label.text = "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	state_label.text = state_text
	_results_visible = results_visible
	timer_card.visible = not results_visible and not _lobby_open


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
	hazard_tray.visible = not _presented_hazards.is_empty() and not _lobby_open


func present_context_action(action: String) -> void:
	_presented_context_action = action
	context_prompt.visible = not action.is_empty() and not personal_danger.visible
	context_action_label.text = action


func present_major_warning(disaster_id: String, remaining_seconds: float = 0.0) -> void:
	var changed := disaster_id != _warning_id
	var seconds := maxi(1, ceili(remaining_seconds)) if not disaster_id.is_empty() else 0
	var countdown_decreased := not changed and seconds < _warning_seconds
	_warning_id = disaster_id
	# Snapshot corrections may increase the display, but must not replay an already heard tick.
	_warning_seconds = seconds if changed else mini(_warning_seconds, seconds)
	warning_banner.visible = not disaster_id.is_empty()
	hazard_tray.offset_top = 220.0 if warning_banner.visible else 120.0
	hazard_tray.offset_bottom = hazard_tray.offset_top + (88.0 if warning_banner.visible else 104.0)
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
	personal_danger.visible = exposure != FloodExposure.SAFE
	warning_action.visible = not personal_danger.visible
	context_prompt.visible = not _presented_context_action.is_empty() and not personal_danger.visible
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
	spectator_card.visible = visible and not _lobby_open
	health_card.visible = not visible and not _lobby_open
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
	health_card.visible = not open and not _spectating
	spectator_card.visible = not open and _spectating
	$AlivePill.visible = not open
	timer_card.visible = not open and not _results_visible
	hazard_tray.visible = not open and not _presented_hazards.is_empty()
	if open:
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
