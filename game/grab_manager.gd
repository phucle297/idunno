class_name GrabManager
extends Node

const Tuning = preload("res://game/player_tuning.gd")

var _players: Dictionary = {}
var _owners: Dictionary = {}
var _held_by_peer: Dictionary = {}


func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _exit_tree() -> void:
	release_all()


func _physics_process(_delta: float) -> void:
	if not _can_mutate():
		return
	for peer_id: int in _held_by_peer.keys():
		var body := _held_by_peer[peer_id] as RigidBody3D
		var player := _players.get(peer_id) as PartyPlayer
		if not is_instance_valid(body) or not is_instance_valid(player) or not player.can_grab_objects():
			release_grab(peer_id)
			continue
		var grab_origin := player.get_grab_origin()
		if grab_origin.distance_to(body.global_position) > Tuning.GRAB_BREAK_DISTANCE:
			release_grab(peer_id)
			continue
		var displacement := player.get_hold_position() - body.global_position
		var force := displacement * Tuning.GRAB_SPRING_STRENGTH - body.linear_velocity * Tuning.GRAB_SPRING_DAMPING
		body.sleeping = false
		body.apply_central_force(force.limit_length(Tuning.GRAB_MAX_FORCE))


func register_player(peer_id: int, player: PartyPlayer) -> bool:
	if not _can_mutate() or peer_id <= 0 or not is_instance_valid(player) or _players.has(peer_id):
		return false
	_players[peer_id] = player
	player.configure_grabbing(self, peer_id)
	return true


func unregister_player(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	release_grab(peer_id)
	_players.erase(peer_id)
	return true


func request_local_toggle(peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		toggle_grab(peer_id)
	else:
		_request_toggle.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_toggle() -> void:
	if multiplayer.is_server():
		toggle_grab(multiplayer.get_remote_sender_id())


func toggle_grab(peer_id: int) -> bool:
	if not _can_mutate():
		return false
	if _held_by_peer.has(peer_id):
		return release_grab(peer_id)
	return request_nearest_grab(peer_id)


func request_nearest_grab(peer_id: int) -> bool:
	if not _can_mutate() or not _players.has(peer_id):
		return false
	var player := _players[peer_id] as PartyPlayer
	var nearest := get_interaction_candidate(player)
	if nearest == null:
		return false
	return request_grab(peer_id, nearest)


func get_interaction_candidate(player: PartyPlayer) -> RigidBody3D:
	if not is_instance_valid(player) or not player.can_grab_objects():
		return null
	var origin := player.get_grab_origin()
	var forward := player.get_grab_direction()
	var nearest: RigidBody3D
	var nearest_distance := Tuning.GRAB_RANGE
	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if not is_instance_valid(body) or int(body.get_meta("grab_owner_peer_id", 0)) != 0:
			continue
		var offset := body.global_position - origin
		var distance := offset.length()
		if distance <= nearest_distance and distance > 0.001 and forward.dot(offset / distance) >= Tuning.GRAB_MIN_FORWARD_DOT:
			nearest = body
			nearest_distance = distance
	return nearest


func request_grab(peer_id: int, body: RigidBody3D) -> bool:
	if not _can_mutate() or not _players.has(peer_id) or not is_instance_valid(body):
		return false
	var player := _players[peer_id] as PartyPlayer
	if not player.can_grab_objects() or not body.is_in_group("grabbable"):
		return false
	if _held_by_peer.has(peer_id) or _owners.has(body):
		return false
	if player.get_grab_origin().distance_to(body.global_position) > Tuning.GRAB_RANGE:
		return false
	_owners[body] = peer_id
	_held_by_peer[peer_id] = body
	body.set_meta("grab_owner_peer_id", peer_id)
	body.add_collision_exception_with(player)
	body.sleeping = false
	return true


func release_grab(peer_id: int) -> bool:
	if not _can_mutate() or not _held_by_peer.has(peer_id):
		return false
	var body := _held_by_peer[peer_id] as RigidBody3D
	var player := _players.get(peer_id) as PartyPlayer
	_held_by_peer.erase(peer_id)
	_owners.erase(body)
	if is_instance_valid(body):
		body.remove_meta("grab_owner_peer_id")
		if is_instance_valid(player):
			body.remove_collision_exception_with(player)
	return true


func release_all() -> void:
	if not _can_mutate():
		return
	for peer_id: int in _held_by_peer.keys():
		release_grab(peer_id)


func get_grab_owner(body: RigidBody3D) -> int:
	return int(_owners.get(body, 0))


func get_held_body(peer_id: int) -> RigidBody3D:
	var held_body := _held_by_peer.get(peer_id) as RigidBody3D
	if is_instance_valid(held_body):
		return held_body
	for candidate in get_tree().get_nodes_in_group("grabbable"):
		var body := candidate as RigidBody3D
		if is_instance_valid(body) and int(body.get_meta("grab_owner_peer_id", 0)) == peer_id:
			return body
	return null


func _on_peer_disconnected(peer_id: int) -> void:
	unregister_player(peer_id)


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
