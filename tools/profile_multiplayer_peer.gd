extends SceneTree
## Local diagnostic entry point, excluded from exports. No gameplay RPC additions.

var main: Node
var control := ""
var label := ""
var sequence := 0
var warmup := 0
var wanted := 0
var last_frame := 0
var physics_ticks := 0
var samples: Array[Dictionary] = []
var result: Dictionary = {}
var camera: Camera3D
var moving_client := false
var movement_ticks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Admission is deliberately outside the measured rendering workload.
	root.disable_3d = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	control = main._argument_value("--profile-control=")
	label = main._argument_value("--profile-label=")
	if control.is_empty() or label.is_empty():
		push_error("Profiler requires private control directory and label")
		quit(1)
		return
	while true:
		var path := control.path_join(label + ".command")
		if FileAccess.file_exists(path):
			var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if command is Dictionary and int(command.get("sequence", 0)) > sequence:
				sequence = int(command.sequence)
				if command.action == "quit":
					await _shutdown()
					return
				_act(command)
		_write_status()
		await create_timer(0.1).timeout


func _act(command: Dictionary) -> void:
	match String(command.action):
		"solo":
			main.home_screen.solo.pressed.emit()
			main.home_screen.start.pressed.emit()
			main.disaster_director.cleanup()
		"map":
			main.request_map_change(String(command.map_id))
		"ready":
			main.set_local_ready(true)
		"start":
			main.start_network_match()
		"cleanup":
			main.disaster_director.cleanup()
		"sample":
			var graphical := DisplayServer.get_name() != "headless"
			if graphical:
				if command.vsync != "default":
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if command.vsync == "off" else DisplayServer.VSYNC_ENABLED)
				if not is_instance_valid(camera):
					camera = Camera3D.new()
					main.add_child(camera)
					camera.look_at_from_position(Vector3(0, 5, 12), Vector3(0, 1, 0))
					camera.make_current()
			# Pacing/quality experiments apply only to clients, never authority.
			if label != "server":
				Engine.max_fps = int(command.fps)
				if command.ablation == "shadows-off":
					main.get_node("Sun").shadow_enabled = false
			root.disable_3d = command.ablation == "no-3d" or not graphical
			main.disaster_director.cleanup()
			warmup = int(command.warmup)
			wanted = int(command.samples)
			moving_client = bool(command.get("moving_client", false)) and label == "client-0"
			movement_ticks = 0
			_release_profile_movement()
			last_frame = 0
			physics_ticks = 0
			samples.clear()
			result.clear()


func _process(_delta: float) -> bool:
	if wanted <= 0:
		return false
	var now := Time.get_ticks_usec()
	if warmup > 0:
		warmup -= 1
		last_frame = now
		physics_ticks = 0
		return false
	if last_frame == 0:
		last_frame = now
		return false
	var local_id: int = main.multiplayer.get_unique_id()
	var player: Node = main._player_nodes.get(local_id)
	var rtt := -1
	if main.is_network_session() and not main.multiplayer.is_server() and main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rtt = main.multiplayer.multiplayer_peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	var authoritative_positions := {}
	if main.multiplayer.is_server():
		for peer_id: int in main._player_nodes:
			var authoritative_player := main._player_nodes[peer_id] as PartyPlayer
			if is_instance_valid(authoritative_player):
				authoritative_positions[str(peer_id)] = [authoritative_player.global_position.x, authoritative_player.global_position.y, authoritative_player.global_position.z]
	var pending_inputs: int = player._prediction_inputs.size() if is_instance_valid(player) and not main.multiplayer.is_server() else -1
	var acknowledged_sequence: int = player._last_movement_ack if is_instance_valid(player) else -1
	var local_position := [player.global_position.x, player.global_position.y, player.global_position.z] if is_instance_valid(player) else []
	samples.append({"time_usec": now, "frame_ms": (now - last_frame) / 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"physics_ticks": physics_ticks, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"state": main.match_manager.state, "players": main.match_manager.players.size(),
		"match_sequence": main._match_snapshot_sequence if main.multiplayer.is_server() else main._last_match_snapshot_sequence,
		"input_sequence": main._local_movement_sequence, "ack_sequence": acknowledged_sequence,
		"observed_pending_input_count": pending_inputs,
		"observed_ack_lag_sequences": maxi(main._local_movement_sequence - acknowledged_sequence, 0) if acknowledged_sequence >= 0 else -1,
		"local_player_position": local_position,
		"authoritative_player_positions": authoritative_positions,
		"rtt_ms": rtt, "window_focused": root.has_focus() if DisplayServer.get_name() != "headless" else false})
	last_frame = now
	physics_ticks = 0
	if samples.size() == wanted:
		_release_profile_movement()
		result = {"sequence": sequence, "samples": samples.duplicate(), "map_id": main.map_id,
			"build": ProjectSettings.get_setting("build/revision", "development"),
			"engine": Engine.get_version_info().string, "display": DisplayServer.get_name(),
			"renderer_setting": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
			"adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y],
			"root_3d_disabled": root.disable_3d, "sun_shadows": main.get_node("Sun").shadow_enabled,
			"fps_cap": Engine.max_fps, "physics_hz": Engine.physics_ticks_per_second,
			"local_peer_id": local_id, "moving_client_input": moving_client,
			"reconciliation_measurement": "Pending snapshot age and correction distance unavailable without a receive/reconcile hook; observed pending-input count and ack lag are not time or packet-loss metrics."}
		var file := FileAccess.open(control.path_join(label + ".trace.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
		wanted = 0
	return false


func _physics_process(_delta: float) -> bool:
	physics_ticks += 1
	if moving_client and wanted > 0:
		movement_ticks += 1
		var right := (movement_ticks / 30) % 2 == 0
		Input.action_press("move_right" if right else "move_left")
		Input.action_release("move_left" if right else "move_right")
	return false


func _release_profile_movement() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _write_status() -> void:
	var status := {"sequence": sequence, "state": main.match_manager.state,
		"owner": main.get_room_owner_id(), "players": main.match_manager.players.size(),
		"can_start": main.match_manager.can_start_match(), "map_id": main.map_id,
		"complete": not result.is_empty()}
	var path := control.path_join(label + ".json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(status))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


func _shutdown() -> void:
	wanted = 0
	_release_profile_movement()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await create_timer(0.2).timeout
	print("MULTIPLAYER_PROFILE_PEER_OK label=" + label)
	quit()
