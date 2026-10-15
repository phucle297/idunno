class_name MatchPowerups
extends Node

signal collected(peer_id: int, kind: int, pickup_id: int)

enum Kind { NONE, SPEED, JUMP }
const SPAWN_INTERVAL := 30.0
const PICKUP_LIFETIME := 60.0
const MAX_PICKUPS := 6
const COLLECTION_RADIUS := 1.1
const DURATIONS := {Kind.SPEED: 12.0, Kind.JUMP: 10.0}

var round_sequence := 0
var pickups: Array[Dictionary] = []
var buffs: Dictionary = {}
var anchors: Array[Vector3] = []
var anchor_is_valid: Callable
var collection_is_clear: Callable
var _slot := 0
var _next_id := 0
var _revision := 0


func begin_round() -> void:
	reset()
	round_sequence += 1
	_revision = 0


func reset_session() -> void:
	reset()
	round_sequence = 0
	_revision = 0


func reset() -> void:
	if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and (not pickups.is_empty() or not buffs.is_empty()):
		_revision += 1
	pickups.clear()
	buffs.clear()
	_slot = 0
	_next_id = 0


func remove_player(peer_id: int) -> void:
	if buffs.erase(peer_id) and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_revision += 1


func tick(manager: MatchManager, players: Dictionary, seed_value: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if manager.state != MatchManager.MatchState.ACTIVE:
		reset()
		return
	var now := manager.elapsed_time
	for peer_id: int in buffs.keys():
		if not players.has(peer_id) or not manager.is_player_alive(peer_id) or float(buffs[peer_id].expires) <= now:
			remove_player(peer_id)
	for index in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[index]
		if float(pickup.expires) <= now or not _valid_anchor(pickup.position, false):
			pickups.remove_at(index)
			_revision += 1
	# A clock jump never emits a backlog of drops on one frame.
	var slot := floori(now / SPAWN_INTERVAL)
	if slot > _slot:
		_slot = slot
		_spawn(now, seed_value, slot)
	for index in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[index]
		var winner := 0
		var closest := INF
		for peer_id: int in players:
			var player := players[peer_id] as PartyPlayer
			if not is_instance_valid(player) or not manager.is_player_alive(peer_id) or player.is_knocked_down():
				continue
			var distance := player.global_position.distance_squared_to(pickup.position)
			if distance > COLLECTION_RADIUS * COLLECTION_RADIUS:
				continue
			if not collection_is_clear.is_valid() or not bool(collection_is_clear.call(player, pickup.position)):
				continue
			if distance < closest or (distance == closest and peer_id < winner):
				winner = peer_id
				closest = distance
		if winner != 0:
			# Consume before notifying: listeners cannot grant this ID twice.
			pickups.remove_at(index)
			buffs[winner] = {"kind": pickup.kind, "id": pickup.id, "expires": now + float(DURATIONS[pickup.kind])}
			_revision += 1
			collected.emit(winner, pickup.kind, pickup.id)


func _valid_anchor(point: Vector3, spawning: bool) -> bool:
	return anchor_is_valid.is_valid() and bool(anchor_is_valid.call(point, spawning))


func _spawn(now: float, seed_value: int, slot: int) -> void:
	if pickups.size() >= MAX_PICKUPS:
		return
	var eligible: Array[Vector3] = []
	for point: Vector3 in anchors:
		if not _valid_anchor(point, true):
			continue
		var occupied := false
		for pickup: Dictionary in pickups:
			if point.distance_squared_to(pickup.position) < 4.0:
				occupied = true
				break
		if not occupied:
			eligible.append(point)
	if eligible.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + slot * 104729
	var point := eligible[rng.randi_range(0, eligible.size() - 1)]
	_next_id += 1
	pickups.append({"id": _next_id, "kind": rng.randi_range(Kind.SPEED, Kind.JUMP), "position": point, "expires": now + PICKUP_LIFETIME})
	_revision += 1


func buff_state(peer_id: int, now: float) -> Vector2:
	var buff: Dictionary = buffs.get(peer_id, {})
	if buff.is_empty() or float(buff.expires) <= now:
		return Vector2.ZERO
	return Vector2(int(buff.kind), float(buff.expires) - now)


func create_snapshot() -> Dictionary:
	return {"round": round_sequence, "revision": _revision, "pickups": pickups.duplicate(true), "buffs": buffs.duplicate(true)}


static func snapshot_is_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("round") is int or not value.get("revision") is int:
		return false
	if value.round < 0 or value.revision < 0 or not value.get("pickups") is Array or not value.get("buffs") is Dictionary:
		return false
	if value.pickups.size() > MAX_PICKUPS or value.buffs.size() > 20:
		return false
	var ids: Array[int] = []
	for entry: Variant in value.pickups:
		if not _entry_is_valid(entry) or not entry.get("position") is Vector3 or not entry.position.is_finite() or entry.id in ids:
			return false
		ids.append(entry.id)
	for peer_id: Variant in value.buffs:
		if not peer_id is int or peer_id <= 0 or not _entry_is_valid(value.buffs[peer_id]):
			return false
	return true


static func _entry_is_valid(entry: Variant) -> bool:
	return entry is Dictionary and entry.get("id") is int and entry.id > 0 and entry.get("kind") is int and entry.kind in DURATIONS and (entry.get("expires") is float or entry.get("expires") is int) and is_finite(float(entry.expires)) and entry.expires >= 0


func apply_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot_is_valid(snapshot) or int(snapshot.round) < round_sequence or (int(snapshot.round) == round_sequence and int(snapshot.revision) < _revision):
		return false
	round_sequence = snapshot.round
	_revision = snapshot.revision
	pickups.assign(snapshot.pickups.duplicate(true))
	buffs = snapshot.buffs.duplicate(true)
	return true
