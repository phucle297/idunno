class_name HotPotato
extends Node3D
## Authority owns the fuse. Public state contains no duration, age or RNG data.

enum Phase { IDLE, GROUND, CARRIED, FLIGHT, BURST, CANCEL }
const FUSE_MIN := 5.0
const FUSE_MAX := 15.0
const RANGE := 3.0
const SPEED := 10.0
const RADIUS := 2.4
const PICKUP_RANGE := 1.5
const WIRE_SIZE := 29

var anchors: Array[Vector3] = []
var anchor_is_valid: Callable
var collection_is_clear: Callable
var usable_area_fraction: Callable
var sweep: Callable
var apply_impulse: Callable
var round_sequence := 0
var phase := Phase.IDLE
var holder_id := 0
var position_world := Vector3.ZERO
var parcel_id := 0
var _revision := 0
var _manager: MatchManager
var _players: Dictionary
var _enabled := false
var _deadline := INF
var _next_spawn := 5.0
var _visual_until := 0.0
var _direction := Vector3.ZERO
var _distance := 0.0
var _source_id := 0
var _last_intent := {}
var _last_action := -INF
var _local_sequence := 0
var _rng := RandomNumberGenerator.new()


func configure(manager: MatchManager, players: Dictionary) -> void:
	_manager = manager
	_players = players
	_rng.randomize() # Independent of the publicly replicated director/map seed.


func begin_round(enabled: bool) -> void:
	reset()
	round_sequence += 1
	_enabled = enabled and _manager.get_alive_count() >= 2
	_last_intent.clear()
	_local_sequence = 0
	_next_spawn = 5.0


func reset() -> void:
	phase = Phase.IDLE
	holder_id = 0
	position_world = Vector3.ZERO
	_deadline = INF
	_enabled = false
	_last_action = -INF
	_revision = _revision + 1 if _authority() else 0


func reset_session() -> void:
	reset()
	round_sequence = 0
	_revision = 0
	parcel_id = 0
	_last_intent.clear()
	_local_sequence = 0


func is_carrier(peer_id: int) -> bool:
	return holder_id == peer_id and phase == Phase.CARRIED


func can_collect(peer_id: int) -> bool:
	var actor := _actor(peer_id)
	return phase == Phase.GROUND and is_instance_valid(actor) and actor.global_position.distance_to(position_world) <= PICKUP_RANGE and collection_is_clear.is_valid() and bool(collection_is_clear.call(actor, position_world))


func local_request(peer_id: int, pickup: bool, direction := Vector3.ZERO) -> void:
	_local_sequence += 1
	if _authority():
		request(peer_id, round_sequence, _local_sequence, pickup, direction)
	else:
		_request.rpc_id(1, round_sequence, _local_sequence, pickup, direction)


@rpc("any_peer", "call_remote", "reliable")
func _request(round_id: int, sequence: int, pickup: bool, direction: Vector3) -> void:
	if multiplayer.is_server():
		request(multiplayer.get_remote_sender_id(), round_id, sequence, pickup, direction)


func request(peer_id: int, round_id: int, sequence: int, pickup: bool, direction := Vector3.ZERO) -> bool:
	if not _authority() or not _enabled or not _active() or not _eligible(peer_id) or round_id != round_sequence or sequence <= int(_last_intent.get(peer_id, 0)) or sequence <= 0 or sequence > 2147483647:
		return false
	_last_intent[peer_id] = sequence
	# Expiry precedes a newly received intent; clients cannot backdate a pass.
	if _expire():
		return false
	var actor := _actor(peer_id)
	if pickup:
		if not can_collect(peer_id) or not actor.is_on_floor() or not _valid_anchor(position_world, false):
			return false
		if is_inf(_deadline):
			_deadline = _now() + _rng.randf_range(FUSE_MIN, FUSE_MAX)
		_source_id = peer_id
		_carry(peer_id)
		return true
	if not is_carrier(peer_id) or _now() - _last_action < 0.25 or not direction.is_finite() or direction.length_squared() < 0.25 or direction.length_squared() > 2.25 or absf(direction.normalized().y) > 0.8:
		return false
	_direction = direction.normalized()
	_distance = 0.0
	position_world = actor.global_position + Vector3.UP * 1.05
	_source_id = peer_id
	phase = Phase.FLIGHT
	_last_action = _now()
	_revision += 1
	return true


func tick(delta: float) -> void:
	if not _authority():
		return
	if not _active() or not _enabled:
		if phase != Phase.IDLE:
			reset()
		return
	if not is_finite(delta) or delta < 0.0:
		return
	if phase in [Phase.CARRIED, Phase.FLIGHT]:
		if not _living(holder_id):
			remove_player(holder_id)
		elif phase == Phase.CARRIED:
			position_world = _actor(holder_id).global_position + Vector3.UP * 1.05
	if phase == Phase.GROUND and not _valid_anchor(position_world, false):
		_cancel()
	# Resolve flight only up to the private expiry, then burst at the resolved
	# position/recipient. Arrival immediately before expiry grants no extra time.
	if phase == Phase.FLIGHT:
		_advance(minf(delta, maxf(0.0, _deadline - (_now() - delta))))
	if _expire():
		return
	if phase in [Phase.BURST, Phase.CANCEL] and _now() >= _visual_until:
		phase = Phase.IDLE
		holder_id = 0
		position_world = Vector3.ZERO
		_revision += 1
	if phase == Phase.IDLE and _now() >= _next_spawn:
		_next_spawn = _now() + 3.0
		var fraction := float(usable_area_fraction.call()) if usable_area_fraction.is_valid() else 1.0
		if not is_finite(fraction) or fraction < 0.25 or _manager.get_alive_count() < 2:
			return
		for point in anchors:
			if _valid_anchor(point, true):
				parcel_id += 1
				position_world = point
				phase = Phase.GROUND
				holder_id = 0
				_deadline = INF
				_revision += 1
				break


func remove_player(peer_id: int) -> void:
	if not _authority():
		return
	_last_intent.erase(peer_id)
	if holder_id != peer_id or phase not in [Phase.CARRIED, Phase.FLIGHT]:
		return
	var point := _actor(peer_id).global_position if is_instance_valid(_actor(peer_id)) else position_world - Vector3.UP * 1.05
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.DOWN * 0.5, 1))
	if not hit.is_empty() and _valid_anchor(hit.position, false):
		phase = Phase.GROUND
		holder_id = 0
		position_world = hit.position
		_revision += 1
	else:
		_cancel()


func _advance(delta: float) -> void:
	var step := minf(delta * SPEED, RANGE - _distance)
	var target := position_world + _direction * step
	var hit: Dictionary = sweep.call(holder_id, position_world, target) if sweep.is_valid() else {"peer_id": 0}
	if not hit.is_empty():
		var recipient := int(hit.get("peer_id", 0))
		if recipient > 0 and _eligible(recipient):
			_carry(recipient)
		else:
			_carry(holder_id)
		return
	position_world = target
	_distance += step
	_revision += 1
	if _distance >= RANGE - 0.001:
		_carry(holder_id)


func _carry(peer_id: int) -> void:
	holder_id = peer_id
	phase = Phase.CARRIED
	position_world = _actor(peer_id).global_position + Vector3.UP * 1.05
	_revision += 1


func _expire() -> bool:
	if phase not in [Phase.GROUND, Phase.CARRIED, Phase.FLIGHT] or _now() < _deadline:
		return false
	var center := position_world + (Vector3.UP * 0.75 if phase == Phase.GROUND else Vector3.ZERO)
	for peer_id: int in _players:
		if not _eligible(peer_id):
			continue
		var actor := _actor(peer_id)
		var target := actor.global_position + Vector3.UP * 0.75
		var offset := target - center
		if offset.length() > RADIUS:
			continue
		var ray := PhysicsRayQueryParameters3D.create(center, target, 1 | 4)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var direction := Vector3(offset.x, 0, offset.z)
		if direction.length_squared() < 0.001:
			direction = actor.get_forward_direction()
		if apply_impulse.is_valid():
			apply_impulse.call(_source_id, peer_id, direction.normalized())
	phase = Phase.BURST
	position_world = center
	_visual_until = _now() + 0.6
	_next_spawn = _now() + 10.0
	_deadline = INF
	_revision += 1
	return true


func _cancel() -> void:
	phase = Phase.CANCEL
	holder_id = 0
	_deadline = INF
	_visual_until = _now() + 0.6
	_next_spawn = _now() + 10.0
	_revision += 1


func create_snapshot() -> Dictionary:
	return {"round": round_sequence, "revision": _revision, "id": parcel_id, "phase": phase, "owner": holder_id, "position": position_world}


func create_wire_snapshot() -> PackedByteArray:
	var wire := PackedByteArray()
	wire.resize(WIRE_SIZE)
	wire.encode_u32(0, round_sequence)
	wire.encode_u32(4, _revision)
	wire.encode_u32(8, parcel_id)
	wire.encode_u8(12, phase)
	wire.encode_u32(13, holder_id)
	wire.encode_float(17, position_world.x)
	wire.encode_float(21, position_world.y)
	wire.encode_float(25, position_world.z)
	return wire


static func decode_wire_snapshot(value: Variant) -> Dictionary:
	if not value is PackedByteArray or value.size() != WIRE_SIZE:
		return {}
	var point := Vector3(value.decode_float(17), value.decode_float(21), value.decode_float(25))
	var state: int = value.decode_u8(12)
	var holder: int = value.decode_u32(13)
	var snapshot := {"round": value.decode_u32(0), "revision": value.decode_u32(4), "id": value.decode_u32(8), "phase": state, "owner": holder, "position": point}
	return snapshot if valid_snapshot(snapshot) else {}


static func valid_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.size() != 6 or not snapshot.has_all(["round", "revision", "id", "phase", "owner", "position"]):
		return false
	for key in ["round", "revision", "id", "phase", "owner"]:
		if not snapshot[key] is int or snapshot[key] < 0 or snapshot[key] > 2147483647:
			return false
	if not snapshot.position is Vector3 or not snapshot.position.is_finite() or snapshot.position.length() > 10000.0 or snapshot.phase > Phase.CANCEL:
		return false
	return not ((snapshot.phase in [Phase.CARRIED, Phase.FLIGHT] and snapshot.owner == 0) or (snapshot.phase in [Phase.IDLE, Phase.GROUND, Phase.CANCEL] and snapshot.owner != 0))


func apply_snapshot(snapshot: Dictionary) -> bool:
	if not valid_snapshot(snapshot):
		return false
	if int(snapshot.round) < round_sequence or (int(snapshot.round) == round_sequence and int(snapshot.revision) < _revision):
		return false
	round_sequence = int(snapshot.round)
	_revision = int(snapshot.revision)
	parcel_id = int(snapshot.id)
	phase = int(snapshot.phase) as Phase
	holder_id = int(snapshot.owner)
	position_world = snapshot.position
	return true


func _actor(peer_id: int) -> PartyPlayer:
	var actor: Variant = _players.get(peer_id)
	return actor as PartyPlayer if is_instance_valid(actor) else null


func _living(peer_id: int) -> bool:
	return peer_id > 0 and is_instance_valid(_actor(peer_id)) and _manager.is_player_alive(peer_id)


func _eligible(peer_id: int) -> bool:
	return _living(peer_id) and _actor(peer_id).can_perform_actions()


func _valid_anchor(point: Vector3, spawning: bool) -> bool:
	return anchor_is_valid.is_valid() and bool(anchor_is_valid.call(point, spawning))


func _now() -> float:
	return _manager.elapsed_time


func _active() -> bool:
	return is_instance_valid(_manager) and _manager.state == MatchManager.MatchState.ACTIVE


func _authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
