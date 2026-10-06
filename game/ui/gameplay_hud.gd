class_name GameplayHud
extends CanvasLayer

enum FloodExposure {
	SAFE,
	WADING,
	SUBMERGED,
	DROWNING,
}

@onready var health_label: Label = $Health
@onready var alive_label: Label = $Alive
@onready var timer_label: Label = $Timer
@onready var state_label: Label = $State
@onready var help_label: Label = $Help
@onready var hazard_label: Label = $MeteorWarning
@onready var flood_overlay: ColorRect = $FloodOverlay
@onready var flood_danger_label: Label = $FloodDanger
@onready var spectating_label: Label = $Spectating


func present_vitals(health: float, alive_count: int, player_count: int) -> void:
	health_label.text = "HP  %d" % int(health)
	alive_label.text = "ALIVE  %d / %d" % [alive_count, player_count]


func present_match_status(remaining_seconds: int, state_text: String, results_visible: bool, controls_visible: bool) -> void:
	timer_label.text = "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	state_label.text = state_text
	timer_label.visible = not results_visible
	state_label.visible = not results_visible
	help_label.visible = controls_visible


func present_hazards(lines: Array[String]) -> void:
	hazard_label.visible = not lines.is_empty()
	hazard_label.text = "\n".join(lines)


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
