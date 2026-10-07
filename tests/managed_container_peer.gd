extends SceneTree
## External test driver only; never exported or reachable through gameplay RPCs.

var main: Node
var label := ""
var sequence := 0
var warmup := 0
var samples_left := 0
var last_tick := 0
var tick_ms: Array[float] = []
var physics_ms: Array[float] = []
var profile := {}
var release_at := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	var config_path: String = main._argument_value("--room-config=")
	if not config_path.is_empty():
		label = "server-" + String(JSON.parse_string(FileAccess.get_file_as_string(config_path)).room_id)
	else:
		label = main._argument_value("--client-id=")
		_write(label + ".prepared", {"ready": true})
	while true:
		var command := _read(label + ".command")
		if int(command.get("sequence", 0)) > sequence:
			sequence = int(command.sequence)
			_act(command)
		if release_at > 0 and Time.get_ticks_msec() >= release_at:
			Input.action_release("move_right")
			release_at = 0
		_write(label + ".json", _summary())
		await create_timer(0.1).timeout


func _act(command: Dictionary) -> void:
	match String(command.action):
		"join":
			var ticket: Dictionary = command.ticket
			main._prepare_offline_player_for_join()
			if main.join_game(ticket.address, int(ticket.port), ticket.token) != OK:
				push_error("Managed test client could not open ENet")
				quit(1)
			main.multiplayer.multiplayer_peer.get_peer(1).set_timeout(1, 500, 1500)
		"ready":
			main.set_local_ready(true)
		"start":
			main.start_network_match()
		"rematch":
			main.restart_network_match()
		"forge":
			main._request_session_action.rpc_id(1, "lobby", main._session_revision)
		"move":
			Input.action_press("move_right")
			release_at = Time.get_ticks_msec() + 500
		"disconnect":
			main.multiplayer.multiplayer_peer.close()
			main._on_server_disconnected()
		"cleanup":
			main.disaster_director.cleanup()
		"damage":
			main.match_manager.apply_damage(int(command.peer), float(command.amount), "Container isolation")
		"hazards":
			main.disaster_director.cleanup()
			main.flood.warning_duration = float(command.get("warning", 6.0))
			main.meteor_shower.warning_duration = float(command.get("warning", 2.5))
			main.flood.start_warning()
			main.meteor_shower.start_warning(Vector3(24.0, 0.06, 24.0))
		"finish":
			main.disaster_director.cleanup()
			for id: int in main.get_network_player_ids():
				if id != main.get_room_owner_id():
					main.match_manager.apply_damage(id, 100.0, "Container round end")
		"profile":
			warmup = 120
			samples_left = 600
			last_tick = 0
			tick_ms.clear()
			physics_ms.clear()
			profile = {}


func _physics_process(_delta: float) -> bool:
	if warmup > 0:
		warmup -= 1
		last_tick = Time.get_ticks_usec()
	elif samples_left > 0:
		var now := Time.get_ticks_usec()
		tick_ms.append((now - last_tick) / 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		last_tick = now
		samples_left -= 1
		if samples_left == 0:
			tick_ms.sort()
			physics_ms.sort()
			profile = {"warmup": 120, "samples": 600, "tick_interval_p95_ms": tick_ms[569], "physics_work_p95_ms": physics_ms[569]}
	return false


func _summary() -> Dictionary:
	var health := {}
	var positions := {}
	var rtt_ms := 0
	if main.is_network_session() and not main.multiplayer.is_server() and main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rtt_ms = main.multiplayer.multiplayer_peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	for id: int in main.get_network_player_ids():
		health[str(id)] = main.match_manager.get_health(id)
		var position: Vector3 = main._player_nodes[id].global_position
		positions[str(id)] = [position.x, position.y, position.z]
	return {"sequence": sequence, "network": main.is_network_session(), "ids": main.get_network_player_ids(),
		"owner": main.get_room_owner_id(), "local_id": main.multiplayer.get_unique_id(),
		"state": main.match_manager.state, "can_start": main.match_manager.can_start_match(), "health": health, "positions": positions, "rtt_ms": rtt_ms,
		"winners": main.match_manager.winner_ids, "flood": main.flood.phase, "meteor": main.meteor_shower.phase,
		"profile_remaining": warmup + samples_left, "sample_time_msec": Time.get_ticks_msec(), "profile": profile}


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists("/control/" + path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("/control/" + path))
	return parsed if parsed is Dictionary else {}


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open("/control/" + path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute("/control/" + path + ".tmp", "/control/" + path)
