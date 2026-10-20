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
		"impact": _material(DisasterPartyUI.DANGER, true),
		"ink": _material(DisasterPartyUI.INK),
	}
	_meshes = {
		"pellet": _pellet_mesh(), "rocket": _rocket_mesh(), "blaster": _blaster_mesh(),
		"hammer": _hammer_mesh(), "blast_ring": _ring_mesh(2.4), "small_ring": _ring_mesh(0.5),
		"hammer_arc": _hammer_arc_mesh(),
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
		if kind in ["pellet", "rocket"] and projectiles.size() < MAX_PROJECTILES:
			projectiles.append(effect)
		elif kind in ["blast_warning", "hammer_warning"] and warnings.size() < MAX_WARNINGS:
			warnings.append(effect)
	# A cosmetic result must never displace an active danger telegraph.
	for effect in effects:
		if effect is Dictionary and str(effect.get("kind", "")) not in ["pellet", "rocket", "blast_warning", "hammer_warning"] and warnings.size() < MAX_WARNINGS:
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
		var kind := str(effect.get("kind", "pellet"))
		slot.global_position = effect.get("position", Vector3.ZERO)
		slot.basis = _basis_for_direction(effect.get("direction", Vector3.FORWARD))
		var mesh := slot.get_node("Mesh") as MeshInstance3D
		mesh.mesh = _meshes["rocket"] if kind == "rocket" else _meshes["pellet"]
		mesh.material_override = _materials["plunger"] if kind == "rocket" else _materials["foam"]


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
	if kind == "hammer_warning":
		slot.position.y -= 1.05
	var mesh := slot.get_node("Mesh") as MeshInstance3D
	var label := slot.get_node("Label") as Label3D
	# Put the swing countdown ahead of its owner rather than inside the avatar.
	label.position = Vector3(0, 0.55, -1.4) if kind == "hammer_warning" else Vector3(0, 0.65, 0)
	var remaining := maxf(0.0, float(effect.get("remaining", 0.0)))
	mesh.material_override = _materials["amber"] if kind in ["blast_warning", "hammer_warning"] else _materials["impact"]
	if kind == "blast_warning":
		mesh.mesh = _meshes["blast_ring"]
		label.text = "ROCKET  %.1fs" % remaining
	elif kind == "hammer_warning":
		mesh.mesh = _meshes["hammer_arc"]
		label.text = "HAMMER  %.1fs" % remaining
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
	_disable_shadows(mesh)
	slot.add_child(mesh)
	var label := Label3D.new()
	label.name = "Label"
	label.position.y = 0.22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 20
	label.pixel_size = 0.008
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
		_: return _meshes["pellet"]


func _material_for(kind: String) -> Material:
	match kind:
		"foam_blaster": return _materials["foam"]
		"plunger_rocket": return _materials["plunger"]
		"squeaky_hammer": return _materials["hammer"]
		_: return _materials["ink"]


func _name_for(kind: String) -> String:
	return {"foam_blaster": "FOAM BLASTER", "plunger_rocket": "PLUNGER ROCKET", "squeaky_hammer": "SQUEAKY HAMMER", "pellet": "FOAM PELLET", "rocket": "PLUNGER ROCKET", "hit": "IMPACT", "blocked": "BLOCKED", "miss": "MISS"}.get(kind, "TOY")


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


func _hammer_arc_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	for index in 9:
		var angle := lerpf(-acos(0.55), acos(0.55), float(index) / 8.0)
		vertices.append(Vector3(sin(angle) * 2.2, 0.0, -cos(angle) * 2.2))
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
