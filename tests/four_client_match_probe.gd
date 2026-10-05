class_name FourClientMatchProbe
extends Node

signal client_validated

const EXPECTED_CLIENTS := 4
const ManagerScript = preload("res://game/match_manager.gd")
const FloodScript = preload("res://game/flood.gd")
const TornadoScript = preload("res://game/tornado.gd")
const PlayerScene = preload("res://scenes/player.tscn")

var role := ""
var manager: Node
var flood: Node3D
var tornado: Node3D
var client_passed := false
var ready_clients: Dictionary = {}
var validated_clients: Dictionary = {}
var _snapshot_sent := false


func configure(peer_role: String) -> void:
	role = peer_role


func create_server_state() -> void:
	manager = ManagerScript.new()
	manager.name = "MatchManager"
	add_child(manager)
	flood = FloodScript.new()
	flood.name = "Flood"
	add_child(flood)
	tornado = TornadoScript.new()
	tornado.name = "Tornado"
	add_child(tornado)
	flood.configure(manager)
	tornado.configure(manager)


func register_server_player(peer_id: int) -> bool:
	if manager.players.has(peer_id):
		return true
	var player := PlayerScene.instantiate()
	player.name = "Player%d" % peer_id
	player.position = Vector3((manager.players.size() - 1.5) * 2.0, 4.95, -13.0)
	player.set_multiplayer_authority(peer_id)
	player.set_physics_process(false)
	add_child(player)
	return (
		manager.register_player(peer_id, player.name)
		and flood.register_player(peer_id, player)
		and tornado.register_player(peer_id, player)
	)


@rpc("any_peer", "call_remote", "reliable")
func submit_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not manager.players.has(peer_id):
		return
	ready_clients[peer_id] = true
	manager.set_player_ready(peer_id, true)
	_try_start_match()


func _try_start_match() -> void:
	if _snapshot_sent or ready_clients.size() != EXPECTED_CLIENTS or manager.players.size() != EXPECTED_CLIENTS:
		return
	if not manager.start_match():
		return
	flood.start_warning()
	flood.tick(flood.warning_duration)
	flood.tick(flood.rise_duration * 0.45)
	tornado.start_warning(Vector3(-7.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0))
	tornado.tick(tornado.warning_duration)
	tornado.tick(1.6)
	var damaged_peer: int = manager.players.keys()[0]
	manager.apply_damage(damaged_peer, 25.0, "Four-client probe")
	_snapshot_sent = true
	receive_snapshot.rpc(_build_snapshot(damaged_peer))


func _build_snapshot(damaged_peer: int) -> Dictionary:
	var health := {}
	for peer_id: int in manager.players:
		health[peer_id] = manager.get_health(peer_id)
	return {
		"state": manager.state,
		"players": manager.players.size(),
		"alive": manager.get_alive_count(),
		"peer_ids": manager.players.keys(),
		"health": health,
		"damaged_peer": damaged_peer,
		"flood_phase": flood.phase,
		"tornado_phase": tornado.phase,
		"hazards": ["Flood", "Tornado"]
	}


@rpc("authority", "call_remote", "reliable")
func receive_snapshot(snapshot: Dictionary) -> void:
	if role != "client":
		return
	var local_id := multiplayer.get_unique_id()
	var peer_ids: Array = snapshot.get("peer_ids", [])
	var health: Dictionary = snapshot.get("health", {})
	var damaged_peer: int = snapshot.get("damaged_peer", 0)
	client_passed = (
		int(snapshot.get("state", -1)) == 1
		and int(snapshot.get("players", 0)) == EXPECTED_CLIENTS
		and int(snapshot.get("alive", 0)) == EXPECTED_CLIENTS
		and local_id in peer_ids
		and health.size() == EXPECTED_CLIENTS
		and is_equal_approx(float(health.get(damaged_peer, -1.0)), 75.0)
		and int(snapshot.get("flood_phase", -1)) == 2
		and int(snapshot.get("tornado_phase", -1)) == 2
		and snapshot.get("hazards", []).size() == 2
	)
	acknowledge_snapshot.rpc_id(1, client_passed)
	client_validated.emit()


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_snapshot(passed: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	validated_clients[peer_id] = passed
	client_validated.emit()


func all_clients_validated() -> bool:
	if validated_clients.size() != EXPECTED_CLIENTS:
		return false
	for passed: bool in validated_clients.values():
		if not passed:
			return false
	return true
