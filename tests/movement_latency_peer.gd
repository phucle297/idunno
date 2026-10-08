extends SceneTree

# Private script-mode instrumentation; never attached to the exported scene.
class MeasuredMain extends "res://game/main.gd":
	var arrivals: Array[float] = []
	var rtts: Array[float] = []
	var telemetry := PacketPeerUDP.new()
	var measurement_role := ""
	var travel := {}
	var previous := {}
	var done := {}
	var corrections: Array[float] = []
	var measuring := false
	var contacts := {}

	func _physics_process(delta: float) -> void:
		# Consume at the same physics boundary as Main, measuring only reconciliation,
		# not the additional prediction step that super performs afterward.
		var player := _player_nodes.get(multiplayer.get_unique_id()) as PartyPlayer
		if is_instance_valid(player) and not multiplayer.is_server() and not _pending_local_movement_snapshot.is_empty():
			var snapshot := _pending_local_movement_snapshot
			_pending_local_movement_snapshot = {}
			var before := player.global_position
			player.reconcile_movement(snapshot.position, snapshot.velocity, snapshot.facing, snapshot.knocked_down, snapshot.sequence, snapshot.state, snapshot.crouched)
			if measuring:
				corrections.append(before.distance_to(player.global_position))
		super._physics_process(delta)
		if measuring and is_instance_valid(player):
			for index in player.get_slide_collision_count():
				var collision := player.get_slide_collision(index)
				if collision.get_normal().y < 0.9:
					contacts[str(collision.get_collider().get_path())] = true

	func mark(event: String, key: int = 0) -> void:
		if measurement_role != "server":
			telemetry.put_packet(JSON.stringify({"role": measurement_role, "event": event, "key": key}).to_utf8_buffer())

	@rpc("authority", "call_remote", "unreliable_ordered", 1)
	func _apply_movement_snapshots(ids: PackedInt32Array, positions: PackedVector3Array, velocities: PackedVector3Array, yaws: PackedFloat32Array, facing: PackedFloat32Array, knockdowns: PackedByteArray, acknowledged_inputs: PackedInt32Array = PackedInt32Array(), replay_states: PackedVector3Array = PackedVector3Array()) -> void:
		arrivals.append(Time.get_ticks_usec() / 1000.0)
		mark("snapshot")
		for i in ids.size():
			if previous.has(ids[i]):
				var step: Vector3 = positions[i] - previous[ids[i]]
				travel[ids[i]] = float(travel.get(ids[i], 0.0)) + Vector2(step.x, step.z).length()
			previous[ids[i]] = positions[i]
		super._apply_movement_snapshots(ids, positions, velocities, yaws, facing, knockdowns, acknowledged_inputs, replay_states)

	@rpc("any_peer", "call_remote", "unreliable", 2)
	func probe(stamp: int) -> void:
		if multiplayer.is_server():
			echo.rpc_id(multiplayer.get_remote_sender_id(), stamp)

	@rpc("authority", "call_remote", "unreliable", 2)
	func echo(stamp: int) -> void:
		rtts.append((Time.get_ticks_usec() - stamp) / 1000.0)
		mark("echo", stamp)

	@rpc("any_peer", "call_remote", "reliable")
	func finished() -> void:
		done[multiplayer.get_remote_sender_id()] = true

var role := ""
var trials := 6
var patterns := PackedStringArray(["walk", "sprint", "reversal"])
var telemetry_port := 0
var main: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		if arg.begins_with("--trials="):
			trials = int(arg.trim_prefix("--trials="))
		if arg.begins_with("--patterns="):
			patterns = arg.trim_prefix("--patterns=").split(",")
		if arg.begins_with("--telemetry-port="):
			telemetry_port = int(arg.trim_prefix("--telemetry-port="))
	_run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)

func wait_for(predicate: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 15000 + trials * 3000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	require(predicate.call(), "Timed out waiting for fixture state")

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.set_script(MeasuredMain)
	main.measurement_role = role
	require(main.telemetry.connect_to_host("127.0.0.1", telemetry_port) == OK, "Telemetry connection failed")
	main.name = "Main"
	root.add_child(main)
	await process_frame
	if role == "server":
		# Disable selection before ACTIVE, not after a hazard has already started.
		main.disaster_director.set_process(false)
		main.disaster_director.initial_delay = 3600.0
		await wait_for(func(): return main.match_manager.state == MatchManager.MatchState.ACTIVE)
		main.disaster_director.cleanup()
		var origins := {}
		for id in main._player_nodes:
			origins[id] = main._player_nodes[id].global_position
		await wait_for(func(): return main.done.size() == 2)
		var distances := {}
		for id in origins:
			var step: Vector3 = main._player_nodes[id].global_position - origins[id]
			distances[str(id)] = Vector2(step.x, step.z).length()
			require(distances[str(id)] > 0.1, "Authoritative server did not move client")
		print("MEASUREMENT " + JSON.stringify({"role": role, "displacement": distances}))
		# Clients stay connected until this process ends; no in-game disconnect noise.
	else:
		await wait_for(func(): return main.match_manager.players.size() >= 1)
		print("LATENCY_CONNECTED " + role)
		await wait_for(func(): return main.match_manager.players.size() == 2)
		main.set_local_ready(true)
		if role == "owner":
			await wait_for(func(): return main.match_manager.can_start_match())
			require(main.start_network_match(), "Start failed")
		await wait_for(func(): return main.match_manager.state == MatchManager.MatchState.ACTIVE)
		var id: int = main.multiplayer.get_unique_id()
		var player: PartyPlayer = main._player_nodes[id]
		var samples := []
		var max_yaw_error := 0.0
		for trial in trials:
			Input.action_release("move_forward")
			Input.action_release("move_back")
			Input.action_release("sprint")
			var pattern: String = patterns[trial % patterns.size()]
			# Headless has no captured mouse: set local aim, then stop changing it.
			var yaw: float = [0.73, -1.17, 2.31][trial % 3] + (0.19 if role == "guest" else 0.0)
			player.set_camera_yaw(yaw)
			await create_timer(1.0).timeout
			require(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Trial must start stationary")
			if trial == 0:
				main.travel.clear()
				main.arrivals.clear()
				main.corrections.clear()
				main.measuring = true
			var probe_stamp := Time.get_ticks_usec()
			main.mark("probe", probe_stamp)
			main.probe.rpc_id(1, probe_stamp)
			var origin := player.global_position
			var stamp := Time.get_ticks_usec()
			main.mark("input", trial)
			Input.action_press("move_forward")
			if pattern != "walk":
				Input.action_press("sprint")
			var latency := -1.0
			var peak_speed := 0.0
			while Time.get_ticks_usec() - stamp < 450000:
				await process_frame
				peak_speed = maxf(peak_speed, Vector2(player.velocity.x, player.velocity.z).length())
				var step := player.global_position - origin
				if latency < 0.0 and Vector2(step.x, step.z).length() > 0.001:
					latency = (Time.get_ticks_usec() - stamp) / 1000.0
					main.mark("motion", trial)
				max_yaw_error = maxf(max_yaw_error, maxf(absf(angle_difference(yaw, player.get_camera_yaw())), absf(angle_difference(yaw, player.camera_pivot.rotation.y))))
			Input.action_release("move_forward")
			var forward_step := player.global_position - origin
			var expected := Basis(Vector3.UP, yaw) * Vector3.FORWARD
			if Vector2(forward_step.x, forward_step.z).normalized().dot(Vector2(expected.x, expected.z)) <= 0.9:
				print("FORWARD_DIAGNOSTIC role=%s trial=%d origin=%s end=%s velocity=%s" % [role, trial, origin, player.global_position, player.velocity])
			require(Vector2(forward_step.x, forward_step.z).normalized().dot(Vector2(expected.x, expected.z)) > 0.9, "Forward movement disagrees with asymmetric camera heading")
			if pattern != "walk":
				require(peak_speed > 6.4, "Sprint must reach configured speed, not walk speed")
			var reversed_distance := 0.0
			if pattern == "reversal":
				var turn_position := player.global_position
				var reversal_stamp := Time.get_ticks_usec()
				main.mark("reverse", trial)
				Input.action_press("move_back")
				await create_timer(0.75).timeout
				main.mark("reverse_end", trial)
				Input.action_release("move_back")
				var reversed_step := player.global_position - turn_position
				reversed_distance = Vector2(reversed_step.x, reversed_step.z).dot(-Vector2(expected.x, expected.z))
				if reversed_distance <= 0.1 or Vector2(player.velocity.x, player.velocity.z).dot(-Vector2(expected.x, expected.z)) <= 6.4:
					print("REVERSAL_DIAGNOSTIC role=%s trial=%d origin=%s turn=%s end=%s velocity=%s grounded=%s collisions=%d distance=%f" % [role, trial, origin, turn_position, player.global_position, player.velocity, player.is_on_floor(), player.get_slide_collision_count(), reversed_distance])
					print("CONTACTS_DIAGNOSTIC " + JSON.stringify(main.contacts))
					print("REVERSAL_TIME_DIAGNOSTIC elapsed_ms=%f" % [(Time.get_ticks_usec() - reversal_stamp) / 1000.0])
					for index in player.get_slide_collision_count():
						print("COLLISION_DIAGNOSTIC collider=%s normal=%s" % [player.get_slide_collision(index).get_collider(), player.get_slide_collision(index).get_normal()])
				require(reversed_distance > 0.1 and Vector2(player.velocity.x, player.velocity.z).dot(-Vector2(expected.x, expected.z)) > 6.4, "Reversal must move and reach sprint speed in the opposite direction")
			Input.action_release("sprint")
			main.mark("release", trial)
			await create_timer(0.8).timeout
			max_yaw_error = maxf(max_yaw_error, maxf(absf(angle_difference(yaw, player.get_camera_yaw())), absf(angle_difference(yaw, player.camera_pivot.rotation.y))))
			var settled_error: float = player.global_position.distance_to(main.previous[id])
			require(settled_error < 0.05, "Stopped prediction must converge within 5 cm of authority")
			require(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Release must stop local movement")
			var displacement := player.global_position - origin
			var horizontal := Vector2(displacement.x, displacement.z)
			require(latency >= 0.0 and horizontal.length() > 0.1, "No horizontal motion in trial")
			if pattern != "reversal":
				require(horizontal.normalized().dot(Vector2(expected.x, expected.z)) > 0.9, "Movement disagrees with asymmetric camera heading")
			samples.append({"trial": trial, "pattern": pattern, "yaw": yaw, "ticks_latency_ms": latency, "peak_speed_mps": peak_speed, "reversed_distance_m": reversed_distance, "displacement_m": horizontal.length(), "settled_error_m": settled_error})
		require(max_yaw_error < 0.0001, "Camera changed after turn input stopped")
		for peer_id in main._player_nodes:
			require(float(main.travel.get(peer_id, 0.0)) > 0.1, "Both clients must observe movement of both peers")
		var gaps := []
		for i in range(1, main.arrivals.size()):
			gaps.append(main.arrivals[i] - main.arrivals[i - 1])
		require(main.rtts.size() >= trials - 1, "Insufficient measured RTT probes")
		require(main.corrections.size() >= 100, "Insufficient reconciliation measurements")
		print("MEASUREMENT " + JSON.stringify({"role": role, "id": id, "trials": samples, "ticks_rtt_ms": main.rtts, "ticks_snapshot_gaps_ms": gaps, "observed_travel_m": main.travel, "corrections_m": main.corrections, "max_camera_error_rad": max_yaw_error}))
		main.finished.rpc_id(1)
		main.set_process(false)
		main.set_physics_process(false)
		await create_timer(2.0).timeout
	print("LATENCY_OK " + role)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	quit(0)
