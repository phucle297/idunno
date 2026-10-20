class_name ToySabotage
extends Node

# Server-owned, analytical toy actions. The snapshot is deliberately bounded so
# presentation never receives an untrusted or unbounded effects list.
const MAX_PICKUPS := 6
const MAX_SLOTS := 20
const MAX_PROJECTILES := 4
const MAX_OWNER_PROJECTILES := 2
const MAX_WARNINGS := 6
const MAX_OUTCOMES := 6
const MAX_EFFECTS := MAX_PROJECTILES + MAX_WARNINGS + MAX_OUTCOMES
const PICKUP_LIFETIME := 60.0
const FIRST_SPAWN := 5.0
const SPAWN_INTERVAL := 15.0
const PICKUP_RANGE := 1.5
const OPENING_PROTECTION := 3.0
const BLAST_RADIUS := 2.4
const HAMMER_RANGE := 2.2
const PLAYER_RADIUS := 0.28
const PLAYER_HEIGHT := 1.5
const FEEDBACK_MAX_CHARS := 24
const KINDS := {"foam_blaster": 3, "plunger_rocket": 1, "squeaky_hammer": 2, "boxing_glove": 2, "boomerang": 2, "water_soaker": 6}
const PROJECTILES := ["pellet", "rocket", "frisbee_out", "frisbee_back", "water_jet"]
const WARNINGS := ["blast_warning", "hammer_warning", "glove_warning", "wet_strip"]
const OUTCOMES := ["hit", "blocked", "miss"]

var anchors: Array[Vector3] = []
var anchor_is_valid: Callable
var collection_is_clear: Callable
var round_sequence := 0
var pickups: Array[Dictionary] = []
var slots: Dictionary = {}
var effects: Array[Dictionary] = []
var _manager: MatchManager
var _players: Dictionary = {}
var _shoves: ShoveManager
var _revision := 0
var _next_id := 0
var _spawn_slot := -1
var _seen_sequences: Dictionary = {}
var _item_sequences: Dictionary = {}
var _local_sequence := 0


func configure(manager: MatchManager, players: Dictionary, shoves: ShoveManager) -> void:
	_manager = manager
	_players = players
	_shoves = shoves


func begin_round() -> void:
	reset()
	round_sequence += 1
	if is_instance_valid(_shoves):
		_shoves.set_item_round(round_sequence)
	_revision = 0
	_seen_sequences.clear()
	_local_sequence = 0


func reset_session() -> void:
	reset()
	round_sequence = 0
	_revision = 0
	_seen_sequences.clear()
	_item_sequences.clear()
	_local_sequence = 0
	if is_instance_valid(_shoves):
		_shoves.reset_item_session()


func reset() -> void:
	if not pickups.is_empty() or not slots.is_empty() or not effects.is_empty():
		_revision += 1
	pickups.clear()
	slots.clear()
	effects.clear()
	_next_id = 0
	_spawn_slot = -1


func remove_player(peer_id: int) -> void:
	if not _can_mutate() or peer_id <= 0:
		return
	var changed := slots.erase(peer_id)
	for index in range(effects.size() - 1, -1, -1):
		if int(effects[index].owner) == peer_id:
			effects.remove_at(index)
			changed = true
	if changed:
		_revision += 1


func local_request_pickup(peer_id: int) -> void:
	_local_sequence += 1
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		request_pickup(peer_id, round_sequence, _local_sequence)
	else:
		_request_pickup.rpc(round_sequence, _local_sequence)


func local_request_use(peer_id: int, direction: Vector3) -> void:
	_local_sequence += 1
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		request_use(peer_id, round_sequence, _local_sequence, direction)
	else:
		_request_use.rpc(round_sequence, _local_sequence, direction)


@rpc("any_peer", "call_remote", "reliable")
func _request_pickup(round: int, sequence: int) -> void:
	if multiplayer.is_server():
		request_pickup(multiplayer.get_remote_sender_id(), round, sequence)


@rpc("any_peer", "call_remote", "reliable")
func _request_use(round: int, sequence: int, direction: Vector3) -> void:
	if multiplayer.is_server():
		request_use(multiplayer.get_remote_sender_id(), round, sequence, direction)


func tick(delta: float, seed_value: int) -> void:
	if not _can_mutate():
		return
	if not is_instance_valid(_manager) or _manager.state != MatchManager.MatchState.ACTIVE:
		reset()
		return
	var now := _manager.elapsed_time
	for index in range(pickups.size() - 1, -1, -1):
		if float(pickups[index].expires) <= now or not _valid_anchor(pickups[index].position, false):
			pickups.remove_at(index)
			_revision += 1
	var spawn_slot := floori((now - FIRST_SPAWN) / SPAWN_INTERVAL)
	if now >= FIRST_SPAWN and spawn_slot > _spawn_slot:
		_spawn_slot = spawn_slot
		_spawn(now, seed_value, spawn_slot)
	_tick_effects(maxf(delta, 0.0))


func request_pickup(peer_id: int, round: int, sequence: int) -> bool:
	if not _can_mutate() or not _eligible(peer_id) or not _accept_sequence(peer_id, round, sequence):
		return false
	var actor := _players.get(peer_id) as PartyPlayer
	var winner := -1
	var closest := INF
	for index in pickups.size():
		var pickup := pickups[index]
		var distance := actor.global_position.distance_to(pickup.position)
		if distance <= PICKUP_RANGE and distance < closest and _collection_clear(actor, pickup.position):
			winner = index
			closest = distance
	if winner < 0:
		return _feedback(peer_id, "range")
	var pickup := pickups[winner]
	pickups.remove_at(winner)
	slots[peer_id] = {"kind": String(pickup.kind), "ammo": int(KINDS[pickup.kind]), "cooldown_until": 0.0, "feedback": "picked"}
	_revision += 1
	return true


func request_use(peer_id: int, round: int, sequence: int, direction: Vector3) -> bool:
	if not _can_mutate() or not _eligible(peer_id) or not _accept_sequence(peer_id, round, sequence):
		return false
	if _manager.elapsed_time < OPENING_PROTECTION:
		return _feedback(peer_id, "protected")
	if not _valid_direction(direction):
		return _feedback(peer_id, "aim")
	direction = direction.normalized()
	var slot: Dictionary = slots.get(peer_id, {})
	if slot.is_empty() or String(slot.get("kind", "")) not in KINDS or int(slot.get("ammo", 0)) <= 0:
		return _feedback(peer_id, "empty")
	if float(slot.get("cooldown_until", 0.0)) > _manager.elapsed_time:
		return _feedback(peer_id, "cooldown")
	var kind := String(slot.kind)
	if kind in ["squeaky_hammer", "boxing_glove"]:
		# Melee telegraphs are planar; camera pitch must not silently narrow them.
		direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if kind in ["plunger_rocket", "squeaky_hammer", "boxing_glove", "water_soaker"] and _warning_reservations() >= MAX_WARNINGS:
		return _feedback(peer_id, "capacity")
	if kind not in ["squeaky_hammer", "boxing_glove"] and (_projectile_count() >= MAX_PROJECTILES or _owner_projectiles(peer_id) >= MAX_OWNER_PROJECTILES):
		return _feedback(peer_id, "capacity")
	slot.ammo -= 1
	slot.cooldown_until = _manager.elapsed_time + (0.22 if kind == "foam_blaster" else 0.55)
	slot.feedback = "used"
	slots[peer_id] = slot
	_next_id += 1
	var origin := (_players[peer_id] as PartyPlayer).global_position + Vector3.UP * 1.05
	if kind in ["squeaky_hammer", "boxing_glove"]:
		effects.append({"id": _next_id, "kind": "glove_warning" if kind == "boxing_glove" else "hammer_warning", "position": origin, "direction": direction, "remaining": 0.65 if kind == "boxing_glove" else 0.35, "owner": peer_id})
	else:
		var effect_kind: String = {"foam_blaster": "pellet", "plunger_rocket": "rocket", "boomerang": "frisbee_out", "water_soaker": "water_jet"}[kind]
		effects.append({"id": _next_id, "kind": effect_kind, "position": origin, "direction": direction, "remaining": 1.0 if kind == "boomerang" else (0.65 if kind == "water_soaker" else 3.0), "owner": peer_id})
	_revision += 1
	return true


func _tick_effects(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		var effect := effects[index]
		effect.remaining = float(effect.remaining) - delta
		var kind := String(effect.kind)
		if kind in ["hammer_warning", "glove_warning"] and float(effect.remaining) <= 0.0:
			_hammer_hit(effect)
			effects.remove_at(index)
			_revision += 1
			continue
		if kind == "blast_warning" and float(effect.remaining) <= 0.0:
			_blast(effect)
			effects.remove_at(index)
			_revision += 1
			continue
		if kind in ["frisbee_out", "frisbee_back"]:
			_tick_frisbee(index, effect, delta)
			continue
		if kind in ["pellet", "rocket", "water_jet"]:
			var from: Vector3 = effect.position
			var speed := 8.0 if kind != "rocket" else 6.0
			var hit := _sweep(effect, from, from + effect.direction * speed * delta, 0.18)
			if not hit.is_empty():
				if kind == "rocket":
					effect.kind = "blast_warning"
					effect.position = hit.position
					effect.remaining = 0.8
					effects[index] = effect
				else:
					var made_strip: bool = kind == "water_jet" and _make_wet_strip(effect, hit.position)
					if int(hit.peer_id) > 0:
						var applied := _impulse(int(effect.owner), int(hit.peer_id), effect.direction, 1.8 if kind == "water_jet" else 2.4)
						_outcome("hit" if applied else "blocked", hit.position, effect.direction, int(effect.owner))
					elif not made_strip:
						_outcome("blocked", hit.position, effect.direction, int(effect.owner))
					if made_strip:
						effects[index] = effect
					else:
						effects.remove_at(index)
				_revision += 1
				continue
			effect.position = from + effect.direction * speed * delta
		if float(effect.remaining) <= 0.0:
			if kind == "water_jet" and _make_wet_strip(effect, effect.position):
				effects[index] = effect
				_revision += 1
				continue
			if kind in PROJECTILES:
				_outcome("miss", effect.position, effect.direction, int(effect.owner))
			effects.remove_at(index)
			_revision += 1
		else:
			effects[index] = effect


func _tick_frisbee(index: int, effect: Dictionary, delta: float) -> void:
	# A fixed straight return lane is readable and never homes on a moving owner.
	# Each leg hits at most one victim; protection still applies across all toys.
	var from: Vector3 = effect.position
	var hit := _sweep(effect, from, from + effect.direction * 6.0 * delta, 0.22)
	if not hit.is_empty():
		var applied := false
		if int(hit.peer_id) > 0:
			applied = _impulse(int(effect.owner), int(hit.peer_id), effect.direction, 2.6)
		_outcome("hit" if applied else "blocked", hit.position, effect.direction, int(effect.owner))
		# Return from the last clear point, not the victim's capsule surface:
		# an initial overlap there would immediately consume the return leg.
		effect.position = from
		if effect.kind == "frisbee_back":
			effects.remove_at(index)
			_revision += 1
			return
		effect.kind = "frisbee_back"
		effect.direction = -effect.direction
		effect.remaining = 1.0
	elif float(effect.remaining) <= 0.0:
		if effect.kind == "frisbee_back":
			_outcome("miss", from, effect.direction, int(effect.owner))
			effects.remove_at(index)
			_revision += 1
			return
		effect.kind = "frisbee_back"
		effect.direction = -effect.direction
		effect.remaining = 1.0
	else:
		effect.position = from + effect.direction * 6.0 * delta
	effects[index] = effect
	_revision += 1


func _make_wet_strip(effect: Dictionary, point: Vector3) -> bool:
	var actor := _players.get(int(effect.owner)) as PartyPlayer
	if not is_instance_valid(actor):
		return false
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point + Vector3.DOWN * 2.0, 1, [actor.get_rid()])
	var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < 0.7:
		return false
	effect.kind = "wet_strip"
	effect.position = floor_hit.position
	effect.direction = Vector3(effect.direction.x, 0, effect.direction.z).normalized()
	effect.remaining = 6.0
	return true


func sample_wet_strip(point: Vector3) -> float:
	if not point.is_finite():
		return 0.0
	var wet := 0.0
	for effect in effects:
		if effect.kind != "wet_strip" or absf(point.y - float(effect.position.y)) > 0.3:
			continue
		var offset: Vector3 = point - effect.position
		var forward: Vector3 = effect.direction
		if forward.length_squared() < 0.1:
			forward = Vector3.FORWARD
		if absf(offset.dot(forward)) <= 0.9 and absf(offset.dot(forward.cross(Vector3.UP))) <= 0.45 and _world_clear(effect.position + Vector3.UP * 0.08, point + Vector3.UP * 0.08, int(effect.owner)):
			wet = maxf(wet, 0.8 * clampf(float(effect.remaining) / 6.0, 0.0, 1.0))
	return wet


func _sweep(effect: Dictionary, from: Vector3, to: Vector3, radius: float) -> Dictionary:
	var owner := _players.get(int(effect.owner)) as PartyPlayer
	if not is_instance_valid(owner):
		return {"position": from, "peer_id": 0}
	var shape := SphereShape3D.new()
	shape.radius = radius
	var world_query := PhysicsShapeQueryParameters3D.new()
	world_query.shape = shape
	world_query.transform.origin = from
	world_query.motion = to - from
	world_query.collision_mask = 1 | 4
	world_query.exclude = [owner.get_rid()]
	var space := owner.get_world_3d().direct_space_state
	var overlap := not space.intersect_shape(world_query, 1).is_empty()
	var fractions := space.cast_motion(world_query)
	var best_t := 0.0 if overlap else fractions[0]
	var world_blocked := overlap or best_t < 1.0
	var result := {"position": from.lerp(to, best_t), "peer_id": 0}
	for peer_id: int in _players:
		if peer_id == int(effect.owner) or not _eligible(peer_id):
			continue
		var victim := _players[peer_id] as PartyPlayer
		var hit_t := _capsule_sweep_t(from, to, victim.global_position, radius + PLAYER_RADIUS)
		if hit_t >= 0.0 and hit_t < best_t:
			best_t = hit_t
			result = {"position": from.lerp(to, hit_t), "peer_id": peer_id}
	return result if world_blocked or int(result.peer_id) > 0 else {}


func _capsule_sweep_t(from: Vector3, to: Vector3, base: Vector3, radius: float) -> float:
	var axis_a := base + Vector3.UP * PLAYER_RADIUS
	var axis_b := base + Vector3.UP * (PLAYER_HEIGHT - PLAYER_RADIUS)
	# A capsule is a vertical finite cylinder plus its two end spheres. Solve
	# each boundary analytically and retain the earliest segment time; using a
	# point-distance check here would report the closest, not first, victim.
	if _point_capsule_distance_squared(from, axis_a, axis_b) <= radius * radius:
		return 0.0
	var delta := to - from
	var relative := from - base
	var a := delta.x * delta.x + delta.z * delta.z
	var b := 2.0 * (relative.x * delta.x + relative.z * delta.z)
	var c := relative.x * relative.x + relative.z * relative.z - radius * radius
	var earliest := INF
	if a > 0.000001:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var candidates: Array[float] = [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]
			for time: float in candidates:
				var y: float = from.y + delta.y * time
				if time >= 0.0 and time <= 1.0 and y >= axis_a.y and y <= axis_b.y:
					earliest = minf(earliest, time)
	for center in [axis_a, axis_b]:
		earliest = minf(earliest, _sphere_sweep_t(from, delta, center, radius))
	return earliest if earliest < INF else -1.0


func _point_capsule_distance_squared(point: Vector3, axis_a: Vector3, axis_b: Vector3) -> float:
	var closest := Geometry3D.get_closest_point_to_segment(point, axis_a, axis_b)
	return point.distance_squared_to(closest)


func _sphere_sweep_t(from: Vector3, delta: Vector3, center: Vector3, radius: float) -> float:
	var offset := from - center
	var a := delta.length_squared()
	var b := 2.0 * offset.dot(delta)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if a <= 0.000001 or discriminant < 0.0:
		return INF
	var first := (-b - sqrt(discriminant)) / (2.0 * a)
	return first if first >= 0.0 and first <= 1.0 else INF


func _hammer_hit(effect: Dictionary) -> void:
	var owner := _players.get(int(effect.owner)) as PartyPlayer
	if not is_instance_valid(owner) or not _eligible(int(effect.owner)):
		return
	var origin: Vector3 = effect.position
	if owner.global_position.distance_to(origin - Vector3.UP * 1.05) > 2.0:
		_outcome("blocked", origin, effect.direction, int(effect.owner))
		return
	var hit_any := false
	for peer_id: int in _players:
		if peer_id == int(effect.owner) or not _eligible(peer_id):
			continue
		var victim := _players[peer_id] as PartyPlayer
		var offset: Vector3 = victim.global_position + Vector3.UP * 0.75 - origin
		var flat := Vector3(offset.x, 0.0, offset.z)
		var glove: bool = effect.kind == "glove_warning"
		if flat.length() <= (3.0 if glove else HAMMER_RANGE) and absf(offset.y) <= 1.2 and flat.length_squared() > 0.001 and effect.direction.dot(flat.normalized()) >= (0.94 if glove else 0.55) and _world_clear(origin, victim.global_position + Vector3.UP * 0.75, int(effect.owner)):
			var applied := _impulse(int(effect.owner), peer_id, effect.direction, 5.5 if glove else 3.2)
			_outcome("hit" if applied else "blocked", victim.global_position, effect.direction, int(effect.owner))
			hit_any = hit_any or applied
	if not hit_any:
		_outcome("miss", origin, effect.direction, int(effect.owner))


func _blast(effect: Dictionary) -> void:
	var hit_any := false
	for peer_id: int in _players:
		if not _eligible(peer_id):
			continue
		var victim := _players[peer_id] as PartyPlayer
		var offset: Vector3 = victim.global_position + Vector3.UP * 0.75 - effect.position
		if offset.length() <= BLAST_RADIUS and _world_clear(effect.position, victim.global_position + Vector3.UP * 0.75, int(effect.owner)):
			hit_any = _impulse(int(effect.owner), peer_id, offset, 4.5) or hit_any
	_outcome("hit" if hit_any else "miss", effect.position, effect.direction, int(effect.owner))


func _impulse(owner: int, victim: int, direction: Vector3, strength: float) -> bool:
	if is_instance_valid(_manager) and _manager.elapsed_time < OPENING_PROTECTION:
		return false
	if is_instance_valid(_shoves) and not _shoves.is_protected(victim):
		_item_sequences[victim] = int(_item_sequences.get(victim, 0)) + 1
		return _shoves.apply_authoritative_item_impulse(owner, victim, _item_sequences[victim], direction, strength)
	return false


func _outcome(kind: String, position: Vector3, direction: Vector3, owner: int) -> void:
	var count := 0
	for effect in effects:
		if String(effect.kind) in ["hit", "blocked", "miss"]:
			count += 1
	if count >= MAX_OUTCOMES:
		return
	_next_id += 1
	effects.append({"id": _next_id, "kind": kind, "position": position, "direction": direction, "remaining": 0.45, "owner": owner})


func _accept_sequence(peer_id: int, round: int, sequence: int) -> bool:
	if peer_id <= 0 or round != round_sequence or sequence <= 0:
		return false
	var seen := int(_seen_sequences.get(peer_id, 0))
	if sequence <= seen or sequence > seen + 64:
		return false
	_seen_sequences[peer_id] = sequence
	return true


func _eligible(peer_id: int) -> bool:
	var actor := _players.get(peer_id) as PartyPlayer
	return peer_id > 0 and is_instance_valid(_manager) and _manager.state == MatchManager.MatchState.ACTIVE and _manager.is_player_alive(peer_id) and is_instance_valid(actor) and actor.can_perform_actions()


func _valid_direction(direction: Vector3) -> bool:
	if not direction.is_finite() or direction.length_squared() < 0.25 or direction.length_squared() > 2.25:
		return false
	var unit := direction.normalized()
	return unit.y >= sin(-1.1) - 0.1 and unit.y <= sin(0.35) + 0.1


func _valid_anchor(point: Vector3, spawning: bool) -> bool:
	return anchor_is_valid.is_valid() and bool(anchor_is_valid.call(point, spawning))


func _collection_clear(actor: PartyPlayer, point: Vector3) -> bool:
	return collection_is_clear.is_valid() and bool(collection_is_clear.call(actor, point))


func _world_clear(from: Vector3, to: Vector3, ignore_id: int) -> bool:
	var actor := _players.get(ignore_id) as PartyPlayer
	if not is_instance_valid(actor):
		return false
	return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [actor.get_rid()])).is_empty()


func _feedback(peer_id: int, value: String) -> bool:
	var slot: Dictionary = slots.get(peer_id, {"kind": "", "ammo": 0, "cooldown_until": 0.0})
	slot.feedback = value.left(FEEDBACK_MAX_CHARS)
	slots[peer_id] = slot
	_revision += 1
	return false


func _spawn(now: float, seed: int, spawn_slot: int) -> void:
	if pickups.size() >= MAX_PICKUPS:
		return
	var eligible: Array[Vector3] = []
	for point in anchors:
		if not _valid_anchor(point, true):
			continue
		var occupied := false
		for pickup in pickups:
			if point.distance_squared_to(pickup.position) < 4.0:
				occupied = true
				break
		if not occupied:
			eligible.append(point)
	if eligible.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + spawn_slot * 104729
	_next_id += 1
	pickups.append({"id": _next_id, "kind": _kind_for_spawn(spawn_slot), "position": eligible[rng.randi_range(0, eligible.size() - 1)], "expires": now + PICKUP_LIFETIME})
	_revision += 1


func _kind_for_spawn(spawn_slot: int) -> String:
	var ordered := KINDS.keys()
	return ordered[posmod(spawn_slot, ordered.size())]


func _projectile_count() -> int:
	var count := 0
	for effect in effects:
		if String(effect.kind) in PROJECTILES:
			count += 1
	return count


func _owner_projectiles(owner: int) -> int:
	var count := 0
	for effect in effects:
		if int(effect.owner) == owner and String(effect.kind) in PROJECTILES:
			count += 1
	return count


func _warning_reservations() -> int:
	var count := 0
	for effect in effects:
		if String(effect.kind) in WARNINGS or String(effect.kind) in ["rocket", "water_jet"]:
			count += 1
	return count


# Fixed-width wire state avoids repeating dictionary keys on every match update.
# Full dictionaries remain the local presentation/testing contract.
const WIRE_KINDS := ["", "foam_blaster", "plunger_rocket", "squeaky_hammer", "boxing_glove", "boomerang", "water_soaker", "pellet", "rocket", "blast_warning", "hammer_warning", "hit", "blocked", "miss", "glove_warning", "frisbee_out", "frisbee_back", "water_jet", "wet_strip"]
const WIRE_FEEDBACK := ["", "picked", "used", "range", "protected", "aim", "empty", "cooldown", "capacity"]


func create_wire_snapshot() -> PackedByteArray:
	var state := create_snapshot()
	var stream := StreamPeerBuffer.new()
	stream.put_u32(state.round)
	stream.put_u32(state.revision)
	stream.put_u8(state.pickups.size())
	stream.put_u8(state.slots.size())
	stream.put_u8(state.effects.size())
	for pickup: Dictionary in state.pickups:
		stream.put_u32(pickup.id)
		stream.put_u8(WIRE_KINDS.find(pickup.kind))
		_wire_put_vector(stream, pickup.position)
		stream.put_float(pickup.expires)
	for peer_id: int in state.slots:
		var slot: Dictionary = state.slots[peer_id]
		stream.put_u32(peer_id)
		stream.put_u8(WIRE_KINDS.find(slot.kind))
		stream.put_u8(slot.ammo)
		stream.put_u16(clampi(ceili(float(slot.cooldown) * 100.0), 0, 65535))
		stream.put_u8(WIRE_FEEDBACK.find(slot.feedback))
	for effect: Dictionary in state.effects:
		stream.put_u32(effect.id)
		stream.put_u8(WIRE_KINDS.find(effect.kind))
		_wire_put_vector(stream, effect.position)
		_wire_put_vector(stream, effect.direction)
		stream.put_float(effect.remaining)
		stream.put_u32(effect.owner)
	return stream.data_array


static func decode_wire_snapshot(value: Variant) -> Dictionary:
	if not value is PackedByteArray or value.size() < 11:
		return {}
	var stream := StreamPeerBuffer.new()
	stream.data_array = value
	var state := {"round": stream.get_u32(), "revision": stream.get_u32(), "pickups": [], "slots": {}, "effects": []}
	var pickup_count := stream.get_u8()
	var slot_count := stream.get_u8()
	var effect_count := stream.get_u8()
	if pickup_count > MAX_PICKUPS or slot_count > MAX_SLOTS or effect_count > MAX_EFFECTS or value.size() != 11 + pickup_count * 21 + slot_count * 9 + effect_count * 37:
		return {}
	for index in pickup_count:
		var id := stream.get_u32()
		var kind := stream.get_u8()
		if kind >= WIRE_KINDS.size() or WIRE_KINDS[kind] not in KINDS:
			return {}
		state.pickups.append({"id": id, "kind": WIRE_KINDS[kind], "position": _wire_get_vector(stream), "expires": stream.get_float()})
	for index in slot_count:
		var peer_id := stream.get_u32()
		var kind := stream.get_u8()
		var ammo := stream.get_u8()
		var cooldown := stream.get_u16() / 100.0
		var feedback := stream.get_u8()
		if kind >= WIRE_KINDS.size() or (kind != 0 and WIRE_KINDS[kind] not in KINDS) or feedback >= WIRE_FEEDBACK.size() or state.slots.has(peer_id):
			return {}
		state.slots[peer_id] = {"kind": WIRE_KINDS[kind], "ammo": ammo, "cooldown": cooldown, "feedback": WIRE_FEEDBACK[feedback]}
	for index in effect_count:
		var id := stream.get_u32()
		var kind := stream.get_u8()
		if kind >= WIRE_KINDS.size() or WIRE_KINDS[kind] not in PROJECTILES + WARNINGS + OUTCOMES:
			return {}
		state.effects.append({"id": id, "kind": WIRE_KINDS[kind], "position": _wire_get_vector(stream), "direction": _wire_get_vector(stream), "remaining": stream.get_float(), "owner": stream.get_u32()})
	return state if snapshot_is_valid(state) else {}


static func _wire_put_vector(stream: StreamPeerBuffer, value: Vector3) -> void:
	stream.put_float(value.x)
	stream.put_float(value.y)
	stream.put_float(value.z)


static func _wire_get_vector(stream: StreamPeerBuffer) -> Vector3:
	return Vector3(stream.get_float(), stream.get_float(), stream.get_float())


func create_snapshot() -> Dictionary:
	var now := _manager.elapsed_time if is_instance_valid(_manager) else 0.0
	var visible_slots := {}
	for peer_id in slots:
		var slot: Dictionary = slots[peer_id]
		visible_slots[peer_id] = {"kind": String(slot.get("kind", "")), "ammo": int(slot.get("ammo", 0)), "cooldown": maxf(0.0, float(slot.get("cooldown_until", 0.0)) - now), "feedback": String(slot.get("feedback", "")).left(FEEDBACK_MAX_CHARS)}
	return {"round": round_sequence, "revision": _revision, "pickups": pickups.duplicate(true), "slots": visible_slots, "effects": effects.duplicate(true)}


static func snapshot_is_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("round") is int or not value.get("revision") is int or not value.get("pickups") is Array or not value.get("slots") is Dictionary or not value.get("effects") is Array:
		return false
	if value.round < 0 or value.revision < 0 or value.pickups.size() > MAX_PICKUPS or value.slots.size() > MAX_SLOTS or value.effects.size() > MAX_EFFECTS:
		return false
	var ids := {}
	for entry in value.pickups:
		if not _pickup_valid(entry) or ids.has(entry.id):
			return false
		ids[entry.id] = true
	for peer_id in value.slots:
		var slot: Variant = value.slots[peer_id]
		if not peer_id is int or peer_id <= 0 or not _slot_valid(slot):
			return false
	for effect in value.effects:
		if not _effect_valid(effect) or ids.has(effect.id):
			return false
		ids[effect.id] = true
	return true


static func _pickup_valid(entry: Variant) -> bool:
	return entry is Dictionary and entry.get("id") is int and entry.id > 0 and String(entry.get("kind", "")) in KINDS and entry.get("position") is Vector3 and entry.position.is_finite() and _finite_number(entry.get("expires")) and float(entry.expires) >= 0.0


static func _slot_valid(slot: Variant) -> bool:
	if not slot is Dictionary or not slot.get("kind") is String or not slot.get("ammo") is int or not slot.get("feedback") is String or not _finite_number(slot.get("cooldown")):
		return false
	var kind := String(slot.kind)
	return (kind.is_empty() or kind in KINDS) and slot.ammo >= 0 and (kind.is_empty() or slot.ammo <= int(KINDS[kind])) and float(slot.cooldown) >= 0.0 and slot.feedback.length() <= FEEDBACK_MAX_CHARS


static func _effect_valid(effect: Variant) -> bool:
	return effect is Dictionary and effect.get("id") is int and effect.id > 0 and String(effect.get("kind", "")) in PROJECTILES + WARNINGS + OUTCOMES and effect.get("position") is Vector3 and effect.position.is_finite() and effect.get("direction") is Vector3 and effect.direction.is_finite() and _finite_number(effect.get("remaining")) and float(effect.remaining) >= 0.0 and effect.get("owner") is int and effect.owner > 0


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func apply_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot_is_valid(snapshot) or int(snapshot.round) < round_sequence or (int(snapshot.round) == round_sequence and int(snapshot.revision) < _revision):
		return false
	if int(snapshot.round) != round_sequence:
		_local_sequence = 0
	round_sequence = int(snapshot.round)
	if is_instance_valid(_shoves):
		_shoves.set_item_round(round_sequence)
	_revision = int(snapshot.revision)
	pickups.assign(snapshot.pickups.duplicate(true))
	effects.assign(snapshot.effects.duplicate(true))
	slots.clear()
	var now := _manager.elapsed_time if is_instance_valid(_manager) else 0.0
	for peer_id in snapshot.slots:
		var slot: Dictionary = snapshot.slots[peer_id]
		slots[peer_id] = {"kind": slot.kind, "ammo": slot.ammo, "cooldown_until": now + float(slot.cooldown), "feedback": slot.feedback}
	return true


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
