class_name MatchManager
extends Node

signal state_changed(state: MatchState)
signal health_changed(peer_id: int, health: float)
signal player_eliminated(peer_id: int, cause: String)
signal match_finished(winner_ids: Array[int])

enum MatchState {
	LOBBY,
	ACTIVE,
	RESULTS
}

const STARTING_HEALTH := 100.0

@export var match_duration := 600.0

var state := MatchState.LOBBY
var elapsed_time := 0.0
var players: Dictionary = {}
var winner_ids: Array[int] = []
var _participants_at_start := 0


func register_player(peer_id: int, player_name: String) -> bool:
	if not _can_mutate() or state == MatchState.ACTIVE or players.has(peer_id):
		return false
	players[peer_id] = _new_player_state(player_name)
	return true


func unregister_player(peer_id: int) -> bool:
	if not _can_mutate() or not players.has(peer_id):
		return false
	players.erase(peer_id)
	return true


func set_player_ready(peer_id: int, ready: bool) -> bool:
	if not _can_mutate() or state != MatchState.LOBBY or not players.has(peer_id):
		return false
	var player: Dictionary = players[peer_id]
	player.ready = ready
	players[peer_id] = player
	return true


func can_start_match() -> bool:
	if players.is_empty():
		return false
	for player: Dictionary in players.values():
		if not player.ready:
			return false
	return true


func start_match() -> bool:
	if not _can_mutate() or state != MatchState.LOBBY or not can_start_match():
		return false
	for peer_id: int in players:
		var player: Dictionary = players[peer_id]
		player.health = STARTING_HEALTH
		player.alive = true
		player.damage_taken = 0.0
		player.elimination_time = -1.0
		player.cause_of_death = ""
		player.disasters_survived = 0
		players[peer_id] = player
	elapsed_time = 0.0
	winner_ids.clear()
	_participants_at_start = players.size()
	_set_state(MatchState.ACTIVE)
	return true


func tick_match(delta: float) -> void:
	if not _can_mutate() or state != MatchState.ACTIVE:
		return
	elapsed_time = minf(elapsed_time + maxf(delta, 0.0), match_duration)
	if elapsed_time >= match_duration:
		_finish_at_timeout()


func apply_damage(peer_id: int, amount: float, cause: String) -> bool:
	return apply_damage_batch([{"peer_id": peer_id, "amount": amount, "cause": cause}])


func apply_damage_batch(events: Array[Dictionary]) -> bool:
	if not _can_mutate() or state != MatchState.ACTIVE:
		return false
	var changed := false
	for event: Dictionary in events:
		var peer_id: int = event.get("peer_id", 0)
		var amount: float = event.get("amount", 0.0)
		if amount <= 0.0 or not players.has(peer_id):
			continue
		var player: Dictionary = players[peer_id]
		if not player.alive:
			continue
		var applied := minf(amount, player.health)
		player.health -= applied
		player.damage_taken += applied
		changed = true
		if player.health <= 0.0:
			player.alive = false
			player.elimination_time = elapsed_time
			player.cause_of_death = String(event.get("cause", "Unknown"))
		players[peer_id] = player
		health_changed.emit(peer_id, player.health)
		if not player.alive:
			player_eliminated.emit(peer_id, player.cause_of_death)
	if changed:
		_evaluate_eliminations()
	return changed


func record_disaster_survived() -> void:
	if not _can_mutate() or state != MatchState.ACTIVE:
		return
	for peer_id: int in players:
		var player: Dictionary = players[peer_id]
		if player.alive:
			player.disasters_survived += 1
			players[peer_id] = player


func get_health(peer_id: int) -> float:
	return players[peer_id].health if players.has(peer_id) else 0.0


func is_player_alive(peer_id: int) -> bool:
	return players[peer_id].alive if players.has(peer_id) else false


func get_cause_of_death(peer_id: int) -> String:
	return players[peer_id].cause_of_death if players.has(peer_id) else ""


func get_alive_count() -> int:
	return _alive_player_ids().size()


func reset_to_lobby() -> bool:
	if not _can_mutate() or state != MatchState.RESULTS:
		return false
	for peer_id: int in players:
		var player: Dictionary = players[peer_id]
		player.ready = false
		players[peer_id] = player
	winner_ids.clear()
	_participants_at_start = 0
	_set_state(MatchState.LOBBY)
	return true


func _evaluate_eliminations() -> void:
	var alive := _alive_player_ids()
	if _participants_at_start == 1:
		if alive.is_empty():
			_finish([])
		return
	if alive.size() == 1:
		_finish([alive[0]])
	elif alive.is_empty():
		var latest_elimination := -1.0
		for player: Dictionary in players.values():
			latest_elimination = maxf(latest_elimination, player.elimination_time)
		var shared_last: Array[int] = []
		for peer_id: int in players:
			if is_equal_approx(players[peer_id].elimination_time, latest_elimination):
				shared_last.append(peer_id)
		_finish(shared_last)


func _finish_at_timeout() -> void:
	var alive := _alive_player_ids()
	if alive.is_empty():
		_evaluate_eliminations()
		return
	var best_disasters := -1
	var least_damage := INF
	for peer_id: int in alive:
		var player: Dictionary = players[peer_id]
		if player.disasters_survived > best_disasters:
			best_disasters = player.disasters_survived
			least_damage = player.damage_taken
		elif player.disasters_survived == best_disasters:
			least_damage = minf(least_damage, player.damage_taken)
	var winners: Array[int] = []
	for peer_id: int in alive:
		var player: Dictionary = players[peer_id]
		if player.disasters_survived == best_disasters and is_equal_approx(player.damage_taken, least_damage):
			winners.append(peer_id)
	_finish(winners)


func _alive_player_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_id: int in players:
		if players[peer_id].alive:
			result.append(peer_id)
	return result


func _finish(winners: Array[int]) -> void:
	winner_ids = winners
	_set_state(MatchState.RESULTS)
	match_finished.emit(winner_ids)


func _set_state(next_state: MatchState) -> void:
	state = next_state
	state_changed.emit(state)


func _new_player_state(player_name: String) -> Dictionary:
	return {
		"name": player_name,
		"ready": false,
		"health": STARTING_HEALTH,
		"alive": true,
		"damage_taken": 0.0,
		"elimination_time": -1.0,
		"cause_of_death": "",
		"disasters_survived": 0
	}


func _can_mutate() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
