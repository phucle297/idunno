extends SceneTree

const ManagerScript = preload("res://game/session/match_manager.gd")

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
	_test_disconnect_winner()
	_test_five_rematches()
	_test_managed_participation()
	if "--reward-test" in OS.get_cmdline_user_args():
		await _test_reward_delivery()
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


func _test_disconnect_winner() -> void:
	var manager = _ready_manager([21, 22])
	_expect(manager.unregister_player(22), "An active disconnected player must unregister")
	_expect(manager.state == ManagerScript.MatchState.RESULTS, "A disconnect leaving one survivor must end the match")
	_expect(manager.winner_ids == [21], "The remaining connected survivor must win")
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


func _test_managed_participation() -> void:
	var manager := ManagerScript.new()
	root.add_child(manager)
	var profiles := {10: "first", 20: "second", 30: "third", 40: "fourth"}
	manager.managed_profile_ids = profiles
	manager.match_duration = 120.0
	for peer_id: int in profiles:
		manager.register_player(peer_id, "Same name")
		manager.set_player_ready(peer_id, true)
	manager.start_match()
	manager.bind_round_id(1, "round-one")
	manager.tick_match(-5.0)
	manager.tick_match(59.99)
	manager.apply_damage(10, 100.0, "Meteor")
	manager.tick_match(0.01)
	manager.apply_damage(20, 100.0, "Flood")
	manager.tick_match(5.0)
	profiles.erase(10) # Admission forgets identity independently of MatchManager.
	manager.unregister_player(10)
	manager.tick_match(54.99)
	var before_finish := manager.get_round_participation()
	_expect(is_equal_approx(before_finish.duration, 119.99) and not before_finish.finished, "119.99 must remain distinct from the 120-second completion boundary")
	manager.tick_match(20.0) # Clamp a large final tick to the authoritative deadline.
	var record := manager.get_round_participation(true)
	_expect(record.round_id == "round-one" and record.finished and is_equal_approx(record.duration, 120.0), "Finished managed round must retain its ID and exact authoritative deadline")
	_expect(record.participants.size() == 4 and record.participants[10].profile_id == "first", "Start identity must survive admission cleanup and mutable player removal")
	_expect(is_equal_approx(record.participants[10].connected_duration, 59.99) and is_equal_approx(record.participants[10].departure_time, 65.0) and not record.participants[10].departed_alive, "Spectating must not turn an early death into 60 seconds of active participation")
	_expect(is_equal_approx(record.participants[20].elimination_time, 60.0) and is_equal_approx(record.participants[20].connected_duration, 60.0), "Death at exactly 60 seconds must remain distinguishable from death at 59.99")
	_expect(record.participants[30].departure_time == -1.0 and is_equal_approx(record.participants[30].connected_duration, 120.0), "Connected survivors must retain the full active duration")
	manager.unregister_player(20) # Results departure cannot rewrite finished facts.
	manager.prepare_lobby()
	_expect(manager.get_round_participation(true) == record, "Results departure and lobby reset must not rewrite completed participation")
	record.participants.clear()
	_expect(manager.get_round_participation(true).participants.size() == 4, "Returned snapshots must not expose mutable authority storage")
	for index in 5:
		for peer_id: int in manager.players:
			manager.set_player_ready(peer_id, true)
		manager.start_match()
		manager.bind_round_id(1, "stale-reply")
		_expect(manager.get_round_participation().round_id.is_empty(), "A previous round HTTP reply must not bind a rematch")
		manager.bind_round_id(index + 2, "rematch-%d" % index)
		manager.tick_match(60.0)
		# Two live players: departure synchronously finishes the match.
		manager.unregister_player(40)
		var finished := manager.get_round_participation(true)
		_expect(finished.sequence == index + 2 and finished.round_id == "rematch-%d" % index and finished.finished, "Every rematch must retain its own participation identity")
		_expect(finished.participants[40].departed_alive and finished.participants[40].elimination_time == -1.0 and finished.participants[40].connected_duration == 60.0, "Live departure must be captured before synchronous finish, not disguised as death")
		manager.bind_round_id(index + 2, "conflicting-id")
		_expect(manager.get_round_participation(true) == finished, "An already bound ID must not be replaced")
		manager.prepare_lobby()
		manager.register_player(40, "Same name")
	manager.free()
	var local = _ready_manager([1, 2])
	_expect(local.get_round_participation().is_empty(), "Unmanaged local/player-hosted play must not produce reward evidence")
	local.free()


func _test_reward_delivery() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.disaster_director.cleanup()
	_expect(main.host_game(0, 4, true) == OK, "Reward fixture must run actual managed admission on a dedicated authority")
	var admission: Node = main.room_admission
	for peer: String in admission.config.fixture_profiles:
		admission.profile_ids[int(peer)] = admission.config.fixture_profiles[peer]
		main.match_manager.register_player(int(peer), "Same name")
	# Complete/rematch before the first HTTP reply; the delivery queue owns both copies.
	for duration: float in [120.0, 119.99]:
		main.match_manager.prepare_lobby()
		for peer: int in main.match_manager.players:
			main.match_manager.set_player_ready(peer, true)
		main.match_manager.start_match()
		main.match_manager.tick_match(duration)
		main.match_manager.apply_damage(90, 100.0, "Meteor")
	main.match_manager.prepare_lobby()
	var deadline := Time.get_ticks_msec() + 7000
	while not admission.reward_delivery.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(admission.reward_delivery.is_empty(), "Both frozen completions must acknowledge after the forced post-commit reply failure")
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	print("ROUND_REWARD_DELIVERY_OK frozen_rematch=passed acknowledgement=passed")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
