extends PanelContainer
## Presentation-only action card; caller supplies the selected nearby pickup.

var title: Label
var status: Label
var prompt: Label
var reticle: Label


func _ready() -> void:
	name = "ToySabotageCard"
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -330
	offset_top = -184
	offset_right = -24
	offset_bottom = -76
	custom_minimum_size = Vector2(276, 96)
	theme_type_variation = "HudMetricCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	add_child(content)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 19)
	content.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 15)
	content.add_child(status)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", DisasterPartyUI.SLATE)
	content.add_child(prompt)
	reticle = Label.new()
	reticle.text = "+"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 22)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position -= Vector2(12, 12)
	reticle.size = Vector2(24, 24)
	# Keep the reticle in the same CanvasLayer/lifetime as the HUD, not on
	# the root Window where it can survive scene departure or sit behind3D.
	get_parent().call_deferred("add_child", reticle)
	hide()


func _exit_tree() -> void:
	if is_instance_valid(reticle):
		reticle.queue_free()


func present(slot: Dictionary, nearest: Dictionary, active: bool) -> void:
	visible = active
	reticle.visible = active
	if not active:
		return
	var kind := str(slot.get("kind", ""))
	var ammo := int(slot.get("ammo", 0))
	var cooldown := maxf(0.0, float(slot.get("cooldown", 0.0)))
	var feedback := str(slot.get("feedback", ""))
	title.text = "%s  %d" % [_name_for(kind), ammo] if not kind.is_empty() else "NO TOY HELD"
	var messages := {"empty": "No charges — find another toy", "range": "Move closer to a toy", "protected": "Opening protection", "aim": "Aim along a clear firing line", "capacity": "Too many toys active — wait", "blocked": "Blocked / protected", "hit": "Hit!", "miss": "Miss"}
	status.text = messages.get(feedback, "COOLDOWN %.1fs" % cooldown if cooldown > 0.0 else "LEFT MOUSE  USE  •  G  SHOVE")
	var nearby_kind := str(nearest.get("kind", ""))
	prompt.text = "[F] %s %s" % ["TAKE" if kind.is_empty() else "SWAP", _name_for(nearby_kind)] if not nearby_kind.is_empty() else "F  TAKE / SWAP WHEN NEAR A TOY"


func _name_for(kind: String) -> String:
	return {"foam_blaster": "FOAM BLASTER", "plunger_rocket": "PLUNGER ROCKET", "squeaky_hammer": "SQUEAKY HAMMER"}.get(kind, "TOY")
