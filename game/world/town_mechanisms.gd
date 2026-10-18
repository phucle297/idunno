class_name TownMechanisms
extends Node3D
## Optional, self-contained shortcuts. Their ramps deliberately meet the real
## ground instead of creating unreachable elevated decoration.

const AWNING_ID := "town_awning"
const BRIDGE_ID := "town_bridge"
const STATE_REST_A := 0
const STATE_MOVING := 1
const STATE_REST_B := 2
const ACTIVATION_RANGE := 2.35
const MOTION_SECONDS := 3.0
const COOLDOWN_SECONDS := 4.0
const MAX_SNAPSHOT_REVISION := 1_000_000_000
const TOY_SAND := Color("d9b77e")
const TOY_SLATE := Color("49566a")
const TOY_TEAL := Color("73b7ad")
const TOY_CORAL := Color("d98d7d")
const TOY_AMBER := Color("ffbf3f")

enum ActivationResult { ACCEPTED, NOT_AUTHORITY, UNKNOWN_MECHANISM, MATCH_INACTIVE, ACTOR_INVALID, OUT_OF_RANGE, BLOCKED, BUSY, COOLDOWN, UNSUPPORTED }

var _mechanisms: Dictionary = {}
var _support_query := Callable()
var _los_query := Callable()
var _revision := 0
var _remote_revision := -1
var _built := false
var _host: Node3D


func construct_toy_town(host: Node3D, support_query := Callable(), los_query := Callable()) -> bool:
	if _built or host == null:
		return false
	_support_query = support_query
	_los_query = los_query
	_host = host
	host.add_child(self)
	name = "TownMechanisms"
	# South-west of the plaza: clear of the Garage/Park ramps, refuge doors,
	# flood approaches and the north/south civic circulation.
	_add_awning(Vector3(-5.0, 2.65, 15.0))
	_add_bridge(Vector3(2.0, 2.35, 25.0))
	_built = true
	return true


func request_activation(mechanism_id: String, actor_id: int, actor_position: Vector3, actor_alive: bool, actor_knocked_down: bool, match_active: bool, server_authority: bool) -> ActivationResult:
	if not server_authority:
		return ActivationResult.NOT_AUTHORITY
	if not _mechanisms.has(mechanism_id):
		return ActivationResult.UNKNOWN_MECHANISM
	if not match_active:
		return ActivationResult.MATCH_INACTIVE
	if actor_id <= 0 or not _finite_vector(actor_position) or not actor_alive or actor_knocked_down:
		return ActivationResult.ACTOR_INVALID
	var mechanism: Dictionary = _mechanisms[mechanism_id]
	if not bool(mechanism.enabled):
		return ActivationResult.UNSUPPORTED
	var control: Vector3 = mechanism.control_position
	if actor_position.distance_to(control) > ACTIVATION_RANGE:
		return ActivationResult.OUT_OF_RANGE
	if not _los_query.is_null() and not bool(_los_query.call(actor_position, control, mechanism_id)):
		return ActivationResult.BLOCKED
	if int(mechanism.state) == STATE_MOVING:
		return ActivationResult.BUSY
	if float(mechanism.cooldown) > 0.0:
		return ActivationResult.COOLDOWN
	mechanism.target = STATE_REST_B if int(mechanism.state) == STATE_REST_A else STATE_REST_A
	mechanism.state = STATE_MOVING
	mechanism.progress = 0.0
	_set_cue(mechanism, "TURNING — STAND CLEAR", TOY_AMBER)
	_mechanisms[mechanism_id] = mechanism
	_revision += 1
	return ActivationResult.ACCEPTED


## Actors must be grounded by the caller's authoritative CharacterBody tick.
## We never return a platform delta: a sync_to_physics AnimatableBody supplies
## the one physical carriage path and avoids double-carrying a passenger.
func server_tick(delta: float, _actors: Dictionary, server_authority: bool) -> Dictionary:
	if not is_finite(delta) or delta <= 0.0:
		return {}
	for mechanism_id: String in _mechanisms:
		var mechanism: Dictionary = _mechanisms[mechanism_id]
		if not bool(mechanism.enabled):
			continue
		if server_authority and not _has_support(mechanism):
			_disable(mechanism_id, mechanism)
			continue
		mechanism.cooldown = maxf(0.0, float(mechanism.cooldown) - delta)
		if int(mechanism.state) == STATE_MOVING:
			mechanism.progress = minf(1.0, float(mechanism.progress) + delta / MOTION_SECONDS)
			_apply_transform(mechanism)
			if float(mechanism.progress) >= 1.0:
				mechanism.state = int(mechanism.target)
				mechanism.progress = 1.0 if int(mechanism.state) == STATE_REST_B else 0.0
				mechanism.cooldown = COOLDOWN_SECONDS
				_set_cue(mechanism, "READY — TURN CRANK", TOY_TEAL)
			if server_authority:
				_revision += 1
		_mechanisms[mechanism_id] = mechanism
	return {}


func create_snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	for mechanism_id: String in [AWNING_ID, BRIDGE_ID]:
		var mechanism: Dictionary = _mechanisms[mechanism_id]
		entries.append({"id": mechanism_id, "state": int(mechanism.state), "target": int(mechanism.target), "progress": float(mechanism.progress), "cooldown": float(mechanism.cooldown), "enabled": bool(mechanism.enabled)})
	return {"revision": _revision, "mechanisms": entries}


func apply_snapshot(snapshot: Dictionary) -> bool:
	if not _valid_snapshot(snapshot) or int(snapshot.revision) < _remote_revision:
		return false
	for entry: Dictionary in snapshot.mechanisms:
		var mechanism: Dictionary = _mechanisms[String(entry.id)]
		mechanism.state = int(entry.state)
		mechanism.target = int(entry.target)
		mechanism.progress = float(entry.progress)
		mechanism.cooldown = float(entry.cooldown)
		mechanism.enabled = bool(entry.enabled)
		_apply_transform(mechanism)
		_set_enabled(mechanism, bool(mechanism.enabled))
		_set_mechanism_nodes_enabled(String(entry.id), bool(mechanism.enabled))
		_set_cue(mechanism, "TURNING — STAND CLEAR" if int(entry.state) == STATE_MOVING else ("COOLING DOWN" if float(entry.cooldown) > 0 else "READY — TURN CRANK"), TOY_AMBER if int(entry.state) == STATE_MOVING else TOY_TEAL)
		_mechanisms[String(entry.id)] = mechanism
	_remote_revision = int(snapshot.revision)
	return true


func reset_for_match() -> void:
	for mechanism_id: String in _mechanisms:
		var mechanism: Dictionary = _mechanisms[mechanism_id]
		mechanism.state = STATE_REST_A
		mechanism.target = STATE_REST_A
		mechanism.progress = 0.0
		mechanism.cooldown = 0.0
		mechanism.enabled = _has_support(mechanism)
		_apply_transform(mechanism)
		_set_enabled(mechanism, bool(mechanism.enabled))
		_set_mechanism_nodes_enabled(mechanism_id, bool(mechanism.enabled))
		_set_cue(mechanism, "READY — TURN CRANK", TOY_TEAL)
		_mechanisms[mechanism_id] = mechanism
	_revision += 1


func handle_support_loss(mechanism_id: String) -> bool:
	if not _mechanisms.has(mechanism_id):
		return false
	_disable(mechanism_id, _mechanisms[mechanism_id])
	return true


func get_control_position(mechanism_id: String) -> Vector3:
	return _mechanisms.get(mechanism_id, {}).get("control_position", Vector3.INF)


func get_crank_position(mechanism_id: String) -> Vector3:
	return get_control_position(mechanism_id)


func set_line_of_sight_query(query: Callable) -> void:
	_los_query = query


func get_deck_transform(mechanism_id: String) -> Transform3D:
	var mechanism: Dictionary = _mechanisms.get(mechanism_id, {})
	return (mechanism.get("body", null) as Node3D).global_transform if not mechanism.is_empty() else Transform3D.IDENTITY


func get_surface_footprint(mechanism_id: String) -> AABB:
	var mechanism: Dictionary = _mechanisms.get(mechanism_id, {})
	return mechanism.get("footprint", AABB())


func _add_awning(pivot: Vector3) -> void:
	var body := _make_solid("RotatingAwning", Vector3(5.4, 0.24, 2.4), TOY_CORAL)
	body.position = pivot
	# The crank is fixed at ground level under the awning edge, not parented to
	# rotating fabric; two posts make its support and clearance unambiguous.
	var control := pivot + Vector3(-2.15, -1.65, 1.35)
	control.y = 0.08
	_add_crank_station("AwningCrankStation", control, "E  CRANK AWNING")
	for x in [-2.25, 2.25]:
		_add_static("AwningPost", Vector3(0.22, 2.65, 0.22), pivot + Vector3(x, -1.325, 0.9), TOY_SLATE)
	_add_static("AwningPivotPost", Vector3(0.25, 2.65, 0.25), pivot - Vector3.UP * 1.325, TOY_SLATE)
	_mechanisms[AWNING_ID] = _entry(body, pivot, Vector3.ZERO, Vector3(5.4, 0.24, 2.4), control)


func _add_bridge(pivot: Vector3) -> void:
	# Four ramped landings form two genuine ground-to-ground optional routes;
	# the rotating deck selects north/south or east/west, never a floating slab.
	for entry in [["North", Vector3(0, 0, -6.1)], ["South", Vector3(0, 0, 6.1)], ["West", Vector3(-6.1, 0, 0)], ["East", Vector3(6.1, 0, 0)]]:
		var direction: Vector3 = entry[1]
		_add_landing_with_ramp("Bridge" + str(entry[0]) + "Landing", pivot + direction, direction.normalized())
	var body := _make_solid("RotatingShortcutBridge", Vector3(3.2, 0.3, 11.4), TOY_TEAL)
	body.position = pivot
	_add_static("BridgePivotPier", Vector3(0.65, 2.2, 0.65), pivot - Vector3.UP * 1.25, TOY_SLATE)
	var control := pivot + Vector3(-3.1, -1.65, -2.0)
	control.y = 0.08
	_add_crank_station("BridgeCrankStation", control, "E  TURN BRIDGE")
	_mechanisms[BRIDGE_ID] = _entry(body, pivot, Vector3.ZERO, Vector3(3.2, 0.3, 11.4), control)


func _entry(body: AnimatableBody3D, pivot: Vector3, local_offset: Vector3, deck_size: Vector3, control: Vector3) -> Dictionary:
	return {"body": body, "pivot": pivot, "local_offset": local_offset, "deck_size": deck_size, "control_position": control, "footprint": AABB(pivot - Vector3(7, 2.5, 7), Vector3(14, 5, 14)), "state": STATE_REST_A, "target": STATE_REST_A, "progress": 0.0, "cooldown": 0.0, "enabled": true}


func _apply_transform(mechanism: Dictionary) -> void:
	(mechanism.body as AnimatableBody3D).global_transform = _mechanism_transform(mechanism)


func _mechanism_transform(mechanism: Dictionary) -> Transform3D:
	var fraction := float(mechanism.progress)
	if int(mechanism.state) == STATE_REST_A:
		fraction = 0.0
	elif int(mechanism.state) == STATE_REST_B:
		fraction = 1.0
	elif int(mechanism.target) == STATE_REST_A:
		fraction = 1.0 - fraction
	var basis := Basis(Vector3.UP, lerpf(0.0, PI * 0.5, fraction))
	return Transform3D(basis, mechanism.pivot + basis * mechanism.local_offset)


func _add_landing_with_ramp(node_name: String, center: Vector3, outward: Vector3) -> void:
	_add_static(node_name, Vector3(3.4, 0.3, 2.2) if absf(outward.z) > 0.5 else Vector3(2.2, 0.3, 3.4), center, TOY_SAND)
	# Meet the OUTER lip at walking height. Ending beneath the far side of a
	# landing creates a low ceiling that blocks a capsule halfway up the ramp.
	var high := center + outward * 1.1 + Vector3.UP * 0.15
	var low := center + outward * 5.0
	low.y = 0.08
	_add_ramp(node_name + "Ramp", low, high, 3.4)


func _add_ramp(node_name: String, low: Vector3, high: Vector3, width: float) -> void:
	var run := low.distance_to(high)
	var body := _make_static(node_name, TOY_SAND)
	var size := Vector3(width, 0.28, run)
	var visual := MeshInstance3D.new()
	visual.mesh = _rounded_mesh(size, TOY_SAND)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var direction := high - low
	var horizontal := Vector2(direction.x, direction.z).length()
	body.basis = Basis(Vector3.UP, atan2(direction.x, direction.z)) * Basis(Vector3.RIGHT, -atan2(direction.y, horizontal))
	body.position = (low + high) * 0.5 - body.basis.y * 0.14


func _make_solid(node_name: String, size: Vector3, color: Color) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = node_name
	body.sync_to_physics = true
	_add_body_geometry(body, size, color)
	add_child(body)
	return body


func _add_static(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var body := _make_static(node_name, color)
	body.position = position
	_add_body_geometry(body, size, color)


func _make_static(node_name: String, _color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	add_child(body)
	return body


func _add_body_geometry(body: CollisionObject3D, size: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = _rounded_mesh(size, color)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _rounded_mesh(size: Vector3, color: Color) -> ArrayMesh:
	# Reuse the town kit's narrow bevel, not oval visuals over box collision.
	return _host.get_parent().call("_toy_box_mesh", size, color) as ArrayMesh


func _add_crank_station(node_name: String, position: Vector3, text: String) -> void:
	_add_static(node_name + "Post", Vector3(0.22, 1.15, 0.22), position + Vector3(0, 0.575, 0), TOY_SLATE)
	var wheel := MeshInstance3D.new()
	wheel.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.34
	cylinder.bottom_radius = 0.34
	cylinder.height = 0.12
	cylinder.radial_segments = 12
	cylinder.material = _material(TOY_AMBER)
	wheel.mesh = cylinder
	wheel.position = position + Vector3(0, 1.0, 0)
	wheel.rotation.x = PI * 0.5
	add_child(wheel)
	var label := Label3D.new()
	label.name = node_name + "Label"
	label.text = text
	label.position = position + Vector3(0, 1.35, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# The awning sweeps over its fixed crank; keep the interaction prompt
	# readable from above as well as from a player standing beneath the roof.
	label.no_depth_test = true
	label.modulate = TOY_AMBER
	label.outline_modulate = TOY_SLATE
	label.outline_size = 8
	label.pixel_size = 0.009
	add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material


func _set_cue(mechanism: Dictionary, text: String, color: Color) -> void:
	var body := mechanism.body as Node3D
	var cue := body.get_node_or_null("Cue") as Label3D
	if cue == null:
		cue = Label3D.new()
		cue.name = "Cue"
		cue.position = Vector3(0, 1.5, 0)
		cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cue.pixel_size = 0.012
		body.add_child(cue)
	cue.text = text
	cue.modulate = color
	cue.outline_modulate = TOY_SLATE
	cue.outline_size = 8


func _has_support(mechanism: Dictionary) -> bool:
	return _support_query.is_null() or bool(_support_query.call(mechanism.pivot))


func _disable(mechanism_id: String, mechanism: Dictionary) -> void:
	mechanism.enabled = false
	mechanism.state = STATE_REST_A
	mechanism.target = STATE_REST_A
	mechanism.progress = 0.0
	_set_enabled(mechanism, false)
	_set_mechanism_nodes_enabled(mechanism_id, false)
	_mechanisms[mechanism_id] = mechanism
	_revision += 1


func _set_enabled(mechanism: Dictionary, enabled: bool) -> void:
	for node: Node in (mechanism.body as Node).find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).set_deferred("disabled", not enabled)
	(mechanism.body as Node3D).visible = enabled


func _set_mechanism_nodes_enabled(mechanism_id: String, enabled: bool) -> void:
	var token := "Awning" if mechanism_id == AWNING_ID else "Bridge"
	for node: Node in get_children():
		if node.name.contains(token):
			node.visible = enabled
			for collision: Node in node.find_children("*", "CollisionShape3D", true, false):
				(collision as CollisionShape3D).set_deferred("disabled", not enabled)


func _valid_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot.has("revision") or not snapshot.revision is int or int(snapshot.revision) < 0 or int(snapshot.revision) > MAX_SNAPSHOT_REVISION or not snapshot.has("mechanisms") or not snapshot.mechanisms is Array or snapshot.mechanisms.size() != 2:
		return false
	var seen := {}
	for entry: Variant in snapshot.mechanisms:
		if not entry is Dictionary or not entry.has_all(["id", "state", "target", "progress", "cooldown", "enabled"]) or not entry.id is String or not entry.state is int or not entry.target is int or not entry.progress is float or not entry.cooldown is float or not entry.enabled is bool or not _mechanisms.has(entry.id) or seen.has(entry.id):
			return false
		if int(entry.state) < STATE_REST_A or int(entry.state) > STATE_REST_B or int(entry.target) < STATE_REST_A or int(entry.target) > STATE_REST_B or not is_finite(float(entry.progress)) or not is_finite(float(entry.cooldown)) or float(entry.progress) < 0.0 or float(entry.progress) > 1.0 or float(entry.cooldown) < 0.0 or float(entry.cooldown) > COOLDOWN_SECONDS:
			return false
		# Rest states have one canonical target/progress; MOVING only travels to
		# the opposite rest state, preventing impossible replica combinations.
		if (int(entry.state) == STATE_REST_A and (int(entry.target) != STATE_REST_A or float(entry.progress) != 0.0)) or (int(entry.state) == STATE_REST_B and (int(entry.target) != STATE_REST_B or float(entry.progress) != 1.0)) or (int(entry.state) == STATE_MOVING and (int(entry.target) == STATE_MOVING or float(entry.progress) >= 1.0)):
			return false
		seen[entry.id] = true
	return seen.size() == 2


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
