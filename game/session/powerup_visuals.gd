extends Node3D
## Six non-physical toy tokens; no particles, lights, bodies or pickup authority.

var _slots: Array[Node3D] = []
var _clock := 0.0


func _ready() -> void:
	for index in MatchPowerups.MAX_PICKUPS:
		var slot := Node3D.new()
		slot.name = "Pickup%d" % index
		add_child(slot)
		var base := MeshInstance3D.new()
		base.name = "Pad"
		var disc := CylinderMesh.new()
		disc.top_radius = 0.42
		disc.bottom_radius = 0.42
		disc.height = 0.1
		disc.radial_segments = 16
		base.mesh = disc
		base.position.y = 0.06
		slot.add_child(base)
		var token := MeshInstance3D.new()
		token.name = "Token"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.65, 0.65, 0.12)
		token.mesh = mesh
		token.position.y = 0.85
		slot.add_child(token)
		var label := Label3D.new()
		label.name = "Identity"
		label.position.y = 1.55
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.pixel_size = 0.008
		label.outline_size = 12
		label.modulate = Color("fffaf0")
		label.outline_modulate = Color("202a38")
		slot.add_child(label)
		var symbol := Label3D.new()
		symbol.name = "Symbol"
		symbol.font_size = 64
		symbol.pixel_size = 0.008
		symbol.outline_size = 0
		symbol.modulate = Color("202a38")
		symbol.position = Vector3(0, 0, 0.068)
		token.add_child(symbol)
		for visual in [base, token]:
			var material := StandardMaterial3D.new()
			material.roughness = 0.8
			visual.material_override = material
		slot.hide()
		_slots.append(slot)


func present(pickups: Array[Dictionary], reduced_motion: bool, delta: float) -> void:
	_clock += delta
	var camera := get_viewport().get_camera_3d()
	for index in _slots.size():
		var slot := _slots[index]
		slot.visible = index < pickups.size()
		if not slot.visible:
			continue
		var pickup := pickups[index]
		var speed: bool = pickup.kind == MatchPowerups.Kind.SPEED
		slot.position = pickup.position
		var token := slot.get_node("Token") as MeshInstance3D
		token.position.y = 0.85 if reduced_motion else 0.85 + sin(_clock * 2 + int(pickup.id)) * 0.06
		if is_instance_valid(camera):
			token.rotation.y = atan2(camera.global_position.x - slot.global_position.x, camera.global_position.z - slot.global_position.z)
		(token.get_node("Symbol") as Label3D).text = "»" if speed else "↑"
		(slot.get_node("Identity") as Label3D).text = "SPEED" if speed else "JUMP"
		for visual: MeshInstance3D in [slot.get_node("Pad"), token]:
			(visual.material_override as StandardMaterial3D).albedo_color = DisasterPartyUI.TEAL if speed else DisasterPartyUI.LIGHTNING
