class_name ShoveManager
extends Node

# Task 3.4 bounded shove: one explicit short-range forward shove. The client
# sends only a request; the server derives everything else. The target is
# picked by a deterministic nearest rule (ties by peer id), the accepted
# effect is one fixed clamped horizontal impulse, and accepted shoves plus
# knockdown recovery grant the victim a short protection window so
# alternating attackers cannot chain-lock. No HP damage, no routine knockdown,
# no client-chosen direction/magnitude/target. After server acceptance the
# effect is replicated once per monotonically sequenced shove so every peer
# applies the same bounded impulse exactly once (duplicates and stale packets
# are suppressed).

const Tuning = preload("res://game/player/player_tuning.gd")

signal shove_effect_applied(shover_id: int, victim_id: int)

var _players: Dictionary = {}
var _cooldown_until: Dictionary = {}
var _protection_until: Dictionary = {}
var _was_knocked_down: Dictionary = {}
var _last_shove_sequence: Dictionary = {}
var _last_item_sequence: Dictionary = {}
var _item_round_sequence := 0
var _shove_origin_position: Dictionary = {}
var _shove_impulse_speed: Dictionary = {}
var _match_manager: MatchManager = null


func configure(match_manager: MatchManager) -> void:
	_match_manager = match_manager


func register_player(peer_id: int, player: PartyPlayer) -> bool:
	if peer_id <= 0 or not is_instance_valid(player):
		return false
	if _players.has(peer_id):
		# Idempotent for the same copy (spawn paths register on every peer);
		# a different live copy for one peer id is stale and must not be
		# accepted. A freed entry is stale cleanup and gets replaced.
		if is_instance_valid(_players[peer_id]):
			return _players[peer_id] == player
	_players[peer_id] = player
	_was_knocked_down[peer_id] = player.is_knocked_down()
	player.configure_shoving(self)
	return true


func unregister_player(peer_id: int) -> bool:
	if not _players.has(peer_id):
		return false
	_players.erase(peer_id)
	_cooldown_until.erase(peer_id)
	_protection_until.erase(peer_id)
	_was_knocked_down.erase(peer_id)
	_last_shove_sequence.erase(peer_id)
	_last_item_sequence.erase(peer_id)
	return true


func reset_state() -> void:
	_cooldown_until.clear()
	_protection_until.clear()
	# Item packets use a session-monotonic channel. Do not clear it between
	# rounds: a delayed first packet from a previous round must not become a
	# valid sequence after the controller starts its next round at one.
	for peer_id: int in _players:
		var player := _valid_player(peer_id)
		_was_knocked_down[peer_id] = is_instance_valid(player) and player.is_knocked_down()
	if _can_mutate() and multiplayer.has_multiplayer_peer():
		_replicate_reset.rpc()


@rpc("authority", "call_remote", "reliable")
func _replicate_reset() -> void:
	_cooldown_until.clear()
	_protection_until.clear()
	for peer_id: int in _players:
		var player := _valid_player(peer_id)
		_was_knocked_down[peer_id] = is_instance_valid(player) and player.is_knocked_down()


func _physics_process(_delta: float) -> void:
	# Knockdown recovery starts the same protection window an accepted shove
	# grants, so a recovering player cannot be immediately re-shoved. This
	# covers only shove acceptance: disasters still damage and knock down.
	for peer_id: int in _players:
		var player := _valid_player(peer_id)
		if not is_instance_valid(player):
			continue
		var knocked := player.is_knocked_down()
		if bool(_was_knocked_down.get(peer_id, false)) and not knocked:
			_protection_until[peer_id] = _now() + Tuning.SHOVE_PROTECTION
		_was_knocked_down[peer_id] = knocked


func request_local_shove(peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		request_shove(peer_id)
	else:
		_request_shove.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_shove() -> void:
	if multiplayer.is_server():
		request_shove(multiplayer.get_remote_sender_id())


func request_shove(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	var shover := _valid_player(peer_id)
	if not is_instance_valid(shover) or not _sender_eligible(peer_id, shover):
		return false
	var now := _now()
	if now < float(_cooldown_until.get(peer_id, 0.0)):
		return false
	var victim_peer := _pick_target(shover)
	if victim_peer == 0:
		return false
	var victim := _valid_player(victim_peer)
	if not is_instance_valid(victim) or now < float(_protection_until.get(victim_peer, 0.0)):
		return false
	# Fixed server-derived effect: horizontal push away from the shover with
	# clamped impulse and clamped result speed. No vertical component. The
	# same formula runs on every peer from the replicated direction so the
	# accepted effect agrees without replaying local prediction.
	var direction := victim.global_position - shover.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = shover.get_forward_direction()
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()
	var sequence := int(_last_shove_sequence.get(victim_peer, 0)) + 1
	var applied := apply_replicated_shove(peer_id, victim_peer, sequence, direction.x, direction.z)
	if applied and multiplayer.has_multiplayer_peer():
		_replicate_shove.rpc(peer_id, victim_peer, sequence, direction.x, direction.z)
	return applied


@rpc("authority", "call_remote", "reliable")
func _replicate_shove(shover_id: int, victim_id: int, sequence: int, direction_x: float, direction_z: float) -> void:
	apply_replicated_shove(shover_id, victim_id, sequence, direction_x, direction_z)


# Single application path for server acceptance and client replication.
# A per-victim monotonic sequence suppresses duplicate application under
# loss/reordering; client responsiveness can never authorize a second impulse.
func apply_replicated_shove(shover_id: int, victim_id: int, sequence: int, direction_x: float, direction_z: float) -> bool:
	if sequence <= int(_last_shove_sequence.get(victim_id, 0)):
		return false
	var victim := _valid_player(victim_id)
	if not is_instance_valid(victim):
		return false
	var direction := Vector3(direction_x, 0.0, direction_z)
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()
	var horizontal := Vector3(victim.velocity.x, 0.0, victim.velocity.z)
	horizontal = (horizontal + direction * Tuning.SHOVE_IMPULSE).limit_length(Tuning.SHOVE_MAX_HORIZONTAL_SPEED)
	# Record the pre-impulse state at application time on every peer. The
	# effect contract is observable from this single call site: knockback
	# distance is measured from this origin, so an observer that joins the
	# scene late still asserts the full replicated displacement.
	_shove_origin_position[victim_id] = victim.global_position
	_shove_impulse_speed[victim_id] = horizontal.length()
	victim.velocity.x = horizontal.x
	victim.velocity.z = horizontal.z
	_last_shove_sequence[victim_id] = sequence
	_cooldown_until[shover_id] = _now() + Tuning.SHOVE_COOLDOWN
	_protection_until[victim_id] = _now() + Tuning.SHOVE_PROTECTION
	shove_effect_applied.emit(shover_id, victim_id)
	return true


func reset_item_session() -> void:
	# A new transport session cannot deliver packets from the old peer. Match
	# resets deliberately retain this channel; a new session must not retain it.
	_last_item_sequence.clear()
	_item_round_sequence = 0


func set_item_round(round_sequence: int) -> void:
	_item_round_sequence = round_sequence


func get_cooldown_remaining(peer_id: int) -> float:
	return maxf(0.0, float(_cooldown_until.get(peer_id, 0.0)) - _now())


func get_last_shove_sequence(peer_id: int) -> int:
	return int(_last_shove_sequence.get(peer_id, 0))


# Toy effects use their own monotonically increasing channel so they cannot
# collide with shove sequencing, while sharing this manager's protection window
# and bounded impulse policy. Springs set, rather than stack, upward velocity.
func apply_replicated_item_impulse(owner_id: int, victim_id: int, sequence: int, direction: Vector3, strength: float, speed_cap: float = 8.0, lift: float = 0.0) -> bool:
	if sequence <= int(_last_item_sequence.get(victim_id, 0)) or not direction.is_finite() or not is_finite(strength) or not is_finite(speed_cap) or not is_finite(lift):
		return false
	var victim := _valid_player(victim_id)
	if not is_instance_valid(victim) or direction.length_squared() < 0.0001:
		return false
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	var horizontal := Vector3(victim.velocity.x, 0.0, victim.velocity.z)
	horizontal = (horizontal + direction.normalized() * clampf(strength, 0.0, 6.0)).limit_length(clampf(speed_cap, 0.0, 8.0))
	victim.velocity.x = horizontal.x
	victim.velocity.z = horizontal.z
	if lift > 0.0:
		victim.velocity.y = clampf(lift, 0.0, 5.4)
	_last_item_sequence[victim_id] = sequence
	_protection_until[victim_id] = maxf(float(_protection_until.get(victim_id, 0.0)), _now() + 1.5)
	return true


# Only server-owned gameplay modules may call this acceptance path. Remote
# clients receive the same victim sequence reliably and still dedupe locally.
func apply_authoritative_item_impulse(owner_id: int, victim_id: int, sequence: int, direction: Vector3, strength: float, speed_cap: float = 8.0, lift: float = 0.0) -> bool:
	if not _can_mutate():
		return false
	var applied := apply_replicated_item_impulse(owner_id, victim_id, sequence, direction, strength, speed_cap, lift)
	if applied and multiplayer.has_multiplayer_peer():
		_replicate_item_impulse.rpc(owner_id, victim_id, sequence, direction, strength, speed_cap, _item_round_sequence, lift)
	return applied


@rpc("authority", "call_remote", "reliable")
func _replicate_item_impulse(owner_id: int, victim_id: int, sequence: int, direction: Vector3, strength: float, speed_cap: float, round_sequence: int, lift: float = 0.0) -> void:
	# Match snapshots and reliable item events use different ENet channels.
	# Monotonic IDs alone cannot reject a previously unseen late old-round hit.
	if round_sequence != _item_round_sequence:
		return
	apply_replicated_item_impulse(owner_id, victim_id, sequence, direction, strength, speed_cap, lift)


func get_last_shove_origin(peer_id: int) -> Vector3:
	return _shove_origin_position.get(peer_id, Vector3.ZERO) as Vector3


func get_last_shove_impulse_speed(peer_id: int) -> float:
	return float(_shove_impulse_speed.get(peer_id, 0.0))


func _valid_player(peer_id: int) -> PartyPlayer:
	# Registry entries can outlive their node when roster churn frees avatars
	# without an unregister; validate before casting to avoid freed casts.
	var entry: Variant = _players.get(peer_id)
	if not is_instance_valid(entry):
		return null
	return entry as PartyPlayer


func is_protected(peer_id: int) -> bool:
	return _now() < float(_protection_until.get(peer_id, 0.0))


func _sender_eligible(peer_id: int, shover: PartyPlayer) -> bool:
	if not is_instance_valid(shover) or not shover.can_perform_actions() or not shover.is_on_floor():
		return false
	if is_instance_valid(_match_manager):
		if _match_manager.state != MatchManager.MatchState.ACTIVE or not _match_manager.is_player_alive(peer_id):
			return false
	return true


func _pick_target(shover: PartyPlayer) -> int:
	var forward := shover.get_forward_direction()
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0
	forward = forward.normalized()
	var candidates: Array[Dictionary] = []
	for candidate_id: int in _players:
		var candidate := _valid_player(candidate_id)
		if not is_instance_valid(candidate) or candidate == shover or not _victim_eligible(candidate_id, candidate):
			continue
		var offset := candidate.global_position - shover.global_position
		if offset.length() > Tuning.SHOVE_RANGE:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.01 or distance > Tuning.SHOVE_RANGE:
			continue
		if forward.dot(offset / distance) < Tuning.SHOVE_MIN_FORWARD_DOT:
			continue
		if not _has_line_of_sight(shover, candidate):
			continue
		candidates.append({"peer_id": candidate_id, "distance": distance})
	if candidates.is_empty():
		return 0
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["distance"]), float(b["distance"])):
			return int(a["peer_id"]) < int(b["peer_id"])
		return float(a["distance"]) < float(b["distance"])
	)
	return int(candidates[0]["peer_id"])


func _victim_eligible(peer_id: int, candidate: PartyPlayer) -> bool:
	if not candidate.can_perform_actions():
		return false
	if is_instance_valid(_match_manager):
		if _match_manager.state != MatchManager.MatchState.ACTIVE or not _match_manager.is_player_alive(peer_id):
			return false
	return true


func _has_line_of_sight(shover: PartyPlayer, candidate: PartyPlayer) -> bool:
	var from := shover.global_position + Vector3.UP * 1.2
	var to := candidate.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, shover.collision_mask, [shover.get_rid(), candidate.get_rid()])
	query.hit_from_inside = true
	return shover.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
