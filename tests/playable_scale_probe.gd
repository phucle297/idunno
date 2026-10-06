class_name PlayableScaleProbe
extends Node

var role := ""
var expected_players := 4
var begin_movement_received := false
var finish_received := false
var movement_ready: Dictionary = {}
var validation_results: Dictionary = {}
var spectator_peer_id := 0
var spectator_results: Dictionary = {}


func configure(peer_role: String, player_count: int) -> void:
	role = peer_role
	expected_players = player_count


@rpc("authority", "call_remote", "reliable")
func begin_movement() -> void:
	begin_movement_received = true


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_movement_ready() -> void:
	if multiplayer.is_server():
		movement_ready[multiplayer.get_remote_sender_id()] = true


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_validation(passed: bool) -> void:
	if not multiplayer.is_server():
		return
	validation_results[multiplayer.get_remote_sender_id()] = passed


@rpc("authority", "call_remote", "reliable")
func finish_clients() -> void:
	finish_received = true


@rpc("authority", "call_remote", "reliable")
func begin_spectator_check(peer_id: int) -> void:
	spectator_peer_id = peer_id


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_spectator(passed: bool) -> void:
	if multiplayer.is_server():
		spectator_results[multiplayer.get_remote_sender_id()] = passed


func all_clients_passed() -> bool:
	if validation_results.size() != expected_players - 1:
		return false
	for passed: bool in validation_results.values():
		if not passed:
			return false
	return true


func all_clients_responded() -> bool:
	return validation_results.size() == expected_players - 1
