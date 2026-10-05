extends SceneTree

const ManagerScript = preload("res://game/match_manager.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_lobby_and_solo_exception()
	_test_multiplayer_winner()
	_test_elimination_signal_observes_death()
	_test_simultaneous_elimination()
	_test_timeout_ranking_and_tie()
	_test_five_rematches()
	if failures.is_empty():
		print("MATCH_MANAGER_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_lobby_and_solo_exception() -> void:
	var manager := ManagerScript.new()
	root.add_child(manager)
	_expect(manager.register_player(1, "Solo"), "Solo player must register")
	_expect(not manager.start_match(), "Unready lobby must not start")
	_expect(manager.set_player_ready(1, true), "Solo player must become ready")
	_expect(manager.start_match(), "Ready solo match must start")
	_expect(manager.state == ManagerScript.MatchState.ACTIVE, "Solo match must remain active while its only player lives")
	manager.tick_match(2.0)
	_expect(manager.state == ManagerScript.MatchState.ACTIVE, "Solo match must not instantly end because one player remains")
	_expect(manager.apply_damage(1, 25.0, "Crate"), "Server must apply valid damage")
	_expect(is_equal_approx(manager.get_health(1), 75.0), "Damage must reduce health from 100 to 75")
	manager.apply_damage(1, 100.0, "Meteor")
	_expect(manager.state == ManagerScript.MatchState.RESULTS, "Solo death must end the match")
	_expect(manager.get_cause_of_death(1) == "Meteor", "Death cause must be retained")
	_expect(manager.winner_ids.is_empty(), "Dead solo player must not win")
	manager.free()


func _test_multiplayer_winner() -> void:
	var manager = _ready_manager([1, 2, 3])
	manager.apply_damage(1, 100.0, "Flood")
	_expect(manager.state == ManagerScript.MatchState.ACTIVE, "Three-player match must continue with two survivors")
	manager.apply_damage(2, 100.0, "Tornado")
	_expect(manager.state == ManagerScript.MatchState.RESULTS, "Match must end with one survivor")
	_expect(manager.winner_ids == [3], "The final living player must win")
	manager.free()


func _test_elimination_signal_observes_death() -> void:
	var manager = _ready_manager([10, 11, 12])
	var alive_during_signal := [true]
	manager.player_eliminated.connect(func(peer_id: int, _cause: String) -> void:
		alive_during_signal[0] = manager.is_player_alive(peer_id)
	)
	manager.apply_damage(10, 100.0, "Meteor")
	_expect(not alive_during_signal[0], "Elimination listeners must observe the authoritative death immediately")
	manager.free()


func _test_simultaneous_elimination() -> void:
	var manager = _ready_manager([4, 5])
	manager.tick_match(12.0)
	var events: Array[Dictionary] = [
		{"peer_id": 4, "amount": 100.0, "cause": "Meteor"},
		{"peer_id": 5, "amount": 100.0, "cause": "Meteor"}
	]
	manager.apply_damage_batch(events)
	_expect(manager.state == ManagerScript.MatchState.RESULTS, "Simultaneous final eliminations must end the match")
	manager.winner_ids.sort()
	_expect(manager.winner_ids == [4, 5], "Same-step final eliminations must produce shared winners")
	manager.free()


func _test_timeout_ranking_and_tie() -> void:
	var manager = _ready_manager([6, 7, 8])
	manager.match_duration = 10.0
	manager.record_disaster_survived()
	manager.apply_damage(6, 20.0, "Debris")
	manager.apply_damage(7, 10.0, "Debris")
	manager.apply_damage(8, 10.0, "Debris")
	manager.tick_match(10.0)
	manager.winner_ids.sort()
	_expect(manager.state == ManagerScript.MatchState.RESULTS, "Timeout must end the match")
	_expect(manager.winner_ids == [7, 8], "Timeout must allow a shared tie after disasters survived and damage")
	_expect(manager.reset_to_lobby(), "Results must reset to lobby")
	_expect(manager.state == ManagerScript.MatchState.LOBBY, "Reset must restore lobby state")
	_expect(not manager.players[6].ready, "Reset must clear ready state")
	manager.free()


func _test_five_rematches() -> void:
	var manager := ManagerScript.new()
	root.add_child(manager)
	manager.register_player(1, "Solo")
	for match_index in 5:
		manager.set_player_ready(1, true)
		_expect(manager.start_match(), "Rematch %d must start" % (match_index + 1))
		manager.apply_damage(1, 100.0, "Test")
		_expect(manager.state == ManagerScript.MatchState.RESULTS, "Rematch %d must reach results" % (match_index + 1))
		_expect(manager.reset_to_lobby(), "Rematch %d must cleanly reset" % (match_index + 1))
	manager.free()


func _ready_manager(peer_ids: Array[int]):
	var manager := ManagerScript.new()
	root.add_child(manager)
	for peer_id in peer_ids:
		manager.register_player(peer_id, "Player %d" % peer_id)
		manager.set_player_ready(peer_id, true)
	manager.start_match()
	return manager


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
