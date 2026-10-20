extends Node3D
## Snapshot-only toy sabotage presentation. It owns no collision, physics or authority.

const MAX_PICKUPS := 6
const MAX_PROJECTILES := 4
const MAX_WARNINGS := 6
const MAX_HELD := 20

var _pickup_slots: Array[Node3D] = []
var _projectile_slots: Array[Node3D] = []
var _warning_slots: Array[Node3D] = []
var _held_slots: Array[Node3D] = []
var _materials := {}
var _meshes := {}
var _clock := 0.0


func _ready() -> void:
	_materials = {
		"foam": _material(DisasterPartyUI.WATER),
		"plunger": _material(DisasterPartyUI.CORAL),
		"hammer": _material(DisasterPartyUI.LIGHTNING),
		"amber": _material(DisasterPartyUI.DANGER, true),
		"wet": _material(DisasterPartyUI.WATER, true),
		"impact": _material(DisasterPartyUI.DANGER, true),
		"ink": _material(DisasterPartyUI.INK),
	}
	_meshes = {
		"pellet": _pellet_mesh(), "rocket": _rocket_mesh(), "blaster": _blaster_mesh(),
		"hammer": _hammer_mesh(), "blast_ring": _ring_mesh(2.4), "small_ring": _ring_mesh(0.5),
		"hammer_arc": _hammer_arc_mesh(), "glove_arc": _hammer_arc_mesh(3.0, 0.94),
		"glove": _glove_mesh(), "frisbee": _frisbee_mesh(), "frisbee_trail": _frisbee_trail_mesh(), "soaker": _soaker_mesh(),
		"wet_strip": _wet_strip_mesh(),
		"soap": _combined_mesh([_box_part(Vector3(0.5, 0.18, 0.32), Vector3.ZERO), _box_part(Vector3(0.27, 0.03, 0.16), Vector3(0, 0.1, 0))]),
		"soap_patch": _trap_mesh(false), "spring": _trap_mesh(true), "confetti": _confetti_mesh(),
		"foam_launcher": _foam_launcher_mesh(), "toy_fan": _toy_fan_mesh(), "decoy_runner": _decoy_runner_mesh(),
		"foam_seed": _foam_seed_mesh(), "foam_preview": _foam_preview_mesh(), "foam_screen": _foam_screen_mesh(),
		"fan_cone": _fan_cone_mesh(),
		"popper": _popper_mesh(), "umbrella": _umbrella_mesh(),
		"popper_blast": _combined_mesh([{"mesh": _popper_mesh(), "transform": Transform3D.IDENTITY}, {"mesh": _ring_mesh(2.4), "transform": Transform3D.IDENTITY}]),
		"rocket_cart": _rocket_cart_mesh(), "cart_windup": _cart_windup_mesh(),
		"balloon": _balloon_mesh(), "balloon_dart": _balloon_dart_mesh(),
	}
	for index in MAX_PICKUPS:
		_pickup_slots.append(_make_pickup("Pickup%d" % index))
	for index in MAX_PROJECTILES:
		_projectile_slots.append(_make_mesh_slot("Projectile%d" % index, SphereMesh.new(), "foam"))
	for index in MAX_WARNINGS:
		_warning_slots.append(_make_warning("Warning%d" % index))
	for index in MAX_HELD:
		_held_slots.append(_make_mesh_slot("Held%d" % index, BoxMesh.new(), "foam"))


func present(snapshot: Dictionary, players: Dictionary, reduced_motion: bool, delta: float) -> void:
	_clock += maxf(delta, 0.0)
	var pickups: Array = snapshot.get("pickups", [])
	var effects: Array = snapshot.get("effects", [])
	_present_pickups(pickups, reduced_motion)
	_present_effects(effects)
	_present_held(snapshot.get("slots", {}), players)


func _present_pickups(pickups: Array, reduced_motion: bool) -> void:
	for index in _pickup_slots.size():
		var slot := _pickup_slots[index]
		slot.visible = index < pickups.size() and pickups[index] is Dictionary
		if not slot.visible:
			continue
		var pickup: Dictionary = pickups[index]
		slot.global_position = pickup.get("position", Vector3.ZERO)
		var kind := str(pickup.get("kind", "unknown"))
		var toy: MeshInstance3D = slot.get_node("Toy")
		toy.mesh = _mesh_for(kind)
		toy.material_override = _material_for(kind)
		toy.position.y = 0.68 if reduced_motion else 0.68 + sin(_clock * 2.0 + int(pickup.get("id", index))) * 0.05
		(slot.get_node("Label") as Label3D).text = "%s\n[F] TAKE / SWAP" % _name_for(kind)


func _present_effects(effects: Array) -> void:
	var projectiles: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	for effect in effects:
		if not effect is Dictionary or float(effect.get("remaining", 0.0)) <= 0.0:
			continue
		var kind := str(effect.get("kind", "unknown"))
		if kind in ToySabotage.PROJECTILES and projectiles.size() < MAX_PROJECTILES:
			projectiles.append(effect)
		elif kind in ToySabotage.WARNINGS and warnings.size() < MAX_WARNINGS:
			warnings.append(effect)
	# A cosmetic result must never displace an active danger telegraph.
	for effect in effects:
		if effect is Dictionary and str(effect.get("kind", "")) in ToySabotage.OUTCOMES and warnings.size() < MAX_WARNINGS:
			warnings.append(effect)
	_present_projectiles(projectiles)
	for index in _warning_slots.size():
		var slot := _warning_slots[index]
		slot.visible = index < warnings.size()
		if slot.visible:
			_configure_warning(slot, warnings[index])


func _present_projectiles(projectiles: Array[Dictionary]) -> void:
	for index in _projectile_slots.size():
		var slot := _projectile_slots[index]
		slot.visible = index < projectiles.size()
		if not slot.visible:
			continue
		var effect := projectiles[index]
		var kind := str(effect.get("kind", "pellet")).trim_suffix("_reflected")
		slot.global_position = effect.get("position", Vector3.ZERO)
		slot.basis = _basis_for_direction(effect.get("direction", Vector3.FORWARD))
		var mesh := slot.get_node("Mesh") as MeshInstance3D
		var mesh_key := "pellet"
		var material_key := "foam"
		match kind:
			"frisbee_out", "frisbee_back":
				mesh_key = "frisbee_trail"
				material_key = "hammer"
			"rocket", "cart_running", "balloon_dart":
				mesh_key = "rocket_cart" if kind == "cart_running" else kind
				material_key = "plunger"
			"foam_seed":
				mesh_key = "foam_seed"
		mesh.mesh = _meshes[mesh_key]
		mesh.material_override = _materials[material_key]


func _present_held(slots: Dictionary, players: Dictionary) -> void:
	var held: Array[Dictionary] = []
	for owner in slots:
		if held.size() >= MAX_HELD:
			break
		var slot = slots[owner]
		if slot is Dictionary and not str(slot.get("kind", "")).is_empty():
			held.append({"owner": owner, "slot": slot})
	for index in _held_slots.size():
		var visual := _held_slots[index]
		visual.visible = index < held.size()
		if not visual.visible:
			continue
		var entry := held[index]
		var player = players.get(entry.owner)
		var anchor := _player_visual(player)
		if not is_instance_valid(anchor):
			visual.hide()
			continue
		var mesh := visual.get_node("Mesh") as MeshInstance3D
		var kind := str(entry.slot.get("kind", "unknown"))
		mesh.mesh = _mesh_for(kind)
		mesh.material_override = _material_for(kind)
		# The body visual is intentionally more stable than animated hands/ragdolls.
		visual.global_transform = anchor.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.34, 0.92, -0.16))
		visual.scale = Vector3(0.48, 0.48, 0.48)


func _configure_warning(slot: Node3D, effect: Dictionary) -> void:
	var kind := str(effect.get("kind", "unknown"))
	slot.global_position = effect.get("position", Vector3.ZERO) + Vector3.UP * 0.025
	var direction: Vector3 = effect.get("direction", Vector3.FORWARD)
	direction.y = 0.0
	slot.basis = _basis_for_direction(direction)
	if kind in ["hammer_warning", "glove_warning"]:
		slot.position.y -= 1.05
	var mesh := slot.get_node("Mesh") as MeshInstance3D
	var label := slot.get_node("Label") as Label3D
	mesh.position = Vector3.ZERO
	label.font_size = 28 if kind in ["foam_screen", "fan_gust", "decoy_running"] else 24
	# Put the swing countdown ahead of its owner rather than inside the avatar.
	label.position = Vector3(0, 1.4, -1.8) if kind in ["hammer_warning", "glove_warning"] else Vector3(0, 0.65, 0)
	if kind in ["soap_patch", "spring_armed", "confetti_warning"]:
		label.position = Vector3(0, 1.5, -0.7)
	var remaining := maxf(0.0, float(effect.get("remaining", 0.0)))
	mesh.material_override = _materials["amber"] if kind in ToySabotage.WARNINGS else _materials["impact"]
	if kind == "blast_warning":
		mesh.mesh = _meshes["blast_ring"]
		label.text = "ROCKET  %.1fs" % remaining
	elif kind == "hammer_warning":
		mesh.mesh = _meshes["hammer_arc"]
		label.text = "HAMMER  %.1fs" % remaining
	elif kind == "glove_warning":
		mesh.mesh = _meshes["glove_arc"]
		label.text = "PUNCH  %.1fs" % remaining
	elif kind == "wet_strip":
		mesh.mesh = _meshes["wet_strip"]
		var wet_material := mesh.get_meta("wet_material") as StandardMaterial3D
		wet_material.albedo_color.a = 0.8 * clampf(remaining / 6.0, 0.0, 1.0)
		mesh.material_override = wet_material
		label.text = "WET  %.1fs" % remaining
	elif kind == "soap_patch":
		mesh.mesh = _meshes["soap_patch"]
		mesh.material_override = _materials["hammer"]
		label.text = "SOAP — SLIPPERY  %.1fs" % remaining
	elif kind == "spring_armed":
		mesh.mesh = _meshes["spring"]
		mesh.material_override = _materials["plunger"]
		label.text = "SPRING — ARMING %.1fs" % (remaining - 9.2) if remaining > 9.2 else "SPRING — READY"
	elif kind == "confetti_warning":
		mesh.mesh = _meshes["blast_ring"]
		label.text = "CONFETTI — RUN  %.1fs" % remaining
	elif kind == "foam_screen":
		var preview := remaining > 6.0
		mesh.mesh = _meshes["foam_preview"] if preview else _meshes["foam_screen"]
		mesh.material_override = _materials["amber"] if preview else _materials["foam"]
		mesh.position.y = 0.65
		label.position = Vector3(0, 1.85, -0.4)
		label.text = "FOAM — ARMING %.1fs" % (remaining - 6.0) if preview else "FOAM %.1fs\nWALK THROUGH / SHOOT TO POP" % remaining
	elif kind == "fan_gust":
		var arming := remaining > 4.0
		mesh.mesh = _meshes["fan_cone"]
		mesh.material_override = _materials["plunger"] if arming else _materials["foam"]
		label.position = Vector3(0, 1.3, -1.1)
		label.text = "FAN — ARMING %.1fs" % (remaining - 4.0) if arming else "FAN %.1fs — COVER / GO BEHIND" % remaining
	elif kind == "decoy_running":
		mesh.mesh = _meshes["decoy_runner"]
		mesh.material_override = _materials["plunger"]
		label.position = Vector3(0, 1.62, 0)
		label.text = "TOY DECOY  %.1fs" % remaining
	elif kind == "popper_armed":
		mesh.mesh = _meshes["popper"]
		mesh.material_override = _materials["plunger"]
		label.position = Vector3(0, 1.8, -0.2)
		label.text = "POPPER — ARMING %.1fs" % (remaining - 8.0) if remaining > 8.0 else "POPPER %.1fs\nSHOOT TO DEFUSE / KEEP CLEAR" % remaining
	elif kind == "popper_warning":
		mesh.mesh = _meshes["popper_blast"]
		label.position = Vector3(0, 1.8, -0.2)
		label.text = "POPPER — RUN / COVER  %.1fs" % remaining
	elif kind == "umbrella_open":
		mesh.mesh = _meshes["umbrella"]
		mesh.position = Vector3(0, 0.85, -0.7)
		mesh.material_override = _materials["plunger"] if remaining > 0.9 else _materials["hammer"]
		label.position = Vector3(0, 1.9, -0.8)
		label.text = "UMBRELLA — OPENING %.1fs" % (remaining - 0.9) if remaining > 0.9 else "REFLECT %.1fs\nFRONT ONLY — FLANK / WAIT" % remaining
	elif kind == "cart_windup":
		# The lane is fixed to authoritative facing during the full windup; it never
		# suggests a late steering choice for this non-solid cart.
		mesh.mesh = _meshes["cart_windup"]
		mesh.material_override = _materials["plunger"]
		label.position = Vector3(0, 1.25, -2.2)
		label.text = "ROCKET CART — MOVE CLEAR  %.1fs" % remaining
	elif kind in ["balloon_attached", "balloon_float"]:
		mesh.mesh = _meshes["balloon"]
		mesh.material_override = _materials["plunger"] if kind == "balloon_attached" else _materials["foam"]
		label.position = Vector3(0, 0.48, 0)
		label.text = "BALLOON — JUMP / MOVE / SHOOT TO POP  %.1fs" % remaining if kind == "balloon_attached" else "BALLOON — FLOATING"
	else:
		mesh.mesh = _meshes["small_ring"]
		label.text = _name_for(kind)


func _make_pickup(slot_name: String) -> Node3D:
	var slot := Node3D.new()
	slot.name = slot_name
	add_child(slot)
	var toy := MeshInstance3D.new()
	toy.name = "Toy"
	_disable_shadows(toy)
	slot.add_child(toy)
	var label := Label3D.new()
	label.name = "Label"
	label.position.y = 1.18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = DisasterPartyUI.WHITE
	label.outline_modulate = DisasterPartyUI.INK
	slot.add_child(label)
	slot.hide()
	return slot


func _make_warning(slot_name: String) -> Node3D:
	var slot := Node3D.new()
	slot.name = slot_name
	add_child(slot)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.set_meta("wet_material", _materials["wet"].duplicate())
	_disable_shadows(mesh)
	slot.add_child(mesh)
	var label := Label3D.new()
	label.name = "Label"
	label.position.y = 0.22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.014
	label.outline_size = 7
	label.modulate = DisasterPartyUI.WHITE
	label.outline_modulate = DisasterPartyUI.INK
	slot.add_child(label)
	slot.hide()
	return slot


func _make_mesh_slot(slot_name: String, mesh: Mesh, material_key: String) -> Node3D:
	var slot := Node3D.new()
	slot.name = slot_name
	add_child(slot)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	visual.material_override = _materials[material_key]
	_disable_shadows(visual)
	slot.add_child(visual)
	slot.hide()
	return slot


func _player_visual(player) -> Node3D:
	if not is_instance_valid(player):
		return null
	if player.has_method("is_knocked_down") and player.is_knocked_down():
		return null
	if player.get("_is_eliminated") == true:
		return null
	var visual = player.get("visual")
	return visual if visual is Node3D and visual.visible else null


func _mesh_for(kind: String) -> Mesh:
	match kind:
		"foam_blaster": return _meshes["blaster"]
		"plunger_rocket": return _meshes["rocket"]
		"squeaky_hammer": return _meshes["hammer"]
		"boxing_glove": return _meshes["glove"]
		"boomerang": return _meshes["frisbee"]
		"water_soaker": return _meshes["soaker"]
		"soap_slick": return _meshes["soap"]
		"spring_pad": return _meshes["spring"]
		"confetti_bomb": return _meshes["confetti"]
		"foam_launcher": return _meshes["foam_launcher"]
		"toy_fan": return _meshes["toy_fan"]
		"decoy_runner": return _meshes["decoy_runner"]
		"remote_popper": return _meshes["popper"]
		"reflector_umbrella": return _meshes["umbrella"]
		"rocket_cart": return _meshes["rocket_cart"]
		"party_balloon": return _meshes["balloon"]
		_: return _meshes["pellet"]


func _material_for(kind: String) -> Material:
	match kind:
		"foam_blaster": return _materials["foam"]
		"plunger_rocket": return _materials["plunger"]
		"squeaky_hammer": return _materials["hammer"]
		"boxing_glove": return _materials["plunger"]
		"boomerang": return _materials["hammer"]
		"water_soaker": return _materials["foam"]
		"soap_slick": return _materials["hammer"]
		"spring_pad", "confetti_bomb": return _materials["plunger"]
		"foam_launcher": return _materials["foam"]
		"toy_fan": return _materials["hammer"]
		"decoy_runner": return _materials["plunger"]
		"remote_popper": return _materials["plunger"]
		"reflector_umbrella": return _materials["hammer"]
		"rocket_cart", "party_balloon": return _materials["plunger"]
		_: return _materials["ink"]


func _name_for(kind: String) -> String:
	return {"foam_blaster": "FOAM BLASTER", "plunger_rocket": "PLUNGER ROCKET", "squeaky_hammer": "SQUEAKY HAMMER", "boxing_glove": "SPRING GLOVE", "boomerang": "BOOMERANG DISC", "water_soaker": "WATER SOAKER", "soap_slick": "SOAP SLICK", "spring_pad": "SPRING PAD", "confetti_bomb": "CONFETTI BOMB", "foam_launcher": "FOAM LAUNCHER", "toy_fan": "TOY FAN", "decoy_runner": "DECOY RUNNER", "remote_popper": "REMOTE POPPER", "reflector_umbrella": "REFLECTOR UMBRELLA", "rocket_cart": "ROCKET CART", "party_balloon": "PARTY BALLOON", "foam_seed": "FOAM SEED", "pellet": "FOAM PELLET", "rocket": "PLUNGER ROCKET", "hit": "IMPACT", "blocked": "BLOCKED", "miss": "MISS"}.get(kind, "TOY")


func _material(color: Color, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.8) if transparent else color
	material.roughness = 0.82
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _disable_shadows(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _basis_for_direction(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	return Basis.IDENTITY if forward.length_squared() < 0.001 else Basis.looking_at(forward, Vector3.UP)


func _pellet_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _rocket_mesh() -> ArrayMesh:
	var body := CapsuleMesh.new()
	body.radius = 0.12
	body.height = 0.64
	body.radial_segments = 8
	body.rings = 4
	var cup := CylinderMesh.new()
	cup.top_radius = 0.24
	cup.bottom_radius = 0.12
	cup.height = 0.14
	cup.radial_segments = 12
	var turned := Basis(Vector3.RIGHT, -PI * 0.5)
	return _combined_mesh([
		{"mesh": body, "transform": Transform3D(turned, Vector3.ZERO)},
		{"mesh": cup, "transform": Transform3D(turned, Vector3(0, 0, -0.36))},
	])


func _blaster_mesh() -> ArrayMesh:
	return _combined_mesh([
		_box_part(Vector3(0.3, 0.26, 0.52), Vector3.ZERO),
		_box_part(Vector3(0.12, 0.32, 0.16), Vector3(0, -0.22, 0.12)),
		_box_part(Vector3(0.18, 0.18, 0.2), Vector3(0, 0.02, -0.33)),
	])


func _hammer_mesh() -> ArrayMesh:
	return _combined_mesh([
		_box_part(Vector3(0.76, 0.28, 0.28), Vector3(0, 0.22, 0)),
		_box_part(Vector3(0.12, 0.55, 0.12), Vector3(0, -0.17, 0)),
	])


func _box_part(size: Vector3, at: Vector3) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "transform": Transform3D(Basis.IDENTITY, at)}


func _combined_mesh(parts: Array[Dictionary]) -> ArrayMesh:
	# All parts use one matte surface: readable silhouettes without a draw
	# call per barrel, grip, handle or suction cup.
	var builder := SurfaceTool.new()
	for part in parts:
		builder.append_from(part.mesh, 0, part.transform)
	return builder.commit()


func _ring_mesh(radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.045
	mesh.outer_radius = radius + 0.045
	mesh.rings = 32
	mesh.ring_segments = 6
	return mesh


func _glove_mesh() -> ArrayMesh:
	var fist := SphereMesh.new()
	fist.radius = 0.28
	fist.height = 0.5
	fist.radial_segments = 12
	fist.rings = 6
	return _combined_mesh([
		{"mesh": fist, "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.25))},
		_box_part(Vector3(0.3, 0.3, 0.32), Vector3(0, 0, 0.1)),
		_box_part(Vector3(0.18, 0.18, 0.3), Vector3(0.26, -0.12, -0.1)),
	])


func _frisbee_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.27
	mesh.height = 0.09
	mesh.radial_segments = 16
	return mesh


func _frisbee_trail_mesh() -> ArrayMesh:
	# Fixed short tail reads the travel direction without another particle draw.
	return _combined_mesh([
		{"mesh": _frisbee_mesh(), "transform": Transform3D.IDENTITY},
		_box_part(Vector3(0.08, 0.04, 0.7), Vector3(0, 0, 0.6)),
	])


func _soaker_mesh() -> ArrayMesh:
	return _combined_mesh([
		_box_part(Vector3(0.24, 0.25, 0.65), Vector3.ZERO),
		_box_part(Vector3(0.18, 0.35, 0.18), Vector3(0, -0.22, 0.12)),
		_box_part(Vector3(0.42, 0.25, 0.3), Vector3(0, 0.23, 0.08)),
	])


func _wet_strip_mesh() -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.9, 1.8)
	return mesh


func _trap_mesh(spring: bool) -> ArrayMesh:
	var parts: Array[Dictionary] = [_box_part(Vector3(1.3, 0.035, 1.3), Vector3(0, 0.02, 0))]
	if spring:
		# Raised chevrons remain visible without shadows or cosmetic rigidbodies.
		for x in [-0.18, 0.18]:
			parts.append(_box_part(Vector3(0.12, 0.08, 0.6), Vector3(x, 0.08, 0)))
	else:
		for x in [-0.35, 0.0, 0.35]:
			parts.append(_box_part(Vector3(0.13, 0.04, 0.8), Vector3(x, 0.06, 0)))
	return _combined_mesh(parts)


func _confetti_mesh() -> ArrayMesh:
	return _combined_mesh([
		_box_part(Vector3(0.42, 0.42, 0.42), Vector3.ZERO),
		_box_part(Vector3(0.12, 0.15, 0.12), Vector3(0, 0.27, 0)),
		_box_part(Vector3(0.3, 0.06, 0.08), Vector3(0.12, 0.38, 0)),
	])


func _foam_launcher_mesh() -> ArrayMesh:
	return _combined_mesh([
		_box_part(Vector3(0.34, 0.28, 0.62), Vector3.ZERO),
		_box_part(Vector3(0.42, 0.2, 0.22), Vector3(0, 0.02, -0.35)),
		_box_part(Vector3(0.14, 0.34, 0.17), Vector3(0, -0.24, 0.12)),
	])


func _toy_fan_mesh() -> ArrayMesh:
	return _combined_mesh([
		_box_part(Vector3(0.42, 0.12, 0.18), Vector3(0, -0.22, 0.08)),
		_box_part(Vector3(0.14, 0.48, 0.14), Vector3(0, 0.05, 0)),
		_box_part(Vector3(0.62, 0.62, 0.1), Vector3(0, 0.26, -0.08)),
	])


func _decoy_runner_mesh() -> ArrayMesh:
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.42
	head.radial_segments = 8
	head.rings = 4
	return _combined_mesh([
		{"mesh": head, "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.98, 0))},
		_box_part(Vector3(0.42, 0.52, 0.24), Vector3(0, 0.62, 0)),
		_box_part(Vector3(0.13, 0.48, 0.13), Vector3(-0.14, 0.22, 0.05)),
		_box_part(Vector3(0.13, 0.48, 0.13), Vector3(0.14, 0.22, -0.05)),
	])


func _foam_seed_mesh() -> ArrayMesh:
	return _combined_mesh([
		{"mesh": _pellet_mesh(), "transform": Transform3D.IDENTITY},
		_box_part(Vector3(0.28, 0.05, 0.28), Vector3(0, 0, 0.06)),
	])


func _foam_preview_mesh() -> ArrayMesh:
	var parts: Array[Dictionary] = []
	for x in [-0.48, 0.0, 0.48]:
		parts.append(_box_part(Vector3(0.22, 1.3, 0.06), Vector3(x, 0, 0)))
	return _combined_mesh(parts)


func _foam_screen_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 1.3, 0.18)
	mesh.material = _materials["foam"]
	return mesh


func _popper_mesh() -> ArrayMesh:
	var body := CylinderMesh.new()
	body.top_radius = 0.22
	body.bottom_radius = 0.3
	body.height = 0.42
	body.radial_segments = 12
	return _combined_mesh([
		{"mesh": body, "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0))},
		_box_part(Vector3(0.06, 0.34, 0.06), Vector3(0, 0.62, 0)),
		_box_part(Vector3(0.32, 0.07, 0.07), Vector3(0, 0.76, 0)),
	])


func _umbrella_mesh() -> ArrayMesh:
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.12
	canopy.bottom_radius = 0.65
	canopy.height = 0.16
	canopy.radial_segments = 8
	return _combined_mesh([
		{"mesh": canopy, "transform": Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)},
		_box_part(Vector3(0.07, 0.07, 0.5), Vector3(0, 0, 0.25)),
		_box_part(Vector3(0.07, 0.28, 0.07), Vector3(0, -0.1, 0.5)),
	])


func _rocket_cart_mesh() -> ArrayMesh:
	# One merged, deliberately oversized wheeled silhouette; wheel bottoms meet y=0
	# because authoritative cart positions are supported floor positions.
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.18
	wheel.bottom_radius = 0.18
	wheel.height = 0.12
	wheel.radial_segments = 10
	var axle := Basis(Vector3.FORWARD, PI * 0.5)
	return _combined_mesh([
		_box_part(Vector3(0.72, 0.27, 0.92), Vector3(0, 0.39, 0)),
		_box_part(Vector3(0.44, 0.18, 0.36), Vector3(0, 0.61, -0.12)),
		_box_part(Vector3(0.18, 0.16, 0.34), Vector3(0, 0.56, -0.56)),
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(-0.41, 0.18, -0.28))},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(0.41, 0.18, -0.28))},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(-0.41, 0.18, 0.28))},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(0.41, 0.18, 0.28))},
	])


func _cart_windup_mesh() -> ArrayMesh:
	# Mark the full maximum eight-metre run, not just its first half.
	var parts: Array[Dictionary] = [{"mesh": _rocket_cart_mesh(), "transform": Transform3D.IDENTITY}]
	for z in [-1.0, -2.2, -3.4, -4.6, -5.8, -7.0, -7.8]:
		parts.append(_box_part(Vector3(0.72, 0.018, 0.10), Vector3(0, 0.02, z)))
		parts.append(_box_part(Vector3(0.10, 0.018, 0.28), Vector3(-0.31, 0.02, z + 0.08)))
		parts.append(_box_part(Vector3(0.10, 0.018, 0.28), Vector3(0.31, 0.02, z + 0.08)))
	return _combined_mesh(parts)


func _balloon_mesh() -> ArrayMesh:
	var balloon := SphereMesh.new()
	balloon.radius = 0.34
	balloon.height = 0.58
	balloon.radial_segments = 12
	balloon.rings = 6
	return _combined_mesh([
		{"mesh": balloon, "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0))},
		_box_part(Vector3(0.022, 1.82, 0.022), Vector3(0, -0.92, 0)),
		_box_part(Vector3(0.11, 0.07, 0.11), Vector3(0, -0.25, 0)),
	])


func _balloon_dart_mesh() -> ArrayMesh:
	# The flying seed has a short ribbon; the long attached string would extend
	# below ground from its chest-height launch origin.
	var seed := SphereMesh.new()
	seed.radius = 0.2
	seed.height = 0.36
	seed.radial_segments = 12
	seed.rings = 6
	return _combined_mesh([
		{"mesh": seed, "transform": Transform3D.IDENTITY},
		_box_part(Vector3(0.07, 0.07, 0.5), Vector3(0, 0, 0.28)),
	])


func _fan_cone_mesh() -> ArrayMesh:
	# Floor arrows preserve visibility of avatars/other warnings in the lane.
	# The merged fan and arc still take a single pooled mesh/draw.
	return _combined_mesh([
		{"mesh": _hammer_arc_mesh(3.5, 0.9), "transform": Transform3D.IDENTITY},
		{"mesh": _toy_fan_mesh(), "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0))},
	])


func _hammer_arc_mesh(radius := 2.2, cosine := 0.55) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	for index in 9:
		var angle := lerpf(-acos(cosine), acos(cosine), float(index) / 8.0)
		vertices.append(Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius))
	var indices := PackedInt32Array()
	for index in range(1, 9):
		indices.append_array([0, index, index + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
