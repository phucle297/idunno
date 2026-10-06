class_name GameplayHud
extends CanvasLayer

enum FloodExposure {
	SAFE,
	WADING,
	SUBMERGED,
	DROWNING,
}

const MAX_HAZARD_CHIPS := 2

@onready var health_card: PanelContainer = $HealthCard
@onready var health_label: Label = $HealthCard/Content/MetricRow/Health
@onready var health_bar: ProgressBar = $HealthCard/Content/HealthBar
@onready var alive_label: Label = $AlivePill/Content/Alive
@onready var timer_card: PanelContainer = $TimerCard
@onready var timer_label: Label = $TimerCard/Content/Timer
@onready var state_label: Label = $TimerCard/Content/State
@onready var help_label: Label = $Help
@onready var hazard_tray: VBoxContainer = $HazardTray
@onready var hazard_chips: Array[PanelContainer] = [
	$HazardTray/HazardChip1,
	$HazardTray/HazardChip2,
]
@onready var flood_overlay: ColorRect = $FloodOverlay
@onready var flood_danger_label: Label = $FloodDanger
@onready var spectating_label: Label = $Spectating

var _presented_health := 0
var _presented_alive_counts := Vector2i.ZERO
var _presented_hazards: Array[String] = []


func present_vitals(health: float, alive_count: int, player_count: int) -> void:
	_presented_health = int(health)
	_presented_alive_counts = Vector2i(alive_count, player_count)
	health_label.text = "%d" % _presented_health
	health_bar.value = clampf(health, health_bar.min_value, health_bar.max_value)
	alive_label.text = "%d / %d" % [alive_count, player_count]


func present_match_status(remaining_seconds: int, state_text: String, results_visible: bool, controls_visible: bool) -> void:
	timer_label.text = "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	state_label.text = state_text
	timer_card.visible = not results_visible
	help_label.visible = controls_visible


func present_hazards(lines: Array[String]) -> void:
	_presented_hazards.clear()
	for index: int in mini(lines.size(), MAX_HAZARD_CHIPS):
		_presented_hazards.append(lines[index])
	for index: int in MAX_HAZARD_CHIPS:
		var chip := hazard_chips[index]
		var chip_visible := index < _presented_hazards.size()
		chip.visible = chip_visible
		if chip_visible:
			(chip.get_node("Text") as Label).text = _presented_hazards[index]
	hazard_tray.visible = not _presented_hazards.is_empty()


func present_flood_exposure(exposure: FloodExposure, grace_remaining: float = 0.0, damage_per_second: float = 0.0) -> void:
	var submerged := exposure == FloodExposure.SUBMERGED or exposure == FloodExposure.DROWNING
	flood_overlay.visible = submerged
	flood_danger_label.visible = exposure != FloodExposure.SAFE
	health_label.modulate = Color.WHITE

	match exposure:
		FloodExposure.WADING:
			flood_danger_label.text = "IN FLOODWATER  •  KEEP YOUR HEAD ABOVE WATER"
		FloodExposure.SUBMERGED:
			flood_danger_label.text = "HOLD BREATH — %.1f s  •  REACH HIGH GROUND" % grace_remaining
			flood_overlay.color.a = 0.12
		FloodExposure.DROWNING:
			flood_danger_label.text = "DROWNING  •  -%d HP/s  •  GET ABOVE WATER" % int(damage_per_second)
			var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.012) * 0.18
			health_label.modulate = Color(1.0, pulse, pulse)
			flood_overlay.color.a = 0.18 + sin(Time.get_ticks_msec() * 0.01) * 0.04


func set_spectating_visible(visible: bool) -> void:
	spectating_label.visible = visible


func present_spectator_target(player_name: String) -> void:
	spectating_label.text = (
		"NO SURVIVORS TO SPECTATE" if player_name.is_empty()
		else "SPECTATING  %s   •   Q / E cycle" % player_name
	)


func get_presented_health() -> int:
	return _presented_health


func get_presented_alive_counts() -> Vector2i:
	return _presented_alive_counts


func get_presented_hazards() -> Array[String]:
	return _presented_hazards.duplicate()
