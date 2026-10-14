class_name Earthquake
extends Node3D

signal warning_started(duration: float)
signal activated
signal structure_changed(piece_id: String, state: int)
signal finished

enum Phase {
	IDLE,
	WARNING,
	ACTIVE
}

const DISASTER_NAME := "Earthquake"
const DAMAGE_CAUSE := "Earthquake"
const BURNING_RUBBLE_CAUSE := "Burning Rubble"
# Fire on another floor cannot ignite dry collapse rubble above it.
const BURNING_RUBBLE_RADIUS := 6.0

@export var warning_duration := 4.0
@export var active_duration := 8.0
@export var pulse_interval := 1.25
@export var pulse_damage := 5.0
@export var fracture_radius := 3.0
@export var max_fractures := 3
@export var prop_impulse_max := 12.0
@export var max_broken_sections := 2
@export var burning_rubble_lifetime := 6.0
@export var burning_rubble_hit_speed := 4.0
@export var burning_rubble_hit_radius := 1.0
@export var burning_rubble_damage := 20.0

var phase := Phase.IDLE
var warning_remaining := 0.0
var active_remaining := 0.0
var pulse_count := 0
var refuge_pressure := false
var fracture_positions := PackedVector3Array()
var support_height: Callable

var _match_manager: MatchManager
var _players: Dictionary = {}
var _pulse_remaining := 0.0
var _rng := RandomNumberGenerator.new()
var _effect: Node3D
var _fracture_material: StandardMaterial3D
var _structure_root: Node
var _burning_positions: Array[Vector3] = []
var _burning_rubble: Array[Dictionary] = []
var _burning_rubble_visuals: Array[MeshInstance3D] = []
var _water_level := -INF


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func set_structure_root(root: Node) -> void:
	_structure_root = root


func set_refuge_pressure(active: bool) -> void:
	refuge_pressure = active


func set_burning_positions(positions: Array[Vector3]) -> void:
	if not _can_mutate():
		return
	_burning_positions.clear()
	for burning_position in positions:
		_burning_positions.append(burning_position)


func burning_rubble_count() -> int:
	return _burning_rubble.size()


func set_water_level(level: float) -> void:
	if not _can_mutate():
		return
	_water_level = level
	for index in range(_burning_rubble.size() - 1, -1, -1):
		var body := _burning_rubble[index].get("body") as RigidBody3D
		if not is_instance_valid(body) or _water_level < body.global_position.y - 0.2:
			continue
		body.remove_from_group("burning_rubble")
		body.set_meta("burning_rubble", false)
		for child in body.get_children():
			if child is MeshInstance3D:
				child.material_override = null
		_remove_burning_visual_at(index)
		_burning_rubble.remove_at(index)
		# Keep the independent physical rubble; its structure owns cleanup.


func get_disaster_metadata() -> Dictionary:
	return {
		"name": DISASTER_NAME,
		"difficulty": 2,
		"minimum_match_time": 90.0,
		"incompatible_disasters": [],
		"combination_tags": ["ground", "debris", "structure"]
	}


func start_disaster(rng: RandomNumberGenerator) -> bool:
	_rng.seed = rng.randi()
	return start_warning()


func is_active() -> bool:
	return phase != Phase.IDLE


func register_player(peer_id: int, player: Node3D) -> bool:
	if not _can_mutate() or peer_id <= 0 or not is_instance_valid(player) or _players.has(peer_id):
		return false
	_players[peer_id] = player
	return true


func unregister_player(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	_players.erase(peer_id)
	return true


func start_warning() -> bool:
	if not _can_mutate() or phase != Phase.IDLE or not is_instance_valid(_match_manager):
		return false
	if _match_manager.state != MatchManager.MatchState.ACTIVE:
		return false
	phase = Phase.WARNING
	warning_remaining = warning_duration
	active_remaining = active_duration
	_pulse_remaining = 0.0
	pulse_count = 0
	_select_fractures()
	_spawn_effect()
	warning_started.emit(warning_duration)
	return true


func tick(delta: float) -> void:
	if not _can_mutate():
		return
	var safe_delta := maxf(delta, 0.0)
	set_water_level(_water_level)
	_update_burning_rubble(safe_delta)
	if phase == Phase.IDLE:
		return
	if phase == Phase.WARNING:
		warning_remaining = maxf(warning_remaining - safe_delta, 0.0)
		_update_effect()
		if warning_remaining <= 0.0:
			phase = Phase.ACTIVE
			_pulse_remaining = 0.0
			activated.emit()
	elif phase == Phase.ACTIVE:
		active_remaining = maxf(active_remaining - safe_delta, 0.0)
		_pulse_remaining -= safe_delta
		while _pulse_remaining <= 0.0 and active_remaining > 0.0:
			_pulse_remaining += pulse_interval
			_apply_pulse()
		_update_effect()
		if active_remaining <= 0.0:
			_finish()


func cleanup() -> void:
	_clear_burning_rubble()
	_burning_positions.clear()
	_reset_phase_state()


func _reset_phase_state() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	phase = Phase.IDLE
	warning_remaining = 0.0
	active_remaining = 0.0
	_pulse_remaining = 0.0
	refuge_pressure = false
	fracture_positions.clear()


func active_effect_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func create_presentation_snapshot() -> Dictionary:
	var structure_states := PackedByteArray()
	for section in _sections():
		structure_states.append(section.structure_state)
	return {
		"phase": int(phase),
		"warning_remaining": warning_remaining,
		"active_remaining": active_remaining,
		"fractures": fracture_positions,
		"structure_states": structure_states,
		"burning_rubble": _burning_rubble_positions(),
	}


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false
	var next_phase := clampi(int(snapshot.get("phase", Phase.IDLE)), Phase.IDLE, Phase.ACTIVE)
	if next_phase == Phase.IDLE:
		cleanup()
	else:
		phase = next_phase
		warning_remaining = maxf(float(snapshot.get("warning_remaining", 0.0)), 0.0)
		active_remaining = maxf(float(snapshot.get("active_remaining", 0.0)), 0.0)
		var next_fractures: PackedVector3Array = snapshot.get("fractures", PackedVector3Array())
		if next_fractures != fracture_positions and is_instance_valid(_effect):
			_effect.queue_free()
			_effect = null
		fracture_positions = next_fractures
		if not is_instance_valid(_effect):
			_spawn_effect()
		_update_effect()
	var structure_states: PackedByteArray = snapshot.get("structure_states", PackedByteArray())
	var sections := _sections()
	for index in mini(structure_states.size(), sections.size()):
		sections[index].set_structure_state(int(structure_states[index]), false)
	_apply_burning_rubble_presentation(snapshot.get("burning_rubble", PackedVector3Array()))
	return true


func get_structure_states() -> Dictionary:
	var result := {}
	for section in _sections():
		result[section.piece_id] = section.structure_state
	return result


func _process(delta: float) -> void:
	tick(delta)


func is_in_fracture(point: Vector3) -> bool:
	for center in fracture_positions:
		# Feet/contact volume includes an ordinary jump: jump-spam is not a
		# separate immunity. Floors above or below the support stay independent.
		if point.y < center.y - 0.5 or point.y > center.y + 2.0:
			continue
		if Vector2(point.x - center.x, point.z - center.z).length() <= fracture_radius:
			return true
	return false


func get_escape_context(point: Vector3) -> String:
	if phase == Phase.IDLE:
		return ""
	for section in _sections():
		if section.structure_state == BreakableStructure.StructureState.DAMAGED and section.supports_point(point):
			return "Leave cracked roof / route"
	if is_in_fracture(point):
		return "Leave cracked ground — %ds" % ceili(warning_remaining) if phase == Phase.WARNING else "Leave cracked ground"
	return ""


func _select_fractures() -> void:
	fracture_positions.clear()
	var ids: Array = _players.keys()
	ids.sort()
	# Freeze at warning start, never chase a player's feet during escape.
	for peer_id: int in ids:
		var player := _players[peer_id] as Node3D
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		var center := player.global_position
		if support_height.is_valid():
			center.y = float(support_height.call(center))
		center.y += 0.06
		if fracture_positions.size() >= max_fractures:
			break
		var separated := true
		for other in fracture_positions:
			if center.distance_to(other) < fracture_radius * 2.5:
				separated = false
		if separated:
			fracture_positions.append(center)


func _apply_pulse() -> void:
	pulse_count += 1
	var damage_events: Array[Dictionary] = []
	for peer_id: int in _players:
		var player := _players[peer_id] as PartyPlayer
		if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
			continue
		if is_in_fracture(player.global_position):
			damage_events.append({"peer_id": peer_id, "amount": pulse_damage, "cause": DAMAGE_CAUSE})
	if not damage_events.is_empty():
		_match_manager.apply_damage_batch(damage_events)
	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.sleeping = false
		body.apply_central_impulse(Vector3(
			_rng.randf_range(-1.0, 1.0),
			0.35,
			_rng.randf_range(-1.0, 1.0)
		).normalized() * prop_impulse_max)
	_damage_structure()


func _damage_structure() -> void:
	var candidates: Array[BreakableStructure] = []
	var broken_count := 0
	for section in _sections():
		if section.structure_state == BreakableStructure.StructureState.BROKEN:
			broken_count += 1
			continue
		# Preserve-one-option guard: never break the last piece of a paired
		# route/refuge group, so at least one reachable escape stays available.
		if section.structure_state == BreakableStructure.StructureState.DAMAGED and _partner_already_broken(section):
			continue
		candidates.append(section)
	if candidates.is_empty():
		return
	var preferred := _preferred_sections(candidates)
	var section := preferred[_rng.randi_range(0, preferred.size() - 1)]
	if section.structure_state == BreakableStructure.StructureState.DAMAGED and broken_count >= max_broken_sections:
		return
	if section.apply_damage(true):
		structure_changed.emit(section.piece_id, section.structure_state)
		if section.structure_state == BreakableStructure.StructureState.BROKEN:
			_maybe_ignite_rubble(section)


func _partner_already_broken(section: BreakableStructure) -> bool:
	if section.pair_group.is_empty():
		return false
	for other in _sections():
		if other != section and other.pair_group == section.pair_group and other.structure_state == BreakableStructure.StructureState.BROKEN:
			return true
	return false


func _preferred_sections(candidates: Array[BreakableStructure]) -> Array[BreakableStructure]:
	var best_score := 0
	var scores: Array[int] = []
	for section in candidates:
		var score := _collapse_score(section)
		scores.append(score)
		best_score = maxi(best_score, score)
	var preferred: Array[BreakableStructure] = []
	for index in candidates.size():
		if scores[index] == best_score:
			preferred.append(candidates[index])
	return preferred


func _collapse_score(section: BreakableStructure) -> int:
	# Meaningful loss over decorative damage; flood refuge pressure pushes the
	# seeded target choice toward elevated standing surfaces first.
	if section.route_role == BreakableStructure.ROLE_DECORATIVE:
		return 1
	if section.route_role == BreakableStructure.ROLE_ELEVATED:
		return 3 if refuge_pressure else 2
	return 2


func _sections() -> Array[BreakableStructure]:
	var result: Array[BreakableStructure] = []
	if not is_inside_tree():
		return result
	if is_instance_valid(_structure_root):
		# Scoped discovery keeps server and client sandboxes from cross-talking
		# when two instances live in one tree (network test fixtures).
		for candidate in _structure_root.get_children():
			if candidate is BreakableStructure:
				result.append(candidate)
	else:
		for candidate in get_tree().get_nodes_in_group("breakable_structure"):
			if candidate is BreakableStructure:
				result.append(candidate)
	result.sort_custom(func(a: BreakableStructure, b: BreakableStructure) -> bool: return a.piece_id < b.piece_id)
	return result


func _spawn_effect() -> void:
	_effect = Node3D.new()
	_effect.name = "EarthquakeEffect"
	add_child(_effect)
	_fracture_material = StandardMaterial3D.new()
	_fracture_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for center in fracture_positions:
		var footprint := Node3D.new()
		footprint.position = center
		_effect.add_child(footprint)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = fracture_radius - 0.16
		mesh.outer_radius = fracture_radius
		mesh.rings = 32
		mesh.ring_segments = 6
		ring.mesh = mesh
		footprint.add_child(ring)
		for index in 3:
			var crack := MeshInstance3D.new()
			var line := BoxMesh.new()
			line.size = Vector3(1.8, 0.04, 0.16)
			crack.mesh = line
			crack.position.x = (index - 1) * 1.35
			crack.rotation.y = 0.4 if index % 2 == 0 else -0.4
			footprint.add_child(crack)
		var label := Label3D.new()
		label.name = "EscapeLabel"
		label.position = Vector3(0.0, 2.2, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		label.pixel_size = 0.007
		label.modulate = Color("202a38")
		label.outline_modulate = Color("f4e6c8")
		label.outline_size = 10
		footprint.add_child(label)
	_update_effect()


func _update_effect() -> void:
	if not is_instance_valid(_effect):
		return
	_fracture_material.albedo_color = Color("ffbf3f") if phase == Phase.WARNING else Color("f06438")
	for footprint in _effect.get_children():
		for child in footprint.get_children():
			if child is MeshInstance3D:
				child.material_override = _fracture_material
		var label := footprint.get_node("EscapeLabel") as Label3D
		label.text = "CRACKS • %ds" % ceili(warning_remaining) if phase == Phase.WARNING else "CRACKS • MOVE OUT"


func _finish() -> void:
	if is_instance_valid(_match_manager) and _match_manager.state == MatchManager.MatchState.ACTIVE:
		_match_manager.record_disaster_survived()
	# Burning rubble outlives the quake's active window and expires on its own
	# short lifetime; only a full cleanup clears it early.
	_reset_phase_state()
	finished.emit()


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _maybe_ignite_rubble(section: BreakableStructure) -> void:
	if _burning_positions.is_empty():
		return
	var body := section.get_debris()
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if _water_level >= body.global_position.y - 0.2:
		return
	var rubble_flat := Vector2(body.global_position.x, body.global_position.z)
	for burning_position in _burning_positions:
		var burning_flat := Vector2(burning_position.x, burning_position.z)
		if rubble_flat.distance_to(burning_flat) <= BURNING_RUBBLE_RADIUS and absf(body.global_position.y - burning_position.y) <= 2.0:
			# Explicit cue: ember-tinted glow on the quake rubble marks it as the
			# short-lived damaging kind rather than ordinary harmless debris.
			for child in body.get_children():
				if child is MeshInstance3D:
					child.material_override = _make_burning_material(1.2)
			var visual := _make_burning_visual()
			body.add_child(visual)
			body.add_to_group("burning_rubble")
			body.set_meta("burning_rubble", true)
			# Hot collapse debris tumbles out of the burning area instead of
			# hiding inside the flames.
			var outward := (body.global_position - burning_position) * Vector3(1.0, 0.0, 1.0)
			if outward.length() > 0.01:
				outward = outward.normalized()
			else:
				outward = Vector3.RIGHT
			body.apply_central_impulse((outward * 3.0 + Vector3.UP * 1.5) * body.mass)
			_burning_rubble.append({"body": body, "age": 0.0, "hits": {}})
			_burning_rubble_visuals.append(visual)
			return


func _update_burning_rubble(delta: float) -> void:
	var index := _burning_rubble.size() - 1
	while index >= 0:
		var rubble := _burning_rubble[index]
		var body := rubble.get("body") as RigidBody3D
		var expired := true
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			rubble["age"] = float(rubble.get("age", 0.0)) + delta
			expired = float(rubble["age"]) >= burning_rubble_lifetime
			if not expired and body.linear_velocity.length() >= burning_rubble_hit_speed:
				var hits := rubble.get("hits") as Dictionary
				for peer_id: int in _players:
					if hits.has(peer_id):
						continue
					var player := _players[peer_id] as Node3D
					if not is_instance_valid(player) or not _match_manager.is_player_alive(peer_id):
						continue
					if player.global_position.distance_to(body.global_position) > burning_rubble_hit_radius:
						continue
					hits[peer_id] = true
					_match_manager.apply_damage(peer_id, burning_rubble_damage, BURNING_RUBBLE_CAUSE)
		if expired:
			if is_instance_valid(body):
				body.queue_free()
			_remove_burning_visual_at(index)
			_burning_rubble.remove_at(index)
		index -= 1


func _clear_burning_rubble() -> void:
	for rubble in _burning_rubble:
		var body := rubble.get("body") as RigidBody3D
		if is_instance_valid(body):
			body.queue_free()
	_burning_rubble.clear()
	for visual in _burning_rubble_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	_burning_rubble_visuals.clear()


func _remove_burning_visual_at(index: int) -> void:
	if index >= _burning_rubble_visuals.size():
		return
	var visual := _burning_rubble_visuals[index]
	if is_instance_valid(visual):
		visual.queue_free()
	_burning_rubble_visuals.remove_at(index)


func _make_burning_visual() -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = "BurningRubbleVisual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 0.72, 0.72)
	mesh.material = _make_burning_material(2.5)
	visual.mesh = mesh
	return visual


func _make_burning_material(emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.12, 0.1, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.16, 0.04, 1.0)
	material.emission_energy_multiplier = emission_energy
	return material


func _burning_rubble_positions() -> PackedVector3Array:
	var positions := PackedVector3Array()
	for rubble in _burning_rubble:
		var body := rubble.get("body") as RigidBody3D
		if is_instance_valid(body):
			positions.append(body.global_position)
	return positions


func _apply_burning_rubble_presentation(positions: PackedVector3Array) -> void:
	# Presentation-only detached markers mirroring the authoritative rubble;
	# server physics and damage never touch these.
	for visual in _burning_rubble_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	_burning_rubble_visuals.clear()
	for value in positions:
		var rubble_position: Vector3 = value
		var visual := _make_burning_visual()
		visual.position = rubble_position
		add_child(visual)
		_burning_rubble_visuals.append(visual)
