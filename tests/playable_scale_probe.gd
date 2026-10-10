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
var expected_results: Array = []
var results_checks: Dictionary = {}
var lobby_checks: Dictionary = {}
var emote_target := 0
var emote_expected_id := 0
var emote_checks: Dictionary = {}
var shove_victim := 0
var shove_checks: Dictionary = {}
var rematch_acks: Dictionary = {}


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


@rpc("authority", "call_remote", "reliable")
func compare_results(rows: Array) -> void:
	expected_results = rows


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_results(passed: bool) -> void:
	if multiplayer.is_server():
		results_checks[multiplayer.get_remote_sender_id()] = passed


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_lobby(passed: bool) -> void:
	if multiplayer.is_server():
		lobby_checks[multiplayer.get_remote_sender_id()] = passed


@rpc("authority", "call_remote", "reliable")
func begin_emote_check(peer_id: int, emote_id: int) -> void:
	emote_target = peer_id
	emote_expected_id = emote_id


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_emote(emote_id: int, passed: bool) -> void:
	if multiplayer.is_server():
		emote_checks["%d_%d" % [multiplayer.get_remote_sender_id(), emote_id]] = passed


@rpc("authority", "call_remote", "reliable")
func begin_shove_check(victim_id: int) -> void:
	shove_victim = victim_id


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_shove(passed: bool) -> void:
	if multiplayer.is_server():
		shove_checks[multiplayer.get_remote_sender_id()] = passed


@rpc("authority", "call_remote", "reliable")
func begin_rematch_check(cycle: int) -> void:
	rematch_acks[cycle] = {}


@rpc("any_peer", "call_remote", "reliable")
func acknowledge_rematch(cycle: int, passed: bool) -> void:
	if multiplayer.is_server():
		var cycle_acks: Dictionary = rematch_acks.get(cycle, {})
		cycle_acks[multiplayer.get_remote_sender_id()] = passed
		rematch_acks[cycle] = cycle_acks


func all_clients_passed() -> bool:
	if validation_results.size() != expected_players - 1:
		return false
	for passed: bool in validation_results.values():
		if not passed:
			return false
	return true


func all_clients_responded() -> bool:
	return validation_results.size() == expected_players - 1
