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
	var fixture := ""
	var fixture_ready := ""
	var fixture_armed := false
	var traversal_done := false
	var baseline_ready := {}
	var all_baselines_ready := false
	var trajectory := []
	var authoritative_trace := []
	var fixture_owner := 0
	var traversal := []
	var traversal_failures := []
	var sent_inputs := []
	var received_inputs := []
	var authority_inputs := []

	# Deterministic test-only geometry, NOT Toy Town stairs: elevated 24x24m
	# floor at y=30 and three 0.2m risers, 0.4m treads, 2m top landing.
	func install_fixture() -> void:
		fixture_box("TraversalFloor", Vector3(0, 29.5, 0), Vector3(24, 1, 24))
		for index in 3:
			fixture_box("TraversalStep%d" % index, Vector3(4, 30 + (index + 1) * 0.1, -1.2 - index * 0.4 - (0.8 if index == 2 else 0.0)), Vector3(3, (index + 1) * 0.2, 2.0 if index == 2 else 0.4))

	func fixture_box(label: String, location: Vector3, size: Vector3) -> void:
		var body := StaticBody3D.new()
		body.name = label
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.global_position = location

	@rpc("any_peer", "call_remote", "reliable")
	func baseline_finished() -> void:
		baseline_ready[multiplayer.get_remote_sender_id()] = true
		if baseline_ready.size() == 2:
			baselines_ready.rpc()

	@rpc("authority", "call_remote", "reliable")
	func baselines_ready() -> void:
		all_baselines_ready = true

	@rpc("any_peer", "call_remote", "reliable")
	func setup_fixture(kind: String) -> void:
		if not multiplayer.is_server():
			return
		fixture_owner = multiplayer.get_remote_sender_id()
		reset_fixture.rpc(kind, fixture_owner)

	@rpc("authority", "call_local", "reliable")
	func reset_fixture(kind: String, owner_id: int) -> void:
		fixture = kind
		fixture_armed = false
		measuring = false # Teleports and stale pre-setup snapshots are not corrections.
		trajectory.clear()
		contacts.clear()
		for id in _player_nodes:
			var position := Vector3(4 if kind == "stairs" else 0, 30.05, 0 if kind == "stairs" else 1)
			if id != owner_id:
				position = Vector3(0, 30.05, -0.5) if kind == "contact" else Vector3(-6, 30.05, 0)
			_player_nodes[id].reset_for_match(position)
		fixture_ready = kind

	@rpc("any_peer", "call_remote", "reliable")
	func arm_fixture() -> void:
		if multiplayer.is_server():
			begin_fixture.rpc()

	@rpc("authority", "call_local", "reliable")
	func begin_fixture() -> void:
		trajectory.clear()
		sent_inputs.clear()
		received_inputs.clear()
		fixture_armed = true
		measuring = measurement_role != "guest"

	@rpc("any_peer", "call_remote", "reliable")
	func trigger_knockdown() -> void:
		if multiplayer.is_server():
			_player_nodes[multiplayer.get_remote_sender_id()].apply_knockdown(Vector3.ZERO)

	@rpc("any_peer", "call_remote", "reliable")
	func fetch_trace() -> void:
		if multiplayer.is_server():
			print("TRAVERSAL_AUTHORITY " + JSON.stringify({"fixture": fixture, "trajectory": trajectory, "received_inputs": received_inputs}))
			receive_trace.rpc_id(multiplayer.get_remote_sender_id(), trajectory, received_inputs)

	@rpc("authority", "call_remote", "reliable")
	func receive_trace(samples: Array, inputs: Array) -> void:
		authoritative_trace = samples
		authority_inputs = inputs

	# Instrument, do not replace, the ordinary movement submission path.
	func submit_local_movement_input(direction: Vector2, sprinting: bool, crouched: bool, jump_pressed: bool, yaw: float) -> void:
		if fixture_armed:
			sent_inputs.append({"sequence": _local_movement_sequence + 1, "jump": jump_pressed})
		super.submit_local_movement_input(direction, sprinting, crouched, jump_pressed, yaw)

	@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
	func _submit_movement_input(direction: Vector2, sprinting: bool, crouched: bool, jump_pressed: bool, yaw: float, sequence: int, jump_sequence: int = -1) -> void:
		if fixture_armed and multiplayer.get_remote_sender_id() == fixture_owner:
			received_inputs.append({"sequence": sequence, "jump": jump_pressed, "jump_sequence": jump_sequence})
		super._submit_movement_input(direction, sprinting, crouched, jump_pressed, yaw, sequence, jump_sequence)

	@rpc("any_peer", "call_remote", "reliable")
	func end_traversal() -> void:
		if multiplayer.is_server():
			traversal_complete.rpc()

	@rpc("authority", "call_remote", "reliable")
	func traversal_complete() -> void:
		traversal_done = true

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
		if not fixture.is_empty():
			var observed := _player_nodes.get(fixture_owner if multiplayer.is_server() else multiplayer.get_unique_id()) as PartyPlayer
			if is_instance_valid(observed):
				var nearest_peer := 1000.0
				for other in _player_nodes.values():
					if other != observed:
						nearest_peer = minf(nearest_peer, observed.global_position.distance_to(other.global_position))
				trajectory.append({"ticks_ms": Time.get_ticks_usec() / 1000.0, "position": [observed.global_position.x, observed.global_position.y, observed.global_position.z], "velocity": [observed.velocity.x, observed.velocity.y, observed.velocity.z], "grounded": observed.is_on_floor(), "knocked_down": observed.is_knocked_down(), "nearest_peer_m": nearest_peer, "pending_inputs": observed._prediction_inputs.size(), "acknowledged_sequence": observed._last_movement_ack})
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
	var deadline := Time.get_ticks_msec() + 60000 + trials * 3000
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
	main.install_fixture()
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
			# A second independent unreliable probe keeps RTT evidence useful under
			# actual loss without relaxing the existing minimum sample assertion.
			var release_probe := Time.get_ticks_usec()
			main.mark("probe", release_probe)
			main.probe.rpc_id(1, release_probe)
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
		# Lost/reordered diagnostic probes are not gameplay failures. Collect the
		# same required minimum, with a bounded retry window; never relax the gate.
		var probe_deadline := Time.get_ticks_msec() + 3000
		while main.rtts.size() < trials - 1 and Time.get_ticks_msec() < probe_deadline:
			var extra_probe := Time.get_ticks_usec()
			main.mark("probe", extra_probe)
			main.probe.rpc_id(1, extra_probe)
			await create_timer(0.15).timeout
		require(main.rtts.size() >= trials - 1, "Insufficient measured RTT probes")
		require(main.corrections.size() >= 100, "Insufficient reconciliation measurements")
		main.measuring = false
		main.baseline_finished.rpc_id(1)
		if role == "owner":
			# Guest remains connected and stationary, with normal snapshot processing.
			await wait_for(func(): return main.all_baselines_ready)
			await run_traversal(player)
			main.end_traversal.rpc_id(1)
			await wait_for(func(): return main.traversal_done)
		else:
			await wait_for(func(): return main.traversal_done)
		print("MEASUREMENT " + JSON.stringify({"role": role, "id": id, "trials": samples, "ticks_rtt_ms": main.rtts, "ticks_snapshot_gaps_ms": gaps, "observed_travel_m": main.travel, "corrections_m": main.corrections, "max_camera_error_rad": max_yaw_error, "traversal": main.traversal}))
		main.finished.rpc_id(1)
		main.set_process(false)
		main.set_physics_process(false)
		await create_timer(2.0).timeout
	var exit_code := 0
	if not main.traversal_failures.is_empty():
		push_error("Traversal assertions failed: " + JSON.stringify(main.traversal_failures))
		exit_code = 1
	else:
		print("LATENCY_OK " + role)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_audio.reset_for_match()
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main.free()
	await process_frame
	quit(exit_code)

func run_traversal(player: PartyPlayer) -> void:
	for kind in ["jump", "stairs", "contact", "knockdown"]:
		main.measuring = false
		main.fixture_ready = ""
		main.setup_fixture.rpc_id(1, kind)
		await wait_for(func(): return main.fixture_ready == kind)
		player.set_camera_yaw(0.0)
		await create_timer(0.8).timeout
		require(player.is_on_floor(), "Fixture must start grounded")
		main.arm_fixture.rpc_id(1)
		await wait_for(func(): return main.fixture_armed)
		var origin := player.global_position
		var correction_start: int = main.corrections.size()
		if kind == "knockdown":
			main.trigger_knockdown.rpc_id(1)
			await wait_for(func(): return player.is_knocked_down())
		var input_stamp := Time.get_ticks_usec() / 1000.0
		Input.action_press("move_forward")
		if kind in ["jump", "stairs"]:
			Input.action_press("jump")
			await physics_frame
			await physics_frame
			Input.action_release("jump")
		await create_timer(2.8 if kind == "knockdown" else (0.95 if kind == "stairs" else 1.2)).timeout
		Input.action_release("move_forward")
		await create_timer(1.0).timeout
		main.authoritative_trace = []
		main.fetch_trace.rpc_id(1)
		await wait_for(func(): return not main.authoritative_trace.is_empty())
		var record := {"fixture": kind, "geometry": "deterministic elevated floor; three 0.2m risers/0.4m treads and 2m top landing (not Toy Town)", "local_trajectory": main.trajectory.duplicate(true), "authority_trajectory": main.authoritative_trace.duplicate(true), "corrections_m": main.corrections.slice(correction_start), "displacement_m": origin.distance_to(player.global_position), "settled_error_m": player.global_position.distance_to(main.previous[main.multiplayer.get_unique_id()])}
		record["sent_inputs"] = main.sent_inputs.duplicate(true)
		record["received_inputs"] = main.authority_inputs.duplicate(true)
		main.traversal.append(record)
		var assertions := []
		var check := func(ok: bool, message: String):
			assertions.append({"passed": ok, "assertion": message})
			if not ok:
				main.traversal_failures.append(kind + ": " + message)
		check.call(record.settled_error_m < 0.05, "Traversal must converge within 5 cm")
		check.call(player.is_on_floor() and not player.is_knocked_down(), "Traversal must finish grounded and recovered")
		check.call(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Release must stop local traversal movement")
		var local_peak := 30.0
		var response := -1.0
		for sample in main.trajectory:
			local_peak = maxf(local_peak, sample.position[1])
			if response < 0.0 and sample.ticks_ms >= input_stamp and Vector2(sample.position[0] - origin.x, sample.position[2] - origin.z).length() > 0.001:
				response = sample.ticks_ms - input_stamp
		record["ticks_response_ms"] = response
		if kind != "knockdown":
			check.call(response >= 0.0 and response <= 50.0, "Local traversal response must be within 50 ms")
		check.call(Vector2(player.global_position.x - origin.x, player.global_position.z - origin.z).normalized().dot(Vector2(0, -1)) > 0.9, "Traversal must preserve forward direction")
		var max_height := 30.0
		var saw_knockdown := false
		var knockdown_motion := 0.0
		var nearest_peer := 1000.0
		for sample in main.authoritative_trace:
			max_height = maxf(max_height, sample.position[1])
			saw_knockdown = saw_knockdown or sample.knocked_down
			if sample.knocked_down:
				knockdown_motion = maxf(knockdown_motion, Vector2(sample.velocity[0], sample.velocity[2]).length())
			nearest_peer = minf(nearest_peer, sample.nearest_peer_m)
		var last: Array = main.authoritative_trace.back().position
		if kind in ["jump", "stairs"]:
			check.call(max_height > 30.7 and local_peak > 30.7, "Authority and prediction must execute jump, not reject geometry")
			check.call(last[2] < -3.0, "Authority must traverse forward through fixture")
		if kind == "stairs":
			check.call(last[1] > 30.5, "Authority must land on top stair, not stop at riser")
		if kind == "contact":
			# Current player masks exclude layer 2: assert actual traversal through
			# the stationary peer, not pretend a body collision is supported.
			check.call(last[2] < -1.5, "Authority must pass stationary player's contact zone")
			check.call(nearest_peer < 0.56, "Authority must actually overlap peer capsule contact zone")
		if kind == "knockdown":
			check.call(saw_knockdown and last[2] < -1.0, "Authority must knock down then resume ordinary movement")
			check.call(knockdown_motion < 0.01, "Zero-impulse knockdown must reject movement until recovery")
		record["assertions"] = assertions
		print("TRAVERSAL " + JSON.stringify(record))
